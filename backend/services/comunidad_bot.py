"""
services/comunidad_bot.py
=========================
El bot de OkVenta en el chat de la Comunidad.

Cuándo habla
  - Bienvenida la primera vez que se abre la sala.
  - Cuando lo etiquetan con @okventa.
  - Cuando alguien RESPONDE a uno de sus mensajes.
  - Y para que haya conversación: si le habló a un usuario hace menos de
    2 minutos, contesta el siguiente mensaje de ese usuario aunque no lo
    vuelva a etiquetar.

Qué sabe hacer
  - Buscar productos y servicios reales ("busco bicicleta", "necesito
    gasfiter"), mostrar ofertas (primero las con descuento), explicar cómo
    comprar, vender, pagar seguro, envíos, historias…
  - Con ANTHROPIC_API_KEY: responde con IA (Haiku), con memoria de la
    conversación con ese usuario, el FAQ oficial y resultados reales como
    contexto. Sin la key: reglas por intención. Nunca se queda callado.
  - Lo que no puede resolver (una orden, un reclamo, datos de cuenta) lo
    DERIVA: crea un ticket de soporte y lo marca en la bitácora.

Todo queda en `comunidad_bot_log`; se administra con
GET /admin/comunidad/bot/conversaciones y /resumen (token ADMIN_TOKEN).
"""
import os
import random
import re
import sqlite3
import unicodedata
from datetime import datetime, timedelta

from config import PUBLICACIONES_DB as DB
from database import comunidad as db

MENCION = re.compile(r"@\s?ok\s?venta\b", re.IGNORECASE)
MODEL = "claude-haiku-4-5"
VENTANA_CONVERSACION = timedelta(minutes=2)

BIENVENIDA = (
    "¡Hola! 👋 Soy el bot de OkVenta. Aquí pueden conversar todos con todos "
    "y anclar lo que venden. Etiquétenme con @okventa y les ayudo a buscar "
    "productos o servicios, ver ofertas o resolver dudas de la app."
)

_FAQ_RUTA = os.path.join(os.path.dirname(os.path.dirname(__file__)),
                         "support", "faq.md")


# ── Utilidades ──────────────────────────────────────────────────────────────

def _norm(t: str) -> str:
    t = unicodedata.normalize("NFD", (t or "").lower())
    return "".join(c for c in t if unicodedata.category(c) != "Mn")


def _fmt_precio(p):
    try:
        return "$" + f"{int(round(float(p))):,}".replace(",", ".")
    except Exception:
        return ""


def _primer_nombre(msg):
    return (msg.get("nombre") or "").split(" ")[0] or "Hola"


def _conn():
    c = sqlite3.connect(DB)
    c.row_factory = sqlite3.Row
    return c


def me_mencionan(texto: str) -> bool:
    return bool(MENCION.search(texto or ""))


def asegurar_bienvenida():
    if db.contar_mensajes() == 0:
        db.guardar_mensaje(None, BIENVENIDA, es_bot=True)


def debe_responder(msg: dict) -> bool:
    """¿Le toca hablar al bot después de este mensaje?"""
    if me_mencionan(msg.get("texto")):
        return True
    resp = msg.get("responde_a")
    if resp:
        original = db.obtener_mensaje(resp)
        if original and original.get("es_bot"):
            return True
    # Conversación en curso: el bot le habló a este usuario hace poco.
    try:
        c = _conn()
        r = c.execute("""
            SELECT created_at FROM comunidad_bot_log
            WHERE user_id = ? ORDER BY id DESC LIMIT 1
        """, (msg.get("user_id"),)).fetchone()
        c.close()
        if r and r["created_at"]:
            ultima = datetime.strptime(r["created_at"][:19], "%Y-%m-%d %H:%M:%S")
            return datetime.utcnow() - ultima <= VENTANA_CONVERSACION
    except Exception:
        pass
    return False


# ── Datos reales para responder ─────────────────────────────────────────────

_VACIAS = set("""el la los las un una unos unas de del al a en y o que por para
con sin me mi tu te se lo le les es son hay quiero busco buscando necesito
necesita alguien algun alguna vende venden vendo compro comprar cuanto cuesta
precio okventa hola favor porfa gracias tienen tiene donde como algo""".split())


def _palabras_clave(texto):
    palabras = re.findall(r"[a-z0-9ñ]+", _norm(MENCION.sub(" ", texto or "")))
    return [w for w in palabras if len(w) >= 4 and w not in _VACIAS][:4]


def _coincide(claves, *campos):
    """Compara sin tildes ni mayúsculas ("gasfiteria" encuentra "Gasfitería")."""
    t = _norm(" ".join(str(c or "") for c in campos))
    return any(k in t for k in claves)


def buscar_productos(texto, limite=3):
    claves = _palabras_clave(texto)
    if not claves:
        return []
    c = _conn()
    filas = c.execute("""
        SELECT id, titulo, precio, precio_original FROM publicaciones
        WHERE estado = 'disponible' ORDER BY created_at DESC LIMIT 800
    """).fetchall()
    c.close()
    return [dict(f) for f in filas if _coincide(claves, f["titulo"])][:limite]


def buscar_servicios(texto, limite=3):
    claves = _palabras_clave(texto)
    if not claves:
        return []
    c = _conn()
    try:
        filas = c.execute("""
            SELECT id, titulo, valor, modalidad, categoria FROM servicios
            WHERE tipo = 'ofrezco' ORDER BY created_at DESC LIMIT 800
        """).fetchall()
    except sqlite3.OperationalError:
        filas = []
    c.close()
    return [dict(f) for f in filas
            if _coincide(claves, f["titulo"], f["categoria"])][:limite]


def ofertas(limite=3):
    """Primero lo que tiene rebaja (precio_original > precio)."""
    c = _conn()
    try:
        filas = c.execute("""
            SELECT id, titulo, precio, precio_original, imagen_url FROM publicaciones
            WHERE estado = 'disponible' AND precio > 0
            ORDER BY (CASE WHEN precio_original > precio THEN 0 ELSE 1 END),
                     created_at DESC
            LIMIT ?
        """, (limite,)).fetchall()
    except sqlite3.OperationalError:
        filas = c.execute("""
            SELECT id, titulo, precio, NULL AS precio_original, imagen_url
            FROM publicaciones WHERE estado = 'disponible' AND precio > 0
            ORDER BY created_at DESC LIMIT ?
        """, (limite,)).fetchall()
    c.close()
    return [dict(f) for f in filas]


def _linea_producto(p):
    pct = ""
    if p.get("precio_original") and p["precio_original"] > (p.get("precio") or 0):
        pct = f" (-{round((p['precio_original'] - p['precio']) * 100 / p['precio_original'])}%)"
    return f"• {p['titulo']} — {_fmt_precio(p['precio'])}{pct}"


def _linea_servicio(s):
    v = f" — {_fmt_precio(s['valor'])}/{'hora' if s.get('modalidad') == 'hora' else 'servicio'}" if s.get("valor") else ""
    return f"• {s['titulo']}{v}"


# ── Reglas (sin IA) ─────────────────────────────────────────────────────────

_INTENCIONES = [
    ("soporte", r"\b(humano|persona|soporte|reclamo|reclamar|denuncia|estafa|no me llego|no llego|mi pedido|mi compra|mi orden|reembolso|devolucion|cancelar)\b"),
    ("saludo", r"\b(hola|holi|buenas|buen dia|buenos dias|buenas tardes|buenas noches|hey|que tal)\b"),
    ("gracias", r"\b(gracias|grax|vale|genial|perfecto|chao|adios)\b"),
    ("ofertas", r"\b(oferta|ofertas|descuento|barato|promo|cyber|rebaja|liquidacion)\b"),
    ("servicio", r"\b(servicio|servicios|instal\w*|gasfit\w*|electric\w*|maestro|tecnico|arregl\w*|repar\w*|limpieza|flete|mudanza|pintor|carpinter\w*)\b"),
    ("buscar", r"\b(busco|buscando|necesito|quiero|hay|venden|vende|tienen|donde compro)\b"),
    ("vender", r"\b(vender|publicar|publico|subir producto|como vendo)\b"),
    ("pago", r"\b(pago|pagar|seguro|segura|retenido|garantia|mercado pago|tarjeta)\b"),
    ("envio", r"\b(envio|enviar|despacho|entrega|delivery|blue express|retiro)\b"),
    ("historia", r"\b(historia|historias|destacada|destacadas)\b"),
    ("comunidad", r"\b(anclar|anclo|etiquetar|mencionar|comunidad)\b"),
]


def _intencion(texto):
    t = _norm(texto)
    for nombre, patron in _INTENCIONES:
        if re.search(patron, t):
            return nombre
    return "otro"


def _respuesta_reglas(msg):
    texto = msg.get("texto") or ""
    nombre = _primer_nombre(msg)
    intent = _intencion(texto)

    if intent == "soporte":
        return intent, (f"{nombre}, eso lo tiene que ver una persona del equipo 🙋. "
                        "Ya dejé tu consulta en soporte; te contestan en Mi OkVenta → "
                        "Obtener ayuda. Por seguridad, no publiques datos de tu compra aquí."), True
    if intent == "saludo":
        return intent, (f"¡Hola {nombre}! 👋 Puedo buscarte productos (\"busco bicicleta\"), "
                        "servicios (\"necesito gasfiter\"), mostrarte ofertas o explicarte "
                        "cómo comprar y vender seguro. ¿Qué necesitas?"), False
    if intent == "gracias":
        return intent, random.choice([
            f"¡De nada, {nombre}! 🙌", f"¡Para eso estoy, {nombre}! 😄",
            f"¡Un gusto ayudarte, {nombre}! Si necesitas algo más, aquí estoy."]), False
    if intent == "ofertas":
        o = ofertas(3)
        if not o:
            return intent, f"{nombre}, por ahora no hay ofertas nuevas. ¡Vuelve pronto! 🙌", False
        return intent, (f"{nombre}, esto está en oferta en OkMarket 🔥\n" +
                        "\n".join(_linea_producto(p) for p in o)), False
    if intent in ("buscar", "servicio"):
        prods = [] if intent == "servicio" else buscar_productos(texto)
        servs = buscar_servicios(texto)
        partes = []
        if prods:
            partes.append("En OkMarket encontré:\n" + "\n".join(_linea_producto(p) for p in prods))
        if servs:
            partes.append("En OkServicios:\n" + "\n".join(_linea_servicio(s) for s in servs))
        if partes:
            return intent, f"{nombre}, mira 👀\n" + "\n".join(partes) + "\nBúscalos por nombre en la app.", False
        return intent, (f"{nombre}, no encontré nada con eso todavía 😕. Prueba con otra "
                        "palabra, o publica lo que buscas en OkServicios → Busco y los "
                        "proveedores te contactan."), False
    if intent == "vender":
        return intent, (f"{nombre}, para vender toca \"+ Publicar\" arriba a la derecha en "
                        "OkMarket (productos) u OkServicios (servicios). Con una foto la app "
                        "te ayuda a completar el aviso. Aquí en la Comunidad puedes anclarlo "
                        "con el 📌."), False
    if intent == "pago":
        return intent, (f"{nombre}, en OkVenta el pago queda retenido hasta que confirmas "
                        "que recibiste el producto; si algo sale mal, reclamas y no se le "
                        "libera al vendedor. Nunca pagues por fuera de la app 🙏"), False
    if intent == "envio":
        return intent, (f"{nombre}, el vendedor elige cómo entregar: lo lleva él (y lo sigues "
                        "en el mapa), OkVenta Delivery o Blue Express. Confirmas la recepción "
                        "con una foto o escaneando el QR de la etiqueta."), False
    if intent == "historia":
        return intent, (f"{nombre}, en Mi OkVenta toca el + de tu foto para subir una historia "
                        "(dura 24 h). Con el ❤️ la dejas como destacada en tu perfil."), False
    if intent == "comunidad":
        return intent, (f"{nombre}, escribe @ y el nombre para mencionar a alguien (le llega un "
                        "aviso), y con el 📌 anclas lo que vendes. Los ⋯ de cada mensaje "
                        "tienen guardar, responder, denunciar y ocultar."), False
    return intent, (f"{nombre}, no estoy seguro de haberte entendido 🤔. Puedo buscar "
                    "productos (\"busco celular\"), servicios (\"necesito electricista\"), "
                    "mostrarte ofertas o explicarte cómo comprar y vender. Si es algo de una "
                    "compra, escribe \"soporte\" y te derivo."), False


# ── IA ───────────────────────────────────────────────────────────────────────

def _faq():
    try:
        with open(_FAQ_RUTA, encoding="utf-8") as f:
            return f.read()[:9000]
    except Exception:
        return ""


def _respuesta_ia(msg):
    import anthropic

    texto = msg.get("texto") or ""
    nombre = _primer_nombre(msg)
    prods = buscar_productos(texto)
    servs = buscar_servicios(texto)
    o = ofertas(5)
    contexto = (
        "Productos que coinciden con lo que escribió:\n" +
        ("\n".join(_linea_producto(p) for p in prods) or "(ninguno)") +
        "\n\nServicios que coinciden:\n" +
        ("\n".join(_linea_servicio(s) for s in servs) or "(ninguno)") +
        "\n\nOfertas actuales:\n" +
        ("\n".join(_linea_producto(p) for p in o) or "(ninguna)")
    )
    sistema = (
        "Eres el bot de OkVenta, un marketplace chileno de productos y servicios, "
        "conversando en el chat PÚBLICO de la Comunidad. Responde en español de Chile, "
        "cercano, breve (máximo 4 frases o una lista corta) y con algún emoji. "
        f"Le hablas a {nombre}.\n"
        "Reglas: usa SOLO los productos, servicios y ofertas del contexto (nunca inventes "
        "productos, precios ni políticas). Para cómo funciona la app usa el FAQ. "
        "No pidas ni repitas datos personales, de pago ni números de orden en el chat "
        "público. Si la consulta necesita revisar una orden, un pago, un reclamo, una "
        "cuenta, o no tienes la respuesta, empieza tu respuesta EXACTAMENTE con "
        "[ESCALAR] y luego una frase diciendo que la derivas al equipo de soporte.\n\n"
        f"## Contexto en vivo\n{contexto}\n\n## FAQ oficial\n{_faq()}"
    )

    # Memoria: la conversación reciente de este usuario con el bot.
    historial = []
    for m in db.ultimos_con_usuario(msg.get("user_id"), 10):
        if m.get("id") == msg.get("id"):
            continue
        rol = "assistant" if m.get("es_bot") else "user"
        contenido = (m.get("texto") or "").strip()
        if not contenido:
            continue
        if historial and historial[-1]["role"] == rol:
            historial[-1]["content"] += "\n" + contenido
        else:
            historial.append({"role": rol, "content": contenido})
    while historial and historial[0]["role"] != "user":
        historial.pop(0)
    if historial and historial[-1]["role"] == "user":
        historial[-1]["content"] += "\n" + texto
    else:
        historial.append({"role": "user", "content": texto})

    client = anthropic.Anthropic(api_key=os.environ["ANTHROPIC_API_KEY"], timeout=25)
    r = client.messages.create(model=MODEL, max_tokens=350, system=sistema,
                               messages=historial)
    salida = "".join(b.text for b in r.content if getattr(b, "type", "") == "text").strip()
    escalar = salida.startswith("[ESCALAR]")
    salida = salida.replace("[ESCALAR]", "").strip()
    return "ia", salida, escalar


# ── Escalamiento y bitácora ─────────────────────────────────────────────────

def _escalar(msg):
    """Crea un ticket de soporte con la consulta. Devuelve el id o None."""
    try:
        from database.ayuda import crear_ticket
        t = crear_ticket(
            msg.get("user_id"), "comunidad",
            f"Comunidad msg #{msg.get('id')}",
            f"Consulta derivada por el bot de la Comunidad: {msg.get('texto')}",
        )
        return t.get("id") if isinstance(t, dict) else None
    except Exception as e:
        print(f"WARN comunidad_bot escalar: {e}")
        return None


def _registrar(msg, respuesta_msg, intencion, modo, escalado, ticket_id):
    try:
        c = _conn()
        c.execute("""
            INSERT INTO comunidad_bot_log
                (user_id, mensaje_id, respuesta_id, pregunta, respuesta,
                 intencion, modo, escalado, ticket_id)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (msg.get("user_id"), msg.get("id"),
              respuesta_msg.get("id") if respuesta_msg else None,
              msg.get("texto"), respuesta_msg.get("texto") if respuesta_msg else None,
              intencion, modo, 1 if escalado else 0, ticket_id))
        c.commit()
        c.close()
    except Exception as e:
        print(f"WARN comunidad_bot log: {e}")


def responder(mensaje: dict):
    """Se llama en segundo plano. Nunca lanza: si la IA falla, usa reglas."""
    intencion, respuesta, escalar, modo = None, "", False, "reglas"
    if os.environ.get("ANTHROPIC_API_KEY"):
        try:
            intencion, respuesta, escalar = _respuesta_ia(mensaje)
            modo = "ia"
        except Exception as e:
            print(f"WARN comunidad_bot IA: {e}")
            respuesta = ""
    if not respuesta:
        intencion, respuesta, escalar = _respuesta_reglas(mensaje)
        modo = "reglas"
    ticket_id = _escalar(mensaje) if escalar else None
    if ticket_id:
        respuesta += f" (caso #{ticket_id})"
    nuevo = db.guardar_mensaje(None, respuesta, es_bot=True,
                               responde_a=mensaje.get("id"))
    _registrar(mensaje, nuevo, intencion, modo, escalar, ticket_id)


def publicar_oferta():
    """El bot ancla una oferta real al chat (desde el backoffice)."""
    o = ofertas(10)
    if not o:
        return None
    p = random.choice(o)
    return db.guardar_mensaje(
        None,
        random.choice([
            "🔥 Oferta del momento en OkMarket:",
            "👀 Miren lo que acaba de llegar:",
            "💥 Esto se va rápido:",
        ]),
        es_bot=True,
        ancla={"tipo": "publicacion", "id": p["id"], "titulo": p["titulo"],
               "precio": p["precio"], "imagen": p.get("imagen_url")},
    )


# ── Administración ──────────────────────────────────────────────────────────

def conversaciones(limite=100, solo_escalados=False, solo_pendientes=False):
    c = _conn()
    where = []
    if solo_escalados:
        where.append("l.escalado = 1")
    if solo_pendientes:
        where.append("l.revisado = 0")
    filas = c.execute(f"""
        SELECT l.*, u.nombre, u.apellido FROM comunidad_bot_log l
        LEFT JOIN users u ON u.id = l.user_id
        {"WHERE " + " AND ".join(where) if where else ""}
        ORDER BY l.id DESC LIMIT ?
    """, (limite,)).fetchall()
    c.close()
    return [dict(f) for f in filas]


def marcar_revisado(log_id):
    c = _conn()
    c.execute("UPDATE comunidad_bot_log SET revisado = 1 WHERE id = ?", (log_id,))
    c.commit()
    c.close()


def resumen():
    c = _conn()
    total = c.execute("SELECT COUNT(*) FROM comunidad_bot_log").fetchone()[0]
    escalados = c.execute(
        "SELECT COUNT(*) FROM comunidad_bot_log WHERE escalado = 1").fetchone()[0]
    pendientes = c.execute(
        "SELECT COUNT(*) FROM comunidad_bot_log WHERE escalado = 1 AND revisado = 0").fetchone()[0]
    por_intencion = {r[0] or "?": r[1] for r in c.execute(
        "SELECT intencion, COUNT(*) FROM comunidad_bot_log GROUP BY intencion ORDER BY 2 DESC")}
    por_modo = {r[0] or "?": r[1] for r in c.execute(
        "SELECT modo, COUNT(*) FROM comunidad_bot_log GROUP BY modo")}
    usuarios = c.execute(
        "SELECT COUNT(DISTINCT user_id) FROM comunidad_bot_log").fetchone()[0]
    c.close()
    return {"total_respuestas": total, "usuarios": usuarios, "escalados": escalados,
            "escalados_pendientes": pendientes, "por_intencion": por_intencion,
            "por_modo": por_modo,
            "ia_activa": bool(os.environ.get("ANTHROPIC_API_KEY"))}
