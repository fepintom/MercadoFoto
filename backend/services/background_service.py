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

    # 1) abrir imagen original y reducir tamaño antes de procesar
    input_image = Image.open(io.BytesIO(image_bytes)).convert("RGBA")
    input_image.thumbnail((_MAX_SIDE, _MAX_SIDE), Image.LANCZOS)

    # 2) remover fondo
    output_image = remove(input_image)

    # 3) fondo blanco del mismo tamaño que el producto procesado
    fondo = Image.new("RGBA", output_image.size, (255, 255, 255, 255))

    # 4) pegar producto sobre el fondo
    fondo.paste(output_image, (0, 0), mask=output_image)

    # 6) guardar como JPEG (mucho más liviano que PNG)
    buffer = io.BytesIO()
    fondo.convert("RGB").save(buffer, format="JPEG", quality=_JPEG_Q, optimize=True)

    return buffer.getvalue()