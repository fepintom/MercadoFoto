"""
routers/comunidad.py
====================
Chat público de la Comunidad.

  GET  /comunidad/mensajes?despues_de=&limite=   últimos mensajes / nuevos
  POST /comunidad/mensajes                       enviar (texto y/o ancla)
  GET  /comunidad/anclados                       franja de lo anclado
  GET  /comunidad/anclables/{user_id}            lo que el usuario puede anclar
  POST /admin/comunidad/bot/oferta?token=        el bot publica una oferta

Autorización: igual que el resto del proyecto (sin JWT), se recibe
`user_id`. El ancla se valida contra el dueño para que nadie ancle lo ajeno.
"""
import os
import time
from typing import Optional

from fastapi import APIRouter, BackgroundTasks, HTTPException
from pydantic import BaseModel

from database import comunidad as db
from services import comunidad_bot as bot

router = APIRouter()

# Freno anti-spam simple, en memoria: un mensaje cada 2 segundos por usuario.
_ultimo_envio: dict[int, float] = {}
_INTERVALO_MIN = 2.0


class MensajeComunidad(BaseModel):
    user_id: int
    texto: Optional[str] = ""
    ancla_tipo: Optional[str] = None   # 'publicacion' | 'servicio'
    ancla_id: Optional[int] = None


@router.get("/comunidad/mensajes")
def listar(despues_de: int = 0, limite: int = 60):
    if not despues_de:
        bot.asegurar_bienvenida()
    return db.obtener_mensajes(despues_de, max(1, min(limite, 200)))


@router.get("/comunidad/anclados")
def anclados():
    return db.obtener_anclados()


@router.get("/comunidad/anclables/{user_id}")
def anclables(user_id: int):
    return db.anclables_de_usuario(user_id)


@router.post("/comunidad/mensajes")
def enviar(data: MensajeComunidad, tareas: BackgroundTasks):
    texto = (data.texto or "").strip()
    if not texto and not data.ancla_tipo:
        raise HTTPException(400, "Mensaje vacío")
    if len(texto) > db.MAX_TEXTO:
        raise HTTPException(400, f"Máximo {db.MAX_TEXTO} caracteres")
    if not db.usuario_existe(data.user_id):
        raise HTTPException(403, "Debes iniciar sesión para escribir")

    ahora = time.monotonic()
    if ahora - _ultimo_envio.get(data.user_id, 0) < _INTERVALO_MIN:
        raise HTTPException(429, "Vas muy rápido, espera un segundo")
    _ultimo_envio[data.user_id] = ahora

    ancla = None
    if data.ancla_tipo:
        if data.ancla_tipo not in ("publicacion", "servicio") or not data.ancla_id:
            raise HTTPException(400, "Ancla inválida")
        ancla = db.ancla_de_usuario(data.user_id, data.ancla_tipo, data.ancla_id)
        if not ancla:
            raise HTTPException(403, "Solo puedes anclar lo que tú publicaste")

    msg = db.guardar_mensaje(data.user_id, texto, ancla=ancla)
    if bot.me_mencionan(texto):
        tareas.add_task(bot.responder, msg)
    return msg


@router.post("/admin/comunidad/bot/oferta")
def bot_oferta(token: str):
    if token != os.environ.get("ADMIN_TOKEN", "okventa-admin-2026"):
        raise HTTPException(403, "Token inválido")
    msg = bot.publicar_oferta()
    if not msg:
        raise HTTPException(404, "No hay publicaciones disponibles")
    return msg
