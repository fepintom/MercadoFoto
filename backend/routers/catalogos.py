"""
routers/catalogos.py
====================
Catálogo de tienda del vendedor: subir un PDF o enlazar una página, que la
app la "absorba" y mostrar ese pedazo de tienda en su perfil.

Flujo:
  1. El vendedor sube su catálogo desde el perfil
     POST /catalogo/pdf   (multipart: user_id + archivo)
     POST /catalogo/web   (form: user_id + url)
     Las dos crean la fila en estado 'procesando' y responden AL TIRO: leer
     un PDF con IA toma decenas de segundos y la app no puede quedarse
     esperando. El trabajo real corre en un BackgroundTask.
  2. La app consulta el avance
     GET /catalogo/{user_id}          -> estado + marca + productos
  3. El dueño ajusta la vitrina
     PATCH  /catalogo/producto/{id}/visibilidad
     DELETE /catalogo/{user_id}
  4. Cualquiera ve la tienda en el perfil público
     GET /usuarios/{user_id}/catalogo -> solo si está 'listo'

Autorización: el proyecto no tiene JWT; la convención es recibir `user_id`
y comparar contra el dueño de la fila. Acá se pide SIEMPRE obligatorio (no
Optional) para que no se pueda saltar el chequeo simplemente omitiéndolo,
que es lo que pasa hoy en varios endpoints de publicaciones.
"""
import os
import secrets
from typing import Optional
from urllib.parse import urlparse

from fastapi import (APIRouter, BackgroundTasks, File, Form, HTTPException,
                     UploadFile)

from config import UPLOADS_DIR
from database import catalogos as db
from services.catalogo_service import extraer_de_pdf, extraer_de_web

router = APIRouter()

MAX_PDF_MB = 25


def _ruta_absoluta(ruta_publica: str) -> str:
    return os.path.join(UPLOADS_DIR, ruta_publica.rsplit("/", 1)[-1])


def _borrar(rutas):
    for r in rutas or []:
        try:
            p = _ruta_absoluta(r)
            if os.path.exists(p):
                os.remove(p)
        except Exception as e:
            print(f"WARN no se pudo borrar {r}: {e}")


# ── Procesamiento en segundo plano ──────────────────────────────────────────

def _procesar(catalogo_id: int, user_id: int, tipo: str, fuente: str):
    """Corre fuera de la request. Nunca propaga excepciones: cualquier
    problema queda registrado en la fila como estado='error'."""
    try:
        if tipo == "pdf":
            productos, marca = extraer_de_pdf(_ruta_absoluta(fuente))
        else:
            productos, marca = extraer_de_web(fuente)

        if marca:
            db.guardar_marca(
                catalogo_id,
                nombre_tienda=marca.get("nombre_tienda"),
                logo_url=marca.get("logo_url"),
                color_primario=marca.get("color_primario"),
                color_fondo=marca.get("color_fondo"),
            )

        if not productos:
            db.marcar_error(
                catalogo_id,
                "No encontramos productos. Si es un PDF, revisa que se vean "
                "los productos con su precio; si es una página, que los "
                "productos estén visibles sin iniciar sesión.")
            return

        n = db.agregar_productos(catalogo_id, user_id, productos)
        db.marcar_listo(catalogo_id, n)
    except Exception as e:
        print(f"ERROR procesando catálogo {catalogo_id}: {e!r}")
        db.marcar_error(catalogo_id, f"No pudimos procesar el catálogo: {e}")


# ── Subida ──────────────────────────────────────────────────────────────────

@router.post("/catalogo/pdf")
async def subir_catalogo_pdf(
    tareas: BackgroundTasks,
    user_id: int = Form(...),
    archivo: UploadFile = File(...),
):
    nombre = (archivo.filename or "").lower()
    if not nombre.endswith(".pdf"):
        raise HTTPException(status_code=400, detail="El archivo debe ser un PDF")

    datos = await archivo.read()
    if len(datos) > MAX_PDF_MB * 1024 * 1024:
        raise HTTPException(
            status_code=400,
            detail=f"El PDF supera los {MAX_PDF_MB} MB. Sube una versión más liviana.")

    os.makedirs(UPLOADS_DIR, exist_ok=True)
    archivo_nombre = f"catalogo_{user_id}_{secrets.token_hex(6)}.pdf"
    with open(os.path.join(UPLOADS_DIR, archivo_nombre), "wb") as f:
        f.write(datos)
    fuente = f"/uploads/{archivo_nombre}"

    anteriores = db.eliminar_catalogo(user_id)
    _borrar([r for r in anteriores if r != fuente])

    catalogo_id = db.crear_o_reemplazar_catalogo(user_id, "pdf", fuente)
    tareas.add_task(_procesar, catalogo_id, user_id, "pdf", fuente)
    return {"ok": True, "catalogo_id": catalogo_id, "estado": "procesando"}


@router.post("/catalogo/web")
async def enlazar_catalogo_web(
    tareas: BackgroundTasks,
    user_id: int = Form(...),
    url: str = Form(...),
):
    url = url.strip()
    if not url.startswith(("http://", "https://")):
        url = "https://" + url
    if not urlparse(url).netloc:
        raise HTTPException(status_code=400, detail="La dirección no es válida")

    _borrar(db.eliminar_catalogo(user_id))
    catalogo_id = db.crear_o_reemplazar_catalogo(user_id, "web", url)
    tareas.add_task(_procesar, catalogo_id, user_id, "web", url)

    aviso = None
    if "instagram.com" in urlparse(url).netloc:
        aviso = ("De Instagram podemos tomar el nombre, la foto y los colores "
                 "de tu perfil, pero no tus publicaciones: para eso Instagram "
                 "exige conectar su API oficial. Si quieres tu catálogo "
                 "completo, sube el PDF o enlaza tu página web.")
    return {"ok": True, "catalogo_id": catalogo_id, "estado": "procesando",
            "aviso": aviso}


# ── Consulta ────────────────────────────────────────────────────────────────

def _serializar(cat, productos):
    return {
        "id": cat["id"],
        "user_id": cat["user_id"],
        "tipo": cat["tipo"],
        "fuente": cat["fuente"],
        "estado": cat["estado"],
        "nombre_tienda": cat["nombre_tienda"],
        "logo_url": cat["logo_url"],
        "color_primario": cat["color_primario"],
        "color_fondo": cat["color_fondo"],
        "total_productos": cat["total_productos"],
        "mensaje_error": cat["mensaje_error"],
        "productos": productos,
    }


@router.get("/catalogo/{user_id}")
def obtener_mi_catalogo(user_id: int):
    """Vista del dueño: incluye los ítems ocultos y el estado del proceso."""
    cat = db.obtener_catalogo_por_usuario(user_id)
    if not cat:
        return {"existe": False}
    productos = db.obtener_productos(cat["id"], solo_visibles=False)
    return {"existe": True, **_serializar(cat, productos)}


@router.get("/usuarios/{user_id}/catalogo")
def obtener_catalogo_publico(user_id: int):
    """Vista pública: solo si terminó de procesarse y solo lo visible."""
    cat = db.obtener_catalogo_por_usuario(user_id)
    if not cat or cat["estado"] != "listo":
        return {"existe": False}
    productos = db.obtener_productos(cat["id"], solo_visibles=True)
    if not productos:
        return {"existe": False}
    return {"existe": True, **_serializar(cat, productos)}


# ── Administración ──────────────────────────────────────────────────────────

@router.patch("/catalogo/producto/{producto_id}/visibilidad")
def cambiar_visibilidad(producto_id: int, user_id: int = Form(...),
                        visible: bool = Form(...)):
    if not db.cambiar_visibilidad(producto_id, user_id, visible):
        raise HTTPException(
            status_code=403,
            detail="No autorizado o el producto no existe")
    return {"ok": True, "visible": visible}


@router.delete("/catalogo/{user_id}")
def eliminar_mi_catalogo(user_id: int, solicitante_id: int):
    if solicitante_id != user_id:
        raise HTTPException(status_code=403, detail="No autorizado")
    _borrar(db.eliminar_catalogo(user_id))
    return {"ok": True}
