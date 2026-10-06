"""
services/imagenes.py
====================
Achicar fotos de perfil.

Antes se guardaba el archivo original de la cámara (3–10 MB) y cada avatar
de 30 px en la app descargaba esa foto completa: por eso las fotos de
perfil tardaban en aparecer en "Mi OkVenta" y en los chats.

  achicar_foto_perfil(bytes) -> (bytes_jpeg, ".jpg")
  optimizar_fotos_existentes()  -> achica en el lugar las que ya están
"""
import io
import os
import sqlite3
import threading

from PIL import Image, ImageOps

from config import PUBLICACIONES_DB as DB, UPLOADS_DIR

LADO_MAXIMO = 640          # px: nítida en un avatar grande de perfil
CALIDAD_JPEG = 82
UMBRAL_BYTES = 250 * 1024  # las que pesan menos se dejan como están


def _redimensionar(im: Image.Image) -> Image.Image:
    im = ImageOps.exif_transpose(im)  # respeta la orientación de la cámara
    im.thumbnail((LADO_MAXIMO, LADO_MAXIMO), Image.LANCZOS)
    return im


def achicar_foto_perfil(contenido: bytes):
    """Devuelve (bytes, extensión). Si no es una imagen válida, devuelve el
    original para no romper la subida."""
    try:
        im = _redimensionar(Image.open(io.BytesIO(contenido)))
        if im.mode in ("RGBA", "LA", "P"):
            fondo = Image.new("RGB", im.size, (255, 255, 255))
            im = im.convert("RGBA")
            fondo.paste(im, mask=im.getchannel("A"))
            im = fondo
        else:
            im = im.convert("RGB")
        out = io.BytesIO()
        im.save(out, "JPEG", quality=CALIDAD_JPEG, optimize=True,
                progressive=True)
        return out.getvalue(), ".jpg"
    except Exception as e:
        print(f"WARN achicar_foto_perfil: {e}")
        return contenido, None


def _optimizar_archivo(ruta: str) -> bool:
    """Achica un archivo en el lugar, conservando nombre y formato (la URL
    guardada en la base no cambia)."""
    if not os.path.exists(ruta) or os.path.getsize(ruta) < UMBRAL_BYTES:
        return False
    try:
        with Image.open(ruta) as original:
            formato = (original.format or "JPEG").upper()
            im = _redimensionar(original)
            im.load()
        tmp = ruta + ".tmp"
        if formato == "PNG":
            im.save(tmp, "PNG", optimize=True)
        else:
            im.convert("RGB").save(tmp, "JPEG", quality=CALIDAD_JPEG,
                                   optimize=True, progressive=True)
        if os.path.getsize(tmp) < os.path.getsize(ruta):
            os.replace(tmp, ruta)
            return True
        os.remove(tmp)
    except Exception as e:
        print(f"WARN optimizar {ruta}: {e}")
    return False


def optimizar_fotos_existentes() -> dict:
    """Achica las fotos de perfil ya subidas que pesen más del umbral."""
    revisadas = optimizadas = 0
    try:
        conn = sqlite3.connect(DB)
        filas = conn.execute(
            "SELECT DISTINCT foto_url FROM users "
            "WHERE foto_url LIKE '/uploads/%'").fetchall()
        conn.close()
    except Exception as e:
        print(f"WARN optimizar_fotos_existentes: {e}")
        return {"revisadas": 0, "optimizadas": 0}
    for (url,) in filas:
        revisadas += 1
        ruta = os.path.join(UPLOADS_DIR, url.rsplit("/", 1)[-1])
        if _optimizar_archivo(ruta):
            optimizadas += 1
    print(f"Fotos de perfil: {optimizadas} achicadas de {revisadas}")
    return {"revisadas": revisadas, "optimizadas": optimizadas}


def optimizar_en_segundo_plano():
    threading.Thread(target=optimizar_fotos_existentes, daemon=True).start()


def achicar_foto_historia(contenido: bytes):
    """Historias: hasta 1280 px por lado (pantalla completa nítida)."""
    try:
        im = ImageOps.exif_transpose(Image.open(io.BytesIO(contenido)))
        im.thumbnail((1280, 1280), Image.LANCZOS)
        im = im.convert("RGB")
        out = io.BytesIO()
        im.save(out, "JPEG", quality=84, optimize=True, progressive=True)
        return out.getvalue()
    except Exception as e:
        print(f"WARN achicar_foto_historia: {e}")
        return None
