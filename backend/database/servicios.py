import sqlite3
import json
from config import PUBLICACIONES_DB as DB


def init_servicios_db():
    conn = sqlite3.connect(DB)
    c = conn.cursor()

    c.execute("""
    CREATE TABLE IF NOT EXISTS servicios (
        id                      INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id                 INTEGER NOT NULL,
        tipo                    TEXT    NOT NULL,       -- 'ofrezco' | 'busco'
        titulo                  TEXT    NOT NULL,
        descripcion             TEXT,
        comunas                 TEXT,                   -- texto libre
        valor                   REAL,
        modalidad               TEXT    DEFAULT 'servicio',  -- 'hora' | 'servicio'
        fotos                   TEXT    DEFAULT '[]',   -- JSON list de paths
        certificado_url         TEXT,
        certificado_verificado  INTEGER DEFAULT 0,
        lat                     REAL,
        lng                     REAL,
        radio_km                REAL    DEFAULT 5,
        telefono                TEXT,
        whatsapp                TEXT,
        created_at              TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
    """)

    # Migración: agregar radio_km si no existe
    try:
        c.execute("ALTER TABLE servicios ADD COLUMN radio_km REAL DEFAULT 5")
        conn.commit()
    except Exception:
        pass  # columna ya existe

    c.execute("""
    CREATE TABLE IF NOT EXISTS valoraciones_servicios (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        servicio_id INTEGER NOT NULL,
        user_id     INTEGER NOT NULL,
        estrellas   INTEGER NOT NULL CHECK(estrellas BETWEEN 1 AND 5),
        created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(servicio_id, user_id)
    )
    """)

    conn.commit()
    conn.close()


# ── Crear ─────────────────────────────────────────────────────────────────────

def crear_servicio(user_id, tipo, titulo, descripcion, comunas,
                   valor, modalidad, fotos,
                   lat=None, lng=None, radio_km=5.0,
                   telefono=None, whatsapp=None):
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    c.execute("""
        INSERT INTO servicios
            (user_id, tipo, titulo, descripcion, comunas,
             valor, modalidad, fotos, lat, lng, radio_km, telefono, whatsapp)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    """, (user_id, tipo, titulo, descripcion, comunas,
          valor, modalidad, json.dumps(fotos),
          lat, lng, radio_km, telefono, whatsapp))
    sid = c.lastrowid
    conn.commit()
    conn.close()
    return sid


def actualizar_ubicacion(servicio_id, user_id, lat, lng, radio_km):
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    c.execute("""
        UPDATE servicios
        SET lat = ?, lng = ?, radio_km = ?
        WHERE id = ? AND user_id = ?
    """, (lat, lng, radio_km, servicio_id, user_id))
    conn.commit()
    conn.close()


# ── Leer ──────────────────────────────────────────────────────────────────────

_SELECT = """
    SELECT s.id, s.user_id, s.tipo, s.titulo, s.descripcion, s.comunas,
           s.valor, s.modalidad, s.fotos,
           s.certificado_url, s.certificado_verificado,
           s.lat, s.lng, COALESCE(s.radio_km, 5) AS radio_km,
           s.telefono, s.whatsapp, s.created_at,
           u.nombre, u.apellido, u.foto_url,
           COALESCE(AVG(v.estrellas), 0) AS rating,
           COUNT(v.id) AS num_val
    FROM servicios s
    JOIN users u ON s.user_id = u.id
    LEFT JOIN valoraciones_servicios v ON s.id = v.servicio_id
"""


def obtener_servicios(tipo=None):
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    q = _SELECT
    if tipo:
        q += " WHERE s.tipo = ?"
        c.execute(q + " GROUP BY s.id ORDER BY s.created_at DESC", (tipo,))
    else:
        c.execute(q + " GROUP BY s.id ORDER BY s.created_at DESC")
    rows = c.fetchall()
    conn.close()
    return [_to_dict(r) for r in rows]


def obtener_servicio_por_id(servicio_id):
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    c.execute(_SELECT + " WHERE s.id = ? GROUP BY s.id", (servicio_id,))
    row = c.fetchone()
    conn.close()
    return _to_dict(row) if row else None


def obtener_servicios_usuario(user_id):
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    c.execute(_SELECT + " WHERE s.user_id = ? GROUP BY s.id ORDER BY s.created_at DESC",
              (user_id,))
    rows = c.fetchall()
    conn.close()
    return [_to_dict(r) for r in rows]


# ── Actualizar certificado ────────────────────────────────────────────────────

def actualizar_certificado(servicio_id, user_id, cert_url, verificado: bool):
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    c.execute("""
        UPDATE servicios
        SET certificado_url = ?, certificado_verificado = ?
        WHERE id = ? AND user_id = ?
    """, (cert_url, 1 if verificado else 0, servicio_id, user_id))
    conn.commit()
    conn.close()


# ── Eliminar ──────────────────────────────────────────────────────────────────

def eliminar_servicio(servicio_id, user_id):
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    c.execute("DELETE FROM servicios WHERE id = ? AND user_id = ?",
              (servicio_id, user_id))
    conn.commit()
    conn.close()


# ── Valoraciones ──────────────────────────────────────────────────────────────

def valorar_servicio(servicio_id, user_id, estrellas):
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    c.execute("""
        INSERT INTO valoraciones_servicios (servicio_id, user_id, estrellas)
        VALUES (?, ?, ?)
        ON CONFLICT(servicio_id, user_id) DO UPDATE SET estrellas = excluded.estrellas
    """, (servicio_id, user_id, estrellas))
    conn.commit()
    conn.close()


# ── Util ──────────────────────────────────────────────────────────────────────

def _to_dict(row):
    if not row:
        return None
    return {
        "id":                     row[0],
        "user_id":                row[1],
        "tipo":                   row[2],
        "titulo":                 row[3],
        "descripcion":            row[4],
        "comunas":                row[5],
        "valor":                  row[6],
        "modalidad":              row[7],
        "fotos":                  json.loads(row[8] or "[]"),
        "certificado_url":        row[9],
        "certificado_verificado": bool(row[10]),
        "lat":                    row[11],
        "lng":                    row[12],
        "radio_km":               float(row[13] or 5),
        "telefono":               row[14],
        "whatsapp":               row[15],
        "created_at":             row[16],
        "nombre":                 row[17],
        "apellido":               row[18],
        "foto_url":               row[19],
        "rating":                 round(float(row[20] or 0), 1),
        "num_valoraciones":       row[21],
    }
