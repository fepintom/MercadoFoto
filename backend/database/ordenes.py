import sqlite3
from config import PUBLICACIONES_DB as DB


def init_ordenes_db():
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    c.execute("""
    CREATE TABLE IF NOT EXISTS ordenes (
        id                  INTEGER PRIMARY KEY AUTOINCREMENT,
        comprador_id        INTEGER NOT NULL,
        vendedor_id         INTEGER NOT NULL,
        tipo                TEXT    NOT NULL,   -- 'producto' | 'servicio'
        publicacion_id      INTEGER,            -- FK a publicaciones (producto)
        servicio_id         INTEGER,            -- FK a servicios
        titulo              TEXT    NOT NULL,
        monto               REAL    NOT NULL,
        comision_okventa    REAL    DEFAULT 0,
        mp_preference_id    TEXT,
        mp_payment_id       TEXT,
        mp_external_ref     TEXT UNIQUE,        -- 'orden_{id}' después de insertar
        estado              TEXT    DEFAULT 'pendiente_pago',
        -- pendiente_pago | pago_confirmado | en_camino | entregado | en_disputa | reembolsado | cancelado
        created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
    """)
    conn.commit()
    conn.close()


# ── Crear ─────────────────────────────────────────────────────────────────────

def crear_orden(comprador_id, vendedor_id, tipo, titulo, monto,
                publicacion_id=None, servicio_id=None, comision=0.0):
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    c.execute("""
        INSERT INTO ordenes
            (comprador_id, vendedor_id, tipo, titulo, monto,
             publicacion_id, servicio_id, comision_okventa)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    """, (comprador_id, vendedor_id, tipo, titulo, monto,
          publicacion_id, servicio_id, comision))
    oid = c.lastrowid
    # Fijar external_reference al ID real
    c.execute("UPDATE ordenes SET mp_external_ref = ? WHERE id = ?",
              (f"orden_{oid}", oid))
    conn.commit()
    conn.close()
    return oid


# ── Leer ──────────────────────────────────────────────────────────────────────

def obtener_orden(orden_id):
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    c.execute("SELECT * FROM ordenes WHERE id = ?", (orden_id,))
    row = c.fetchone()
    conn.close()
    return _to_dict(c, row) if row else None


def obtener_por_external_ref(external_ref: str):
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    c.execute("SELECT * FROM ordenes WHERE mp_external_ref = ?",
              (external_ref,))
    row = c.fetchone()
    conn.close()
    return _to_dict(c, row) if row else None


def obtener_mis_compras(user_id: int):
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    c.execute("""
        SELECT o.*, uc.nombre AS nombre_vendedor, uc.foto_url AS foto_vendedor
        FROM ordenes o
        LEFT JOIN users uc ON o.vendedor_id = uc.id
        WHERE o.comprador_id = ?
        ORDER BY o.created_at DESC
    """, (user_id,))
    rows = c.fetchall()
    cols = [d[0] for d in c.description]
    conn.close()
    return [dict(zip(cols, r)) for r in rows]


def obtener_mis_ventas(user_id: int):
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    c.execute("""
        SELECT o.*, uc.nombre AS nombre_comprador, uc.foto_url AS foto_comprador
        FROM ordenes o
        LEFT JOIN users uc ON o.comprador_id = uc.id
        WHERE o.vendedor_id = ?
        ORDER BY o.created_at DESC
    """, (user_id,))
    rows = c.fetchall()
    cols = [d[0] for d in c.description]
    conn.close()
    return [dict(zip(cols, r)) for r in rows]


# ── Actualizar ────────────────────────────────────────────────────────────────

def guardar_preference(orden_id, preference_id):
    _update(orden_id, mp_preference_id=preference_id)


def confirmar_pago(orden_id, payment_id):
    _update(orden_id, mp_payment_id=payment_id, estado="pago_confirmado")


def confirmar_entrega(orden_id):
    _update(orden_id, estado="entregado")


def abrir_disputa(orden_id):
    _update(orden_id, estado="en_disputa")


def marcar_reembolsado(orden_id):
    _update(orden_id, estado="reembolsado")


def _update(orden_id, **kwargs):
    if not kwargs:
        return
    sets = ", ".join(f"{k} = ?" for k in kwargs)
    vals = list(kwargs.values()) + [orden_id]
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    c.execute(
        f"UPDATE ordenes SET {sets}, updated_at = CURRENT_TIMESTAMP WHERE id = ?",
        vals,
    )
    conn.commit()
    conn.close()


# ── Util ──────────────────────────────────────────────────────────────────────

def _to_dict(cursor, row):
    if not row:
        return None
    cols = [d[0] for d in cursor.description]
    return dict(zip(cols, row))
