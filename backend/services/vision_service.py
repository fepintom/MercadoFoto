import base64
import json
import os
from openai import OpenAI

client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))


def detectar_producto(original_bytes: bytes):
    try:
        imagen_b64 = base64.b64encode(original_bytes).decode("utf-8")

        prompt = """
Eres un experto en ecommerce latinoamericano.

Analiza esta imagen de un producto y responde SOLO en JSON con este formato exacto:
{
    "titulo": "...",
    "descripcion": "...",
    "dimensiones": "..."
}

Reglas:
- Título corto, máximo 6 palabras, en español
- Descripción clara y orientada a venta, máximo 60 palabras, en español
- Dimensiones: estimación visual aproximada en cm (ej: "30 x 20 x 10 cm"). Si no puedes estimarlas escribe "No determinado"
- No inventes datos que no puedas ver
- Si no reconoces el producto responde con titulo: "Producto" y descripción genérica
- Sin emojis
- Sin comillas internas
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
            max_tokens= 300,
            temperature=0.3,
        )

        content = response.choices[0].message.content.strip()
        print("GPT-4o Vision respondió:", content)

        content = content.replace("```json", "").replace("```", "").strip()

        data = json.loads(content)
        titulo = data.get("titulo", "Producto").strip()
        descripcion = data.get("descripcion", "").strip()
        dimensiones = data.get("dimensiones", "No determinado").strip()

        return titulo, descripcion, dimensiones

    except Exception as e:
        print("ERROR GPT-4o Vision:", e)
        return "Producto", "Producto en buen estado disponible para la venta.", "No determinado"