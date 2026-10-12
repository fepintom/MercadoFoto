"""
routers/privados.py
===================
Mensajes privados entre usuarios (se abren tocando a alguien en Comunidad).

  POST /privados/enviar                     {de_id, para_id, texto, lat?, lng?}
  GET  /privados/{user_id}/con/{otro_id}?despues_de=   la conversación (marca
                                                       como leídos los recibidos)
  GET  /privados/{user_id}/conversaciones   una fila por persona: último
                                            mensaje, no leídos, nombre y foto
  GET  /privados/{user_id}/no_leidos        total de no leídos
"""
import json
import sqlite3
import time
from typing import Dict, Optional

from fastapi import APIRouter, BackgroundTasks, HTTPException
from pydantic import BaseModel

from config import PUBLICACIONES_DB as DB

router = APIRouter()

MAX_TEXTO = 1000
_ultimo: Dict[int, float] = {}


def init_privados_db():
    conn = sqlite3.connect(DB)
    conn.execute("""
        CREATE TABLE IF NOT EXISTS mensajes_privados (
            id         INTEGER PRIMARY KEY AUTOINCREMENT,
            de_id      INTEGER NOT NULL,
            para_id    INTEGER NOT NULL,
            texto      TEXT,
            ubicacion  TEXT,
            leido      INTEGER DEFAULT 0,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)
    conn.execute("CREATE INDEX IF NOT EXISTS idx_priv_par "
                 "ON mensajes_privados(de_id, para_id)")
    conn.commit()
    conn.close()


def _conn():
    c = sqlite3.connect(DB)
    c.row_factory = sqlite3.Row
    return c


def _dict(r):
    d = dict(r)
    try:
        d["ubicacion"] = json.loads(d["ubicacion"]) if d.get("ubicacion") else None
    except Exception:
        d["ubicacion"] = None
    return d


class MensajePrivado(BaseModel):
    de_id: int
    para_id: int
    texto: Optional[str] = ""
    lat: Optional[float] = None
    lng: Optional[float] = None


def _avisar(de: dict, para_id: int, texto: str):
    try:
        from database.notifications import crear_notificacion
        from database.users import obtener_fcm_token
        from services.fcm_service import enviar_push
    except Exception as e:
        print(f"WARN privados imports: {e}")
        return
    quien = (de.get("nombre") or "Alguien").split(" ")[0]
    try:
        crear_notificacion(para_id, "privado",
                           f"✉️ {quien} te escribió: {texto[:80]}",
                           remitente_id=de.get("id"))
        tok = obtener_fcm_token(para_id)
        if tok:
            enviar_push(tok, f"Mensaje de {quien}", texto[:100],
                        {"tipo": "privado", "remitente_id": str(de.get("id"))})
    except Exception as e:
        print(f"WARN aviso privado: {e}")


@router.post("/privados/enviar")
def enviar(data: MensajePrivado, tareas: BackgroundTasks):
    texto = (data.texto or "").strip()[:MAX_TEXTO]
    hay_ubicacion = data.lat is not None and data.lng is not None
    if not texto and not hay_ubicacion:
        raise HTTPException(400, "Mensaje vacío")
    if data.de_id == data.para_id:
        raise HTTPException(400, "No puedes escribirte a ti mismo")
    conn = _conn()
    usuarios = {r["id"]: dict(r) for r in conn.execute(
        "SELECT id, nombre, apellido, foto_url FROM users WHERE id IN (?, ?)",
        (data.de_id, data.para_id))}
    if data.de_id not in usuarios or data.para_id not in usuarios:
        conn.close()
        raise HTTPException(404, "Usuario no encontrado")
    ahora = time.monotonic()
    if ahora - _ultimo.get(data.de_id, 0) < 1.0:
        conn.close()
        raise HTTPException(429, "Vas muy rápido, espera un segundo")
    _ultimo[data.de_id] = ahora
    ubicacion = None
    if hay_ubicacion:
        if not (-90 <= data.lat <= 90 and -180 <= data.lng <= 180):
            conn.close()
            raise HTTPException(400, "Ubicación inválida")
        # En privado va la ubicación exacta: es una conversación 1 a 1.
        ubicacion = json.dumps({"lat": round(data.lat, 5),
                                "lng": round(data.lng, 5)})
    cur = conn.execute(
        "INSERT INTO mensajes_privados (de_id, para_id, texto, ubicacion) "
        "VALUES (?, ?, ?, ?)", (data.de_id, data.para_id, texto, ubicacion))
    conn.commit()
    fila = conn.execute("SELECT * FROM mensajes_privados WHERE id = ?",
                        (cur.lastrowid,)).fetchone()
    conn.close()
    tareas.add_task(_avisar, usuarios[data.de_id], data.para_id,
                    texto or "📍 Te compartió su ubicación")
    return _dict(fila)


@router.get("/privados/{user_id}/con/{otro_id}")
def conversacion(user_id: int, otro_id: int, despues_de: int = 0):
    conn = _conn()
    filas = conn.execute("""
        SELECT * FROM mensajes_privados
        WHERE ((de_id = ? AND para_id = ?) OR (de_id = ? AND para_id = ?))
          AND id > ?
        ORDER BY id ASC LIMIT 300
    """, (user_id, otro_id, otro_id, user_id, despues_de)).fetchall()
    conn.execute("UPDATE mensajes_privados SET leido = 1 "
                 "WHERE para_id = ? AND de_id = ? AND leido = 0",
                 (user_id, otro_id))
    conn.commit()
    conn.close()
    return [_dict(f) for f in filas]


@router.get("/privados/{user_id}/conversaciones")
def conversaciones(user_id: int):
    conn = _conn()
    filas = conn.execute("""
        SELECT m.*,
               CASE WHEN m.de_id = ? THEN m.para_id ELSE m.de_id END AS otro_id
        FROM mensajes_privados m
        WHERE m.id IN (
            SELECT MAX(id) FROM mensajes_privados
            WHERE de_id = ? OR para_id = ?
            GROUP BY CASE WHEN de_id = ? THEN para_id ELSE de_id END
        )
        ORDER BY m.id DESC
    """, (user_id, user_id, user_id, user_id)).fetchall()
    salida = []
    for f in filas:
        d = _dict(f)
        u = conn.execute("SELECT nombre, apellido, foto_url FROM users "
                         "WHERE id = ?", (d["otro_id"],)).fetchone()
        d["otro_nombre"] = " ".join(
            x for x in [(u["nombre"] if u else None),
                        (u["apellido"] if u else None)] if x) or "Usuario"
        d["otro_foto"] = u["foto_url"] if u else None
        d["no_leidos"] = conn.execute(
            "SELECT COUNT(*) FROM mensajes_privados "
            "WHERE para_id = ? AND de_id = ? AND leido = 0",
            (user_id, d["otro_id"])).fetchone()[0]
        salida.append(d)
    conn.close()
    return salida


@router.get("/privados/{user_id}/no_leidos")
def no_leidos(user_id: int):
    conn = _conn()
    n = conn.execute("SELECT COUNT(*) FROM mensajes_privados "
                     "WHERE para_id = ? AND leido = 0", (user_id,)).fetchone()[0]
    conn.close()
    return {"no_leidos": n}
