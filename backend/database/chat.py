import sqlite3
import os
from config import PUBLICACIONES_DB as DB


def init_chat_db():

    conn = sqlite3.connect(DB)
    cursor = conn.cursor()

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS chat (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        publicacion_id INTEGER,
        remitente_id INTEGER,
        mensaje TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
    """)

    conn.commit()
    conn.close()



def guardar_mensaje(publicacion_id, remitente_id, mensaje):

    conn = sqlite3.connect(DB)
    cursor = conn.cursor()

    cursor.execute("""
        INSERT INTO chat (
            publicacion_id,
            remitente_id,
            mensaje
        )
        VALUES (?, ?, ?)
    """, (
        publicacion_id,
        remitente_id,
        mensaje
    ))

    conn.commit()
    conn.close()



def obtener_chat(publicacion_id):

    conn = sqlite3.connect(DB)
    cursor = conn.cursor()

    cursor.execute("""
        SELECT remitente_id, mensaje, created_at
        FROM chat
        WHERE publicacion_id = ?
        ORDER BY id ASC
    """, (publicacion_id,))

    rows = cursor.fetchall()
    conn.close()

    mensajes = []

    for r in rows:

        mensajes.append({
            "remitente": r[0],
            "mensaje": r[1],
            "fecha": r[2]
        })

    return mensajes