import sqlite3
import uuid

from config import PUBLICACIONES_DB as DB


def init_guest_db():

    conn = sqlite3.connect(DB)
    cursor = conn.cursor()

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS guest_sessions (
        id TEXT PRIMARY KEY,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
    """)

    conn.commit()
    conn.close()


def crear_guest():

    guest_id = str(uuid.uuid4())

    conn = sqlite3.connect(DB)
    cursor = conn.cursor()

    cursor.execute(
        "INSERT INTO guest_sessions (id) VALUES (?)",
        (guest_id,)
    )

    conn.commit()
    conn.close()

    return guest_id