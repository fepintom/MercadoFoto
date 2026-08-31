"""Catálogo de tienda de un vendedor.

Un usuario con empresa o emprendimiento sube su catálogo (un PDF) o enlaza
su página web, y la app lo "absorbe": extrae los productos y la identidad
visual de la tienda (nombre, logo, colores) para mostrar un pedazo de esa
tienda dentro de OkVenta, en el perfil del vendedor.

Decisión de diseño — tablas propias, no `publicaciones`:
    `publicaciones` ya tiene el vocabulario (sku, stock, etc.) y una columna
    discriminadora `tipo_publicacion`, así que era tentador reutilizarla.
    Pero TODAS las consultas de listado de esa tabla
    (obtener_publicaciones, obtener_publicaciones_por_usuario) filtran solo
    por estado='disponible' y no por tipo, así que los productos importados
    aparecerían de inmediato en el feed del marketplace y en la grilla del
    perfil, mezclados con las publicaciones reales. Un catálogo importado
    es una vitrina, no un producto puesto a la venta con envío y pago por
    OkVenta: son cosas distintas y merecen tablas distintas. Si más adelante
    el vendedor quiere convertir un ítem del catálogo en publicación real,
    se copia la fila; el camino inverso (filtrar 8 consultas compartidas)
    es mucho más frágil.

Un usuario tiene a lo más UN catálogo activo (UNIQUE en user_id): volver a
subir reemplaza el anterior.
"""
import sqlite3
from config import PUBLICACIONES_DB as DB

# procesando: se está leyendo el PDF / la página en segundo plano
# listo:      terminó y hay productos que mostrar
# error:      no se pudo procesar (mensaje_error explica por qué)
ESTADOS = ("procesando", "listo", "error")
TIPOS = ("pdf", "web")


def init_catalogos_db():
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    c.execute("""
    CREATE TABLE IF NOT EXISTS catalogos (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id          INTEGER NOT NULL UNIQUE,
        tipo             TEXT    NOT NULL,          -- 'pdf' | 'web'
        fuente           TEXT,                      -- URL, o /uploads/... del PDF
        estado           TEXT DEFAULT 'procesando',
        nombre_tienda    TEXT,
        logo_url         TEXT,
        color_primario   TEXT,                      -- '#RRGGBB' de la marca
        color_fondo      TEXT,                      -- '#RRGGBB' de fondo
        total_productos  INTEGER DEFAULT 0,
        mensaje_error    TEXT,
        creado_en        TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        procesado_en     TIMESTAMP
    )
    """)
    c.execute("""
    CREATE TABLE IF NOT EXISTS catalogo_productos (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        catalogo_id  INTEGER NOT NULL,
        user_id      INTEGER NOT NULL,
        titulo       TEXT    NOT NULL,
        descripcion  TEXT,
        precio       REAL,
        moneda       TEXT DEFAULT 'CLP',
        imagen_url   TEXT,
        orden        INTEGER DEFAULT 0,
        visible      INTEGER DEFAULT 1,   -- el dueño puede ocultar ítems sueltos
        creado_en    TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
    """)
    c.execute("CREATE INDEX IF NOT EXISTS idx_catprod_catalogo ON catalogo_productos(catalogo_id)")
    c.execute("CREATE INDEX IF NOT EXISTS idx_catprod_user ON catalogo_productos(user_id)")
    conn.commit()
    conn.close()


def _dict(cursor, row):
    return dict(zip([d[0] for d in cursor.description], row)) if row else None


# ── Catálogo ────────────────────────────────────────────────────────────────

def crear_o_reemplazar_catalogo(user_id: int, tipo: str, fuente: str) -> int:
    """Deja el catálogo del usuario en 'procesando' y borra el contenido
    anterior. Devuelve el id del catálogo."""
    if tipo not in TIPOS:
        raise ValueError(f"Tipo de catálogo inválido: {tipo}")
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    c.execute("SELECT id FROM catalogos WHERE user_id = ?", (user_id,))
    fila = c.fetchone()
    if fila:
        cat_id = fila[0]
        c.execute("DELETE FROM catalogo_productos WHERE catalogo_id = ?", (cat_id,))
        c.execute("""
            UPDATE catalogos
            SET tipo = ?, fuente = ?, estado = 'procesando', total_productos = 0,
                mensaje_error = NULL, procesado_en = NULL,
                nombre_tienda = NULL, logo_url = NULL,
                color_primario = NULL, color_fondo = NULL
            WHERE id = ?
        """, (tipo, fuente, cat_id))
    else:
        c.execute("""
            INSERT INTO catalogos (user_id, tipo, fuente, estado)
            VALUES (?, ?, ?, 'procesando')
        """, (user_id, tipo, fuente))
        cat_id = c.lastrowid
    conn.commit()
    conn.close()
    return cat_id


def obtener_catalogo_por_usuario(user_id: int):
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    c.execute("SELECT * FROM catalogos WHERE user_id = ?", (user_id,))
    d = _dict(c, c.fetchone())
    conn.close()
    return d


def obtener_catalogo(catalogo_id: int):
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    c.execute("SELECT * FROM catalogos WHERE id = ?", (catalogo_id,))
    d = _dict(c, c.fetchone())
    conn.close()
    return d


def guardar_marca(catalogo_id: int, nombre_tienda=None, logo_url=None,
                  color_primario=None, color_fondo=None):
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    c.execute("""
        UPDATE catalogos
        SET nombre_tienda = COALESCE(?, nombre_tienda),
            logo_url      = COALESCE(?, logo_url),
            color_primario= COALESCE(?, color_primario),
            color_fondo   = COALESCE(?, color_fondo)
        WHERE id = ?
    """, (nombre_tienda, logo_url, color_primario, color_fondo, catalogo_id))
    conn.commit()
    conn.close()


def marcar_listo(catalogo_id: int, total: int):
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    c.execute("""
        UPDATE catalogos
        SET estado = 'listo', total_productos = ?,
            procesado_en = CURRENT_TIMESTAMP, mensaje_error = NULL
        WHERE id = ?
    """, (total, catalogo_id))
    conn.commit()
    conn.close()


def marcar_error(catalogo_id: int, mensaje: str):
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    c.execute("""
        UPDATE catalogos
        SET estado = 'error', mensaje_error = ?, procesado_en = CURRENT_TIMESTAMP
        WHERE id = ?
    """, (mensaje[:500], catalogo_id))
    conn.commit()
    conn.close()


def eliminar_catalogo(user_id: int):
    """Devuelve las rutas /uploads/... que quedaron huérfanas, para que el
    caller borre los archivos del disco."""
    cat = obtener_catalogo_por_usuario(user_id)
    if not cat:
        return []
    rutas = [p["imagen_url"] for p in obtener_productos(cat["id"], solo_visibles=False)
             if p.get("imagen_url")]
    if cat.get("logo_url"):
        rutas.append(cat["logo_url"])
    if cat.get("tipo") == "pdf" and cat.get("fuente"):
        rutas.append(cat["fuente"])
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    c.execute("DELETE FROM catalogo_productos WHERE catalogo_id = ?", (cat["id"],))
    c.execute("DELETE FROM catalogos WHERE id = ?", (cat["id"],))
    conn.commit()
    conn.close()
    return [r for r in rutas if r and r.startswith("/uploads/")]


# ── Productos del catálogo ──────────────────────────────────────────────────

def agregar_productos(catalogo_id: int, user_id: int, productos: list) -> int:
    """`productos`: lista de dicts con titulo, descripcion, precio, moneda,
    imagen_url. Devuelve cuántos se insertaron."""
    if not productos:
        return 0
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    n = 0
    for i, p in enumerate(productos):
        titulo = (p.get("titulo") or "").strip()
        if not titulo:
            continue
        c.execute("""
            INSERT INTO catalogo_productos
                (catalogo_id, user_id, titulo, descripcion, precio, moneda,
                 imagen_url, orden)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """, (catalogo_id, user_id, titulo[:200],
              (p.get("descripcion") or "")[:500],
              p.get("precio"), p.get("moneda") or "CLP",
              p.get("imagen_url"), i))
        n += 1
    conn.commit()
    conn.close()
    return n


def obtener_productos(catalogo_id: int, solo_visibles: bool = True):
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    sql = "SELECT * FROM catalogo_productos WHERE catalogo_id = ?"
    if solo_visibles:
        sql += " AND visible = 1"
    sql += " ORDER BY orden ASC, id ASC"
    c.execute(sql, (catalogo_id,))
    cols = [d[0] for d in c.description]
    filas = [dict(zip(cols, r)) for r in c.fetchall()]
    conn.close()
    return filas


def cambiar_visibilidad(producto_id: int, user_id: int, visible: bool) -> bool:
    """Solo el dueño puede ocultar/mostrar. Devuelve si se aplicó."""
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    c.execute("""
        UPDATE catalogo_productos SET visible = ?
        WHERE id = ? AND user_id = ?
    """, (1 if visible else 0, producto_id, user_id))
    ok = c.rowcount > 0
    conn.commit()
    conn.close()
    return ok
