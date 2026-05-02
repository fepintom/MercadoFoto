import base64
import json
import os
from openai import OpenAI

client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))


def detectar_producto(original_bytes: bytes):
    """
    Analiza la imagen con GPT-4o Vision y retorna una tupla:
        (titulo, descripcion, dimensiones, precio_min, precio_max, moneda, confianza)
    """
    try:
        imagen_b64 = base64.b64encode(original_bytes).decode("utf-8")

        prompt = """
Eres un experto en ecommerce latinoamericano especializado en el mercado chileno.

Analiza esta imagen de un producto y responde SOLO en JSON con este formato exacto:
{
    "titulo": "...",
    "descripcion": "...",
    "dimensiones": "...",
    "precio_min": 0,
    "precio_max": 0,
    "moneda": "CLP",
    "confianza": "alta"
}

Reglas generales:
- Título corto, máximo 6 palabras, en español
- Descripción clara y orientada a venta, máximo 60 caracteres, en español, sin repetir el título
- Dimensiones: estimación visual aproximada en cm (ej: "30 x 20 x 10 cm"). Si no puedes estimarlas escribe "No determinado"
- No inventes datos que no puedas ver
- Si no reconoces el producto responde con titulo: "Producto" y descripción genérica
- Sin emojis
- Sin comillas internas

Reglas para el precio sugerido en Chile (CLP):
- precio_min y precio_max deben ser valores enteros en pesos chilenos (CLP)
- Considera el estado visual del producto (nuevo, usado en buen estado, desgastado)
- Usa precios realistas para el mercado chileno (Mercado Libre Chile / Facebook Marketplace CL)
- El rango precio_min–precio_max no debería superar el 40% del valor del punto medio
- Ejemplos orientativos: ropa usada 2000–15000, electrónica usada 10000–150000,
  muebles 20000–200000, juguetes 2000–25000, libros 1000–8000, calzado 5000–30000
- confianza debe ser "alta" si identificas claramente el producto y su categoría de precio,
  "media" si hay incertidumbre moderada, "baja" si el producto es difícil de identificar
  o el rango de precios varía mucho
"""

        response = client.chat.completions.create(
            model="gpt-4o",
            messages=[
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "image_url",
                            "image_url": {
                                "url": f"data:image/jpeg;base64,{imagen_b64}",
                                "detail": "low",
                            },
                        },
                        {
                            "type": "text",
                            "text": prompt,
                        },
                    ],
                }
            ],
            max_tokens=400,
            temperature=0.3,
        )

        content = response.choices[0].message.content.strip()
        print("GPT-4o Vision respondió:", content)

        content = content.replace("```json", "").replace("```", "").strip()

        data = json.loads(content)
        titulo      = data.get("titulo",      "Producto").strip()
        descripcion = data.get("descripcion", "").strip()
        dimensiones = data.get("dimensiones", "No determinado").strip()
        precio_min  = float(data.get("precio_min", 0) or 0)
        precio_max  = float(data.get("precio_max", 0) or 0)
        moneda      = data.get("moneda",      "CLP")
        confianza   = data.get("confianza",   "media")

        # Sanidad: si min > max los intercambiamos
        if precio_min > precio_max and precio_max > 0:
            precio_min, precio_max = precio_max, precio_min

        return titulo, descripcion, dimensiones, precio_min, precio_max, moneda, confianza

    except Exception as e:
        print("ERROR GPT-4o Vision:", e)
        return (
            "Producto",
            "Producto en buen estado disponible para la venta.",
            "No determinado",
            0.0,
            0.0,
            "CLP",
            "baja",
        )
