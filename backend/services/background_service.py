from rembg import remove
from PIL import Image
import io
from pathlib import Path

# Ruta al fondo institucional
BASE_DIR = Path(__file__).resolve().parent.parent
FONDO_PATH = BASE_DIR / "assets" / "fondo_okventa.png"


_MAX_SIDE   = 900   # px — lado máximo tras resize
_JPEG_Q     = 72    # calidad JPEG (balance tamaño/calidad)


def quitar_fondo(image_bytes):
    """Foto subida → foto de publicación OkVenta: sin fondo, sobre gris de
    estudio y con la marca de agua "OK Venta App" (services/marca_agua.py).
    Si quitar el fondo falla, se usa la foto tal cual (con fondo y marca)."""
    from services.marca_agua import componer_jpeg

    # 1) abrir imagen original y reducir tamaño antes de procesar
    input_image = Image.open(io.BytesIO(image_bytes))
    try:
        from PIL import ImageOps
        input_image = ImageOps.exif_transpose(input_image)
    except Exception:
        pass
    input_image = input_image.convert("RGBA")
    input_image.thumbnail((_MAX_SIDE, _MAX_SIDE), Image.LANCZOS)

    # 2) remover fondo
    try:
        output_image = remove(input_image)
    except Exception as e:
        print("rembg falló, se usa la foto original:", repr(e))
        output_image = input_image

    # 3) lienzo gris + sombra + marca de agua → JPEG
    return componer_jpeg(output_image, calidad=_JPEG_Q + 8)
