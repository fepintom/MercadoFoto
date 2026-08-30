"""
routers/verificacion_paquete.py
================================
Antifraude de envíos: sellos de seguridad numerados + verificación por IA
comparando fotogramas clave del packing (vendedor) vs. el unboxing
(comprador).

  1. Al generar la etiqueta de envío se crean (una sola vez) los 4 códigos
     de sello para la orden -> GET /ordenes/{id}/sellos
  2. El vendedor graba el embalaje (con rejilla en cámara para encuadrar el
     paquete); la app extrae unos pocos fotogramas clave y los sube ->
     POST /ordenes/{id}/boxing-frames
  3. El comprador, al recibir, graba el unboxing con la misma rejilla; la
     app extrae fotogramas clave y los sube ->
     POST /ordenes/{id}/unboxing-frames
  4. El comprador presiona "Analizar" -> POST /ordenes/{id}/analizar-empaque
     compara ambos grupos con GPT-4o Vision y devuelve el veredicto.
  5. Al confirmarse la entrega (por cualquiera de las 3 vías existentes:
     foto, QR o flujo OkDelivery) se llama a eliminar_verificacion_paquete
     para borrar los fotogramas de disco y la fila de la base — nunca se
     guarda el video completo, solo estos fotogramas, y ni siquiera esos
     sobreviven al cierre de la compra.
"""
import os
import secrets
from typing import List

from fastapi import APIRouter, HTTPException, UploadFile, File

from config import UPLOADS_DIR
from database.ordenes import obtener_orden
from database import verificacion_paquete as db
from services.tamper_vision_service import analizar_empaque

router = APIRouter()


def _guardar_frame(upload: UploadFile, prefix: str) -> str:
    ext = os.path.splitext(upload.filename or "")[1].lower() or ".jpg"
    name = f"{prefix}_{secrets.token_hex(8)}{ext}"
    path = os.path.join(UPLOADS_DIR, name)
    with open(path, "wb") as f:
        f.write(upload.file.read())
    return f"/uploads/{name}"


def _ruta_a_path(ruta: str) -> str:
    """'/uploads/xxx.jpg' -> ruta absoluta en disco."""
    nombre = ruta.rsplit("/", 1)[-1]
    return os.path.join(UPLOADS_DIR, nombre)


@router.get("/ordenes/{orden_id}/sellos")
def obtener_sellos(orden_id: int):
    orden = obtener_orden(orden_id)
    if not orden:
        raise HTTPException(status_code=404, detail="Orden no encontrada")
    sellos = db.obtener_o_crear_sellos(orden_id)
    return {"orden_id": orden_id, "sellos": sellos}


@router.post("/ordenes/{orden_id}/boxing-frames")
async def subir_boxing_frames(orden_id: int, frames: List[UploadFile] = File(...)):
    orden = obtener_orden(orden_id)
    if not orden:
        raise HTTPException(status_code=404, detail="Orden no encontrada")
    if not frames:
        raise HTTPException(status_code=400, detail="No se recibieron fotogramas")
    urls = [_guardar_frame(f, f"boxing_{orden_id}") for f in frames]
    db.guardar_boxing_frames(orden_id, urls)
    return {"ok": True, "frames": urls}


@router.post("/ordenes/{orden_id}/unboxing-frames")
async def subir_unboxing_frames(orden_id: int, frames: List[UploadFile] = File(...)):
    orden = obtener_orden(orden_id)
    if not orden:
        raise HTTPException(status_code=404, detail="Orden no encontrada")
    if not frames:
        raise HTTPException(status_code=400, detail="No se recibieron fotogramas")
    urls = [_guardar_frame(f, f"unboxing_{orden_id}") for f in frames]
    db.guardar_unboxing_frames(orden_id, urls)
    return {"ok": True, "frames": urls}


@router.post("/ordenes/{orden_id}/analizar-empaque")
async def analizar_empaque_endpoint(orden_id: int):
    orden = obtener_orden(orden_id)
    if not orden:
        raise HTTPException(status_code=404, detail="Orden no encontrada")

    verificacion = db.obtener_verificacion(orden_id)
    if not verificacion:
        raise HTTPException(
            status_code=400,
            detail="Todavía no hay fotogramas de embalaje ni de unboxing para esta orden")

    boxing_urls = verificacion.get("boxing_frames") or []
    unboxing_urls = verificacion.get("unboxing_frames") or []
    if not boxing_urls:
        raise HTTPException(
            status_code=400,
            detail="El vendedor todavía no registró el video de embalaje")
    if not unboxing_urls:
        raise HTTPException(
            status_code=400,
            detail="Primero graba el unboxing antes de analizar")

    def _leer(rutas):
        datos = []
        for r in rutas:
            path = _ruta_a_path(r)
            if os.path.exists(path):
                with open(path, "rb") as fh:
                    datos.append(fh.read())
        return datos

    boxing_bytes = _leer(boxing_urls)
    unboxing_bytes = _leer(unboxing_urls)

    resultado = analizar_empaque(boxing_bytes, unboxing_bytes)
    db.guardar_resultado_analisis(
        orden_id,
        "ok" if resultado["ok"] else "alerta",
        resultado["mensaje"],
    )
    return resultado


def eliminar_verificacion_paquete(orden_id: int):
    """Borra los fotogramas físicos y el registro de verificación de una
    orden. Se llama desde los 3 endpoints de confirmación de entrega —
    nunca rompe el flujo de confirmación si algo falla al borrar."""
    try:
        rutas = db.eliminar_verificacion(orden_id)
        for ruta in rutas:
            try:
                path = _ruta_a_path(ruta)
                if os.path.exists(path):
                    os.remove(path)
            except Exception as e:
                print(f"WARN: no se pudo borrar fotograma {ruta}: {e}")
    except Exception as e:
        print(f"WARN: no se pudo limpiar verificación de paquete de orden {orden_id}: {e}")
