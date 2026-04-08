from openai import OpenAI
import os
import json

client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))


def mejorar_descripcion_producto(titulo, descripcion):
    try:
        prompt = f"""
        Eres un experto en ecommerce.

        Mejora este producto:

        TITULO BASE: {titulo}
        DESCRIPCION BASE: {descripcion}

        Reglas:
        - Título corto (máx 6 palabras)
        - Descripción clara y orientada a venta
        - Español neutro
        - No inventar datos

        Responde SOLO en JSON:
        {{
            "titulo": "...",
            "descripcion": "..."
        }}
        """

        response = client.chat.completions.create(
            model="gpt-4.1-mini",
            messages=[
                {"role": "system", "content": "Eres experto en ecommerce"},
                {"role": "user", "content": prompt},
            ],
            temperature=0.4,
        )

        content = response.choices[0].message.content
        try:
            data = json.loads(content)
        except:
            return titulo, descripcion
        
        print("GPT RESPONSE:", content)
        return data["titulo"], data["descripcion"]

    except Exception as e:
        print("ERROR GPT:", e)
        return titulo, descripcion