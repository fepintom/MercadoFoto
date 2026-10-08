import sqlite3
import os
from config import PUBLICACIONES_DB as DB


def init_notifications_db():

    conn = sqlite3.connect(DB)
    cursor = conn.cursor()

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS notifications (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        tipo TEXT,
        mensaje TEXT,
        leido INTEGER DEFAULT 0,
        publicacion_id INTEGER DEFAULT NULL,
        remitente_id INTEGER DEFAULT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
    """)

    # Migraciones
    for col, definition in [
        ("publicacion_id", "INTEGER DEFAULT NULL"),
        ("remitente_id",   "INTEGER DEFAULT NULL"),
        ("orden_id",       "INTEGER DEFAULT NULL"),
        # Para que tocar la notificación de un servicio abra el chat correcto
        # hace falta el par completo (servicio + con quién es la conversación).
        ("servicio_id",    "INTEGER DEFAULT NULL"),
        ("cliente_id",     "INTEGER DEFAULT NULL"),
    ]:
        try:
            cursor.execute(f"ALTER TABLE notifications ADD COLUMN {col} {definition}")
        except Exception:
            pass

    conn.commit()
    conn.close()


def crear_notificacion(user_id, tipo, mensaje, publicacion_id=None, remitente_id=None,
                       orden_id=None, servicio_id=None, cliente_id=None):

    conn = sqlite3.connect(DB)
    cursor = conn.cursor()

    cursor.execute("""
        INSERT INTO notifications (user_id, tipo, mensaje, publicacion_id, remitente_id,
                                   orden_id, servicio_id, cliente_id)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    """, (user_id, tipo, mensaje, publicacion_id, remitente_id, orden_id,
          servicio_id, cliente_id))

    conn.commit()
    conn.close()


def marcar_leidas(user_id):

    conn = sqlite3.connect(DB)
    cursor = conn.cursor()

    cursor.execute(
        "UPDATE notifications SET leido = 1 WHERE user_id = ? AND leido = 0",
        (user_id,)
    )

    conn.commit()
    conn.close()


# Categorías para los filtros de la pestaña Notificaciones de la app.
_VENTAS = {"oferta", "interes_compra", "review", "elegir_entrega",
           "entrega_confirmada", "orden_cancelada", "fondos_liberados",
           "disputa", "okdelivery_asignado", "okdelivery_observaciones"}
_COMPRAS = {"oferta_respuesta", "precio", "en_camino", "entrega_reportada",
            "recordatorio_confirmacion", "okdelivery_en_camino",
            "venta_cancelada"}
_PREGUNTAS = {"pregunta", "chat", "chat_servicio"}


def _categoria(tipo, user_id, orden):
    """compras | ventas | preguntas | comunidad | otros.

    Si la notificación es de una orden, manda el rol real del usuario en esa
    orden (comprador → compras, vendedor → ventas): así los tipos que llegan
    a ambos lados (pagos de servicios, OkDelivery) quedan bien."""
    tipo = tipo or ""
    if tipo.startswith("comunidad"):
        return "comunidad"
    if tipo in _PREGUNTAS:
        return "preguntas"
    if orden:
        comprador, vendedor = orden
        if user_id == comprador:
            return "compras"
        if user_id == vendedor:
            return "ventas"
    if tipo in _VENTAS:
        return "ventas"
    if tipo in _COMPRAS:
        return "compras"
    return "otros"


def obtener_notificaciones(user_id):

    conn = sqlite3.connect(DB)
    cursor = conn.cursor()

    cursor.execute("""
        SELECT id, tipo, mensaje, leido, created_at, publicacion_id, remitente_id,
               orden_id, servicio_id, cliente_id
        FROM notifications
        WHERE user_id = ?
        ORDER BY id DESC
        LIMIT 100
    """, (user_id,))

    rows = cursor.fetchall()

    ordenes = {}
    ids = sorted({r[7] for r in rows if len(r) > 7 and r[7]})
    if ids:
        try:
            marcas = ",".join("?" * len(ids))
            for oid, comp, vend in cursor.execute(
                    f"SELECT id, comprador_id, vendedor_id FROM ordenes "
                    f"WHERE id IN ({marcas})", ids):
                ordenes[oid] = (comp, vend)
        except sqlite3.OperationalError:
            pass
    conn.close()

    data = []
    for r in rows:
        data.append({
            "id":             r[0],
            "tipo":           r[1],
            "mensaje":        r[2],
            "leido":          r[3],
            "fecha":          r[4],
            "publicacion_id": r[5],
            "remitente_id":   r[6],
            "orden_id":       r[7] if len(r) > 7 else None,
            "servicio_id":    r[8] if len(r) > 8 else None,
            "cliente_id":     r[9] if len(r) > 9 else None,
            "categoria":      _categoria(r[1], user_id, ordenes.get(r[7])),
        })

    return data