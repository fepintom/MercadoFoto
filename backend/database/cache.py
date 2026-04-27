import sqlite3
from datetime import datetime, timedelta

from config import GENERAL_CACHE_DB as DB_PATH

def init_db():
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    cursor.execute("""
        CREATE TABLE IF NOT EXISTS cache (
            producto TEXT PRIMARY KEY,
            precio_min INTEGER,
            precio_max INTEGER,
            fecha TEXT
        )
    """)

    conn.commit()
    conn.close()


def guardar_cache(producto, min_price, max_price):
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    cursor.execute("""
        INSERT OR REPLACE INTO cache
        VALUES (?, ?, ?, ?)
    """, (producto, min_price, max_price, datetime.now().isoformat()))

    conn.commit()
    conn.close()


def obtener_cache(producto):
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    cursor.execute("SELECT * FROM cache WHERE producto=?", (producto,))
    row = cursor.fetchone()

    conn.close()

    if row:
        fecha = datetime.fromisoformat(row[3])
        if datetime.now() - fecha < timedelta(hours=24):
            return {
                "moneda": "CLP",
                "min": {
                    "precio": row[1],
                    "tienda": "MercadoLibre"
                },
                "max": {
                    "precio": row[2],
                    "tienda": "MercadoLibre"
                }
            }

    return None
