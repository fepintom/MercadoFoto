import sqlite3
import os

# --------------------------------------------------
# DB PATH
# --------------------------------------------------

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB = os.path.join(BASE_DIR, "database", "publicaciones.db")


# --------------------------------------------------
# INIT DB
# --------------------------------------------------

def init_publicaciones_db():

    conn = sqlite3.connect(DB)
    cursor = conn.cursor()

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS publicaciones (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        titulo TEXT,
        descripcion TEXT,
        precio REAL,
        imagen_url TEXT,
        guest_id TEXT,
        user_id INTEGER,
        estado TEXT DEFAULT 'disponible',
        dimensiones TEXT,
        categoria TEXT,
        subcategoria TEXT,
        imagenes_extra TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
    """)

    # Migraciones seguras para columnas nuevas
    for col in ["dimensiones TEXT", "categoria TEXT", "subcategoria TEXT", "imagenes_extra TEXT"]:
        try:
            cursor.execute(f"ALTER TABLE publicaciones ADD COLUMN {col}")
        except Exception:
            pass

    conn.commit()
    conn.close()


# --------------------------------------------------
# GUARDAR PUBLICACION
# --------------------------------------------------

def guardar_publicacion(
    titulo,
    descripcion,
    precio,
    imagen_url,
    guest_id=None,
    user_id=None,
    dimensiones=None,
    categoria=None,
    subcategoria=None,
    imagenes_extra=None,
):

    conn = sqlite3.connect(DB)
    cursor = conn.cursor()

    cursor.execute("""
        INSERT INTO publicaciones (
            titulo,
            descripcion,
            precio,
            imagen_url,
            guest_id,
            user_id,
            dimensiones,
            categoria,
            subcategoria,
            imagenes_extra
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    """, (
        titulo,
        descripcion,
        precio,
        imagen_url,
        guest_id,
        user_id,
        dimensiones,
        categoria,
        subcategoria,
        imagenes_extra,
    ))

    conn.commit()
    conn.close()


# --------------------------------------------------
# OBTENER PUBLICACIONES
# --------------------------------------------------

def obtener_publicaciones():

    conn = sqlite3.connect(DB)
    cursor = conn.cursor()

    cursor.execute("""
    SELECT
        p.id,
        p.titulo,
        p.descripcion,
        p.precio,
        p.imagen_url,
        p.guest_id,
        p.user_id,
        p.estado,
        p.dimensiones,
        p.categoria,
        p.subcategoria,
        p.imagenes_extra,
        CASE
            WHEN u.nombre IS NOT NULL AND TRIM(u.nombre) <> ''
            THEN u.nombre
            ELSE 'Usuario invitado'
        END
    FROM publicaciones p
    LEFT JOIN users u
    ON p.user_id = u.id
    ORDER BY p.id DESC
    """)

    rows = cursor.fetchall()
    conn.close()

    publicaciones = []

    for row in rows:

        user_id = row[6]
        nombre_vendedor = row[12]
        emoji = "🙂" if user_id else "🙁"

        publicaciones.append({
            "id": row[0],
            "titulo": row[1],
            "descripcion": row[2],
            "precio": row[3],
            "imagen_url": row[4],
            "guest_id": row[5],
            "user_id": row[6],
            "estado": row[7],
            "dimensiones": row[8],
            "categoria": row[9],
            "subcategoria": row[10],
            "imagenes_extra": row[11],
            "seller_status": emoji,
            "nombre_vendedor": nombre_vendedor,
        })

    return publicaciones


# --------------------------------------------------
# FUNCION CAMBIAR ESTADO
# --------------------------------------------------

def cambiar_estado_publicacion(publicacion_id, estado):

    conn = sqlite3.connect(DB)
    cursor = conn.cursor()

    cursor.execute("""
        UPDATE publicaciones
        SET estado = ?
        WHERE id = ?
    """, (estado, publicacion_id))

    conn.commit()
    conn.close()


# --------------------------------------------------
# MIGRAR PUBLICACIONES GUEST → USER
# --------------------------------------------------

def migrar_publicaciones_guest(guest_id, user_id):

    conn = sqlite3.connect(DB)
    cursor = conn.cursor()

    cursor.execute("""
        UPDATE publicaciones
        SET user_id = ?, guest_id = NULL
        WHERE guest_id = ?
    """, (user_id, guest_id))

    conn.commit()
    conn.close()


# --------------------------------------------------
# OBTENER VENDEDOR DE PUBLICACION
# --------------------------------------------------

def obtener_vendedor_publicacion(publicacion_id):

    conn = sqlite3.connect(DB)
    cursor = conn.cursor()

    cursor.execute("""
        SELECT user_id
        FROM publicaciones
        WHERE id = ?
    """, (publicacion_id,))

    row = cursor.fetchone()
    conn.close()

    if not row:
        return None

    return row[0]


# --------------------------------------------------
# PRODUCTOS SIMILARES
# --------------------------------------------------

def obtener_productos_similares(publicacion_id):

    conn = sqlite3.connect(DB)
    cursor = conn.cursor()

    cursor.execute("""
        SELECT titulo
        FROM publicaciones
        WHERE id = ?
    """, (publicacion_id,))

    row = cursor.fetchone()

    if not row:
        conn.close()
        return []

    titulo = row[0]
    palabra = titulo.split(" ")[0]

    cursor.execute("""
        SELECT id, titulo, precio, imagen_url
        FROM publicaciones
        WHERE titulo LIKE ?
        AND id != ?
        LIMIT 10
    """, (f"%{palabra}%", publicacion_id))

    rows = cursor.fetchall()
    conn.close()

    data = []

    for r in rows:
        data.append({
            "id": r[0],
            "titulo": r[1],
            "precio": r[2],
            "imagen_url": r[3],
        })

    return data


# --------------------------------------------------
# ACTUALIZAR PRECIO PUBLICACION
# --------------------------------------------------

def actualizar_precio(publicacion_id, nuevo_precio):

    conn = sqlite3.connect(DB)
    cursor = conn.cursor()

    cursor.execute("""
        SELECT precio
        FROM publicaciones
        WHERE id = ?
    """, (publicacion_id,))

    row = cursor.fetchone()

    if not row:
        conn.close()
        return None

    precio_anterior = row[0]

    cursor.execute("""
        UPDATE publicaciones
        SET precio = ?
        WHERE id = ?
    """, (nuevo_precio, publicacion_id))

    conn.commit()
    conn.close()

    return precio_anterior