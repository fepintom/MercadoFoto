"""Cotizaciones de servicios.

El proveedor envía una cotización desde el chat del servicio. Se guarda como
fila propia (los datos estructurados) y además se genera un PDF con el
formato estándar de OkVenta, que viaja como un mensaje más del chat.

El cliente la acepta o la rechaza desde ese mismo mensaje. Al aceptar se
crea la orden y se cobra, reutilizando el flujo de pago que ya existe.

Estados:
    enviada   -> el cliente todavía no responde
    aceptada  -> se creó la orden y se pagó (orden_id apunta a ella)
    rechazada -> el cliente la descartó
"""
import sqlite3
from config import PUBLICACIONES_DB as DB

ESTADOS = ("enviada", "aceptada", "rechazada")


def init_cotizaciones_db():
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    c.execute("""
    CREATE TABLE IF NOT EXISTS cotizaciones (
        id                INTEGER PRIMARY KEY AUTOINCREMENT,
        servicio_id       INTEGER NOT NULL,
        proveedor_id      INTEGER NOT NULL,
        cliente_id        INTEGER NOT NULL,
        empresa           TEXT,           -- nombre de empresa del proveedor
        servicio_cotizado TEXT NOT NULL,
        monto             REAL NOT NULL,
        detalle           TEXT,
        pdf_url           TEXT,           -- /uploads/cotizacion_*.pdf
        estado            TEXT DEFAULT 'enviada',
        orden_id          INTEGER,        -- la orden creada al aceptar
        creado_en         TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        respondido_en     TIMESTAMP
    )
    """)
    c.execute("CREATE INDEX IF NOT EXISTS idx_cotiz_servicio ON cotizaciones(servicio_id)")
    c.execute("CREATE INDEX IF NOT EXISTS idx_cotiz_cliente ON cotizaciones(cliente_id)")
    conn.commit()
    conn.close()


def _dict(cursor, row):
    return dict(zip([d[0] for d in cursor.description], row)) if row else None


def crear_cotizacion(servicio_id: int, proveedor_id: int, cliente_id: int,
                     empresa: str, servicio_cotizado: str, monto: float,
                     detalle: str) -> int:
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    c.execute("""
        INSERT INTO cotizaciones
            (servicio_id, proveedor_id, cliente_id, empresa,
             servicio_cotizado, monto, detalle)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    """, (servicio_id, proveedor_id, cliente_id, (empresa or "").strip(),
          servicio_cotizado.strip(), float(monto), (detalle or "").strip()))
    cid = c.lastrowid
    conn.commit()
    conn.close()
    return cid


def guardar_pdf(cotizacion_id: int, pdf_url: str):
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    c.execute("UPDATE cotizaciones SET pdf_url = ? WHERE id = ?",
              (pdf_url, cotizacion_id))
    conn.commit()
    conn.close()


def obtener_cotizacion(cotizacion_id: int):
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    c.execute("SELECT * FROM cotizaciones WHERE id = ?", (cotizacion_id,))
    d = _dict(c, c.fetchone())
    conn.close()
    return d


def responder(cotizacion_id: int, estado: str, orden_id=None) -> bool:
    """Marca la cotización como aceptada o rechazada. Solo se puede
    responder una vez: si ya salió de 'enviada' devuelve False."""
    if estado not in ("aceptada", "rechazada"):
        raise ValueError(f"Estado inválido: {estado}")
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    c.execute("""
        UPDATE cotizaciones
        SET estado = ?, orden_id = ?, respondido_en = CURRENT_TIMESTAMP
        WHERE id = ? AND estado = 'enviada'
    """, (estado, orden_id, cotizacion_id))
    ok = c.rowcount > 0
    conn.commit()
    conn.close()
    return ok


def obtener_por_servicio(servicio_id: int, cliente_id=None):
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    if cliente_id is None:
        c.execute("SELECT * FROM cotizaciones WHERE servicio_id = ? ORDER BY id DESC",
                  (servicio_id,))
    else:
        c.execute("""SELECT * FROM cotizaciones
                     WHERE servicio_id = ? AND cliente_id = ?
                     ORDER BY id DESC""", (servicio_id, cliente_id))
    cols = [d[0] for d in c.description]
    filas = [dict(zip(cols, r)) for r in c.fetchall()]
    conn.close()
    return filas
