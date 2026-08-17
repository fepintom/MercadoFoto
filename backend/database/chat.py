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

    # Migración: columna para imágenes en chat
    try:
        cursor.execute("ALTER TABLE chat ADD COLUMN imagen_url TEXT")
    except Exception:
        pass

    # Migración: videos en chat (se eliminan automáticamente a las 48h,
    # ver limpiar_videos_expirados()).
    for col in ["video_url TEXT", "video_expira_en TIMESTAMP"]:
        try:
            cursor.execute(f"ALTER TABLE chat ADD COLUMN {col}")
        except Exception:
            pass

    conn.commit()
    conn.close()



def guardar_mensaje(publicacion_id, remitente_id, mensaje, imagen_url=None,
                    video_url=None, video_expira_en=None):

    conn = sqlite3.connect(DB)
    cursor = conn.cursor()

    cursor.execute("""
        INSERT INTO chat (
            publicacion_id,
            remitente_id,
            mensaje,
            imagen_url,
            video_url,
            video_expira_en
        )
        VALUES (?, ?, ?, ?, ?, ?)
    """, (
        publicacion_id,
        remitente_id,
        mensaje,
        imagen_url,
        video_url,
        video_expira_en,
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
        SELECT remitente_id, mensaje, created_at, imagen_url, video_url
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
            "fecha": r[2],
            "imagen_url": r[3],
            "video_url": r[4],
        })

    return mensajes


def limpiar_videos_expirados():
    """Videos de chat con más de 48h: borra la referencia en la DB y
    devuelve las URLs para que quien llame elimine los archivos físicos
    (permanencia máxima de 48h para no acumular memoria)."""
    conn = sqlite3.connect(DB)
    cursor = conn.cursor()

    cursor.execute("""
        SELECT id, video_url FROM chat
        WHERE video_url IS NOT NULL
          AND video_expira_en IS NOT NULL
          AND video_expira_en <= datetime('now')
    """)
    rows = cursor.fetchall()

    urls = []
    for mensaje_id, video_url in rows:
        urls.append(video_url)
        cursor.execute("""
            UPDATE chat
            SET video_url = NULL,
                mensaje = '🎥 Video eliminado (48 h)'
            WHERE id = ?
        """, (mensaje_id,))

    conn.commit()
    conn.close()
    return urls