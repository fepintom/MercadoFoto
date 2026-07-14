"""Tracking de ubicación del vendedor cuando elige 'entrego yo'.

El vendedor publica su posición mientras va en camino y el comprador
la consulta (polling) para verlo moverse en el mapa, estilo Uber.
"""
import sqlite3
from config import PUBLICACIONES_DB as DB


def init_tracking_db():
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    c.execute("""
    CREATE TABLE IF NOT EXISTS tracking_vendedor (
        orden_id    INTEGER PRIMARY KEY,
        lat         REAL,
        lng         REAL,
        updated_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
    """)
    conn.commit()
    conn.close()


def actualizar_ubicacion_vendedor(orden_id: int, lat: float, lng: float):
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    c.execute("""
        INSERT INTO tracking_vendedor (orden_id, lat, lng, updated_at)
        VALUES (?, ?, ?, CURRENT_TIMESTAMP)
        ON CONFLICT(orden_id) DO UPDATE SET
            lat = excluded.lat,
            lng = excluded.lng,
            updated_at = CURRENT_TIMESTAMP
    """, (orden_id, lat, lng))
    conn.commit()
    conn.close()


def obtener_ubicacion_vendedor(orden_id: int):
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    c.execute(
        "SELECT lat, lng, updated_at FROM tracking_vendedor WHERE orden_id = ?",
        (orden_id,)
    )
    row = c.fetchone()
    conn.close()
    if not row:
        return None
    return {"lat": row[0], "lng": row[1], "updated_at": row[2]}
