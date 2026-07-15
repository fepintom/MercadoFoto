"""Evidencia fotográfica de entregas y disputas de órdenes.

Flujo de doble confirmación (solo delivery_method='yo'; OkVenta Delivery
tiene su propio flujo con evidencia en entregas_okdelivery, y Blue Express
se actualiza por guía/soporte, sin foto manual):

    en_camino --(vendedor sube foto)--> entrega_reportada
    entrega_reportada --(comprador sube foto)--> entregado
    entrega_reportada | en_camino --(comprador reclama)--> en_disputa

La evidencia nunca se sobreescribe ni se borra: es la prueba en caso de
disputa. UNIQUE(orden_id, tipo) garantiza a lo más una foto de 'entrega'
y una de 'recepcion' por orden.
"""
import sqlite3
from config import PUBLICACIONES_DB as DB

TIPOS_EVIDENCIA = ("entrega", "recepcion")


def init_evidencias_db():
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    c.execute("""
    CREATE TABLE IF NOT EXISTS entregas_evidencia (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        orden_id     INTEGER NOT NULL,
        tipo         TEXT    NOT NULL,   -- 'entrega' | 'recepcion'
        foto_path    TEXT    NOT NULL,
        lat          REAL,
        lng          REAL,
        capturado_en TEXT,               -- timestamp de la cámara (cliente)
        creado_en    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(orden_id, tipo)
    )
    """)
    c.execute("""
    CREATE TABLE IF NOT EXISTS disputas_orden (
        id                 INTEGER PRIMARY KEY AUTOINCREMENT,
        orden_id           INTEGER NOT NULL,
        motivo             TEXT    NOT NULL,
        descripcion        TEXT,
        foto_reclamo_path  TEXT,
        estado             TEXT DEFAULT 'abierta',
        -- abierta | resuelta_comprador | resuelta_vendedor
        creado_en          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        resuelto_en        TIMESTAMP
    )
    """)
    conn.commit()
    conn.close()


def crear_evidencia(orden_id: int, tipo: str, foto_path: str,
                    lat=None, lng=None, capturado_en=None):
    """Devuelve el id creado, o None si ya existía evidencia de ese tipo."""
    if tipo not in TIPOS_EVIDENCIA:
        raise ValueError(f"Tipo de evidencia inválido: {tipo}")
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    try:
        c.execute("""
            INSERT INTO entregas_evidencia
                (orden_id, tipo, foto_path, lat, lng, capturado_en)
            VALUES (?, ?, ?, ?, ?, ?)
        """, (orden_id, tipo, foto_path, lat, lng, capturado_en))
        conn.commit()
        return c.lastrowid
    except sqlite3.IntegrityError:
        return None
    finally:
        conn.close()


def obtener_evidencias(orden_id: int):
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    c.execute("""
        SELECT id, orden_id, tipo, foto_path, lat, lng, capturado_en, creado_en
        FROM entregas_evidencia WHERE orden_id = ?
    """, (orden_id,))
    rows = c.fetchall()
    cols = [d[0] for d in c.description]
    conn.close()
    return [dict(zip(cols, r)) for r in rows]


def existe_evidencia(orden_id: int, tipo: str) -> bool:
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    c.execute(
        "SELECT 1 FROM entregas_evidencia WHERE orden_id = ? AND tipo = ?",
        (orden_id, tipo))
    row = c.fetchone()
    conn.close()
    return row is not None


# ── Disputas ──────────────────────────────────────────────────────────────────

def crear_disputa(orden_id: int, motivo: str, descripcion=None,
                  foto_reclamo_path=None):
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    c.execute("""
        INSERT INTO disputas_orden (orden_id, motivo, descripcion, foto_reclamo_path)
        VALUES (?, ?, ?, ?)
    """, (orden_id, motivo, descripcion, foto_reclamo_path))
    did = c.lastrowid
    conn.commit()
    conn.close()
    return did


def obtener_disputas(orden_id: int):
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    c.execute("""
        SELECT id, orden_id, motivo, descripcion, foto_reclamo_path,
               estado, creado_en, resuelto_en
        FROM disputas_orden WHERE orden_id = ? ORDER BY id DESC
    """, (orden_id,))
    rows = c.fetchall()
    cols = [d[0] for d in c.description]
    conn.close()
    return [dict(zip(cols, r)) for r in rows]
