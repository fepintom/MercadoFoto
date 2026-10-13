"""
routers/fotos_estilo.py
=======================
Pasa TODAS las fotos de publicaciones ya existentes al estilo actual de
OkVenta (services/marca_agua.py): producto sin fondo, grande y centrado,
sobre gris de estudio con sombra y el sello de agua detrás.

- Corre solo, en segundo plano, un rato después de arrancar el servidor.
  Es idempotente: la tabla `fotos_rehechas` recuerda qué foto ya se pasó,
  así que si el servidor se reinicia a mitad, sigue donde quedó.
- La foto nueva se guarda con otro nombre (la app no muestra la vieja por
  caché) y se actualiza `imagen_url` / `imagenes_extra`. La vieja queda en
  disco por si algo la sigue citando (anclas de Comunidad, cotizaciones).

Administración (token = ADMIN_TOKEN):
  POST /admin/fotos/rehacer?token=...      vuelve a lanzar la pasada
  GET  /admin/fotos/rehacer/estado?token=...
"""
import json
import os
import sqlite3
import threading
import time

from fastapi import APIRouter, HTTPException

from config import PUBLICACIONES_DB as DB, UPLOADS_DIR

router = APIRouter()

_estado = {"corriendo": False, "hechas": 0, "fallidas": 0, "pendientes": None,
           "ultima": None, "error": None}
_lock = threading.Lock()


def _token_ok(token: str):
    if token != os.environ.get("ADMIN_TOKEN", "okventa-admin-2026"):
        raise HTTPException(403, "Token inválido")


def init_fotos_estilo_db():
    conn = sqlite3.connect(DB)
    conn.execute("""
        CREATE TABLE IF NOT EXISTS fotos_rehechas (
            url        TEXT PRIMARY KEY,   -- foto original
            nueva      TEXT,               -- foto con el estilo nuevo
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)
    conn.commit()
    conn.close()


def _urls_de(fila):
    urls = []
    if fila["imagen_url"]:
        urls.append(fila["imagen_url"])
    try:
        extras = json.loads(fila["imagenes_extra"] or "[]")
        urls += [u for u in extras if isinstance(u, str)]
    except Exception:
        pass
    return urls


def _pendientes(conn):
    hechas = {r[0] for r in conn.execute("SELECT url FROM fotos_rehechas")}
    nuevas = {r[0] for r in conn.execute(
        "SELECT nueva FROM fotos_rehechas WHERE nueva IS NOT NULL")}
    filas = conn.execute(
        "SELECT id, imagen_url, imagenes_extra FROM publicaciones "
        "ORDER BY id DESC").fetchall()
    salida, vistas = [], set()
    for f in filas:
        for u in _urls_de(f):
            if (u.startswith("/uploads/") and u not in hechas
                    and u not in nuevas and (f["id"], u) not in vistas):
                vistas.add((f["id"], u))
                salida.append((f["id"], u))
    return salida


def _rehacer_una(conn, pub_id, url):
    from services.background_service import quitar_fondo
    from services.storage_service import guardar_imagen_procesada

    # La misma foto en otra publicación (o repetida): se reutiliza.
    ya = conn.execute("SELECT nueva FROM fotos_rehechas WHERE url = ?",
                      (url,)).fetchone()
    ruta = os.path.join(UPLOADS_DIR, os.path.basename(url))
    if ya and not ya[0]:
        return False
    if not ya and not os.path.isfile(ruta):
        conn.execute("INSERT OR IGNORE INTO fotos_rehechas (url, nueva) "
                     "VALUES (?, NULL)", (url,))
        conn.commit()
        return False
    if ya:
        nueva = ya[0]
    else:
        with open(ruta, "rb") as fh:
            datos = fh.read()
        nueva = guardar_imagen_procesada(quitar_fondo(datos))
    fila = conn.execute(
        "SELECT imagen_url, imagenes_extra FROM publicaciones WHERE id = ?",
        (pub_id,)).fetchone()
    if fila:
        if fila["imagen_url"] == url:
            conn.execute("UPDATE publicaciones SET imagen_url = ? WHERE id = ?",
                         (nueva, pub_id))
        try:
            extras = json.loads(fila["imagenes_extra"] or "[]")
        except Exception:
            extras = []
        if url in extras:
            extras = [nueva if e == url else e for e in extras]
            conn.execute(
                "UPDATE publicaciones SET imagenes_extra = ? WHERE id = ?",
                (json.dumps(extras), pub_id))
    conn.execute("INSERT OR IGNORE INTO fotos_rehechas (url, nueva) "
                 "VALUES (?, ?)", (url, nueva))
    conn.commit()
    return True


def _pasada(espera: float = 0):
    if espera:
        time.sleep(espera)
    with _lock:
        if _estado["corriendo"]:
            return
        _estado.update(corriendo=True, error=None)
    try:
        conn = sqlite3.connect(DB, timeout=30)
        conn.row_factory = sqlite3.Row
        lista = _pendientes(conn)
        _estado["pendientes"] = len(lista)
        for pub_id, url in lista:
            try:
                if _rehacer_una(conn, pub_id, url):
                    _estado["hechas"] += 1
                _estado["ultima"] = url
            except Exception as e:  # una foto mala no corta la pasada
                _estado["fallidas"] += 1
                print("fotos_estilo: falló", url, repr(e))
                try:
                    conn.execute("INSERT OR IGNORE INTO fotos_rehechas "
                                 "(url, nueva) VALUES (?, NULL)", (url,))
                    conn.commit()
                except Exception:
                    pass
            _estado["pendientes"] -= 1
            time.sleep(0.3)  # deja respirar al servidor
        conn.close()
    except Exception as e:
        _estado["error"] = repr(e)
        print("fotos_estilo: error", repr(e))
    finally:
        _estado["corriendo"] = False


def lanzar_en_segundo_plano(espera: float = 90):
    """Al arrancar: espera un poco (que el servidor responda primero) y
    pasa las fotos que falten."""
    if os.environ.get("FOTOS_ESTILO_AUTO", "1") != "1":
        return
    threading.Thread(target=_pasada, args=(espera,), daemon=True).start()


@router.post("/admin/fotos/rehacer")
def rehacer(token: str):
    _token_ok(token)
    threading.Thread(target=_pasada, daemon=True).start()
    return {"ok": True}


@router.get("/admin/fotos/rehacer/estado")
def estado(token: str):
    _token_ok(token)
    return _estado
