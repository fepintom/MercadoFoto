"""
routers/okdelivery.py
======================
Flujo completo de entrega propia OkDelivery (tipo Uber/inDrive):

  1. Vendedor elige 'okventa' como método de entrega (endpoint existente
     PATCH /ordenes/{id}/entrega en main.py) -> se crea la fila en
     entregas_okdelivery y se notifica a los repartidores dentro del radio.
  2. Un repartidor acepta -> se activa el tracking en vivo.
  3. Retiro donde el vendedor: llegada, entrega física, foto + estado
     (ok / con observaciones). Si hay observaciones, el vendedor repara o
     se cancela la venta (con reembolso).
  4. Entrega al comprador: llegada, foto de entrega, arranca timer de 1h.
  5. El comprador confirma con video de unboxing (todo bien) o reporta un
     reclamo (texto + video) que abre una disputa. Si no responde en 1h,
     un worker externo cierra la venta automáticamente (ver
     scripts/run_delivery_worker.py y el endpoint /admin/okdelivery/cerrar_vencidas).

Notas de diseño (decisiones ya conversadas con el usuario):
  - Tracking en vivo = polling simple (el repartidor manda su ubicación
    cada 10-15s, comprador/vendedor consultan /okdelivery/{orden_id}/tracking).
    No hay WebSockets/Redis en este stack todavía.
  - Liberación de fondos = por ahora solo interna (se calcula y marca en
    la DB); la transferencia real al vendedor se hace manualmente fuera
    del sistema mientras no exista OAuth de MercadoPago por vendedor.
"""

import os
import secrets
import traceback
from typing import Optional

from fastapi import APIRouter, HTTPException, UploadFile, File, Form

from config import UPLOADS_DIR
from services.geo_service import distancia_km
from services.fcm_service import enviar_push
from services.mp_service import _comision_pct, reembolsar_pago as mp_reembolsar_pago

from database import entregas as db
from database.ordenes import (
    obtener_orden,
    confirmar_entrega as ordenes_confirmar_entrega,
    abrir_disputa,
    marcar_reembolsado,
)
from database.delivery import (
    obtener_perfil_delivery_por_id,
)
from database.publicaciones import obtener_publicacion_por_id
from database.users import obtener_ubicacion_usuario, obtener_fcm_token
from database.notifications import crear_notificacion

router = APIRouter()


# --------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------

def _guardar_archivo(upload: UploadFile, prefix: str) -> str:
    ext = os.path.splitext(upload.filename or "")[1].lower() or ".jpg"
    name = f"{prefix}_{secrets.token_hex(8)}{ext}"
    path = os.path.join(UPLOADS_DIR, name)
    with open(path, "wb") as f:
        f.write(upload.file.read())
    return f"/uploads/{name}"


def _notificar(user_id: int, tipo: str, titulo_push: str, cuerpo: str,
               orden_id: int, extra_data: Optional[dict] = None):
    """Push (si tiene token) + notificación en la campanita. Nunca rompe el flujo si falla."""
    data = {"tipo": tipo, "orden_id": str(orden_id)}
    if extra_data:
        data.update({k: str(v) for k, v in extra_data.items()})
    try:
        fcm_tok = obtener_fcm_token(user_id)
        if fcm_tok:
            enviar_push(fcm_tok, titulo_push, cuerpo, data)
    except Exception:
        pass
    try:
        crear_notificacion(user_id, tipo, cuerpo, orden_id=orden_id)
    except Exception:
        pass


def _orden_y_entrega(orden_id: int):
    orden = obtener_orden(orden_id)
    if not orden:
        raise HTTPException(status_code=404, detail="Orden no encontrada")
    entrega = db.obtener_entrega(orden_id)
    if not entrega:
        raise HTTPException(status_code=404, detail="Esta orden no tiene un flujo OkDelivery activo")
    return orden, entrega


def _liberar_fondos(orden: dict):
    """Cierra financieramente la venta: marca fondos liberados y actualiza la orden."""
    monto = float(orden.get("monto") or 0)
    comision = float(orden.get("comision_okventa") or round(monto * _comision_pct() / 100, 2))
    monto_vendedor = round(monto - comision, 2)
    db.liberar_fondos(orden["id"], monto_vendedor=monto_vendedor, monto_comision=comision)
    try:
        ordenes_confirmar_entrega(orden["id"])
    except Exception:
        pass
    _notificar(
        orden["vendedor_id"], "fondos_liberados",
        "🎉 Venta cerrada — fondos liberados",
        f"Se liberaron ${monto_vendedor:,.0f} por '{orden['titulo']}'. "
        f"Coordina con OkVenta la transferencia a tu cuenta.",
        orden["id"],
    )


# --------------------------------------------------------------------------
# Creación de la entrega (llamado desde main.py al elegir 'okventa')
# --------------------------------------------------------------------------

def crear_y_notificar_entrega(orden: dict, delivery_id_sugerido: int = None):
    """
    Crea la fila de entregas_okdelivery.

    Si el vendedor ya preseleccionó un repartidor específico (delivery_id_sugerido,
    elegido en la pantalla "Elegir entrega"), se notifica solo a ese repartidor.
    Si no, se hace broadcast a todos los repartidores activos dentro del radio
    de la ubicación de retiro (publicación o, si no tiene coordenadas, la
    ubicación del vendedor).
    """
    pickup_lat = pickup_lng = None
    if orden.get("publicacion_id"):
        pub = obtener_publicacion_por_id(orden["publicacion_id"])
        if pub:
            pickup_lat, pickup_lng = pub.get("lat"), pub.get("lng")

    if pickup_lat is None or pickup_lng is None:
        ubic_vendedor = obtener_ubicacion_usuario(orden["vendedor_id"])
        if ubic_vendedor:
            pickup_lat, pickup_lng = ubic_vendedor.get("lat"), ubic_vendedor.get("lng")

    ubic_comprador = obtener_ubicacion_usuario(orden["comprador_id"]) or {}
    destino_lat = ubic_comprador.get("lat")
    destino_lng = ubic_comprador.get("lng")

    db.crear_entrega(
        orden["id"],
        pickup_lat=pickup_lat, pickup_lng=pickup_lng,
        destino_lat=destino_lat, destino_lng=destino_lng,
    )

    if delivery_id_sugerido:
        rep = obtener_perfil_delivery_por_id(delivery_id_sugerido)
        if rep:
            _notificar(
                rep["user_id"], "okdelivery_disponible",
                "📦 Te seleccionaron para una entrega OkDelivery",
                f"'{orden['titulo']}' — el vendedor te eligió como repartidor",
                orden["id"],
            )
        return

    if pickup_lat is None or pickup_lng is None:
        # Sin coordenadas no podemos filtrar por radio; no hacemos broadcast automático.
        return

    from database.delivery import obtener_perfiles_delivery
    repartidores = obtener_perfiles_delivery(solo_activos=True)
    for rep in repartidores:
        if rep.get("lat") is None or rep.get("lng") is None:
            continue
        radio = rep.get("radio_km") or 5.0
        if distancia_km(pickup_lat, pickup_lng, rep["lat"], rep["lng"]) <= radio:
            _notificar(
                rep["user_id"], "okdelivery_disponible",
                "📦 Nueva entrega OkDelivery disponible",
                f"'{orden['titulo']}' — retiro cerca de ti",
                orden["id"],
            )


# --------------------------------------------------------------------------
# Repartidor: descubrir y aceptar
# --------------------------------------------------------------------------

@router.get("/okdelivery/pendientes/{delivery_id}")
def pendientes_para_repartidor(delivery_id: int):
    perfil = obtener_perfil_delivery_por_id(delivery_id)
    if not perfil:
        raise HTTPException(status_code=404, detail="Perfil de delivery no encontrado")

    resultado = []
    for e in db.obtener_entregas_buscando():
        if e["pickup_lat"] is None or e["pickup_lng"] is None:
            continue
        radio = perfil.get("radio_km") or 5.0
        d = distancia_km(e["pickup_lat"], e["pickup_lng"], perfil["lat"], perfil["lng"])
        if perfil.get("lat") is not None and d <= radio:
            orden = obtener_orden(e["orden_id"])
            resultado.append({**e, "distancia_km": round(d, 2),
                               "titulo": orden["titulo"] if orden else None,
                               "monto": orden["monto"] if orden else None})
    resultado.sort(key=lambda x: x["distancia_km"])
    return resultado


@router.get("/okdelivery/repartidor/{delivery_id}/activas")
def entregas_activas_repartidor(delivery_id: int):
    """Entregas en curso de este repartidor (para retomar el flujo si cierra la app)."""
    resultado = []
    for e in db.obtener_entregas_pendientes_repartidor(delivery_id):
        orden = obtener_orden(e["orden_id"])
        resultado.append({**e, "titulo": orden["titulo"] if orden else None,
                           "monto": orden["monto"] if orden else None})
    return resultado


@router.post("/okdelivery/{orden_id}/aceptar")
def aceptar_entrega(orden_id: int, body: dict):
    delivery_id = body.get("delivery_id")
    if not delivery_id:
        raise HTTPException(status_code=400, detail="delivery_id requerido")

    orden, entrega = _orden_y_entrega(orden_id)
    if entrega["estado"] != "buscando_repartidor":
        raise HTTPException(status_code=409, detail="Esta entrega ya fue tomada por otro repartidor")

    db.asignar_repartidor(orden_id, delivery_id)
    _notificar(orden["vendedor_id"], "okdelivery_asignado",
               "🛵 Repartidor asignado",
               "Un repartidor OkDelivery viene en camino a retirar tu producto",
               orden_id)
    return {"ok": True, "estado": "asignado"}


# --------------------------------------------------------------------------
# Tracking en vivo
# --------------------------------------------------------------------------

@router.post("/okdelivery/{orden_id}/ubicacion")
def actualizar_ubicacion(orden_id: int, body: dict):
    lat = body.get("lat")
    lng = body.get("lng")
    if lat is None or lng is None:
        raise HTTPException(status_code=400, detail="lat/lng requeridos")
    entrega = db.obtener_entrega(orden_id)
    if not entrega:
        raise HTTPException(status_code=404, detail="Entrega no encontrada")
    nuevo_estado = db.actualizar_ubicacion_repartidor(orden_id, lat, lng)
    return {"ok": True, "estado": nuevo_estado}


@router.get("/okdelivery/{orden_id}/tracking")
def tracking(orden_id: int):
    entrega = db.obtener_entrega(orden_id)
    if not entrega:
        raise HTTPException(status_code=404, detail="Entrega no encontrada")
    return {
        "estado": entrega["estado"],
        "delivery_lat": entrega["delivery_lat"],
        "delivery_lng": entrega["delivery_lng"],
        "actualizado_at": entrega["ubicacion_actualizada_at"],
    }


@router.get("/okdelivery/{orden_id}")
def detalle_entrega(orden_id: int):
    entrega = db.obtener_entrega(orden_id)
    if not entrega:
        raise HTTPException(status_code=404, detail="Entrega no encontrada")
    orden = obtener_orden(orden_id)
    if orden:
        entrega = {**entrega, "titulo": orden["titulo"], "monto": orden["monto"],
                   "vendedor_id": orden["vendedor_id"], "comprador_id": orden["comprador_id"]}
    return entrega


# --------------------------------------------------------------------------
# Retiro donde el vendedor
# --------------------------------------------------------------------------

@router.post("/okdelivery/{orden_id}/llegue_retiro")
def llegue_retiro(orden_id: int):
    orden, entrega = _orden_y_entrega(orden_id)
    db.marcar_llegada_retiro(orden_id)
    _notificar(orden["vendedor_id"], "okdelivery_llego",
               "🛵 Tu repartidor llegó",
               "El repartidor OkDelivery llegó. Entrégale el producto en la app.",
               orden_id)
    return {"ok": True, "estado": "llegado_retiro"}


@router.post("/ventas/{orden_id}/entregue_a_delivery")
def entregue_a_delivery(orden_id: int):
    orden, entrega = _orden_y_entrega(orden_id)
    if entrega["estado"] != "llegado_retiro":
        raise HTTPException(status_code=409, detail=f"Estado actual '{entrega['estado']}' no permite esta acción")
    db.marcar_entrega_del_vendedor(orden_id)
    if entrega.get("delivery_id"):
        rep = obtener_perfil_delivery_por_id(entrega["delivery_id"])
        if rep:
            _notificar(rep["user_id"], "okdelivery_confirmar_recepcion",
                       "📸 Confirma que recibiste el producto",
                       "Saca una foto y marca el estado del producto",
                       orden_id)
    return {"ok": True, "estado": "esperando_confirmacion_calidad"}


@router.post("/okdelivery/{orden_id}/confirmar_recepcion")
async def confirmar_recepcion_repartidor(
    orden_id: int,
    estado_producto: str = Form(...),  # 'ok' | 'con_observaciones'
    observaciones: Optional[str] = Form(None),
    foto: UploadFile = File(...),
):
    orden, entrega = _orden_y_entrega(orden_id)
    if estado_producto not in ("ok", "con_observaciones"):
        raise HTTPException(status_code=400, detail="estado_producto inválido")

    foto_url = _guardar_archivo(foto, "okdelivery_retiro")
    db.confirmar_recepcion_repartidor(orden_id, foto_url, estado_producto, observaciones)

    if estado_producto == "ok":
        _notificar(orden["comprador_id"], "okdelivery_en_camino",
                   "🚚 Tu producto viene en camino",
                   f"'{orden['titulo']}' fue retirado y está en camino",
                   orden_id)
        return {"ok": True, "estado": "en_camino_entrega"}

    _notificar(orden["vendedor_id"], "okdelivery_observaciones",
               "⚠️ El repartidor reportó un problema",
               f"Observación: {observaciones or 'sin detalle'}. Debes repararlo o se cancela la venta.",
               orden_id)
    return {"ok": True, "estado": "observaciones_reportadas"}


@router.post("/ventas/{orden_id}/reparar")
def reparar(orden_id: int):
    orden, entrega = _orden_y_entrega(orden_id)
    if entrega["estado"] != "observaciones_reportadas":
        raise HTTPException(status_code=409, detail=f"Estado actual '{entrega['estado']}' no permite esta acción")
    db.marcar_reparacion_reportada(orden_id)
    if entrega.get("delivery_id"):
        rep = obtener_perfil_delivery_por_id(entrega["delivery_id"])
        if rep:
            _notificar(rep["user_id"], "okdelivery_verificar_reparacion",
                       "🔧 El vendedor indica que reparó el producto",
                       "Verifica en persona y confirma para continuar la entrega",
                       orden_id)
    return {"ok": True, "estado": "reparacion_reportada"}


@router.post("/okdelivery/{orden_id}/confirmar_reparacion")
def confirmar_reparacion(orden_id: int):
    orden, entrega = _orden_y_entrega(orden_id)
    if entrega["estado"] != "reparacion_reportada":
        raise HTTPException(status_code=409, detail=f"Estado actual '{entrega['estado']}' no permite esta acción")
    db.confirmar_reparacion(orden_id)
    _notificar(orden["comprador_id"], "okdelivery_en_camino",
               "🚚 Tu producto viene en camino",
               f"'{orden['titulo']}' está en camino",
               orden_id)
    return {"ok": True, "estado": "en_camino_entrega"}


@router.post("/ventas/{orden_id}/no_reparar")
def no_reparar(orden_id: int):
    orden, entrega = _orden_y_entrega(orden_id)
    if entrega["estado"] not in ("observaciones_reportadas", "reparacion_reportada"):
        raise HTTPException(status_code=409, detail=f"Estado actual '{entrega['estado']}' no permite esta acción")

    db.cancelar_sin_reparar(orden_id)
    try:
        if orden.get("mp_payment_id"):
            mp_reembolsar_pago(orden["mp_payment_id"])
        marcar_reembolsado(orden_id)
    except Exception:
        traceback.print_exc()

    _notificar(orden["comprador_id"], "venta_cancelada",
               "❌ Venta cancelada",
               f"'{orden['titulo']}' no pudo repararse. Tu pago fue reembolsado.",
               orden_id)
    if entrega.get("delivery_id"):
        rep = obtener_perfil_delivery_por_id(entrega["delivery_id"])
        if rep:
            _notificar(rep["user_id"], "venta_cancelada",
                       "❌ Venta cancelada",
                       "Puedes devolver el producto al vendedor. La entrega quedó cerrada.",
                       orden_id)
    return {"ok": True, "estado": "cancelado_sin_reparar"}


# --------------------------------------------------------------------------
# Entrega al comprador
# --------------------------------------------------------------------------

@router.post("/okdelivery/{orden_id}/llegue_entrega")
def llegue_entrega(orden_id: int):
    orden, entrega = _orden_y_entrega(orden_id)
    db.marcar_llegada_entrega(orden_id)
    _notificar(orden["comprador_id"], "okdelivery_llego",
               "🛵 Tu repartidor llegó",
               "El repartidor OkDelivery llegó con tu pedido",
               orden_id)
    return {"ok": True, "estado": "llegado_entrega"}


@router.post("/okdelivery/{orden_id}/confirmar_entrega")
async def confirmar_entrega_comprador(orden_id: int, foto: UploadFile = File(...)):
    orden, entrega = _orden_y_entrega(orden_id)
    foto_url = _guardar_archivo(foto, "okdelivery_entrega")
    db.confirmar_entrega_comprador(orden_id, foto_url)
    _notificar(
        orden["comprador_id"], "okdelivery_confirmar_recepcion",
        "📦 Confirma la recepción de tu producto",
        "Graba un video de unboxing sin cortes. Tienes 1 hora para confirmar o reportar un problema.",
        orden_id,
    )
    return {"ok": True, "estado": "entregado_pendiente_confirmacion"}


# --------------------------------------------------------------------------
# Confirmación del comprador
# --------------------------------------------------------------------------

@router.post("/compras/{orden_id}/confirmar_recepcion")
async def confirmar_recepcion_comprador(orden_id: int, video: Optional[UploadFile] = File(None)):
    orden, entrega = _orden_y_entrega(orden_id)
    if entrega["estado"] != "entregado_pendiente_confirmacion":
        raise HTTPException(status_code=409, detail=f"Estado actual '{entrega['estado']}' no permite esta acción")

    video_url = _guardar_archivo(video, "okdelivery_unboxing") if video and video.filename else None
    db.confirmar_recepcion_comprador(orden_id, video_url=video_url)
    _liberar_fondos(orden)
    return {"ok": True, "estado": "cerrado_ok"}


@router.post("/compras/{orden_id}/reclamo")
async def reclamo_comprador(
    orden_id: int,
    texto: str = Form(...),
    video: UploadFile = File(...),
):
    orden, entrega = _orden_y_entrega(orden_id)
    if entrega["estado"] != "entregado_pendiente_confirmacion":
        raise HTTPException(status_code=409, detail=f"Estado actual '{entrega['estado']}' no permite esta acción")
    if len(texto) > 500:
        raise HTTPException(status_code=400, detail="El texto debe tener máximo 500 caracteres")

    video_url = _guardar_archivo(video, "okdelivery_reclamo")
    db.reportar_reclamo_comprador(orden_id, texto, video_url)
    abrir_disputa(orden_id)

    crear_notificacion(1, "disputa", f"⚠️ Reclamo OkDelivery en orden #{orden_id}: {texto[:120]}", orden_id=orden_id)
    _notificar(orden["vendedor_id"], "disputa",
               "⚠️ El comprador reportó un problema",
               f"Reclamo en '{orden['titulo']}': {texto[:120]}",
               orden_id)
    return {"ok": True, "estado": "cerrado_con_reclamo"}


# --------------------------------------------------------------------------
# Worker de auto-cierre (llamado por scripts/run_delivery_worker.py)
# --------------------------------------------------------------------------

@router.post("/admin/okdelivery/cerrar_vencidas")
def cerrar_vencidas(token: str = "", minutos: int = 60):
    secret = os.environ.get("ADMIN_TOKEN", "okventa-admin-2026")
    if token != secret:
        raise HTTPException(status_code=403, detail="Token inválido")

    cerradas = []
    for e in db.obtener_entregas_vencidas(minutos=minutos):
        orden = obtener_orden(e["orden_id"])
        if not orden:
            continue
        try:
            db.confirmar_recepcion_comprador(e["orden_id"], video_url=None, por_timeout=True)
            _liberar_fondos(orden)
            cerradas.append(e["orden_id"])
        except Exception:
            traceback.print_exc()

    return {"ok": True, "cerradas": cerradas, "total": len(cerradas)}
