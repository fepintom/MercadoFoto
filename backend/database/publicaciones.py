import sqlite3
import os
from config import PUBLICACIONES_DB as DB


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
    for col in [
        "dimensiones TEXT",
        "categoria TEXT",
        "subcategoria TEXT",
        "imagenes_extra TEXT",
        "lat REAL",
        "lng REAL",
        "delivery_id INTEGER",
        "condicion TEXT DEFAULT 'nuevo'",
        "acepta_ofertas INTEGER DEFAULT 1",
        "sku TEXT",
        "stock INTEGER",
        "codigo_universal TEXT",
        "tallas TEXT",
        "tipo_publicacion TEXT DEFAULT 'expres'",
    ]:
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
    lat=None,
    lng=None,
    delivery_id=None,
    condicion=None,
    acepta_ofertas=1,
    tallas=None,
    tipo_publicacion='expres',
    sku=None,
    stock=None,
    codigo_universal=None,
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
            imagenes_extra,
            lat,
            lng,
            delivery_id,
            condicion,
            acepta_ofertas,
            tallas,
            tipo_publicacion,
            sku,
            stock,
            codigo_universal
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
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
        lat,
        lng,
        delivery_id,
        condicion or 'nuevo',
        acepta_ofertas,
        tallas,
        tipo_publicacion or 'expres',
        sku,
        stock,
        codigo_universal,
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
        END,
        p.lat,
        p.lng,
        p.condicion,
        p.acepta_ofertas,
        p.sku,
        p.stock,
        p.codigo_universal,
        p.tallas,
        p.tipo_publicacion
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
            "lat": row[13],
            "lng": row[14],
            "condicion": row[15],
            "acepta_ofertas": row[16],
            "sku": row[17],
            "stock": row[18],
            "codigo_universal": row[19],
            "tallas": row[20],
            "tipo_publicacion": row[21],
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

def obtener_productos_similares(publicacion_id, limite=12):
    """Otras publicaciones disponibles de la misma categoría (idealmente la
    misma subcategoría), para mostrar como "también te puede interesar" al
    final del detalle de un producto sin salir de esa pantalla."""

    conn = sqlite3.connect(DB)
    cursor = conn.cursor()

    cursor.execute("""
        SELECT titulo, categoria, subcategoria
        FROM publicaciones
        WHERE id = ?
    """, (publicacion_id,))

    row = cursor.fetchone()

    if not row:
        conn.close()
        return []

    titulo, categoria, subcategoria = row
    rows = []

    if subcategoria:
        cursor.execute("""
            SELECT id, titulo, precio, imagen_url, categoria, subcategoria, condicion
            FROM publicaciones
            WHERE estado = 'disponible' AND id != ? AND subcategoria = ?
            ORDER BY id DESC
            LIMIT ?
        """, (publicacion_id, subcategoria, limite))
        rows = cursor.fetchall()

    # Si la subcategoría no alcanza el límite, se completa con la categoría.
    if len(rows) < limite and categoria:
        vistos = {r[0] for r in rows}
        cursor.execute("""
            SELECT id, titulo, precio, imagen_url, categoria, subcategoria, condicion
            FROM publicaciones
            WHERE estado = 'disponible' AND id != ? AND categoria = ?
            ORDER BY id DESC
            LIMIT ?
        """, (publicacion_id, categoria, limite))
        for r in cursor.fetchall():
            if r[0] not in vistos and len(rows) < limite:
                rows.append(r)

    # Última opción: sin categoría registrada, se aproxima por palabra del
    # título (comportamiento anterior), para no dejar la sección vacía.
    if not rows:
        palabra = titulo.split(" ")[0] if titulo else ""
        if palabra:
            cursor.execute("""
                SELECT id, titulo, precio, imagen_url, categoria, subcategoria, condicion
                FROM publicaciones
                WHERE estado = 'disponible' AND titulo LIKE ? AND id != ?
                LIMIT ?
            """, (f"%{palabra}%", publicacion_id, limite))
            rows = cursor.fetchall()

    conn.close()

    return [
        {
            "id": r[0],
            "titulo": r[1],
            "precio": r[2],
            "imagen_url": r[3],
            "categoria": r[4],
            "subcategoria": r[5],
            "condicion": r[6],
        }
        for r in rows
    ]


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


# --------------------------------------------------
# OBTENER PUBLICACION POR ID
# --------------------------------------------------

def obtener_publicacion_por_id(publicacion_id):

    conn = sqlite3.connect(DB)
    cursor = conn.cursor()

    cursor.execute("""
    SELECT
        p.id, p.titulo, p.descripcion, p.precio, p.imagen_url,
        p.guest_id, p.user_id, p.estado, p.dimensiones,
        p.categoria, p.subcategoria, p.imagenes_extra,
        CASE WHEN u.nombre IS NOT NULL AND TRIM(u.nombre) <> ''
             THEN u.nombre ELSE 'Usuario invitado' END,
        p.lat, p.lng, p.condicion, p.acepta_ofertas,
        p.sku, p.stock, p.codigo_universal, p.tallas, p.tipo_publicacion
    FROM publicaciones p
    LEFT JOIN users u ON p.user_id = u.id
    WHERE p.id = ?
    """, (publicacion_id,))

    row = cursor.fetchone()
    conn.close()

    if not row:
        return None

    return {
        "id": row[0], "titulo": row[1], "descripcion": row[2],
        "precio": row[3], "imagen_url": row[4], "guest_id": row[5],
        "user_id": row[6], "estado": row[7], "dimensiones": row[8],
        "categoria": row[9], "subcategoria": row[10],
        "imagenes_extra": row[11],
        "seller_status": "🙂" if row[6] else "🙁",
        "nombre_vendedor": row[12],
        "lat": row[13], "lng": row[14],
        "condicion": row[15], "acepta_ofertas": row[16],
        "sku": row[17], "stock": row[18],
        "codigo_universal": row[19], "tallas": row[20],
        "tipo_publicacion": row[21],
    }


# --------------------------------------------------
# EDITAR PUBLICACION
# --------------------------------------------------

def editar_publicacion(publicacion_id, titulo, descripcion, precio,
                       imagen_url=None, imagenes_extra=None,
                       condicion=None, acepta_ofertas=None):

    conn = sqlite3.connect(DB)
    cursor = conn.cursor()

    if imagen_url is not None:
        cursor.execute("""
            UPDATE publicaciones
            SET titulo = ?, descripcion = ?, precio = ?,
                imagen_url = ?, imagenes_extra = ?,
                condicion = COALESCE(?, condicion),
                acepta_ofertas = COALESCE(?, acepta_ofertas)
            WHERE id = ?
        """, (titulo, descripcion, precio,
              imagen_url, imagenes_extra,
              condicion, acepta_ofertas, publicacion_id))
    else:
        cursor.execute("""
            UPDATE publicaciones
            SET titulo = ?, descripcion = ?, precio = ?,
                condicion = COALESCE(?, condicion),
                acepta_ofertas = COALESCE(?, acepta_ofertas)
            WHERE id = ?
        """, (titulo, descripcion, precio,
              condicion, acepta_ofertas, publicacion_id))

    conn.commit()
    conn.close()


# --------------------------------------------------
# INFO ADICIONAL (SKU / STOCK / CÓDIGO UNIVERSAL)
# --------------------------------------------------

def guardar_info_adicional(publicacion_id, sku=None, stock=None, codigo_universal=None):
    conn = sqlite3.connect(DB)
    cursor = conn.cursor()
    cursor.execute(
        "UPDATE publicaciones SET sku=?, stock=?, codigo_universal=? WHERE id=?",
        (sku, stock, codigo_universal, publicacion_id),
    )
    conn.commit()
    conn.close()


# --------------------------------------------------
# ELIMINAR PUBLICACION
# --------------------------------------------------

def eliminar_publicacion(publicacion_id):

    conn = sqlite3.connect(DB)
    cursor = conn.cursor()

    cursor.execute("DELETE FROM publicaciones WHERE id = ?", (publicacion_id,))

    conn.commit()
    conn.close()


# --------------------------------------------------
# PUBLICACIONES CERCANAS (Haversine)
# --------------------------------------------------

def obtener_publicaciones_cercanas(lat, lng, radio_km=5.0):
    """Retorna publicaciones disponibles dentro del radio (km) usando fórmula Haversine."""
    import math

    conn = sqlite3.connect(DB)
    cursor = conn.cursor()

    cursor.execute("""
    SELECT
        p.id, p.titulo, p.descripcion, p.precio, p.imagen_url,
        p.guest_id, p.user_id, p.estado, p.dimensiones,
        p.categoria, p.subcategoria, p.imagenes_extra,
        CASE WHEN u.nombre IS NOT NULL AND TRIM(u.nombre) <> ''
             THEN u.nombre ELSE 'Usuario invitado' END,
        p.lat, p.lng, p.condicion, p.acepta_ofertas,
        p.sku, p.stock, p.codigo_universal, p.tallas
    FROM publicaciones p
    LEFT JOIN users u ON p.user_id = u.id
    WHERE p.estado = 'disponible'
      AND p.lat IS NOT NULL
      AND p.lng IS NOT NULL
    """)

    rows = cursor.fetchall()
    conn.close()

    R = 6371  # Radio de la Tierra en km

    resultado = []
    for row in rows:
        p_lat, p_lng = row[13], row[14]
        if p_lat is None or p_lng is None:
            continue

        dlat = math.radians(p_lat - lat)
        dlng = math.radians(p_lng - lng)
        a = (math.sin(dlat / 2) ** 2
             + math.cos(math.radians(lat))
             * math.cos(math.radians(p_lat))
             * math.sin(dlng / 2) ** 2)
        distancia_km = R * 2 * math.asin(math.sqrt(a))

        if distancia_km <= radio_km:
            resultado.append({
                "id": row[0], "titulo": row[1], "descripcion": row[2],
                "precio": row[3], "imagen_url": row[4],
                "user_id": row[6], "estado": row[7],
                "categoria": row[9], "subcategoria": row[10],
                "imagenes_extra": row[11],
                "nombre_vendedor": row[12],
                "lat": p_lat, "lng": p_lng,
                "distancia_km": round(distancia_km, 2),
                "condicion": row[15], "acepta_ofertas": row[16],
                "sku": row[17], "stock": row[18],
                "codigo_universal": row[19], "tallas": row[20],
            })

    resultado.sort(key=lambda x: x["distancia_km"])
    return resultado


# --------------------------------------------------
# PUBLICACIONES POR USUARIO (perfil público)
# --------------------------------------------------

def obtener_publicaciones_por_usuario(user_id: int):
    """Retorna las publicaciones disponibles de un usuario (para perfil público)."""
    conn = sqlite3.connect(DB)
    cursor = conn.cursor()

    cursor.execute("""
    SELECT
        p.id, p.titulo, p.precio, p.imagen_url,
        p.categoria, p.subcategoria, p.estado
    FROM publicaciones p
    WHERE p.user_id = ?
      AND p.estado = 'disponible'
    ORDER BY p.id DESC
    """, (user_id,))

    rows = cursor.fetchall()
    conn.close()

    return [
        {
            "id": r[0],
            "titulo": r[1],
            "precio": r[2],
            "imagen_url": r[3],
            "categoria": r[4],
            "subcategoria": r[5],
            "estado": r[6],
        }
        for r in rows
    ]

