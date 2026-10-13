"""
routers/vistas.py
=================
Contador de visualizaciones (👁) de productos y servicios.

Una "vista" = una persona abrió el detalle. Para que el número signifique
algo se cuenta como máximo una vez por persona y por día, y el dueño no se
suma vistas a sí mismo.

  POST /vistas?tipo=producto|servicio&item_id=&visitante=   cuenta una vista
  GET  /vistas/top_productos?limite=5&dias=30               los más vistos
                                                             (disponibles)
  GET  /vistas/mas_vendidos?limite=5&dias=30                 los más vendidos
                                                             del mes; si hay
                                                             menos de 5, se
                                                             completa con los
                                                             más vistos
`conteos(tipo)` lo usa main.py para agregar "vistas" a los listados.
"""
import sqlite3
import time

from fastapi import APIRouter, HTTPException

from config import PUBLICACIONES_DB as DB

router = APIRouter()

TIPOS = {"producto": "publicaciones", "servicio": "servicios"}

# Los listados se piden muy seguido: el conteo se cachea unos segundos.
_cache: dict = {}
_TTL = 20


def init_vistas_db():
    conn = sqlite3.connect(DB)
    conn.execute("""
        CREATE TABLE IF NOT EXISTS vistas_items (
            tipo       TEXT NOT NULL,
            item_id    INTEGER NOT NULL,
            visitante  TEXT NOT NULL,
            dia        TEXT NOT NULL DEFAULT (date('now')),
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            UNIQUE (tipo, item_id, visitante, dia)
        )
    """)
    conn.execute(
        "CREATE INDEX IF NOT EXISTS idx_vistas_item ON vistas_items(tipo, item_id)")
    conn.commit()
    conn.close()


def conteos(tipo: str) -> dict:
    """{item_id: vistas} de todos los ítems de ese tipo."""
    ahora = time.time()
    hit = _cache.get(tipo)
    if hit and ahora - hit[0] < _TTL:
        return hit[1]
    conn = sqlite3.connect(DB)
    try:
        rows = conn.execute(
            "SELECT item_id, COUNT(*) FROM vistas_items WHERE tipo = ? "
            "GROUP BY item_id", (tipo,)).fetchall()
    except sqlite3.OperationalError:
        rows = []
    conn.close()
    data = {r[0]: r[1] for r in rows}
    _cache[tipo] = (ahora, data)
    return data


def agregar_vistas(items, tipo: str):
    """Pone item['vistas'] en cada dict (lista o uno solo)."""
    c = conteos(tipo)
    if isinstance(items, dict):
        items["vistas"] = c.get(items.get("id"), 0)
        return items
    for it in items or []:
        if isinstance(it, dict):
            it["vistas"] = c.get(it.get("id"), 0)
    return items


@router.post("/vistas")
def contar_vista(tipo: str, item_id: int, visitante: str = ""):
    tabla = TIPOS.get(tipo)
    if not tabla:
        raise HTTPException(400, "tipo debe ser producto o servicio")
    visitante = (visitante or "").strip()[:64]
    if not visitante:
        raise HTTPException(400, "Falta visitante")
    conn = sqlite3.connect(DB)
    fila = conn.execute(
        f"SELECT user_id FROM {tabla} WHERE id = ?", (item_id,)).fetchone()
    if not fila:
        conn.close()
        raise HTTPException(404, "No existe")
    contada = False
    # El dueño mirando lo suyo no suma.
    if str(fila[0]) != visitante:
        cur = conn.execute(
            "INSERT OR IGNORE INTO vistas_items (tipo, item_id, visitante) "
            "VALUES (?, ?, ?)", (tipo, item_id, visitante))
        contada = cur.rowcount > 0
        conn.commit()
    total = conn.execute(
        "SELECT COUNT(*) FROM vistas_items WHERE tipo = ? AND item_id = ?",
        (tipo, item_id)).fetchone()[0]
    conn.close()
    if contada:
        _cache.pop(tipo, None)
    return {"vistas": total, "contada": contada}


@router.get("/vistas/top_productos")
def top_productos(limite: int = 5, dias: int = 30):
    """Los productos disponibles más vistos en los últimos `dias` días."""
    from database.publicaciones import obtener_publicacion_por_id

    limite = max(1, min(limite, 20))
    conn = sqlite3.connect(DB)
    rows = conn.execute("""
        SELECT v.item_id, COUNT(*) AS n
        FROM vistas_items v
        JOIN publicaciones p ON p.id = v.item_id
        WHERE v.tipo = 'producto'
          AND v.dia >= date('now', ?)
          AND COALESCE(p.estado, 'disponible') = 'disponible'
        GROUP BY v.item_id
        -- Empate de vistas: primero el que llegó antes a ese número (su
        -- última vista del período es la más antigua).
        ORDER BY n DESC, MAX(v.created_at) ASC, MAX(v.rowid) ASC
        LIMIT ?
    """, (f"-{max(1, dias)} days", limite)).fetchall()
    conn.close()
    total = conteos("producto")
    salida = []
    for item_id, n in rows:
        pub = obtener_publicacion_por_id(item_id)
        if not pub:
            continue
        pub["vistas"] = total.get(item_id, n)
        pub["vistas_periodo"] = n
        salida.append(pub)
    return salida


_ESTADOS_PAGADOS = ("pago_confirmado", "en_camino", "entrega_reportada",
                    "entregado")


@router.get("/vistas/mas_vendidos")
def mas_vendidos(limite: int = 5, dias: int = 30):
    """Más vendidos del mes (órdenes pagadas, sin las de prueba). Cada
    producto trae `ventas_periodo` y `origen` ('ventas' o 'vistas' cuando se
    completa con los más vistos)."""
    from database.publicaciones import obtener_publicacion_por_id

    limite = max(1, min(limite, 20))
    conn = sqlite3.connect(DB)
    marcas = ",".join("?" * len(_ESTADOS_PAGADOS))
    try:
        rows = conn.execute(f"""
            SELECT o.publicacion_id, COUNT(*) AS n
            FROM ordenes o
            JOIN publicaciones p ON p.id = o.publicacion_id
            WHERE o.tipo = 'producto'
              AND o.estado IN ({marcas})
              AND COALESCE(o.es_test, 0) = 0
              AND o.created_at >= datetime('now', ?)
            GROUP BY o.publicacion_id
            ORDER BY n DESC, MAX(o.id) DESC
            LIMIT ?
        """, (*_ESTADOS_PAGADOS, f"-{max(1, dias)} days", limite)).fetchall()
    except sqlite3.OperationalError:
        rows = []
    conn.close()
    vistas = conteos("producto")
    salida, ids = [], set()
    for pid, n in rows:
        pub = obtener_publicacion_por_id(pid)
        if not pub:
            continue
        pub["vistas"] = vistas.get(pid, 0)
        pub["ventas_periodo"] = n
        pub["origen"] = "ventas"
        salida.append(pub)
        ids.add(pid)
    if len(salida) < limite:
        for pub in top_productos(limite=limite + len(ids), dias=dias):
            if pub["id"] in ids:
                continue
            pub["ventas_periodo"] = 0
            pub["origen"] = "vistas"
            salida.append(pub)
            if len(salida) >= limite:
                break
    return salida
