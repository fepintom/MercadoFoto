import sqlite3
from datetime import datetime
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
        delivery_method     TEXT,   -- null | 'yo' | 'okventa' | 'blueexpress'
        created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
    """)
    # Migraciones: columnas añadidas después de la creación inicial
    c.execute("PRAGMA table_info(ordenes)")
    cols = [row[1] for row in c.fetchall()]
    migrations = [
        ("es_test",              "INTEGER DEFAULT 0"),
        ("delivery_method",      "TEXT"),
        ("updated_at",           "TIMESTAMP DEFAULT CURRENT_TIMESTAMP"),
        ("entrega_reportada_en", "TIMESTAMP"),
        ("recordatorio_enviado", "INTEGER DEFAULT 0"),
        ("token_confirmacion",   "TEXT"),
        # ── Seguro Garantía OkVenta (servicios) ──────────────────────────
        # Al aprobarse el pago de un servicio no se libera todo de una: se
        # abona el 80% al proveedor y se retiene el 20% durante 30 días. Si
        # el cliente no reclama garantía en ese plazo, un job libera el
        # resto (ver /admin/ordenes/liberar_retenidos).
        ("monto_liberado",       "REAL DEFAULT 0"),
        ("monto_retenido",       "REAL DEFAULT 0"),
        ("liberado_parcial_en",  "TIMESTAMP"),
        ("liberado_total_en",    "TIMESTAMP"),
        ("garantia_reclamada",   "INTEGER DEFAULT 0"),
        ("cotizacion_id",        "INTEGER"),
    ]
    for col, definition in migrations:
        if col not in cols:
            c.execute(f"ALTER TABLE ordenes ADD COLUMN {col} {definition}")
    conn.commit()
    conn.close()


# ── Crear ─────────────────────────────────────────────────────────────────────

def crear_orden(comprador_id, vendedor_id, tipo, titulo, monto,
                publicacion_id=None, servicio_id=None, comision=0.0,
                es_test=False):
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    c.execute("""
        INSERT INTO ordenes
            (comprador_id, vendedor_id, tipo, titulo, monto,
             publicacion_id, servicio_id, comision_okventa, es_test)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    """, (comprador_id, vendedor_id, tipo, titulo, monto,
          publicacion_id, servicio_id, comision, 1 if es_test else 0))
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
        SELECT o.*, uc.nombre AS nombre_vendedor, uc.foto_url AS foto_vendedor,
               CASE WHEN r.orden_id IS NOT NULL THEN 1 ELSE 0 END AS ya_calificado
        FROM ordenes o
        LEFT JOIN users uc ON o.vendedor_id = uc.id
        LEFT JOIN reviews r ON r.orden_id = o.id
        WHERE o.comprador_id = ?
        ORDER BY o.created_at DESC
    """, (user_id,))
    rows = c.fetchall()
    cols = [d[0] for d in c.description]
    conn.close()
    return [dict(zip(cols, r)) for r in rows]


def contar_ventas_completadas(vendedor_id: int) -> int:
    """Cantidad de órdenes entregadas de este vendedor — se muestra junto a
    su calificación como "n productos vendidos"."""
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    c.execute(
        "SELECT COUNT(*) FROM ordenes WHERE vendedor_id = ? AND estado = 'entregado'",
        (vendedor_id,),
    )
    total = c.fetchone()[0]
    conn.close()
    return total


def obtener_mis_ventas(user_id: int):
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    c.execute("""
        SELECT o.*, uc.nombre AS nombre_comprador, uc.foto_url AS foto_comprador,
               p.imagen_url AS foto_producto
        FROM ordenes o
        LEFT JOIN users uc ON o.comprador_id = uc.id
        LEFT JOIN publicaciones p ON o.publicacion_id = p.id
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


def guardar_delivery_method(orden_id: int, method: str):
    _update(orden_id, delivery_method=method, estado="en_camino")


def cancelar_orden(orden_id: int):
    _update(orden_id, estado="cancelado")


def obtener_pendientes_pago_vencidas(horas: int = 24):
    """Órdenes cuyo pago nunca se completó, para expirarlas (→ cancelado)."""
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    c.execute("""
        SELECT * FROM ordenes
        WHERE estado = 'pendiente_pago'
          AND created_at <= datetime('now', ?)
    """, (f"-{int(horas)} hours",))
    rows = c.fetchall()
    result = [_to_dict(c, r) for r in rows]
    conn.close()
    return result


def obtener_o_crear_token_confirmacion(orden_id: int):
    """Token del QR 'Confirmar entrega' de la etiqueta. Se genera una sola
    vez por orden: reimprimir la etiqueta no lo invalida."""
    import secrets as _secrets
    orden = obtener_orden(orden_id)
    if not orden:
        return None
    token = orden.get("token_confirmacion")
    if not token:
        token = _secrets.token_urlsafe(16)
        _update(orden_id, token_confirmacion=token)
    return token


def reportar_entrega(orden_id: int):
    """El vendedor reporta que entregó; empieza la ventana de 48h del comprador."""
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    c.execute("""
        UPDATE ordenes
        SET estado = 'entrega_reportada',
            entrega_reportada_en = CURRENT_TIMESTAMP,
            updated_at = CURRENT_TIMESTAMP
        WHERE id = ?
    """, (orden_id,))
    conn.commit()
    conn.close()


def marcar_recordatorio_enviado(orden_id: int):
    _update(orden_id, recordatorio_enviado=1)


def obtener_pendientes_recordatorio(horas: int = 24):
    """Órdenes en entrega_reportada hace más de `horas` sin recordatorio enviado."""
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    c.execute("""
        SELECT * FROM ordenes
        WHERE estado = 'entrega_reportada'
          AND COALESCE(recordatorio_enviado, 0) = 0
          AND entrega_reportada_en <= datetime('now', ?)
    """, (f"-{int(horas)} hours",))
    rows = c.fetchall()
    result = [_to_dict(c, r) for r in rows]
    conn.close()
    return result


def obtener_vencidas_autoconfirmar(horas: int = 48):
    """Órdenes en entrega_reportada hace más de `horas` (en_disputa queda
    excluida por el filtro de estado — nunca se auto-confirma una disputa)."""
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    c.execute("""
        SELECT * FROM ordenes
        WHERE estado = 'entrega_reportada'
          AND entrega_reportada_en <= datetime('now', ?)
    """, (f"-{int(horas)} hours",))
    rows = c.fetchall()
    result = [_to_dict(c, r) for r in rows]
    conn.close()
    return result


def _update(orden_id, **kwargs):
    if not kwargs:
        return
    sets = ", ".join(f"{k} = ?" for k in kwargs)
    vals = list(kwargs.values()) + [orden_id]
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    try:
        c.execute(
            f"UPDATE ordenes SET {sets}, updated_at = CURRENT_TIMESTAMP WHERE id = ?",
            vals,
        )
    except Exception as e:
        # Auto-migración: añade columnas faltantes y reintenta
        if "no such column" in str(e):
            _ensure_ordenes_cols(c)
            c.execute(
                f"UPDATE ordenes SET {sets}, updated_at = CURRENT_TIMESTAMP WHERE id = ?",
                vals,
            )
        else:
            raise
    conn.commit()
    conn.close()


def _ensure_ordenes_cols(cursor):
    cursor.execute("PRAGMA table_info(ordenes)")
    existing = {row[1] for row in cursor.fetchall()}
    for col, defn in [
        ("delivery_method",      "TEXT"),
        ("updated_at",           "TIMESTAMP DEFAULT CURRENT_TIMESTAMP"),
        ("es_test",              "INTEGER DEFAULT 0"),
        ("entrega_reportada_en", "TIMESTAMP"),
        ("recordatorio_enviado", "INTEGER DEFAULT 0"),
        ("token_confirmacion",   "TEXT"),
        # Mantener en paralelo con la lista de migrations de init_ordenes_db.
        ("monto_liberado",       "REAL DEFAULT 0"),
        ("monto_retenido",       "REAL DEFAULT 0"),
        ("liberado_parcial_en",  "TIMESTAMP"),
        ("liberado_total_en",    "TIMESTAMP"),
        ("garantia_reclamada",   "INTEGER DEFAULT 0"),
        ("cotizacion_id",        "INTEGER"),
    ]:
        if col not in existing:
            cursor.execute(f"ALTER TABLE ordenes ADD COLUMN {col} {defn}")


# ── Util ──────────────────────────────────────────────────────────────────────

def _to_dict(cursor, row):
    if not row:
        return None
    cols = [d[0] for d in cursor.description]
    return dict(zip(cols, row))


# ── Seguro Garantía OkVenta ─────────────────────────────────────────────────
# Reparte el pago de un servicio en dos tramos: 80% al proveedor apenas se
# aprueba el pago, y el 20% restante a los 30 días si el cliente no reclamó
# garantía. Igual que el resto del sistema de fondos, esto es contabilidad
# interna: marca cuánto corresponde pagar y cuándo, la transferencia al
# proveedor se coordina fuera (no existe payout automático de MercadoPago
# por vendedor todavía).

PORCENTAJE_LIBERACION_INICIAL = 0.80
DIAS_RETENCION_GARANTIA = 30


def liberar_inicial(orden_id: int, monto_neto: float):
    """Abona el 80% y retiene el 20%. Devuelve (liberado, retenido)."""
    liberado = round(monto_neto * PORCENTAJE_LIBERACION_INICIAL, 2)
    retenido = round(monto_neto - liberado, 2)
    _update(orden_id,
            monto_liberado=liberado,
            monto_retenido=retenido,
            liberado_parcial_en=datetime.now().isoformat(timespec="seconds"))
    return liberado, retenido


def liberar_retencion(orden_id: int):
    """Libera el 20% retenido (lo suma a monto_liberado y deja retenido en 0)."""
    orden = obtener_orden(orden_id)
    if not orden:
        return 0.0
    retenido = float(orden.get("monto_retenido") or 0)
    if retenido <= 0:
        return 0.0
    _update(orden_id,
            monto_liberado=round(float(orden.get("monto_liberado") or 0) + retenido, 2),
            monto_retenido=0,
            liberado_total_en=datetime.now().isoformat(timespec="seconds"))
    return retenido


def marcar_garantia_reclamada(orden_id: int):
    """Congela la retención: el 20% no se libera hasta resolver el reclamo."""
    _update(orden_id, garantia_reclamada=1)


def ordenes_con_retencion_vencida(dias: int = DIAS_RETENCION_GARANTIA):
    """Órdenes cuyo 20% ya cumplió el plazo y no tienen garantía reclamada."""
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    c.execute("""
        SELECT * FROM ordenes
        WHERE monto_retenido > 0
          AND COALESCE(garantia_reclamada, 0) = 0
          AND liberado_parcial_en IS NOT NULL
          AND datetime(liberado_parcial_en, '+' || ? || ' days') <= datetime('now')
    """, (int(dias),))
    cols = [d[0] for d in c.description]
    filas = [dict(zip(cols, r)) for r in c.fetchall()]
    conn.close()
    return filas
