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
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
    """)

    conn.commit()
    conn.close()


def crear_notificacion(user_id, tipo, mensaje):

    conn = sqlite3.connect(DB)
    cursor = conn.cursor()

    cursor.execute("""
        INSERT INTO notifications (
            user_id,
            tipo,
            mensaje
        )
        VALUES (?, ?, ?)
    """, (
        user_id,
        tipo,
        mensaje
    ))

    conn.commit()
    conn.close()



def obtener_notificaciones(user_id):

    conn = sqlite3.connect(DB)
    cursor = conn.cursor()

    cursor.execute("""
        SELECT id, tipo, mensaje, leido, created_at
        FROM notifications
        WHERE user_id = ?
        ORDER BY id DESC
    """, (user_id,))

    rows = cursor.fetchall()

    conn.close()

    data = []

    for r in rows:

        data.append({
            "id": r[0],
            "tipo": r[1],
            "mensaje": r[2],
            "leido": r[3],
            "fecha": r[4]
        })

    return data