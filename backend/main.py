# --------------------------------------------------
# STANDARD LIBRARY
# --------------------------------------------------

import hashlib
import traceback
import sqlite3

# --------------------------------------------------
# THIRD PARTY
# --------------------------------------------------

from fastapi import FastAPI, UploadFile, File, HTTPException, Form
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
from services.gpt_service import mejorar_descripcion_producto
from typing import Optional

# --------------------------------------------------
# SERVICES
# --------------------------------------------------

from services.background_service import quitar_fondo
from services.storage_service import guardar_imagen_procesada
from services.translation_service import traducir_a_es
from services.vision_service import detectar_producto
from services.trust_score_service import calcular_trust_score

# --------------------------------------------------
# FUNCIONES DE BASE DE DATOS
# --------------------------------------------------

from database.publicaciones import (
    init_publicaciones_db,
    guardar_publicacion,
    obtener_publicaciones,
    migrar_publicaciones_guest,
    obtener_vendedor_publicacion,
    cambiar_estado_publicacion,
    obtener_productos_similares,
    actualizar_precio,
)

from database.users import (
    obtener_usuario_por_email,
    init_users_db,
    crear_usuario,
    obtener_usuario_por_id,
)

from database.chat import (
    init_chat_db,
    guardar_mensaje,
    obtener_chat,
)

from database.favoritos import (
    init_favoritos_db,
    guardar_favorito,
    obtener_favoritos,
    obtener_usuarios_favorito,
)

from database.analisis_cache import (
    init_cache_db,
    get_cached_analisis,
    save_cached_analisis,
)

from database.preguntas import (
    init_preguntas_db,
    guardar_pregunta,
    obtener_preguntas,
)

from database.reviews import (
    init_reviews_db,
    guardar_review,
    obtener_reviews_vendedor,
)

from database.notifications import (
    init_notifications_db,
    crear_notificacion,
    obtener_notificaciones,
)

from database.guest_sessions import (
    init_guest_db,
    crear_guest,
)

# --------------------------------------------------
# RANKING
# --------------------------------------------------

def ranking_producto(producto):
    score = 0

    # vendedor registrado vale más
    if producto["user_id"]:
        score += 20

    # precio menor mejor
    if producto["precio"]:
        score += max(0, 100 - producto["precio"] / 1000)

    return score


# --------------------------------------------------
# APP
# --------------------------------------------------

app = FastAPI()

# Exponer carpeta uploads como pública
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")

# Inicializar bases de datos
init_publicaciones_db()
init_cache_db()
init_guest_db()
init_users_db()
init_preguntas_db()
init_reviews_db()
init_notifications_db()
init_favoritos_db()
init_chat_db()

# --------------------------------------------------
# CORS
# --------------------------------------------------

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --------------------------------------------------
# MODELOS
# --------------------------------------------------

class LoginRequest(BaseModel):
    email: str
    password: str


class Publicacion(BaseModel):
    titulo: str
    descripcion: str
    precio: float
    imagen_url: str
    guest_id: Optional[str] = None
    user_id: Optional[int] = None


class RegistroUsuario(BaseModel):
    email: str
    password: str
    guest_id: Optional[str] = None
    direccion: Optional[str] = None
    comuna: Optional[str] = None
    ciudad: Optional[str] = None


class LoginUsuario(BaseModel):
    email: str
    password: str


class Pregunta(BaseModel):
    publicacion_id: int
    mensaje: str
    guest_id: Optional[str] = None
    user_id: Optional[int] = None


class Review(BaseModel):
    vendedor_id: int
    comprador_id: int
    estrellas: int
    comentario: str


class Mensaje(BaseModel):
    publicacion_id: int
    remitente_id: int
    mensaje: str


# --------------------------------------------------
# ANALIZAR IMAGEN
# --------------------------------------------------

@app.post("/analizar")
async def analizar_producto(file: UploadFile = File(...)):
    try:
        original_bytes = await file.read()
        image_hash = hashlib.sha256(original_bytes).hexdigest()

        cached = get_cached_analisis(image_hash)

        if cached:
            titulo, descripcion, _ = cached
            dimensiones = "No determinado"
            print("Cache hit:", titulo)
        else:
            # GPT-4o Vision detecta, titula, describe y estima dimensiones
            titulo, descripcion, dimensiones = detectar_producto(original_bytes)

            # Guardar en cache
            save_cached_analisis(image_hash, titulo, descripcion, False)

        # Quitar fondo y guardar imagen
        imagen_procesada = quitar_fondo(original_bytes)
        imagen_url = guardar_imagen_procesada(imagen_procesada)

        return {
            "titulo": titulo,
            "descripcion": descripcion,
            "dimensiones": dimensiones,
            "imagen_url": imagen_url,
        }

    except Exception as e:
        print("ERROR EN /analizar:", repr(e))
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/publicar")
async def publicar_producto(
    titulo: str = Form(...),
    descripcion: str = Form(...),
    precio: float = Form(...),
    file: UploadFile = File(...),
    guest_id: Optional[str] = Form(None),
    user_id: Optional[int] = Form(None),
    dimensiones: Optional[str] = Form(None),
):
    if not guest_id and not user_id:
        raise HTTPException(
            status_code=400,
            detail="Se requiere guest_id o user_id",
        )

    try:
        image_bytes = await file.read()
        imagen_sin_fondo = quitar_fondo(image_bytes)
        imagen_url = guardar_imagen_procesada(imagen_sin_fondo)

        guardar_publicacion(
            titulo,
            descripcion,
            precio,
            imagen_url,
            guest_id,
            user_id,
            dimensiones,
        )

        return {
            "mensaje": "Producto publicado correctamente",
            "imagen_url": imagen_url,
        }

    except Exception as e:
        print("ERROR EN /publicar:", repr(e))
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))


# --------------------------------------------------
# PUBLICAR PRODUCTO
# --------------------------------------------------

@app.post("/publicar")
async def publicar_producto(
    titulo: str = Form(...),
    descripcion: str = Form(...),
    precio: float = Form(...),
    file: UploadFile = File(...),
    guest_id: Optional[str] = Form(None),
    user_id: Optional[int] = Form(None),
):
    if not guest_id and not user_id:
        raise HTTPException(
            status_code=400,
            detail="Se requiere guest_id o user_id",
        )

    try:
        image_bytes = await file.read()
        imagen_sin_fondo = quitar_fondo(image_bytes)
        imagen_url = guardar_imagen_procesada(imagen_sin_fondo)

        guardar_publicacion(
            titulo,
            descripcion,
            precio,
            imagen_url,
            guest_id,
            user_id,
        )

        return {
            "mensaje": "Producto publicado correctamente",
            "imagen_url": imagen_url,
        }

    except Exception as e:
        print("ERROR EN /publicar:", repr(e))
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))


# --------------------------------------------------
# LISTAR PUBLICACIONES
# --------------------------------------------------

@app.get("/publicaciones")
def listar_publicaciones():
    try:
        return obtener_publicaciones()

    except Exception as e:
        print("ERROR EN /publicaciones:", repr(e))
        raise HTTPException(status_code=500, detail=str(e))


# --------------------------------------------------
# BUSCAR PUBLICACIONES
# --------------------------------------------------

@app.get("/buscar")
def buscar_publicaciones(q: str):
    try:
        resultados = obtener_publicaciones()
        q = q.lower()

        filtrados = [
            p for p in resultados
            if q in p["titulo"].lower() or q in p["descripcion"].lower()
        ]

        filtrados.sort(
            key=lambda p: ranking_producto(p),
            reverse=True,
        )

        return filtrados

    except Exception as e:
        print("ERROR EN /buscar:", repr(e))
        raise HTTPException(status_code=500, detail=str(e))


# --------------------------------------------------
# SESION INVITADO
# --------------------------------------------------

@app.get("/guest")
def crear_sesion_guest():
    guest_id = crear_guest()

    return {
        "guest_id": guest_id,
        "status": "guest",
        "emoji": "🙁",
    }


# --------------------------------------------------
# REGISTRO USUARIO
# --------------------------------------------------

@app.post("/registro")
def registrar_usuario(data: RegistroUsuario):
    if not data.email or "@" not in data.email:
        raise HTTPException(status_code=400, detail="Email inválido")

    if len(data.password) < 6:
        raise HTTPException(
            status_code=400,
            detail="La contraseña debe tener al menos 6 caracteres",
        )

    try:
        nombre = data.email.split("@")[0]

        user_id = crear_usuario(
            rut="TEMP",
            nombre=nombre,
            email=data.email.lower().strip(),
            password=data.password,
        )

        if data.guest_id:
            migrar_publicaciones_guest(data.guest_id, user_id)

        return {
            "user_id": user_id,
            "nombre": nombre,
            "email": data.email,
            "emoji": "🙂",
            "mensaje": "Usuario registrado correctamente",
        }

    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    except Exception as e:
        print("ERROR EN /registro:", repr(e))
        traceback.print_exc()
        raise HTTPException(
            status_code=500,
            detail="Error interno del servidor",
        )


# --------------------------------------------------
# LOGIN USUARIO
# --------------------------------------------------


@app.post("/login")
def login_usuario(data: LoginUsuario):

    usuario = obtener_usuario_por_email(data.email)

    if not usuario:
        raise HTTPException(
            status_code=404,
            detail="Usuario no encontrado",
        )

    if data.password != usuario["password"]:
        raise HTTPException(
            status_code=401,
            detail="Contraseña incorrecta",
        )

    return {
        "user_id": usuario["id"],
        "nombre": usuario["nombre"],
        "email": usuario["email"],
        "emoji": "🙂",
    }


# --------------------------------------------------
# END POINT PREGUNTAR
# --------------------------------------------------

@app.post("/preguntar")
def preguntar(pregunta: Pregunta):
    if not pregunta.guest_id and not pregunta.user_id:
        raise HTTPException(
            status_code=400,
            detail="Se requiere guest_id o user_id",
        )

    guardar_pregunta(
        pregunta.publicacion_id,
        pregunta.mensaje,
        pregunta.user_id,
        pregunta.guest_id,
    )

    vendedor_id = obtener_vendedor_publicacion(pregunta.publicacion_id)

    if vendedor_id:
        crear_notificacion(
            vendedor_id,
            "pregunta",
            "Tienes una nueva pregunta en tu publicación",
        )

    return {"mensaje": "Pregunta enviada"}


@app.get("/preguntas/{publicacion_id}")
def listar_preguntas(publicacion_id: int):
    return obtener_preguntas(publicacion_id)


# --------------------------------------------------
# END POINT CALIFICAR VENDEDOR
# --------------------------------------------------

@app.post("/calificar")
def calificar(review: Review):
    if review.estrellas < 1 or review.estrellas > 5:
        raise HTTPException(
            status_code=400,
            detail="Las estrellas deben ser entre 1 y 5",
        )

    guardar_review(
        review.vendedor_id,
        review.comprador_id,
        review.estrellas,
        review.comentario,
    )

    return {"mensaje": "Calificación registrada"}


@app.get("/reputacion/{vendedor_id}")
def reputacion_vendedor(vendedor_id: int):
    return obtener_reviews_vendedor(vendedor_id)


# --------------------------------------------------
# END POINT VER NOTIFICACIONES
# --------------------------------------------------

@app.get("/notificaciones/{user_id}")
def ver_notificaciones(user_id: int):
    return obtener_notificaciones(user_id)


# --------------------------------------------------
# PERFIL VENDEDOR
# --------------------------------------------------

# @app.get("/vendedor/{user_id}")
# def perfil_vendedor(user_id: int):
#
#     usuario = obtener_usuario_por_id(user_id)
#
#     if not usuario:
#         raise HTTPException(
#             status_code=404,
#             detail="Vendedor no encontrado"
#         )
#
#     publicaciones = obtener_publicaciones_vendedor(user_id)
#     reviews = obtener_reviews_vendedor(user_id)
#
#     trust_score = calcular_trust_score(reviews, publicaciones)
#
#     return {
#         "vendedor": usuario,
#         "trust_score": trust_score,
#         "publicaciones": publicaciones,
#         "reputacion": reviews
#     }

# --------------------------------------------------
# GUARDAR FAVORITOS
# --------------------------------------------------

@app.post("/favorito")
def favorito(user_id: int, publicacion_id: int):
    guardar_favorito(user_id, publicacion_id)
    return {"mensaje": "Guardado en favoritos"}


@app.get("/favoritos/{user_id}")
def ver_favoritos(user_id: int):
    return obtener_favoritos(user_id)


# --------------------------------------------------
# CAMBIAR ESTADO
# --------------------------------------------------

@app.post("/estado_publicacion")
def actualizar_estado(publicacion_id: int, estado: str):
    estados_validos = ["disponible", "reservado", "vendido"]

    if estado not in estados_validos:
        raise HTTPException(
            status_code=400,
            detail="Estado inválido",
        )

    cambiar_estado_publicacion(publicacion_id, estado)
    return {"mensaje": "Estado actualizado"}


# --------------------------------------------------
# PRODUCTOS SIMILARES
# --------------------------------------------------

@app.get("/recomendados/{publicacion_id}")
def productos_similares(publicacion_id: int):
    return obtener_productos_similares(publicacion_id)


# --------------------------------------------------
# ACTUALIZAR PRECIO
# --------------------------------------------------

@app.post("/actualizar_precio")
def actualizar_precio_publicacion(publicacion_id: int, nuevo_precio: float):
    precio_anterior = actualizar_precio(publicacion_id, nuevo_precio)

    if precio_anterior is None:
        raise HTTPException(
            status_code=404,
            detail="Publicación no encontrada",
        )

    if nuevo_precio < precio_anterior:
        usuarios = obtener_usuarios_favorito(publicacion_id)

        for user_id in usuarios:
            crear_notificacion(
                user_id,
                "precio",
                "Un producto que guardaste bajó de precio 💰",
            )

    return {"mensaje": "Precio actualizado"}


# --------------------------------------------------
# ENVIAR MENSAJE CHAT
# --------------------------------------------------

@app.post("/chat/enviar")
def enviar_mensaje(data: Mensaje):
    guardar_mensaje(
        data.publicacion_id,
        data.remitente_id,
        data.mensaje,
    )

    return {"mensaje": "Mensaje enviado"}


# --------------------------------------------------
# VER CHAT
# --------------------------------------------------

@app.get("/chat/{publicacion_id}")
def ver_chat(publicacion_id: int):
    return obtener_chat(publicacion_id)