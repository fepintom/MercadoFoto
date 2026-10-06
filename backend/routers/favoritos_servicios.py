"""
routers/favoritos_servicios.py
==============================
Favoritos de servicios (el corazón de las tarjetas de OkServicios).

Los favoritos de productos viven en la tabla `favoritos` (publicacion_id);
un servicio no es una publicación, así que tiene su propia tabla.

  POST   /favorito_servicio?user_id=&servicio_id=
  DELETE /favorito_servicio?user_id=&servicio_id=
  GET    /favoritos_servicios/{user_id}            -> [ids]
"""
import sqlite3

from fastapi import APIRouter

from config import PUBLICACIONES_DB as DB

router = APIRouter()


def init_favoritos_servicios_db():
    conn = sqlite3.connect(DB)
    conn.execute("""
    CREATE TABLE IF NOT EXISTS favoritos_servicios (
        user_id     INTEGER NOT NULL,
        servicio_id INTEGER NOT NULL,
        created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (user_id, servicio_id)
    )
    """)
    conn.commit()
    conn.close()


@router.post("/favorito_servicio")
def guardar(user_id: int, servicio_id: int):
    conn = sqlite3.connect(DB)
    conn.execute("INSERT OR IGNORE INTO favoritos_servicios (user_id, servicio_id) "
                 "VALUES (?, ?)", (user_id, servicio_id))
    conn.commit()
    conn.close()
    return {"mensaje": "Guardado"}


@router.delete("/favorito_servicio")
def quitar(user_id: int, servicio_id: int):
    conn = sqlite3.connect(DB)
    conn.execute("DELETE FROM favoritos_servicios WHERE user_id = ? AND servicio_id = ?",
                 (user_id, servicio_id))
    conn.commit()
    conn.close()
    return {"mensaje": "Quitado"}


@router.get("/favoritos_servicios/{user_id}")
def listar(user_id: int):
    conn = sqlite3.connect(DB)
    filas = conn.execute("SELECT servicio_id FROM favoritos_servicios WHERE user_id = ?",
                         (user_id,)).fetchall()
    conn.close()
    return [f[0] for f in filas]
