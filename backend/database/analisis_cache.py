# backend/database/analisis_cache.py
import sqlite3
from datetime import datetime
from typing import Optional, Tuple

from config import ANALISIS_CACHE_DB as DB_PATH

def init_cache_db():
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute("""
        CREATE TABLE IF NOT EXISTS analisis_cache (
            image_hash  TEXT PRIMARY KEY,
            titulo      TEXT NOT NULL,
            descripcion TEXT NOT NULL,
            used_gemini INTEGER NOT NULL DEFAULT 0,
            created_at  TEXT NOT NULL,
            precio_min  REAL,
            precio_max  REAL,
            moneda      TEXT DEFAULT 'CLP',
            confianza   TEXT
        )
    """)

    # ── Migraciones seguras para bases de datos existentes ──────────────
    _add_column_if_missing(cur, "precio_min", "REAL")
    _add_column_if_missing(cur, "precio_max", "REAL")
    _add_column_if_missing(cur, "moneda",     "TEXT DEFAULT 'CLP'")
    _add_column_if_missing(cur, "confianza",  "TEXT")

    conn.commit()
    conn.close()


def _add_column_if_missing(cur, column: str, column_def: str):
    """Agrega una columna solo si no existe (migración idempotente)."""
    try:
        cur.execute(f"ALTER TABLE analisis_cache ADD COLUMN {column} {column_def}")
    except Exception:
        pass  # La columna ya existe


def get_cached_analisis(image_hash: str) -> Optional[Tuple]:
    """
    Retorna (titulo, descripcion, used_gemini, precio_min, precio_max, moneda, confianza)
    o None si no existe en caché.
    """
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute(
        """SELECT titulo, descripcion, used_gemini,
                  precio_min, precio_max, moneda, confianza
           FROM analisis_cache
           WHERE image_hash = ?""",
        (image_hash,)
    )
    row = cur.fetchone()
    conn.close()
    if not row:
        return None
    return (
        row[0],           # titulo
        row[1],           # descripcion
        int(row[2]),      # used_gemini
        row[3],           # precio_min  (puede ser None si el registro es antiguo)
        row[4],           # precio_max
        row[5] or "CLP",  # moneda
        row[6],           # confianza
    )


def save_cached_analisis(
    image_hash: str,
    titulo: str,
    descripcion: str,
    used_gemini: int,
    precio_min: Optional[float] = None,
    precio_max: Optional[float] = None,
    moneda: str = "CLP",
    confianza: Optional[str] = None,
):
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()
    cur.execute("""
        INSERT OR REPLACE INTO analisis_cache
            (image_hash, titulo, descripcion, used_gemini, created_at,
             precio_min, precio_max, moneda, confianza)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    """, (
        image_hash,
        titulo,
        descripcion,
        int(used_gemini),
        datetime.utcnow().isoformat(),
        precio_min,
        precio_max,
        moneda,
        confianza,
    ))
    conn.commit()
    conn.close()
