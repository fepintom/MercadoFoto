import sqlite3
from config import PUBLICACIONES_DB as DB

# --------------------------------------------------------------------------
# ESTADOS DEL FLUJO OKDELIVERY (entregas_okdelivery.estado)
# --------------------------------------------------------------------------
# buscando_repartidor            -> se acaba de elegir 'okventa', buscando quién acepte
# asignado                       -> un repartidor aceptó, aún no se mueve
# en_camino_retiro               -> repartidor en camino a buscar el producto (tracking activo)
# llegado_retiro                 -> repartidor llegó donde el vendedor
# esperando_entrega_vendedor     -> esperando que el vendedor le entregue el producto
# esperando_confirmacion_calidad -> repartidor debe fotografiar y marcar ok/observaciones
# observaciones_reportadas       -> repartidor reportó observaciones, esperando que el vendedor repare
# reparacion_reportada           -> el vendedor dice que reparó, esperando que el repartidor lo verifique
# cancelado_sin_reparar          -> el vendedor no reparó -> venta cancelada
# en_camino_entrega               -> repartidor en camino al comprador (tracking activo)
# llegado_entrega                -> repartidor llegó donde el comprador
# entregado_pendiente_confirmacion -> entregado, foto tomada, corre timer de 1h, esperando al comprador
# cerrado_ok                     -> comprador confirmó (o venció el timer) -> fondos liberados
# cerrado_con_reclamo            -> comprador reportó un problema con video de unboxing


def init_entregas_db():
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    c.execute("""
    CREATE TABLE IF NOT EXISTS entregas_okdelivery (
        id                       INTEGER PRIMARY KEY AUTOINCREMENT,
        orden_id                 INTEGER NOT NULL UNIQUE,
        delivery_id              INTEGER,
        estado                   TEXT DEFAULT 'buscando_repartidor',
        pickup_lat               REAL,
        pickup_lng               REAL,
        destino_lat              REAL,
        destino_lng              REAL,
        delivery_lat             REAL,
        delivery_lng             REAL,
        ubicacion_actualizada_at TIMESTAMP,
        foto_retiro_url          TEXT,
        estado_producto_retiro   TEXT,
        observaciones_retiro     TEXT,
        foto_entrega_url         TEXT,
        entregado_at             TIMESTAMP,
        video_unboxing_url       TEXT,
        confirmacion_comprador   TEXT,
        reclamo_texto            TEXT,
        fondos_liberados         INTEGER DEFAULT 0,
        monto_vendedor           REAL,
        monto_comision           REAL,
        cerrado_at               TIMESTAMP,
        created_at               TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at               TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
    """)
    conn.commit()
    conn.close()


_COLS = [
    "id", "orden_id", "delivery_id", "estado",
    "pickup_lat", "pickup_lng", "destino_lat", "destino_lng",
    "delivery_lat", "delivery_lng", "ubicacion_actualizada_at",
    "foto_retiro_url", "estado_producto_retiro", "observaciones_retiro",
    "foto_entrega_url", "entregado_at", "video_unboxing_url",
    "confirmacion_comprador", "reclamo_texto",
    "fondos_liberados", "monto_vendedor", "monto_comision",
    "cerrado_at", "created_at", "updated_at",
]


def _to_dict(row):
    if not row:
        return None
    return dict(zip(_COLS, row))


def _select_one(where_sql, params):
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    c.execute("SELECT " + ", ".join(_COLS) + f" FROM entregas_okdelivery WHERE {where_sql}", params)
    row = c.fetchone()
    conn.close()
    return _to_dict(row)


def _update(orden_id, **kwargs):
    if not kwargs:
        return
    sets = ", ".join(f"{k} = ?" for k in kwargs)
    vals = list(kwargs.values()) + [orden_id]
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    c.execute(
        f"UPDATE entregas_okdelivery SET {sets}, updated_at = CURRENT_TIMESTAMP WHERE orden_id = ?",
        vals,
    )
    conn.commit()
    conn.close()


# ── Crear / leer ──────────────────────────────────────────────────────────────

def crear_entrega(orden_id, pickup_lat=None, pickup_lng=None, destino_lat=None, destino_lng=None):
    """Se llama al elegir 'okventa' como método de entrega. Idempotente."""
    existente = obtener_entrega(orden_id)
    if existente:
        return existente["id"]

    conn = sqlite3.connect(DB)
    c = conn.cursor()
    c.execute("""
        INSERT INTO entregas_okdelivery
            (orden_id, pickup_lat, pickup_lng, destino_lat, destino_lng, estado)
        VALUES (?, ?, ?, ?, ?, 'buscando_repartidor')
    """, (orden_id, pickup_lat, pickup_lng, destino_lat, destino_lng))
    eid = c.lastrowid
    conn.commit()
    conn.close()
    return eid


def obtener_entrega(orden_id):
    return _select_one("orden_id = ?", (orden_id,))


def obtener_entrega_por_id(entrega_id):
    return _select_one("id = ?", (entrega_id,))


def obtener_entregas_buscando():
    """Entregas 'okventa' esperando que un repartidor acepte."""
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    c.execute(
        "SELECT " + ", ".join(_COLS) +
        " FROM entregas_okdelivery WHERE estado = 'buscando_repartidor' ORDER BY created_at ASC"
    )
    rows = c.fetchall()
    conn.close()
    return [_to_dict(r) for r in rows]


def obtener_entregas_pendientes_repartidor(delivery_id):
    """Entregas activas asignadas a un repartidor (para su panel)."""
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    c.execute(
        "SELECT " + ", ".join(_COLS) + """
        FROM entregas_okdelivery
        WHERE delivery_id = ?
          AND estado NOT IN ('cerrado_ok', 'cerrado_con_reclamo', 'cancelado_sin_reparar')
        ORDER BY created_at DESC
        """,
        (delivery_id,),
    )
    rows = c.fetchall()
    conn.close()
    return [_to_dict(r) for r in rows]


# ── Transiciones del flujo ────────────────────────────────────────────────────

def asignar_repartidor(orden_id, delivery_id):
    _update(orden_id, delivery_id=delivery_id, estado="asignado")


def actualizar_ubicacion_repartidor(orden_id, lat, lng):
    """Ping periódico del repartidor. Si sigue 'asignado' pasa a 'en_camino_retiro'."""
    entrega = obtener_entrega(orden_id)
    if not entrega:
        return None
    nuevo_estado = entrega["estado"]
    if nuevo_estado == "asignado":
        nuevo_estado = "en_camino_retiro"
    elif nuevo_estado == "llegado_retiro":
        # ya retiró y va en camino al comprador
        pass
    _update(orden_id, delivery_lat=lat, delivery_lng=lng,
            ubicacion_actualizada_at=_now(), estado=nuevo_estado)
    return nuevo_estado


def marcar_llegada_retiro(orden_id):
    _update(orden_id, estado="llegado_retiro")


def marcar_entrega_del_vendedor(orden_id):
    """El vendedor confirma que entregó el producto al repartidor."""
    _update(orden_id, estado="esperando_confirmacion_calidad")


def confirmar_recepcion_repartidor(orden_id, foto_url, estado_producto, observaciones=None):
    """
    estado_producto: 'ok' | 'con_observaciones'
    """
    if estado_producto == "ok":
        _update(orden_id,
                foto_retiro_url=foto_url,
                estado_producto_retiro=estado_producto,
                estado="en_camino_entrega")
    else:
        _update(orden_id,
                foto_retiro_url=foto_url,
                estado_producto_retiro=estado_producto,
                observaciones_retiro=observaciones or "",
                estado="observaciones_reportadas")


def marcar_reparacion_reportada(orden_id):
    """El vendedor indica que reparó el producto. El repartidor debe verificarlo en persona."""
    _update(orden_id, estado="reparacion_reportada")


def confirmar_reparacion(orden_id):
    """El repartidor verifica en persona que el producto quedó ok y sigue camino al comprador."""
    _update(orden_id, estado="en_camino_entrega")


def cancelar_sin_reparar(orden_id):
    _update(orden_id, estado="cancelado_sin_reparar", cerrado_at=_now())


def marcar_llegada_entrega(orden_id):
    _update(orden_id, estado="llegado_entrega")


def confirmar_entrega_comprador(orden_id, foto_url):
    """El repartidor entrega al comprador y sube foto. Arranca el timer de 1h."""
    _update(orden_id,
            foto_entrega_url=foto_url,
            estado="entregado_pendiente_confirmacion",
            entregado_at=_now())


def confirmar_recepcion_comprador(orden_id, video_url=None, por_timeout=False):
    _update(orden_id,
            confirmacion_comprador="timeout" if por_timeout else "ok",
            video_unboxing_url=video_url,
            estado="cerrado_ok",
            cerrado_at=_now())


def reportar_reclamo_comprador(orden_id, texto, video_url):
    _update(orden_id,
            confirmacion_comprador="con_reclamo",
            reclamo_texto=(texto or "")[:500],
            video_unboxing_url=video_url,
            estado="cerrado_con_reclamo",
            cerrado_at=_now())


def liberar_fondos(orden_id, monto_vendedor, monto_comision):
    """
    Marca los fondos como liberados internamente (transferencia manual al
    vendedor por fuera del sistema mientras no exista payout automático de MP).
    """
    _update(orden_id,
            fondos_liberados=1,
            monto_vendedor=monto_vendedor,
            monto_comision=monto_comision)


def obtener_entregas_vencidas(minutos=60):
    """Para el worker de auto-cierre: entregadas hace más de `minutos` sin respuesta."""
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    c.execute("""
        SELECT """ + ", ".join(_COLS) + """
        FROM entregas_okdelivery
        WHERE estado = 'entregado_pendiente_confirmacion'
          AND confirmacion_comprador IS NULL
          AND entregado_at IS NOT NULL
          AND datetime(entregado_at, ?) <= datetime('now')
    """, (f"+{int(minutos)} minutes",))
    rows = c.fetchall()
    conn.close()
    return [_to_dict(r) for r in rows]


def _now():
    import datetime
    return datetime.datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S")
