import os
import json
import re
from typing import Optional

import google.generativeai as genai

# 🔥 FORZAMOS MODELO (SIN ENV PARA EVITAR ERRORES)
MODEL = "gemini-1.0-pro"


_SYSTEM = (
    "Eres un clasificador de productos para un marketplace.\n"
    "Identifica el objeto físico principal de la foto.\n"
    "Genera un título atractivo para vender el producto.\n"
    "Reglas estrictas:\n"
    "1) Puedes usar OCR para decidir marca o modelo, pero sólo del producto principal identificado.\n"
    "2) Si la MARCA es claramente reconocible por diseño (logo visible o forma icónica), inclúyela después del objeto.\n"
    "3) No inventes modelo ni versión.\n"
    "4) Máximo 4 palabras.\n"
    "5) Español.\n"
)

_USER = 'Responde SOLO en JSON válido: {"titulo":"<MAXIMO_2_PALABRAS>"}'


# 🔥 LIMPIEZA FUERTE DE TEXTO (CLAVE)
def _fix_encoding(text: str) -> str:
    if not text:
        return text

    # caso típico UTF8 mal interpretado
    try:
        text = text.encode("latin1").decode("utf-8")
    except:
        pass

    # reemplazos manuales (casos comunes)
    reemplazos = {
        "Ã¡": "á",
        "Ã©": "é",
        "Ã­": "í",
        "Ã³": "ó",
        "Ãº": "ú",
        "Ã±": "ñ",
        "Ã": "í",
    }

    for k, v in reemplazos.items():
        text = text.replace(k, v)

    return text


def _extract_json_title(text: str) -> Optional[str]:
    if not text:
        return None

    try:
        data = json.loads(text)
        return (data.get("titulo") or "").strip()
    except:
        pass

    match = re.search(r"\{.*\}", text, re.DOTALL)
    if not match:
        return None

    try:
        data = json.loads(match.group(0))
        return (data.get("titulo") or "").strip()
    except:
        return None


def gemini_titulo_producto(image_bytes: bytes, mime_type: str) -> Optional[str]:

    api_key = os.getenv("GEMINI_API_KEY")

    if not api_key:
        print("ERROR GEMINI: API KEY no configurada")
        return None

    genai.configure(api_key=api_key)

    print("MODELO GEMINI USADO:", MODEL)

    raw = ""

    try:
        model = genai.GenerativeModel(MODEL)

        response = model.generate_content(
            [
                _SYSTEM,
                _USER,
                {
                    "mime_type": mime_type,
                    "data": image_bytes,
                },
            ],
            generation_config={"temperature": 0},
        )

        raw = (response.text or "").strip()

    except Exception as e:
        print("ERROR GEMINI SERVICE:", e)
        return None

    titulo = _extract_json_title(raw)

    if not titulo:
        return None

    # 🔥 FIX FUERTE
    titulo = _fix_encoding(titulo)

    titulo = titulo.strip()

    # máximo 2 palabras
    titulo = " ".join(titulo.split()[:2])

    # capitalizar
    titulo = titulo.title()

    return titulo