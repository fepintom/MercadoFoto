"""
routers/comunidad.py
====================
Chat público de la Comunidad.

  GET    /comunidad/mensajes?despues_de=&limite=   últimos mensajes / nuevos
  POST   /comunidad/mensajes                       enviar (texto, ancla, menciones, respuesta)
  DELETE /comunidad/mensajes/{id}?user_id=         borrar un mensaje propio (para todos)
  GET    /comunidad/anclados                       franja de lo anclado
  GET    /comunidad/anclables/{user_id}            lo que el usuario puede anclar
  GET    /comunidad/usuarios?q=&user_id=           autocompletar @menciones

Administración (token = ADMIN_TOKEN):
  POST /admin/comunidad/bot/oferta?token=                 el bot publica una oferta
  GET  /admin/comunidad/bot/conversaciones?token=&escalados=&pendientes=&limite=
  GET  /admin/comunidad/bot/resumen?token=
  POST /admin/comunidad/bot/log/{id}/revisado?token=

Autorización: igual que el resto del proyecto (sin JWT), se recibe `user_id`.
"""
import os
import time
from typing import Dict, List, Optional

from fastapi import APIRouter, BackgroundTasks, HTTPException
from pydantic import BaseModel

from database import comunidad as db
from services import comunidad_bot as bot

router = APIRouter()

# Freno anti-spam simple, en memoria: un mensaje cada 2 segundos por usuario.
# `Dict` de typing y no `dict[...]`, por compatibilidad con Pythons viejos.
_ultimo_envio: Dict[int, float] = {}
_INTERVALO_MIN = 2.0
_MAX_MENCIONES = 5


class MensajeComunidad(BaseModel):
    user_id: int
    texto: Optional[str] = ""
    ancla_tipo: Optional[str] = None   # 'publicacion' | 'servicio'
    ancla_id: Optional[int] = None
    menciones: Optional[List[int]] = None  # ids elegidos en el autocompletar
    responde_a: Optional[int] = None       # id del mensaje al que responde


def _token_ok(token: str):
    if token != os.environ.get("ADMIN_TOKEN", "okventa-admin-2026"):
        raise HTTPException(403, "Token inválido")


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


@router.get("/comunidad/usuarios")
def usuarios(q: str = "", user_id: Optional[int] = None):
    return db.buscar_usuarios(q, excluir=user_id)


def _avisar_menciones(remitente: dict, mencionados: list, texto: str):
    """Notificación + push a cada mencionado. Best-effort."""
    try:
        from database.notifications import crear_notificacion
        from database.users import obtener_fcm_token
        from services.fcm_service import enviar_push
    except Exception as e:
        print(f"WARN menciones imports: {e}")
        return
    quien = (remitente.get("nombre") or "Alguien").split(" ")[0]
    for m in mencionados:
        try:
            crear_notificacion(
                m["id"], "comunidad_mencion",
                f"💬 {quien} te mencionó en la Comunidad: {texto[:80]}",
                remitente_id=remitente.get("user_id"))
            tok = obtener_fcm_token(m["id"])
            if tok:
                enviar_push(tok, f"{quien} te mencionó", texto[:100],
                            {"tipo": "comunidad_mencion"})
        except Exception as e:
            print(f"WARN mencion {m}: {e}")


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

    # Menciones: solo usuarios que existen y cuyo @handle está en el texto
    # (si el usuario borró la mención antes de enviar, no se notifica).
    mencionados = []
    ids = [i for i in (data.menciones or []) if i != data.user_id][:_MAX_MENCIONES]
    for u in db.usuarios_por_id(ids):
        handle = db.handle_de(u["nombre"], u["apellido"])
        if f"@{handle}".lower() in texto.lower():
            mencionados.append({"id": u["id"], "handle": handle})

    responde_a = data.responde_a
    if responde_a and not db.obtener_mensaje(responde_a):
        responde_a = None

    msg = db.guardar_mensaje(data.user_id, texto, ancla=ancla,
                             menciones=mencionados, responde_a=responde_a)
    if mencionados:
        tareas.add_task(_avisar_menciones, msg, mencionados, texto)
    if bot.debe_responder(msg):
        tareas.add_task(bot.responder, msg)
    return msg


@router.delete("/comunidad/mensajes/{mensaje_id}")
def borrar(mensaje_id: int, user_id: int):
    if not db.eliminar_mensaje(mensaje_id, user_id):
        raise HTTPException(403, "Solo puedes borrar tus propios mensajes")
    return {"ok": True}


# ── Administración del bot ──────────────────────────────────────────────────

@router.post("/admin/comunidad/bot/oferta")
def bot_oferta(token: str):
    _token_ok(token)
    msg = bot.publicar_oferta()
    if not msg:
        raise HTTPException(404, "No hay publicaciones disponibles")
    return msg


@router.get("/admin/comunidad/bot/conversaciones")
def bot_conversaciones(token: str, escalados: bool = False,
                       pendientes: bool = False, limite: int = 100):
    _token_ok(token)
    return bot.conversaciones(max(1, min(limite, 500)), escalados, pendientes)


@router.get("/admin/comunidad/bot/resumen")
def bot_resumen(token: str):
    _token_ok(token)
    return bot.resumen()


@router.post("/admin/comunidad/bot/log/{log_id}/revisado")
def bot_revisado(log_id: int, token: str):
    _token_ok(token)
    bot.marcar_revisado(log_id)
    return {"ok": True}
