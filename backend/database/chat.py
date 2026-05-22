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



def obtener_conversaciones(user_id: int):
    """Retorna todas las conversaciones donde el usuario es comprador o vendedor."""
    conn = sqlite3.connect(DB)
    cursor = conn.cursor()
    cursor.execute("""
        SELECT
            p.id            AS publicacion_id,
            p.titulo,
            p.imagen_url,
            p.user_id       AS vendedor_id,
            uv.nombre       AS nombre_vendedor,
            uv.foto_url     AS foto_vendedor,
            uc.id           AS comprador_id,
            uc.nombre       AS nombre_comprador,
            uc.foto_url     AS foto_comprador,
            MAX(c.created_at) AS ultimo_at,
            (SELECT mensaje FROM chat
             WHERE publicacion_id = p.id
             ORDER BY id DESC LIMIT 1) AS ultimo_mensaje
        FROM chat c
        JOIN publicaciones p ON c.publicacion_id = p.id
        JOIN users uv ON p.user_id = uv.id
        JOIN users uc ON c.remitente_id = uc.id AND uc.id != p.user_id
        WHERE c.remitente_id = ? OR p.user_id = ?
        GROUP BY p.id
        ORDER BY ultimo_at DESC
    """, (user_id, user_id))
    rows = cursor.fetchall()
    conn.close()

    result = []
    for r in rows:
        result.append({
            "publicacion_id":   r[0],
            "titulo":           r[1],
            "imagen_url":       r[2],
            "vendedor_id":      r[3],
            "nombre_vendedor":  r[4],
            "foto_vendedor":    r[5],
            "comprador_id":     r[6],
            "nombre_comprador": r[7],
            "foto_comprador":   r[8],
            "ultimo_at":        r[9],
            "ultimo_mensaje":   r[10],
        })
    return result


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