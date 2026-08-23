import sqlite3
import os
from config import PUBLICACIONES_DB as DB


def init_reviews_db():

    conn = sqlite3.connect(DB)
    cursor = conn.cursor()

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS reviews (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        vendedor_id INTEGER,
        comprador_id INTEGER,
        estrellas INTEGER,
        comentario TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
    """)

    # Migraciones: columnas añadidas después de la creación inicial.
    # orden_id liga la calificación a una compra concreta, para poder exigir
    # que solo el comprador real de esa orden (ya entregada) pueda calificar,
    # y para evitar que la misma compra se califique más de una vez.
    cursor.execute("PRAGMA table_info(reviews)")
    cols = [row[1] for row in cursor.fetchall()]
    if "orden_id" not in cols:
        cursor.execute("ALTER TABLE reviews ADD COLUMN orden_id INTEGER")

    # Único por orden (permite múltiples NULL para filas antiguas sin orden_id).
    cursor.execute("""
        CREATE UNIQUE INDEX IF NOT EXISTS idx_reviews_orden_unica
        ON reviews(orden_id) WHERE orden_id IS NOT NULL
    """)

    conn.commit()
    conn.close()


def ya_califico_orden(orden_id):
    conn = sqlite3.connect(DB)
    cursor = conn.cursor()
    cursor.execute("SELECT 1 FROM reviews WHERE orden_id = ?", (orden_id,))
    existe = cursor.fetchone() is not None
    conn.close()
    return existe


def guardar_review(vendedor_id, comprador_id, estrellas, comentario, orden_id=None):

    conn = sqlite3.connect(DB)
    cursor = conn.cursor()

    cursor.execute("""
        INSERT INTO reviews (
            vendedor_id,
            comprador_id,
            estrellas,
            comentario,
            orden_id
        )
        VALUES (?, ?, ?, ?, ?)
    """, (
        vendedor_id,
        comprador_id,
        estrellas,
        comentario,
        orden_id
    ))

    conn.commit()
    conn.close()


def obtener_reviews_vendedor(vendedor_id):

    conn = sqlite3.connect(DB)
    cursor = conn.cursor()

    cursor.execute("""
        SELECT r.estrellas, r.comentario, r.created_at, u.nombre
        FROM reviews r
        LEFT JOIN users u ON u.id = r.comprador_id
        WHERE r.vendedor_id = ?
        ORDER BY r.created_at DESC
    """, (vendedor_id,))

    rows = cursor.fetchall()

    conn.close()

    total = len(rows)

    if total == 0:
        promedio = 0
    else:
        promedio = sum(r[0] for r in rows) / total

    # Distribución para la barra de reputación (4 tramos, igual que el diseño
    # de la app): malas (1-2★), regular (3★), buena (4★), excelente (5★).
    malas = sum(1 for r in rows if r[0] <= 2)
    regular = sum(1 for r in rows if r[0] == 3)
    buena = sum(1 for r in rows if r[0] == 4)
    excelente = sum(1 for r in rows if r[0] == 5)

    def pct(n):
        return round((n / total) * 100, 1) if total else 0

    comentarios = []

    for r in rows:
        comentarios.append({
            "estrellas": r[0],
            "comentario": r[1],
            "fecha": r[2],
            "nombre_comprador": r[3] or "Usuario",
        })

    return {
        "promedio": round(promedio, 2),
        "total_reviews": total,
        "distribucion": {
            "malas": pct(malas),
            "regular": pct(regular),
            "buena": pct(buena),
            "excelente": pct(excelente),
        },
        "comentarios": comentarios,
    }


def obtener_reviews_vendedor_agrupadas(vendedor_id):
    """Evaluaciones del vendedor organizadas por producto (para el "muro"
    de reseñas). Cada review se liga a su producto a través de
    reviews.orden_id -> ordenes.publicacion_id. Las reviews antiguas sin
    orden_id (o cuya orden ya no tenga publicacion_id, p.ej. servicios)
    se agrupan aparte bajo "Otras reseñas"."""

    conn = sqlite3.connect(DB)
    cursor = conn.cursor()

    cursor.execute("""
        SELECT r.estrellas, r.comentario, r.created_at, u.nombre,
               o.publicacion_id, o.titulo, p.imagen_url
        FROM reviews r
        LEFT JOIN users u ON u.id = r.comprador_id
        LEFT JOIN ordenes o ON o.id = r.orden_id
        LEFT JOIN publicaciones p ON p.id = o.publicacion_id
        WHERE r.vendedor_id = ?
        ORDER BY r.created_at DESC
    """, (vendedor_id,))

    rows = cursor.fetchall()
    conn.close()

    grupos = {}
    orden_grupos = []

    for r in rows:
        (estrellas, comentario, fecha, nombre_comprador,
         publicacion_id, titulo_orden, imagen_url) = r

        if publicacion_id:
            clave = f"pub_{publicacion_id}"
            titulo = titulo_orden or "Producto"
        else:
            clave = "otras"
            titulo = "Otras reseñas"

        if clave not in grupos:
            grupos[clave] = {
                "publicacion_id": publicacion_id,
                "titulo": titulo,
                "imagen_url": imagen_url,
                "evaluaciones": [],
            }
            orden_grupos.append(clave)

        grupos[clave]["evaluaciones"].append({
            "estrellas": estrellas,
            "comentario": comentario,
            "fecha": fecha,
            "nombre_comprador": nombre_comprador or "Usuario",
        })

    return [grupos[c] for c in orden_grupos]
