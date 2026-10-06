"""
routers/historias.py
====================
Historias, como en Instagram/Facebook: una foto (con texto opcional) que se
ve 24 horas. El dueño puede marcarla con el corazón como DESTACADA: las
destacadas no vencen y se muestran en su perfil.

  POST   /historias                          multipart: user_id, archivo, texto?
  GET    /historias/activos                  [user_id, ...] con historia vigente
                                             (para encender el anillo del avatar)
  GET    /historias/usuario/{user_id}        historias vigentes de un usuario
  GET    /historias/destacadas/{user_id}     destacadas (sin vencimiento)
  POST   /historias/{id}/destacar?user_id=&destacada=true|false   (solo el dueño)
  DELETE /historias/{id}?user_id=            (solo el dueño)
  POST   /historias/{id}/vista               cuenta una vista
"""
import os
import secrets
import sqlite3

from fastapi import APIRouter, File, Form, HTTPException, UploadFile

from config import PUBLICACIONES_DB as DB, UPLOADS_DIR
from services.imagenes import achicar_foto_historia

router = APIRouter()

HORAS_VIGENCIA = 24
MAX_MB = 15


def init_historias_db():
    conn = sqlite3.connect(DB)
    conn.execute("""
    CREATE TABLE IF NOT EXISTS historias (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id     INTEGER NOT NULL,
        media_url   TEXT    NOT NULL,
        texto       TEXT,
        destacada   INTEGER DEFAULT 0,
        vistas      INTEGER DEFAULT 0,
        created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
    """)
    conn.execute("CREATE INDEX IF NOT EXISTS idx_historias_user ON historias(user_id)")
    conn.commit()
    conn.close()


def _conn():
    c = sqlite3.connect(DB)
    c.row_factory = sqlite3.Row
    return c


_VIGENTE = f"created_at >= datetime('now', '-{HORAS_VIGENCIA} hours')"


def _dict(r):
    d = dict(r)
    d["destacada"] = bool(d.get("destacada"))
    return d


@router.post("/historias")
async def subir(user_id: int = Form(...), archivo: UploadFile = File(...),
                texto: str = Form("")):
    contenido = await archivo.read()
    if len(contenido) > MAX_MB * 1024 * 1024:
        raise HTTPException(413, f"La foto supera {MAX_MB} MB")
    c = _conn()
    existe = c.execute("SELECT 1 FROM users WHERE id = ?", (user_id,)).fetchone()
    if not existe:
        c.close()
        raise HTTPException(403, "Usuario no válido")
    jpg = achicar_foto_historia(contenido)
    if jpg is None:
        c.close()
        raise HTTPException(400, "El archivo no es una imagen válida")
    nombre = f"historia_{user_id}_{secrets.token_hex(8)}.jpg"
    with open(os.path.join(UPLOADS_DIR, nombre), "wb") as f:
        f.write(jpg)
    cur = c.execute(
        "INSERT INTO historias (user_id, media_url, texto) VALUES (?, ?, ?)",
        (user_id, f"/uploads/{nombre}", (texto or "").strip()[:200]))
    c.commit()
    h = c.execute("SELECT * FROM historias WHERE id = ?", (cur.lastrowid,)).fetchone()
    c.close()
    return _dict(h)


@router.get("/historias/activos")
def activos():
    c = _conn()
    filas = c.execute(f"SELECT DISTINCT user_id FROM historias WHERE {_VIGENTE}").fetchall()
    c.close()
    return [f[0] for f in filas]


@router.get("/historias/usuario/{user_id}")
def de_usuario(user_id: int):
    c = _conn()
    filas = c.execute(f"""
        SELECT * FROM historias WHERE user_id = ? AND {_VIGENTE}
        ORDER BY created_at ASC
    """, (user_id,)).fetchall()
    c.close()
    return [_dict(f) for f in filas]


@router.get("/historias/destacadas/{user_id}")
def destacadas(user_id: int):
    c = _conn()
    filas = c.execute("""
        SELECT * FROM historias WHERE user_id = ? AND destacada = 1
        ORDER BY created_at DESC
    """, (user_id,)).fetchall()
    c.close()
    return [_dict(f) for f in filas]


def _de_quien(c, historia_id):
    r = c.execute("SELECT user_id FROM historias WHERE id = ?", (historia_id,)).fetchone()
    if not r:
        c.close()
        raise HTTPException(404, "Historia no encontrada")
    return r[0]


@router.post("/historias/{historia_id}/destacar")
def destacar(historia_id: int, user_id: int, destacada: bool = True):
    c = _conn()
    if _de_quien(c, historia_id) != user_id:
        c.close()
        raise HTTPException(403, "Solo el dueño puede destacar su historia")
    c.execute("UPDATE historias SET destacada = ? WHERE id = ?",
              (1 if destacada else 0, historia_id))
    c.commit()
    c.close()
    return {"id": historia_id, "destacada": destacada}


@router.delete("/historias/{historia_id}")
def borrar(historia_id: int, user_id: int):
    c = _conn()
    if _de_quien(c, historia_id) != user_id:
        c.close()
        raise HTTPException(403, "Solo el dueño puede borrar su historia")
    c.execute("DELETE FROM historias WHERE id = ?", (historia_id,))
    c.commit()
    c.close()
    return {"ok": True}


@router.post("/historias/{historia_id}/vista")
def vista(historia_id: int):
    c = _conn()
    c.execute("UPDATE historias SET vistas = vistas + 1 WHERE id = ?", (historia_id,))
    c.commit()
    c.close()
    return {"ok": True}
