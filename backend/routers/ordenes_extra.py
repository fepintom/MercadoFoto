"""
routers/ordenes_extra.py
========================
Dos cosas de "Mis órdenes":

1. Cancelar una compra o un servicio dentro de la PRIMERA HORA.
     POST /ordenes/{orden_id}/cancelar_compra   {"user_id": ...}
   Solo el comprador, solo si el pedido aún no sale (pendiente de pago o
   pago confirmado) y solo hasta 60 minutos después de creado. Si ya se
   pagó, se reembolsa (respetando el modo prueba) y se repone el stock.
   Pasada la hora el botón desaparece en la app y aquí se rechaza.

2. "Ver pago" de una venta:
     GET /ordenes/{orden_id}/pago?user_id=...
   Monto, comisión, neto, medio de pago del comprador (tarjeta, débito,
   dinero en cuenta…), cuándo se pagó y cuándo se le abona al vendedor.
   La cuenta de destino la muestra la app con los datos bancarios que el
   vendedor guardó en "Mi cuenta".
"""
import sqlite3
from datetime import datetime, timedelta
from typing import Optional

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from config import PUBLICACIONES_DB as DB

router = APIRouter()

MINUTOS_CANCELACION = 60
_CANCELABLES = ("pendiente_pago", "pago_confirmado")


def init_ordenes_extra_db():
    conn = sqlite3.connect(DB)
    try:
        conn.execute("ALTER TABLE ordenes ADD COLUMN mp_medio_pago TEXT")
    except sqlite3.OperationalError:
        pass
    conn.commit()
    conn.close()


def _orden(orden_id):
    conn = sqlite3.connect(DB)
    conn.row_factory = sqlite3.Row
    r = conn.execute("SELECT * FROM ordenes WHERE id = ?",
                     (orden_id,)).fetchone()
    conn.close()
    return dict(r) if r else None


def _fecha(ts) -> Optional[datetime]:
    if not ts:
        return None
    try:
        return datetime.strptime(str(ts)[:19], "%Y-%m-%d %H:%M:%S")
    except Exception:
        try:
            return datetime.fromisoformat(str(ts).replace("Z", ""))
        except Exception:
            return None


def cancelable_hasta(orden) -> Optional[datetime]:
    """Hasta cuándo (UTC) se puede cancelar, o None si ya no aplica."""
    if (orden.get("estado") or "") not in _CANCELABLES:
        return None
    creada = _fecha(orden.get("created_at"))
    if not creada:
        return None
    return creada + timedelta(minutes=MINUTOS_CANCELACION)


def _reponer_stock(publicacion_id):
    conn = sqlite3.connect(DB)
    r = conn.execute("SELECT stock, estado FROM publicaciones WHERE id = ?",
                     (publicacion_id,)).fetchone()
    if r:
        if r[0] is None:
            conn.execute("UPDATE publicaciones SET estado = 'disponible' "
                         "WHERE id = ? AND estado = 'vendido'",
                         (publicacion_id,))
        else:
            conn.execute("UPDATE publicaciones SET stock = COALESCE(stock,0)+1, "
                         "estado = CASE WHEN estado = 'vendido' THEN "
                         "'disponible' ELSE estado END WHERE id = ?",
                         (publicacion_id,))
    conn.commit()
    conn.close()


class Cancelacion(BaseModel):
    user_id: int
    motivo: Optional[str] = None


@router.post("/ordenes/{orden_id}/cancelar_compra")
def cancelar_compra(orden_id: int, data: Cancelacion):
    orden = _orden(orden_id)
    if not orden:
        raise HTTPException(404, "Orden no encontrada")
    if orden.get("comprador_id") != data.user_id:
        raise HTTPException(403, "Solo quien compró puede cancelar")
    hasta = cancelable_hasta(orden)
    if hasta is None:
        raise HTTPException(
            409, "Este pedido ya no se puede cancelar (ya está en camino o "
                 "terminado). Si hay un problema, repórtalo desde la orden.")
    if datetime.utcnow() > hasta:
        raise HTTPException(
            409, "Pasó la primera hora: la compra ya no se puede cancelar.")

    # Si ya se pagó, se devuelve la plata (en modo prueba se simula).
    reembolsado = False
    if orden.get("mp_payment_id"):
        try:
            from services.mp_service import reembolsar_pago_seguro
            reembolsar_pago_seguro(orden)
            reembolsado = True
        except Exception as e:
            raise HTTPException(502, f"No se pudo reembolsar el pago: {e}")

    conn = sqlite3.connect(DB)
    conn.execute("UPDATE ordenes SET estado = 'cancelado', "
                 "updated_at = CURRENT_TIMESTAMP WHERE id = ?", (orden_id,))
    conn.commit()
    conn.close()

    if orden.get("publicacion_id") and orden.get("stock_descontado"):
        try:
            _reponer_stock(orden["publicacion_id"])
        except Exception:
            pass

    try:
        from database.bitacora import registrar_evento
        registrar_evento(orden_id, "cancelada", actor_id=data.user_id,
                         detalle="cancelada por el comprador dentro de la "
                                 "primera hora"
                                 + (" (reembolsada)" if reembolsado else ""))
    except Exception:
        pass
    try:
        from database.notifications import crear_notificacion
        es_srv = orden.get("tipo") == "servicio"
        crear_notificacion(
            orden["vendedor_id"], "orden_cancelada",
            f"❌ {'El cliente canceló el servicio' if es_srv else 'El comprador canceló la compra'} "
            f"'{orden.get('titulo')}' dentro de la primera hora. "
            f"{'No debes despachar nada.' if not es_srv else ''}".strip(),
            orden_id=orden_id)
    except Exception:
        pass
    return {"ok": True, "estado": "cancelado", "reembolsado": reembolsado}


# ── Ver pago ────────────────────────────────────────────────────────────────

_MEDIOS = {
    "credit_card": "Tarjeta de crédito",
    "debit_card": "Tarjeta de débito",
    "prepaid_card": "Tarjeta de prepago",
    "account_money": "Dinero en cuenta Mercado Pago",
    "bank_transfer": "Transferencia bancaria",
    "ticket": "Pago en efectivo",
    "atm": "Cajero / efectivo",
}
_MARCAS = {"visa": "Visa", "master": "Mastercard", "amex": "American Express",
           "debvisa": "Visa Débito", "debmaster": "Mastercard Débito",
           "redcompra": "Redcompra", "magna": "Magna", "diners": "Diners"}


def _medio_pago(orden) -> str:
    if orden.get("mp_medio_pago"):
        return orden["mp_medio_pago"]
    pid = orden.get("mp_payment_id") or ""
    if not pid:
        return "Aún sin pagar"
    if orden.get("es_test") or pid.startswith("TEST-"):
        return "Pago de prueba"
    texto = "Mercado Pago"
    try:
        from services.mp_service import obtener_pago
        p = obtener_pago(pid)
        tipo = _MEDIOS.get(p.get("payment_type_id") or "", "Mercado Pago")
        marca = _MARCAS.get(p.get("payment_method_id") or "", "")
        ult = ((p.get("card") or {}).get("last_four_digits") or "")
        texto = tipo + (f" {marca}" if marca and marca not in tipo else "")
        if ult:
            texto += f" •••• {ult}"
        cuotas = p.get("installments") or 1
        if p.get("payment_type_id") == "credit_card" and cuotas > 1:
            texto += f" ({cuotas} cuotas)"
        conn = sqlite3.connect(DB)
        conn.execute("UPDATE ordenes SET mp_medio_pago = ? WHERE id = ?",
                     (texto, orden["id"]))
        conn.commit()
        conn.close()
    except Exception:
        pass
    return texto


_EVENTOS_ABONO = ("fondos_liberados_total", "fondos_liberados_parcial",
                  "recepcion_confirmada", "auto_confirmada", "entregado")


@router.get("/ordenes/{orden_id}/pago")
def ver_pago(orden_id: int, user_id: int):
    orden = _orden(orden_id)
    if not orden:
        raise HTTPException(404, "Orden no encontrada")
    if user_id not in (orden.get("vendedor_id"), orden.get("comprador_id")):
        raise HTTPException(403, "No es tu orden")

    eventos = {}
    try:
        conn = sqlite3.connect(DB)
        for ev, ts in conn.execute(
                "SELECT evento, created_at FROM ordenes_bitacora "
                "WHERE orden_id = ? ORDER BY id ASC", (orden_id,)):
            eventos.setdefault(ev, ts)
        conn.close()
    except sqlite3.OperationalError:
        pass

    monto = float(orden.get("monto") or 0)
    comision = float(orden.get("comision_okventa") or 0)
    estado = orden.get("estado")
    pagado_en = eventos.get("pago_confirmado") or (
        orden.get("updated_at") if orden.get("mp_payment_id") else None)

    # Cuándo se le abona al vendedor
    abonado_en = None
    if orden.get("tipo") == "servicio":
        abonado_en = orden.get("liberado_parcial_en") or orden.get(
            "liberado_total_en")
    for ev in _EVENTOS_ABONO:
        if not abonado_en and eventos.get(ev):
            abonado_en = eventos[ev]

    if estado in ("reembolsado", "cancelado"):
        estado_abono = "No corresponde: el pago se devolvió al comprador"
        abonado_en = None
    elif estado == "en_disputa":
        estado_abono = "Congelado por un reclamo del comprador"
    elif abonado_en:
        estado_abono = "Abonado"
    elif orden.get("mp_payment_id"):
        estado_abono = ("Retenido: se abona cuando el comprador confirme la "
                        "recepción" if orden.get("tipo") != "servicio" else
                        "Retenido: se abona el 80 % al confirmarse el servicio")
    else:
        estado_abono = "Pendiente: el comprador aún no paga"

    return {
        "orden_id": orden_id,
        "titulo": orden.get("titulo"),
        "tipo": orden.get("tipo"),
        "monto": round(monto, 2),
        "comision": round(comision, 2),
        "neto": round(monto - comision, 2),
        "monto_liberado": float(orden.get("monto_liberado") or 0),
        "monto_retenido": float(orden.get("monto_retenido") or 0),
        "medio_pago": _medio_pago(orden),
        "pagado_en": pagado_en,
        "abonado_en": abonado_en,
        "estado_abono": estado_abono,
        "operacion_mp": orden.get("mp_payment_id"),
        "es_test": bool(orden.get("es_test")),
    }
