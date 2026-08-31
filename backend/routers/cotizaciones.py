"""
routers/cotizaciones.py
=======================
Cotizaciones de servicios enviadas por el chat.

Flujo:
  1. El proveedor envía la cotización desde el chat del servicio
     POST /cotizaciones            -> crea la fila, genera el PDF con el
                                      formato estándar y lo publica como un
                                      mensaje de tipo 'cotizacion' en el chat
  2. El cliente la ve en el chat con la botonera aceptar / rechazar
     POST /cotizaciones/{id}/aceptar
     POST /cotizaciones/{id}/rechazar
  3. Al aceptar se crea la orden y se cobra reutilizando exactamente el mismo
     camino de pago que "Contratar y pagar" — no hay una segunda
     implementación de pagos.
  4. Al aprobarse el pago entra el Seguro Garantía: 80% al proveedor y 20%
     retenido 30 días (se aplica en _procesar_pago_aprobado, main.py).

Autorización: como en el resto del proyecto no hay JWT, se recibe el
user_id y se compara contra el dueño de la fila. Acá va obligatorio para
que no se pueda saltar omitiéndolo.
"""
from fastapi import APIRouter, Form, HTTPException

from database import cotizaciones as db
from database.chat import guardar_mensaje
from database.ordenes import crear_orden, obtener_orden
from database.servicios import obtener_servicio_por_id
from database.users import obtener_usuario_por_id
from services.cotizacion_service import generar_pdf_cotizacion
from services.mp_service import _comision_pct, crear_preferencia, test_mode

router = APIRouter()

MONTO_MAXIMO = 50_000_000


def _nombre(user_id: int) -> str:
    u = obtener_usuario_por_id(user_id) or {}
    return (u.get("nombre") or "").strip()


@router.post("/cotizaciones")
def enviar_cotizacion(
    servicio_id: int = Form(...),
    proveedor_id: int = Form(...),
    cliente_id: int = Form(...),
    servicio_cotizado: str = Form(...),
    monto: float = Form(...),
    detalle: str = Form(""),
    empresa: str = Form(""),
):
    servicio = obtener_servicio_por_id(servicio_id)
    if not servicio:
        raise HTTPException(status_code=404, detail="Servicio no encontrado")
    if servicio.get("user_id") != proveedor_id:
        raise HTTPException(
            status_code=403,
            detail="Solo quien publicó el servicio puede cotizarlo")
    if monto <= 0 or monto > MONTO_MAXIMO:
        raise HTTPException(status_code=400, detail="El monto no es válido")
    if not servicio_cotizado.strip():
        raise HTTPException(status_code=400, detail="Falta el servicio cotizado")

    cotizacion_id = db.crear_cotizacion(
        servicio_id=servicio_id,
        proveedor_id=proveedor_id,
        cliente_id=cliente_id,
        empresa=empresa or servicio.get("titulo", ""),
        servicio_cotizado=servicio_cotizado,
        monto=monto,
        detalle=detalle,
    )
    cotizacion = db.obtener_cotizacion(cotizacion_id)

    # El PDF es un adjunto: si falla, la cotización igual se envía y se puede
    # aceptar. Mejor una cotización sin documento que un chat roto.
    pdf_url = generar_pdf_cotizacion(
        cotizacion,
        nombre_proveedor=_nombre(proveedor_id),
        nombre_cliente=_nombre(cliente_id),
    )
    if pdf_url:
        db.guardar_pdf(cotizacion_id, pdf_url)
        cotizacion["pdf_url"] = pdf_url

    guardar_mensaje(
        publicacion_id=None,
        servicio_id=servicio_id,
        remitente_id=proveedor_id,
        mensaje=f"Cotización: {servicio_cotizado}",
        tipo="cotizacion",
        cotizacion_id=cotizacion_id,
    )
    return {"ok": True, "cotizacion": cotizacion}


@router.get("/cotizaciones/{cotizacion_id}")
def obtener(cotizacion_id: int):
    c = db.obtener_cotizacion(cotizacion_id)
    if not c:
        raise HTTPException(status_code=404, detail="Cotización no encontrada")
    return c


@router.post("/cotizaciones/{cotizacion_id}/rechazar")
def rechazar(cotizacion_id: int, user_id: int = Form(...)):
    c = db.obtener_cotizacion(cotizacion_id)
    if not c:
        raise HTTPException(status_code=404, detail="Cotización no encontrada")
    if c["cliente_id"] != user_id:
        raise HTTPException(status_code=403, detail="No autorizado")
    if not db.responder(cotizacion_id, "rechazada"):
        raise HTTPException(status_code=409, detail="Ya fue respondida")

    guardar_mensaje(
        publicacion_id=None,
        servicio_id=c["servicio_id"],
        remitente_id=user_id,
        mensaje="Cotización rechazada",
        tipo="texto",
    )
    return {"ok": True, "estado": "rechazada"}


@router.post("/cotizaciones/{cotizacion_id}/aceptar")
def aceptar(cotizacion_id: int, user_id: int = Form(...),
            comprador_email: str = Form("")):
    """Acepta la cotización, crea la orden y arranca el cobro.

    Reutiliza el mismo camino de pago que 'Contratar y pagar':
    `_procesar_pago_aprobado` cuando estamos en modo prueba, o una
    preferencia real de MercadoPago cuando no. La importación de main va
    dentro de la función a propósito: main importa este router, así que a
    nivel de módulo sería un import circular.
    """
    from main import _procesar_pago_aprobado  # noqa: PLC0415  (ver docstring)
    import time

    c = db.obtener_cotizacion(cotizacion_id)
    if not c:
        raise HTTPException(status_code=404, detail="Cotización no encontrada")
    if c["cliente_id"] != user_id:
        raise HTTPException(status_code=403, detail="No autorizado")
    if c["estado"] != "enviada":
        raise HTTPException(status_code=409, detail="Ya fue respondida")

    monto = float(c["monto"])
    comision = round(monto * _comision_pct() / 100, 2)
    modo_test = test_mode()

    orden_id = crear_orden(
        comprador_id=c["cliente_id"],
        vendedor_id=c["proveedor_id"],
        tipo="servicio",
        titulo=c["servicio_cotizado"],
        monto=monto,
        publicacion_id=None,
        servicio_id=c["servicio_id"],
        comision=comision,
        es_test=modo_test,
    )
    db.responder(cotizacion_id, "aceptada", orden_id=orden_id)

    guardar_mensaje(
        publicacion_id=None,
        servicio_id=c["servicio_id"],
        remitente_id=user_id,
        mensaje="Cotización aceptada",
        tipo="texto",
    )

    orden = obtener_orden(orden_id)

    if modo_test:
        _procesar_pago_aprobado(orden, f"TEST-{orden_id}-{int(time.time())}")
        return {
            "ok": True,
            "orden_id": orden_id,
            "test_mode": True,
            "estado": "pago_confirmado",
            "mensaje": "Pago simulado (modo prueba). No se realizó ningún "
                       "cobro real.",
        }

    try:
        pref = crear_preferencia(
            orden_id=orden_id,
            titulo=c["servicio_cotizado"],
            monto=monto,
            comprador_email=comprador_email,
        )
    except Exception as e:
        raise HTTPException(status_code=502,
                            detail=f"No se pudo iniciar el pago: {e}")

    return {
        "ok": True,
        "orden_id": orden_id,
        "test_mode": False,
        "init_point": pref.get("init_point") or pref.get("sandbox_init_point"),
        "preference_id": pref.get("preference_id"),
    }
