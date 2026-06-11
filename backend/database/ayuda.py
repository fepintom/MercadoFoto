import sqlite3
import os
from config import DB_DIR

_DB = os.path.join(DB_DIR, "ayuda.db")


def init_ayuda_db():
    conn = sqlite3.connect(_DB)
    cur = conn.cursor()

    cur.execute("""
        CREATE TABLE IF NOT EXISTS ayuda_tickets (
            id                 INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id            INTEGER NOT NULL,
            tipo               TEXT NOT NULL,
            numero_referencia  TEXT,
            detalle            TEXT NOT NULL,
            estado             TEXT DEFAULT 'abierto',
            created_at         TEXT DEFAULT (datetime('now'))
        )
    """)

    cur.execute("""
        CREATE TABLE IF NOT EXISTS ayuda_mensajes (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            ticket_id   INTEGER NOT NULL,
            remitente   TEXT NOT NULL,   -- 'usuario' | 'soporte'
            mensaje     TEXT NOT NULL,
            created_at  TEXT DEFAULT (datetime('now'))
        )
    """)

    conn.commit()
    conn.close()


def crear_ticket(user_id: int, tipo: str,
                 numero_referencia: str, detalle: str) -> dict:
    conn = sqlite3.connect(_DB)
    cur = conn.cursor()

    cur.execute("""
        INSERT INTO ayuda_tickets (user_id, tipo, numero_referencia, detalle)
        VALUES (?, ?, ?, ?)
    """, (user_id, tipo, numero_referencia or None, detalle))

    ticket_id = cur.lastrowid

    # Primer mensaje = el detalle del usuario
    cur.execute("""
        INSERT INTO ayuda_mensajes (ticket_id, remitente, mensaje)
        VALUES (?, 'usuario', ?)
    """, (ticket_id, detalle))

    conn.commit()
    conn.close()
    return {"id": ticket_id, "estado": "abierto"}


def agregar_mensaje(ticket_id: int, mensaje: str,
                    remitente: str = "soporte") -> bool:
    conn = sqlite3.connect(_DB)
    cur = conn.cursor()

    cur.execute("SELECT id FROM ayuda_tickets WHERE id = ?", (ticket_id,))
    if not cur.fetchone():
        conn.close()
        return False

    cur.execute("""
        INSERT INTO ayuda_mensajes (ticket_id, remitente, mensaje)
        VALUES (?, ?, ?)
    """, (ticket_id, remitente, mensaje))

    # Pasar a "en_proceso" cuando soporte responde por primera vez
    if remitente == "soporte":
        cur.execute("""
            UPDATE ayuda_tickets SET estado = 'en_proceso'
            WHERE id = ? AND estado = 'abierto'
        """, (ticket_id,))

    conn.commit()
    conn.close()
    return True


def obtener_tickets_usuario(user_id: int) -> list:
    conn = sqlite3.connect(_DB)
    conn.row_factory = sqlite3.Row
    cur = conn.cursor()

    cur.execute("""
        SELECT t.*,
               (SELECT COUNT(*) FROM ayuda_mensajes
                WHERE ticket_id = t.id AND remitente = 'soporte') AS respuestas
        FROM ayuda_tickets t
        WHERE t.user_id = ?
        ORDER BY t.created_at DESC
    """, (user_id,))

    tickets = [dict(r) for r in cur.fetchall()]
    conn.close()
    return tickets


def obtener_mensajes_ticket(ticket_id: int) -> list:
    conn = sqlite3.connect(_DB)
    conn.row_factory = sqlite3.Row
    cur = conn.cursor()

    cur.execute("""
        SELECT * FROM ayuda_mensajes
        WHERE ticket_id = ?
        ORDER BY created_at ASC
    """, (ticket_id,))

    mensajes = [dict(r) for r in cur.fetchall()]
    conn.close()
    return mensajes


def obtener_ticket(ticket_id: int):
    conn = sqlite3.connect(_DB)
    conn.row_factory = sqlite3.Row
    cur = conn.cursor()

    cur.execute("SELECT * FROM ayuda_tickets WHERE id = ?", (ticket_id,))
    row = cur.fetchone()
    conn.close()
    return dict(row) if row else None


def crear_ticket_chat_directo(user_id: int) -> dict:
    """Crea un ticket de chat directo con número de caso auto-generado."""
    conn = sqlite3.connect(_DB)
    cur = conn.cursor()

    cur.execute("""
        INSERT INTO ayuda_tickets (user_id, tipo, numero_referencia, detalle)
        VALUES (?, 'chat_directo', NULL, 'Chat directo iniciado desde la app')
    """, (user_id,))

    ticket_id = cur.lastrowid
    caso_numero = f"CASO-{str(ticket_id).zfill(6)}"

    cur.execute("UPDATE ayuda_tickets SET numero_referencia = ? WHERE id = ?",
                (caso_numero, ticket_id))

    # Mensaje de bienvenida automático de soporte
    cur.execute("""
        INSERT INTO ayuda_mensajes (ticket_id, remitente, mensaje)
        VALUES (?, 'soporte', '¡Hola! 👋 Soy del equipo OkVenta. ¿En qué te puedo ayudar hoy?')
    """, (ticket_id,))

    conn.commit()
    conn.close()
    return {"id": ticket_id, "caso_numero": caso_numero, "estado": "abierto"}


def cerrar_ticket(ticket_id: int) -> bool:
    conn = sqlite3.connect(_DB)
    cur = conn.cursor()
    cur.execute(
        "UPDATE ayuda_tickets SET estado = 'resuelto' WHERE id = ?",
        (ticket_id,))
    ok = cur.rowcount > 0
    conn.commit()
    conn.close()
    return ok
