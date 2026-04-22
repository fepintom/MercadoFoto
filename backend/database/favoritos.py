import sqlite3
import os

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB = os.path.join(BASE_DIR, "database", "publicaciones.db")


def init_favoritos_db():

    conn = sqlite3.connect(DB)
    cursor = conn.cursor()

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS favoritos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        publicacion_id INTEGER,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
    """)

    conn.commit()
    conn.close()


def guardar_favorito(user_id, publicacion_id):
    """Guarda favorito solo si no existe (idempotente)."""
    conn = sqlite3.connect(DB)
    cursor = conn.cursor()

    cursor.execute("""
        SELECT id FROM favoritos WHERE user_id = ? AND publicacion_id = ?
    """, (user_id, publicacion_id))

    if not cursor.fetchone():
        cursor.execute("""
            INSERT INTO favoritos (user_id, publicacion_id)
            VALUES (?, ?)
        """, (user_id, publicacion_id))
        conn.commit()

    conn.close()


def eliminar_favorito(user_id, publicacion_id):

    conn = sqlite3.connect(DB)
    cursor = conn.cursor()

    cursor.execute("""
        DELETE FROM favoritos
        WHERE user_id = ? AND publicacion_id = ?
    """, (user_id, publicacion_id))

    conn.commit()
    conn.close()


def es_favorito(user_id, publicacion_id):

    conn = sqlite3.connect(DB)
    cursor = conn.cursor()

    cursor.execute("""
        SELECT id FROM favoritos
        WHERE user_id = ? AND publicacion_id = ?
    """, (user_id, publicacion_id))

    row = cursor.fetchone()
    conn.close()

    return row is not None


def obtener_favoritos(user_id):
    """Retorna IDs de publicaciones favoritas del usuario."""
    conn = sqlite3.connect(DB)
    cursor = conn.cursor()

    cursor.execute("""
        SELECT publicacion_id
        FROM favoritos
        WHERE user_id = ?
    """, (user_id,))

    rows = cursor.fetchall()
    conn.close()

    return [r[0] for r in rows]


def obtener_favoritos_completos(user_id):
    """Retorna las publicaciones completas guardadas como favorito."""
    conn = sqlite3.connect(DB)
    cursor = conn.cursor()

    cursor.execute("""
    SELECT
        p.id, p.titulo, p.descripcion, p.precio, p.imagen_url,
        p.user_id, p.estado, p.categoria, p.subcategoria,
        p.imagenes_extra,
        CASE WHEN u.nombre IS NOT NULL AND TRIM(u.nombre) <> ''
             THEN u.nombre ELSE 'Usuario invitado' END,
        p.lat, p.lng
    FROM favoritos f
    JOIN publicaciones p ON f.publicacion_id = p.id
    LEFT JOIN users u ON p.user_id = u.id
    WHERE f.user_id = ?
    ORDER BY f.id DESC
    """, (user_id,))

    rows = cursor.fetchall()
    conn.close()

    resultado = []
    for row in rows:
        resultado.append({
            "id": row[0], "titulo": row[1], "descripcion": row[2],
            "precio": row[3], "imagen_url": row[4],
            "user_id": row[5], "estado": row[6],
            "categoria": row[7], "subcategoria": row[8],
            "imagenes_extra": row[9],
            "nombre_vendedor": row[10],
            "lat": row[11], "lng": row[12],
        })

    return resultado


# --------------------------------------------------
# USUARIOS QUE GUARDARON PUBLICACION
# --------------------------------------------------

def obtener_usuarios_favorito(publicacion_id):

    conn = sqlite3.connect(DB)
    cursor = conn.cursor()

    cursor.execute("""
        SELECT user_id
        FROM favoritos
        WHERE publicacion_id = ?
    """, (publicacion_id,))

    rows = cursor.fetchall()

    conn.close()

    return [r[0] for r in rows]