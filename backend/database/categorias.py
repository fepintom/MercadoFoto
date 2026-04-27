import sqlite3
from typing import Optional

from config import PUBLICACIONES_DB as DB_PATH

def init_categorias_db():
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()

    cur.execute("""
        CREATE TABLE IF NOT EXISTS categorias (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nombre TEXT NOT NULL,
            parent_id INTEGER,
            nivel INTEGER NOT NULL,
            UNIQUE(nombre, parent_id),
            FOREIGN KEY (parent_id) REFERENCES categorias(id)
        )
    """)

    conn.commit()
    conn.close()


def get_or_create_categoria(nombre: str, parent_id: Optional[int], nivel: int) -> int:
    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()

    cur.execute("""
        SELECT id FROM categorias
        WHERE nombre = ? AND parent_id IS ?
    """, (nombre.strip(), parent_id))
    row = cur.fetchone()

    if row:
        conn.close()
        return row[0]

    cur.execute("""
        INSERT INTO categorias (nombre, parent_id, nivel)
        VALUES (?, ?, ?)
    """, (nombre.strip(), parent_id, nivel))

    conn.commit()
    new_id = cur.lastrowid
    conn.close()
    return new_id