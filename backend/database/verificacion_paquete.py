"""Verificación anti-fraude del embalaje: sellos de seguridad + fotogramas
clave de los videos de boxing (vendedor) y unboxing (comprador).

Flujo:
    pago_confirmado/en_camino --(vendedor genera etiqueta)--> se crean los
        4 códigos de sello para la orden (obtener_o_crear_sellos)
    vendedor graba el packing --(app extrae fotogramas clave)-->
        guardar_boxing_frames
    comprador graba el unboxing --(app extrae fotogramas clave)-->
        guardar_unboxing_frames --(botón "Analizar")--> guardar_resultado_analisis
    al confirmarse la entrega (por cualquiera de las 3 vías: foto, QR u
        OkDelivery) --> eliminar_verificacion se llama para borrar los
        fotogramas de disco y la fila de la base, según la política de
        "los videos/fotogramas se eliminan cuando se cierra la compra".

Solo se guardan fotogramas clave (imágenes), nunca el video completo —
así se ahorra almacenamiento y de todas formas es lo único que necesita
el análisis con IA.
"""
import json
import secrets
import sqlite3
from config import PUBLICACIONES_DB as DB

RESULTADOS = ("pendiente", "ok", "alerta")


def init_verificacion_paquete_db():
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    c.execute("""
    CREATE TABLE IF NOT EXISTS verificacion_paquete (
        id                 INTEGER PRIMARY KEY AUTOINCREMENT,
        orden_id           INTEGER NOT NULL UNIQUE,
        sellos_json        TEXT    NOT NULL,   -- [{"numero":1,"codigo":"..."}, ...]
        boxing_frames      TEXT,               -- JSON: lista de "/uploads/..."
        unboxing_frames    TEXT,               -- JSON: lista de "/uploads/..."
        resultado          TEXT DEFAULT 'pendiente',  -- pendiente | ok | alerta
        mensaje_resultado  TEXT,
        creado_en          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        analizado_en       TIMESTAMP
    )
    """)
    conn.commit()
    conn.close()


def _row_to_dict(row, cols):
    d = dict(zip(cols, row))
    for campo in ("sellos_json", "boxing_frames", "unboxing_frames"):
        if d.get(campo):
            d[campo.replace("_json", "")] = json.loads(d[campo])
        else:
            d[campo.replace("_json", "")] = []
    return d


def obtener_verificacion(orden_id: int):
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    c.execute("SELECT * FROM verificacion_paquete WHERE orden_id = ?", (orden_id,))
    row = c.fetchone()
    cols = [d[0] for d in c.description]
    conn.close()
    return _row_to_dict(row, cols) if row else None


def obtener_o_crear_sellos(orden_id: int):
    """Devuelve los 4 códigos de sello de la orden, generándolos la primera
    vez que se piden (típicamente al generar la etiqueta de envío)."""
    existente = obtener_verificacion(orden_id)
    if existente:
        return existente["sellos"]

    sellos = [
        {"numero": n, "codigo": f"{orden_id:05d}-{n}-{secrets.token_hex(3).upper()}"}
        for n in range(1, 5)
    ]
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    try:
        c.execute("""
            INSERT INTO verificacion_paquete (orden_id, sellos_json)
            VALUES (?, ?)
        """, (orden_id, json.dumps(sellos)))
        conn.commit()
    except sqlite3.IntegrityError:
        # Carrera: otra request ya los creó justo antes.
        conn.close()
        return obtener_verificacion(orden_id)["sellos"]
    conn.close()
    return sellos


def guardar_boxing_frames(orden_id: int, frame_urls: list):
    obtener_o_crear_sellos(orden_id)  # asegura que exista la fila
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    c.execute("""
        UPDATE verificacion_paquete SET boxing_frames = ? WHERE orden_id = ?
    """, (json.dumps(frame_urls), orden_id))
    conn.commit()
    conn.close()


def guardar_unboxing_frames(orden_id: int, frame_urls: list):
    obtener_o_crear_sellos(orden_id)
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    c.execute("""
        UPDATE verificacion_paquete SET unboxing_frames = ? WHERE orden_id = ?
    """, (json.dumps(frame_urls), orden_id))
    conn.commit()
    conn.close()


def guardar_resultado_analisis(orden_id: int, resultado: str, mensaje: str):
    if resultado not in RESULTADOS:
        raise ValueError(f"Resultado inválido: {resultado}")
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    c.execute("""
        UPDATE verificacion_paquete
        SET resultado = ?, mensaje_resultado = ?, analizado_en = CURRENT_TIMESTAMP
        WHERE orden_id = ?
    """, (resultado, mensaje, orden_id))
    conn.commit()
    conn.close()


def eliminar_verificacion(orden_id: int):
    """Se llama cuando se confirma/cierra la entrega. Devuelve la lista de
    rutas '/uploads/...' (boxing + unboxing) para que el caller borre los
    archivos físicos del disco, y luego borra la fila de la base."""
    v = obtener_verificacion(orden_id)
    if not v:
        return []
    rutas = list(v.get("boxing_frames") or []) + list(v.get("unboxing_frames") or [])
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    c.execute("DELETE FROM verificacion_paquete WHERE orden_id = ?", (orden_id,))
    conn.commit()
    conn.close()
    return rutas
