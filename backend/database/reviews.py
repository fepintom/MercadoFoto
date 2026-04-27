import sqlite3
import os
from config import PUBLICACIONES_DB as DB


def init_reviews_db():

    conn = sqlite3.connect(DB)
    cursor = conn.cursor()

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS reviews (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        vendedor_id INTEGER,
        comprador_id INTEGER,
        estrellas INTEGER,
        comentario TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
    """)

    conn.commit()
    conn.close()


def guardar_review(vendedor_id, comprador_id, estrellas, comentario):

    conn = sqlite3.connect(DB)
    cursor = conn.cursor()

    cursor.execute("""
        INSERT INTO reviews (
            vendedor_id,
            comprador_id,
            estrellas,
            comentario
        )
        VALUES (?, ?, ?, ?)
    """, (
        vendedor_id,
        comprador_id,
        estrellas,
        comentario
    ))

    conn.commit()
    conn.close()


def obtener_reviews_vendedor(vendedor_id):

    conn = sqlite3.connect(DB)
    cursor = conn.cursor()

    cursor.execute("""
        SELECT estrellas, comentario
        FROM reviews
        WHERE vendedor_id = ?
    """, (vendedor_id,))

    rows = cursor.fetchall()

    conn.close()

    total = len(rows)

    if total == 0:
        promedio = 0
    else:
        promedio = sum(r[0] for r in rows) / total

    comentarios = []

    for r in rows:
        comentarios.append({
            "estrellas": r[0],
            "comentario": r[1]
        })

    return {
        "promedio": round(promedio, 2),
        "total_reviews": total,
        "comentarios": comentarios
    }