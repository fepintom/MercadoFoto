from rembg import remove
from PIL import Image
import io
from pathlib import Path

# Ruta al fondo institucional
BASE_DIR = Path(__file__).resolve().parent.parent
FONDO_PATH = BASE_DIR / "assets" / "fondo_okventa.png"


def quitar_fondo(image_bytes):

    # 1) abrir imagen original
    input_image = Image.open(io.BytesIO(image_bytes)).convert("RGBA")

    # 2) remover fondo
    output_image = remove(input_image)

    # 3) abrir fondo MercadoFoto
    if not FONDO_PATH.exists():
        raise FileNotFoundError(f"No se encontró el fondo en: {FONDO_PATH}")

    fondo = Image.open(FONDO_PATH).convert("RGBA")

    # 4) ajustar fondo al tamaño del producto
    fondo = fondo.resize(output_image.size)

    # 5) pegar producto sobre el fondo
    fondo.paste(output_image, (0, 0), mask=output_image)

    # 6) guardar resultado
    buffer = io.BytesIO()
    fondo.convert("RGB").save(buffer, format="PNG")

    return buffer.getvalue()