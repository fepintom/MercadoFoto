import os
import uuid
from config import UPLOADS_DIR as UPLOAD_DIR


def guardar_imagen_procesada(image_bytes: bytes) -> str:
    """
    Guarda la imagen procesada en la carpeta uploads
    y devuelve la ruta pública relativa.
    """

    # Crear carpeta uploads si no existe
    os.makedirs(UPLOAD_DIR, exist_ok=True)

    # Generar nombre único (.jpg — mucho más liviano que .png)
    filename = f"{uuid.uuid4().hex}.jpg"
    file_path = os.path.join(UPLOAD_DIR, filename)

    # Guardar archivo
    with open(file_path, "wb") as f:
        f.write(image_bytes)

    # Retornar ruta pública (usada por FastAPI StaticFiles)
    return f"/uploads/{filename}"