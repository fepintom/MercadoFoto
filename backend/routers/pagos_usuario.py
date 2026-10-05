"""
routers/pagos_usuario.py
========================
"Mis pagos": la bitácora de los pagos que ha recibido un vendedor o
proveedor.

  GET /usuarios/{user_id}/pagos

Arma, por cada orden pagada en la que el usuario es el vendedor:
  - monto que pagó el comprador, comisión de OkVenta y neto para él,
  - en qué estado está su plata:
      liberado     ya le corresponde (producto entregado / servicio liberado)
      retenido     pagado por el comprador, en garantía hasta que confirme la
                   recepción (productos) o hasta 30 días (20% de servicios)
      en_disputa   congelado por un reclamo
      reembolsado  se devolvió al comprador: no se paga
  - los hitos de la bitácora (pago, entrega, confirmación, liberación...).

Es contabilidad interna, igual que el resto del sistema de fondos: dice
cuánto corresponde y desde cuándo; la transferencia se coordina aparte.
"""
import sqlite3

from fastapi import APIRouter

from config import PUBLICACIONES_DB as DB

router = APIRouter()

# Estados de orden en los que el comprador ya pagó.
_PAGADAS = ("pago_confirmado", "en_camino", "entrega_reportada", "entregado",
            "en_disputa", "reembolsado")

# Hitos de la bitácora que tienen que ver con la plata, con su texto.
_HITOS = {
    "pago_confirmado": "Pago recibido (queda retenido)",
    "entrega_reportada": "Entrega reportada",
    "recepcion_confirmada": "El comprador confirmó la recepción",
    "auto_confirmada": "Confirmada automáticamente a las 48 h",
    "entregado": "Entrega cerrada",
    "fondos_liberados_total": "Se liberó el saldo retenido",
    "disputa_abierta": "El comprador abrió un reclamo",
    "garantia_reclamada": "Se reclamó la garantía",
    "cancelada": "Orden cancelada",
}


def _f(v):
    try:
        return round(float(v or 0), 2)
    except Exception:
        return 0.0


def _estado_y_montos(o):
    neto = round(_f(o.get("monto")) - _f(o.get("comision_okventa")), 2)
    estado = o.get("estado")
    if estado == "reembolsado":
        return "reembolsado", 0.0, 0.0
    if estado == "en_disputa":
        return "en_disputa", 0.0, neto
    if o.get("tipo") == "servicio":
        liberado = _f(o.get("monto_liberado"))
        retenido = _f(o.get("monto_retenido"))
        if liberado == 0 and retenido == 0:
            return "retenido", 0.0, neto
        return ("liberado" if retenido == 0 else "parcial"), liberado, retenido
    if estado == "entregado":
        return "liberado", neto, 0.0
    return "retenido", 0.0, neto


@router.get("/usuarios/{user_id}/pagos")
def mis_pagos(user_id: int):
    conn = sqlite3.connect(DB)
    conn.row_factory = sqlite3.Row
    marcas = ",".join("?" * len(_PAGADAS))
    ordenes = [dict(r) for r in conn.execute(f"""
        SELECT o.*, uc.nombre AS nombre_comprador, p.imagen_url AS foto_producto
        FROM ordenes o
        LEFT JOIN users uc ON uc.id = o.comprador_id
        LEFT JOIN publicaciones p ON p.id = o.publicacion_id
        WHERE o.vendedor_id = ? AND o.estado IN ({marcas})
        ORDER BY o.created_at DESC
    """, (user_id, *_PAGADAS)).fetchall()]

    hitos_por_orden = {}
    if ordenes:
        ids = [o["id"] for o in ordenes]
        try:
            filas = conn.execute(f"""
                SELECT orden_id, evento, created_at FROM ordenes_bitacora
                WHERE orden_id IN ({",".join("?" * len(ids))})
                ORDER BY created_at ASC, id ASC
            """, ids).fetchall()
        except sqlite3.OperationalError:
            filas = []  # sin tabla de bitácora todavía
        for f in filas:
            if f["evento"] in _HITOS:
                hitos_por_orden.setdefault(f["orden_id"], []).append(
                    {"evento": f["evento"], "texto": _HITOS[f["evento"]],
                     "fecha": f["created_at"]})
    conn.close()

    resumen = {"liberado": 0.0, "retenido": 0.0, "en_disputa": 0.0,
               "comisiones": 0.0}
    movimientos = []
    for o in ordenes:
        estado_pago, liberado, retenido = _estado_y_montos(o)
        es_test = bool(o.get("es_test"))
        if not es_test:
            resumen["liberado"] += liberado
            if estado_pago == "en_disputa":
                resumen["en_disputa"] += retenido
            else:
                resumen["retenido"] += retenido
            if estado_pago != "reembolsado":
                resumen["comisiones"] += _f(o.get("comision_okventa"))
        movimientos.append({
            "orden_id": o["id"],
            "tipo": o.get("tipo"),
            "titulo": o.get("titulo"),
            "foto": o.get("foto_producto"),
            "comprador": o.get("nombre_comprador"),
            "monto": _f(o.get("monto")),
            "comision": _f(o.get("comision_okventa")),
            "neto": round(_f(o.get("monto")) - _f(o.get("comision_okventa")), 2),
            "estado_pago": estado_pago,
            "liberado": liberado,
            "retenido": retenido,
            "es_test": es_test,
            "fecha": o.get("created_at"),
            "hitos": hitos_por_orden.get(o["id"], []),
        })
    resumen = {k: round(v, 2) for k, v in resumen.items()}
    return {"resumen": resumen, "movimientos": movimientos}
