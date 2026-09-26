"""
database/comunidad.py
=====================
Chat público de la Comunidad: una sola sala donde todos hablan con todos,
como los chats antiguos de Messenger.

Un mensaje puede traer un "ancla": una publicación o un servicio del que lo
escribe. El título, precio e imagen se copian al momento de anclar para que
la tarjeta se pueda dibujar sin otra consulta y para que el mensaje siga
teniendo sentido aunque después se venda o se borre lo anclado.

Los mensajes del bot de OkVenta llevan `es_bot = 1` y `user_id` en NULL.
"""
import sqlite3

from config import PUBLICACIONES_DB as DB

MAX_TEXTO = 500


def _conn():
    conn = sqlite3.connect(DB)
    conn.row_factory = sqlite3.Row
    return conn


def init_comunidad_db():
    conn = _conn()
    conn.execute("""
    CREATE TABLE IF NOT EXISTS comunidad_mensajes (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id       INTEGER,
        es_bot        INTEGER DEFAULT 0,
        texto         TEXT,
        ancla_tipo    TEXT,      -- 'publicacion' | 'servicio' | NULL
        ancla_id      INTEGER,
        ancla_titulo  TEXT,
        ancla_precio  REAL,
        ancla_imagen  TEXT,
        responde_a    INTEGER,   -- id del mensaje al que responde (el bot)
        created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
    """)
    conn.execute(
        "CREATE INDEX IF NOT EXISTS idx_comunidad_created "
        "ON comunidad_mensajes(created_at)")
    conn.commit()
    conn.close()


_SELECT = """
    SELECT m.id, m.user_id, m.es_bot, m.texto,
           m.ancla_tipo, m.ancla_id, m.ancla_titulo, m.ancla_precio,
           m.ancla_imagen, m.responde_a, m.created_at,
           u.nombre, u.apellido, u.foto_url
    FROM comunidad_mensajes m
    LEFT JOIN users u ON u.id = m.user_id
"""


def _a_dict(r):
    d = dict(r)
    d["es_bot"] = bool(d.get("es_bot"))
    if d["es_bot"]:
        d["nombre"] = "OkVenta"
        d["apellido"] = None
        d["foto_url"] = None
    return d


def guardar_mensaje(user_id, texto, es_bot=False, ancla=None, responde_a=None):
    """Guarda un mensaje y lo devuelve ya armado como lo lee la app."""
    ancla = ancla or {}
    conn = _conn()
    cur = conn.execute("""
        INSERT INTO comunidad_mensajes
            (user_id, es_bot, texto, ancla_tipo, ancla_id, ancla_titulo,
             ancla_precio, ancla_imagen, responde_a)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    """, (
        user_id, 1 if es_bot else 0, (texto or "")[:MAX_TEXTO],
        ancla.get("tipo"), ancla.get("id"), ancla.get("titulo"),
        ancla.get("precio"), ancla.get("imagen"), responde_a,
    ))
    nuevo_id = cur.lastrowid
    conn.commit()
    row = conn.execute(_SELECT + " WHERE m.id = ?", (nuevo_id,)).fetchone()
    conn.close()
    return _a_dict(row)


def obtener_mensajes(despues_de=0, limite=60):
    """Sin `despues_de`: los últimos `limite`. Con él: solo los nuevos, que
    es lo que pide la app cada pocos segundos."""
    conn = _conn()
    if despues_de:
        rows = conn.execute(
            _SELECT + " WHERE m.id > ? ORDER BY m.id ASC LIMIT ?",
            (despues_de, limite)).fetchall()
    else:
        rows = conn.execute(
            _SELECT + " ORDER BY m.id DESC LIMIT ?", (limite,)).fetchall()
        rows = list(reversed(rows))
    conn.close()
    return [_a_dict(r) for r in rows]


def contar_mensajes():
    conn = _conn()
    n = conn.execute("SELECT COUNT(*) FROM comunidad_mensajes").fetchone()[0]
    conn.close()
    return n


def obtener_anclados(dias=7, limite=10):
    """Lo último que se ancló, sin repetir la misma publicación/servicio."""
    conn = _conn()
    rows = conn.execute(_SELECT + """
        WHERE m.id IN (
            SELECT MAX(id) FROM comunidad_mensajes
            WHERE ancla_tipo IS NOT NULL
              AND created_at >= datetime('now', ?)
            GROUP BY ancla_tipo, ancla_id
        )
        ORDER BY m.id DESC LIMIT ?
    """, (f"-{int(dias)} days", limite)).fetchall()
    conn.close()
    return [_a_dict(r) for r in rows]


def usuario_existe(user_id):
    conn = _conn()
    r = conn.execute("SELECT 1 FROM users WHERE id = ?", (user_id,)).fetchone()
    conn.close()
    return r is not None


def _primera_foto(fotos_json):
    import json
    try:
        fotos = json.loads(fotos_json or "[]")
        return fotos[0] if fotos else None
    except Exception:
        return None


def ancla_de_usuario(user_id, tipo, ancla_id):
    """Devuelve el snapshot del ancla SOLO si es del usuario. Así nadie
    puede anclar lo que vende otro."""
    conn = _conn()
    try:
        if tipo == "publicacion":
            r = conn.execute("""
                SELECT id, titulo, precio, imagen_url FROM publicaciones
                WHERE id = ? AND user_id = ? AND estado = 'disponible'
            """, (ancla_id, user_id)).fetchone()
            if not r:
                return None
            return {"tipo": tipo, "id": r["id"], "titulo": r["titulo"],
                    "precio": r["precio"], "imagen": r["imagen_url"]}
        if tipo == "servicio":
            r = conn.execute("""
                SELECT id, titulo, valor, fotos FROM servicios
                WHERE id = ? AND user_id = ?
            """, (ancla_id, user_id)).fetchone()
            if not r:
                return None
            return {"tipo": tipo, "id": r["id"], "titulo": r["titulo"],
                    "precio": r["valor"], "imagen": _primera_foto(r["fotos"])}
        return None
    finally:
        conn.close()


def anclables_de_usuario(user_id):
    """Lo que el usuario puede anclar: sus productos disponibles y sus
    servicios."""
    conn = _conn()
    pubs = conn.execute("""
        SELECT id, titulo, precio, imagen_url FROM publicaciones
        WHERE user_id = ? AND estado = 'disponible'
        ORDER BY created_at DESC LIMIT 50
    """, (user_id,)).fetchall()
    servs = conn.execute("""
        SELECT id, titulo, valor, fotos, tipo FROM servicios
        WHERE user_id = ? ORDER BY created_at DESC LIMIT 50
    """, (user_id,)).fetchall()
    conn.close()
    return {
        "publicaciones": [
            {"tipo": "publicacion", "id": r["id"], "titulo": r["titulo"],
             "precio": r["precio"], "imagen": r["imagen_url"]} for r in pubs],
        "servicios": [
            {"tipo": "servicio", "id": r["id"], "titulo": r["titulo"],
             "precio": r["valor"], "imagen": _primera_foto(r["fotos"]),
             "subtipo": r["tipo"]} for r in servs],
    }


def ofertas_recientes(limite=5):
    """Publicaciones disponibles para que el bot las recomiende."""
    conn = _conn()
    rows = conn.execute("""
        SELECT id, titulo, precio, imagen_url, categoria FROM publicaciones
        WHERE estado = 'disponible' AND precio IS NOT NULL AND precio > 0
        ORDER BY created_at DESC LIMIT ?
    """, (limite,)).fetchall()
    conn.close()
    return [dict(r) for r in rows]
