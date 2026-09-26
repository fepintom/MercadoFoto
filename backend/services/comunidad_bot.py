"""
services/comunidad_bot.py
=========================
El bot de OkVenta dentro del chat de la Comunidad.

Por ahora hace tres cosas:
  - Da la bienvenida la primera vez que se abre la sala.
  - Responde cuando alguien lo etiqueta con @okventa.
  - Publica una oferta cuando se le pide desde el backoffice.

Con ANTHROPIC_API_KEY responde con IA (Haiku, respuestas cortas). Sin la key
responde con reglas simples: nunca se queda callado ni muestra un error.
"""
import os
import random
import re

from database import comunidad as db

MENCION = re.compile(r"@\s?ok\s?venta\b", re.IGNORECASE)

BIENVENIDA = (
    "¡Hola! 👋 Bienvenidos a la Comunidad de OkVenta. Aquí pueden conversar "
    "todos con todos, anclar lo que venden o los servicios que dan, y "
    "etiquetarme con @okventa si necesitan algo."
)

MODEL = "claude-haiku-4-5"


def me_mencionan(texto: str) -> bool:
    return bool(MENCION.search(texto or ""))


def asegurar_bienvenida():
    if db.contar_mensajes() == 0:
        db.guardar_mensaje(None, BIENVENIDA, es_bot=True)


def _fmt_precio(p):
    try:
        return "$" + f"{int(round(float(p))):,}".replace(",", ".")
    except Exception:
        return ""


def _respuesta_reglas(texto: str, nombre: str) -> str:
    t = (texto or "").lower()
    if any(p in t for p in ("oferta", "barato", "descuento", "promo", "recomienda")):
        ofertas = db.ofertas_recientes(3)
        if not ofertas:
            return f"{nombre}, por ahora no hay ofertas nuevas. ¡Vuelve pronto! 🙌"
        lineas = [f"• {o['titulo']} — {_fmt_precio(o['precio'])}" for o in ofertas]
        return f"{nombre}, esto es lo más nuevo en OkMarket 🔥\n" + "\n".join(lineas)
    if any(p in t for p in ("hola", "buenas", "buen día", "buenos")):
        return f"¡Hola {nombre}! 👋 ¿En qué te ayudo?"
    if any(p in t for p in ("publicar", "vender", "anclar")):
        return (f"{nombre}, para vender toca \"+ Publicar\" arriba a la derecha "
                "en OkMarket u OkServicios. Aquí en la Comunidad puedes anclar "
                "lo que ya publicaste con el 📌 junto al cuadro de texto.")
    if any(p in t for p in ("pago", "compra", "segur", "estafa")):
        return (f"{nombre}, en OkVenta el pago queda retenido hasta que "
                "confirmas que recibiste el producto. Nunca pagues por fuera 🙏")
    return (f"{nombre}, te leo 👀. Puedo mostrarte ofertas (escribe "
            "\"@okventa ofertas\") o explicarte cómo publicar y comprar seguro.")


def _respuesta_ia(texto: str, nombre: str) -> str:
    import anthropic

    ofertas = db.ofertas_recientes(5)
    contexto = "\n".join(
        f"- {o['titulo']} ({o.get('categoria') or 'General'}) {_fmt_precio(o['precio'])}"
        for o in ofertas) or "(sin ofertas por ahora)"
    client = anthropic.Anthropic(api_key=os.environ["ANTHROPIC_API_KEY"], timeout=20)
    msg = client.messages.create(
        model=MODEL,
        max_tokens=250,
        system=(
            "Eres el bot de OkVenta, un marketplace chileno de productos y "
            "servicios, dentro de un chat público de la comunidad. Responde "
            "en español de Chile, cercano y breve (máximo 3 frases), con algún "
            "emoji. Si piden ofertas, usa SOLO esta lista de publicaciones "
            f"reales:\n{contexto}\n"
            "Nunca inventes productos, precios ni políticas. Para problemas "
            "con una compra, deriva a Ayuda en 'Mi OkVenta'."
        ),
        messages=[{"role": "user", "content": f"{nombre} escribe: {texto}"}],
    )
    return "".join(b.text for b in msg.content if getattr(b, "type", "") == "text").strip()


def responder(mensaje: dict):
    """Se llama en segundo plano después de guardar un mensaje que etiqueta
    al bot. Nunca lanza: si algo falla, cae a las reglas."""
    nombre = (mensaje.get("nombre") or "").split(" ")[0] or "Hola"
    texto = mensaje.get("texto") or ""
    respuesta = ""
    if os.environ.get("ANTHROPIC_API_KEY"):
        try:
            respuesta = _respuesta_ia(texto, nombre)
        except Exception as e:
            print(f"WARN comunidad_bot IA: {e}")
    if not respuesta:
        respuesta = _respuesta_reglas(texto, nombre)
    db.guardar_mensaje(None, respuesta, es_bot=True, responde_a=mensaje.get("id"))


def publicar_oferta():
    """El bot ancla una oferta real al chat. Para usar desde el backoffice."""
    ofertas = db.ofertas_recientes(10)
    if not ofertas:
        return None
    o = random.choice(ofertas)
    return db.guardar_mensaje(
        None,
        random.choice([
            "🔥 Oferta del momento en OkMarket:",
            "👀 Miren lo que acaba de llegar:",
            "💥 Esto se va rápido:",
        ]),
        es_bot=True,
        ancla={"tipo": "publicacion", "id": o["id"], "titulo": o["titulo"],
               "precio": o["precio"], "imagen": o["imagen_url"]},
    )
