import sqlite3
import os
from config import PUBLICACIONES_DB as DB


def init_preguntas_db():

    conn = sqlite3.connect(DB)
    cursor = conn.cursor()

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS preguntas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        publicacion_id INTEGER,
        usuario_id INTEGER,
        guest_id TEXT,
        mensaje TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
    """)

    conn.commit()
    conn.close()


def guardar_pregunta(publicacion_id, mensaje, user_id=None, guest_id=None):

    conn = sqlite3.connect(DB)
    cursor = conn.cursor()

    cursor.execute("""
        INSERT INTO preguntas (
            publicacion_id,
            usuario_id,
            guest_id,
            mensaje
        )
        VALUES (?, ?, ?, ?)
    """, (
        publicacion_id,
        user_id,
        guest_id,
        mensaje
    ))

    conn.commit()
    conn.close()


def obtener_preguntas(publicacion_id):

    conn = sqlite3.connect(DB)
    cursor = conn.cursor()

    cursor.execute("""
        SELECT mensaje, created_at
        FROM preguntas
        WHERE publicacion_id = ?
        ORDER BY id ASC
    """, (publicacion_id,))

    rows = cursor.fetchall()
    conn.close()

    preguntas = []

    for row in rows:

        preguntas.append({
            "mensaje": row[0],
            "fecha": row[1]
        })

    return preguntas