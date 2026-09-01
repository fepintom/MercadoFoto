import sqlite3
import os
from config import PUBLICACIONES_DB as DB


def init_notifications_db():

    conn = sqlite3.connect(DB)
    cursor = conn.cursor()

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS notifications (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        tipo TEXT,
        mensaje TEXT,
        leido INTEGER DEFAULT 0,
        publicacion_id INTEGER DEFAULT NULL,
        remitente_id INTEGER DEFAULT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
    """)

    # Migraciones
    for col, definition in [
        ("publicacion_id", "INTEGER DEFAULT NULL"),
        ("remitente_id",   "INTEGER DEFAULT NULL"),
        ("orden_id",       "INTEGER DEFAULT NULL"),
        # Para que tocar la notificación de un servicio abra el chat correcto
        # hace falta el par completo (servicio + con quién es la conversación).
        ("servicio_id",    "INTEGER DEFAULT NULL"),
        ("cliente_id",     "INTEGER DEFAULT NULL"),
    ]:
        try:
            cursor.execute(f"ALTER TABLE notifications ADD COLUMN {col} {definition}")
        except Exception:
            pass

    conn.commit()
    conn.close()


def crear_notificacion(user_id, tipo, mensaje, publicacion_id=None, remitente_id=None,
                       orden_id=None, servicio_id=None, cliente_id=None):

    conn = sqlite3.connect(DB)
    cursor = conn.cursor()

    cursor.execute("""
        INSERT INTO notifications (user_id, tipo, mensaje, publicacion_id, remitente_id,
                                   orden_id, servicio_id, cliente_id)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    """, (user_id, tipo, mensaje, publicacion_id, remitente_id, orden_id,
          servicio_id, cliente_id))

    conn.commit()
    conn.close()


def marcar_leidas(user_id):

    conn = sqlite3.connect(DB)
    cursor = conn.cursor()

    cursor.execute(
        "UPDATE notifications SET leido = 1 WHERE user_id = ? AND leido = 0",
        (user_id,)
    )

    conn.commit()
    conn.close()


def obtener_notificaciones(user_id):

    conn = sqlite3.connect(DB)
    cursor = conn.cursor()

    cursor.execute("""
        SELECT id, tipo, mensaje, leido, created_at, publicacion_id, remitente_id,
               orden_id, servicio_id, cliente_id
        FROM notifications
        WHERE user_id = ?
        ORDER BY id DESC
        LIMIT 50
    """, (user_id,))

    rows = cursor.fetchall()
    conn.close()

    data = []
    for r in rows:
        data.append({
            "id":             r[0],
            "tipo":           r[1],
            "mensaje":        r[2],
            "leido":          r[3],
            "fecha":          r[4],
            "publicacion_id": r[5],
            "remitente_id":   r[6],
            "orden_id":       r[7] if len(r) > 7 else None,
            "servicio_id":    r[8] if len(r) > 8 else None,
            "cliente_id":     r[9] if len(r) > 9 else None,
        })

    return data