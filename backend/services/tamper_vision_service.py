import base64
import json
import os
from openai import OpenAI

client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

MENSAJE_OK = "Las etiquetas y el paquete se ven bien, puedes abrir tu okcompra"
MENSAJE_ALERTA = (
    "No logramos verificar la integridad del paquete. "
    "Te sugerimos guardar evidencias y levantar una disputa."
)


def _img_block(b64: str):
    return {
        "type": "image_url",
        "image_url": {"url": f"data:image/jpeg;base64,{b64}", "detail": "low"},
    }


def analizar_empaque(boxing_frames: list, unboxing_frames: list):
    """
    Compara los fotogramas clave del video de embalaje (grabado por el
    vendedor al despachar) con los del video de unboxing (grabado por el
    comprador al recibir), usando GPT-4o Vision, para la política
    anti-fraude de sellos de seguridad.

    Verifica: (1) que las dimensiones/proporciones del paquete sean
    consistentes, (2) que la posición de las etiquetas y sellos de
    seguridad sea la misma, (3) que el paquete no muestre daños, cortes
    ni señales de haber sido abierto y vuelto a cerrar.

    Retorna dict: {"ok": bool, "mensaje": str, "detalle": str}
    """
    try:
        if not boxing_frames or not unboxing_frames:
            return {
                "ok": False,
                "mensaje": MENSAJE_ALERTA,
                "detalle": "Faltan fotogramas de embalaje o de unboxing para comparar.",
            }

        prompt = """
Eres un perito antifraude de una plataforma de marketplace chilena (OkVenta).
Te muestro dos grupos de fotogramas de un mismo envío:

1) Fotogramas del PACKING/BOXING: el vendedor grabó el paquete siendo
   embalado y sellado con 4 sellos de seguridad numerados, justo antes de
   despacharlo.
2) Fotogramas del UNBOXING: el comprador grabó el mismo paquete al
   recibirlo, antes de abrirlo, mostrando los mismos sellos.

Compara ambos grupos y evalúa exclusivamente:
- Dimensiones y proporciones del paquete (¿es visualmente el mismo tamaño
  de caja/bulto en ambos grupos?)
- Posición de las etiquetas y de los 4 sellos de seguridad (¿están en los
  mismos lugares, sin despegar, cortar, mover ni reemplazar?)
- Estado físico del paquete (¿hay roturas, cortes, aplastones, humedad o
  señales de que fue abierto y vuelto a cerrar que no estaban en el
  packing?)

No evalúes el producto interno (no lo puedes ver). No inventes detalles
que no se aprecien con claridad en las imágenes: ante la duda razonable,
prioriza no generar una falsa alarma, pero si hay evidencia clara de
alteración, repórtala.

Responde SOLO en JSON con este formato exacto:
{
    "integridad_ok": true,
    "razon": "explicación breve en español, máximo 200 caracteres"
}
"""

        content_blocks = [
            {"type": "text", "text": "Fotogramas de PACKING/BOXING (al despachar):"}
        ]
        for f in boxing_frames:
            content_blocks.append(_img_block(base64.b64encode(f).decode("utf-8")))
        content_blocks.append(
            {"type": "text", "text": "Fotogramas de UNBOXING (al recibir):"}
        )
        for f in unboxing_frames:
            content_blocks.append(_img_block(base64.b64encode(f).decode("utf-8")))
        content_blocks.append({"type": "text", "text": prompt})

        response = client.chat.completions.create(
            model="gpt-4o",
            messages=[{"role": "user", "content": content_blocks}],
            max_tokens=300,
            temperature=0.2,
        )

        content = response.choices[0].message.content.strip()
        print("GPT-4o Vision (empaque) respondió:", content)
        content = content.replace("```json", "").replace("```", "").strip()

        data = json.loads(content)
        integridad_ok = bool(data.get("integridad_ok", False))
        razon = (data.get("razon") or "").strip()

        return {
            "ok": integridad_ok,
            "mensaje": MENSAJE_OK if integridad_ok else MENSAJE_ALERTA,
            "detalle": razon,
        }

    except Exception as e:
        print("ERROR GPT-4o Vision (empaque):", e)
        # Ante cualquier falla del análisis, nunca afirmamos falsamente que
        # todo está bien: se prefiere pedir revisión manual.
        return {
            "ok": False,
            "mensaje": MENSAJE_ALERTA,
            "detalle": "No fue posible completar el análisis automático.",
        }
