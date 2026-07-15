"""Bitácora de eventos del proceso de compra-venta.

Registro append-only de cada transición relevante de una orden, con hora
(servidor) y lugar (lat/lng cuando aplica). Alimenta el backoffice JSON
en /admin/ordenes/{id}/bitacora para auditoría y análisis.

Eventos registrados:
    pago_confirmado        pago aprobado (test o webhook MP)
    entrega_elegida        vendedor eligió método (detalle = método)
    delivery_aceptado      repartidor OkDelivery tomó la entrega (hora+lugar)
    entrega_reportada      vendedor/repartidor entregó (hora+lugar+foto)
    recepcion_confirmada   comprador confirmó con foto
    auto_confirmada        confirmada por el job de 48h sin respuesta
    disputa_abierta        comprador reportó problema
    entregado              cierre por el flujo legacy (sin foto)
"""
import sqlite3
from config import PUBLICACIONES_DB as DB


def init_bitacora_db():
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    c.execute("""
    CREATE TABLE IF NOT EXISTS ordenes_bitacora (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        orden_id   INTEGER NOT NULL,
        evento     TEXT    NOT NULL,
        actor_id   INTEGER,             -- user/repartidor que gatilló el evento
        lat        REAL,
        lng        REAL,
        detalle    TEXT,                -- texto libre (método, motivo, foto...)
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
    """)
    c.execute("""
    CREATE INDEX IF NOT EXISTS idx_bitacora_orden
    ON ordenes_bitacora (orden_id)
    """)
    conn.commit()
    conn.close()


def registrar_evento(orden_id: int, evento: str, actor_id=None,
                     lat=None, lng=None, detalle=None):
    """Nunca debe romper el flujo principal: cualquier error se traga."""
    try:
        conn = sqlite3.connect(DB)
        c = conn.cursor()
        c.execute("""
            INSERT INTO ordenes_bitacora (orden_id, evento, actor_id, lat, lng, detalle)
            VALUES (?, ?, ?, ?, ?, ?)
        """, (orden_id, evento, actor_id, lat, lng, detalle))
        conn.commit()
        conn.close()
    except Exception:
        pass


def obtener_bitacora(orden_id: int):
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    c.execute("""
        SELECT id, evento, actor_id, lat, lng, detalle, created_at
        FROM ordenes_bitacora WHERE orden_id = ? ORDER BY id ASC
    """, (orden_id,))
    rows = c.fetchall()
    cols = [d[0] for d in c.description]
    conn.close()
    return [dict(zip(cols, r)) for r in rows]
