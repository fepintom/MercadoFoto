# --------------------------------------------------
# STANDARD LIBRARY
# --------------------------------------------------

import hashlib
import traceback
import sqlite3
import json
import os
import secrets
import bcrypt

# Centraliza paths (DB y uploads) — debe importarse antes que todo lo demás
import config  # noqa: F401  (crea los directorios al importarse)
from config import UPLOADS_DIR


# --------------------------------------------------
# THIRD PARTY
# --------------------------------------------------

from fastapi import FastAPI, UploadFile, File, HTTPException, Form, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import JSONResponse
from pydantic import BaseModel
import json as _json

class UTF8JSONResponse(JSONResponse):
    def render(self, content) -> bytes:
        return _json.dumps(content, ensure_ascii=False).encode("utf-8")
from services.gpt_service import mejorar_descripcion_producto
from typing import Optional, List

# --------------------------------------------------
# SERVICES
# --------------------------------------------------

from services.background_service import quitar_fondo
from services.storage_service import guardar_imagen_procesada
from services.vision_service import detectar_producto
from services.trust_score_service import calcular_trust_score
from services.email_service import enviar_plantilla_carga_masiva, enviar_email_reset_password

# --------------------------------------------------
# FUNCIONES DE BASE DE DATOS
# --------------------------------------------------

from database.publicaciones import (
    init_publicaciones_db,
    guardar_publicacion,
    obtener_publicaciones,
    obtener_publicacion_por_id,
    migrar_publicaciones_guest,
    obtener_vendedor_publicacion,
    cambiar_estado_publicacion,
    obtener_productos_similares,
    actualizar_precio,
    editar_publicacion,
    eliminar_publicacion,
    guardar_info_adicional,
    obtener_publicaciones_cercanas,
    obtener_publicaciones_por_usuario,
)

from database.users import (
    obtener_usuario_por_email,
    init_users_db,
    crear_usuario,
    obtener_usuario_por_id,
    crear_o_obtener_usuario_firebase,
    actualizar_ubicacion_usuario,
    obtener_ubicacion_usuario,
    crear_reset_token,
    validar_reset_token,
    usar_reset_token,
    actualizar_foto_perfil,
    obtener_direcciones_usuario,
    agregar_direccion,
    actualizar_direccion,
    eliminar_direccion,
    establecer_principal,
)

from database.chat import (
    init_chat_db,
    guardar_mensaje,
    obtener_chat,
    obtener_conversaciones,
)

from database.favoritos import (
    init_favoritos_db,
    guardar_favorito,
    eliminar_favorito,
    es_favorito,
    obtener_favoritos,
    obtener_favoritos_completos,
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

from database.ordenes import guardar_delivery_method as _guardar_delivery
from database.ordenes import (
    init_ordenes_db,
    crear_orden,
    obtener_orden,
    obtener_por_external_ref,
    obtener_mis_compras,
    obtener_mis_ventas,
    guardar_preference,
    confirmar_pago,
    confirmar_entrega,
    abrir_disputa,
    marcar_reembolsado,
)
from services.mp_service import (
    crear_preferencia as mp_crear_preferencia,
    obtener_pago     as mp_obtener_pago,
    reembolsar_pago  as mp_reembolsar_pago,
)

from database.servicios import (
    init_servicios_db,
    crear_servicio,
    obtener_servicios,
    obtener_servicio_por_id,
    obtener_servicios_usuario,
    obtener_servicios_usuario_con_contactos,
    eliminar_servicio,
    valorar_servicio,
    actualizar_certificado,
    actualizar_ubicacion,
    registrar_contacto,
    obtener_contactos_servicio,
)

from database.delivery import (
    init_delivery_db,
    crear_perfil_delivery,
    obtener_perfiles_delivery,
    obtener_perfil_delivery_usuario,
    obtener_perfil_delivery_por_id,
    actualizar_estado_delivery,
    actualizar_ubicacion_delivery,
)

from services.blue_express_service import buscar_puntos as be_buscar_puntos

from database.users import guardar_fcm_token, obtener_fcm_token
from services.fcm_service import enviar_push

from database.ayuda import (
    init_ayuda_db,
    crear_ticket,
    crear_ticket_chat_directo,
    agregar_mensaje,
    obtener_tickets_usuario,
    obtener_mensajes_ticket,
    obtener_ticket,
    cerrar_ticket,
)

from database.entregas import init_entregas_db
from routers.okdelivery import router as okdelivery_router, crear_y_notificar_entrega

# --------------------------------------------------
# CATEGORIZACIÓN AUTOMÁTICA (keyword-based, sin dependencias externas)
# --------------------------------------------------

_CATEGORIA_MAP = [
    {
        "categoria": "Electrónica",
        "keywords": ["laptop", "computador", "notebook", "celular", "iphone", "samsung",
                     "tablet", "television", "tv", "monitor", "teclado", "mouse",
                     "impresora", "auricular", "audifonos", "cargador", "cable", "usb",
                     "camara", "drone", "smartwatch", "router", "disco"],
        "subcategorias": {
            "Computación": ["laptop", "computador", "notebook", "monitor", "teclado", "mouse", "disco"],
            "Impresión 3D": ["impresora 3d", "filamento", "3d"],
            "Celulares": ["celular", "iphone", "samsung", "smartphone", "telefono"],
            "TV": ["tv", "television", "smart tv", "pantalla"],
        },
    },
    {
        "categoria": "Ropa",
        "keywords": ["polera", "camiseta", "camisa", "poleron", "polerón", "chaqueta",
                     "chaleco", "sueter", "suéter", "sweater", "pantalon", "pantalón",
                     "jean", "jeans", "falda", "vestido", "short", "shorts", "blusa",
                     "polo", "abrigo", "parka", "cortaviento", "buzo", "pijama",
                     "traje", "terno", "conjunto ropa", "legging", "licra", "ropa"],
        "subcategorias": {
            "Superior": ["polera", "camiseta", "camisa", "poleron", "polerón",
                         "chaqueta", "chaleco", "sueter", "suéter", "sweater",
                         "blusa", "polo", "abrigo", "parka", "cortaviento", "buzo"],
            "Inferior": ["pantalon", "pantalón", "jean", "jeans", "falda",
                         "short", "shorts", "legging", "licra"],
            "Vestidos": ["vestido", "conjunto ropa", "traje", "terno"],
            "Ropa interior y pijamas": ["pijama", "ropa interior"],
        },
    },
    {
        "categoria": "Calzado",
        "keywords": ["zapato", "zapatilla", "zapatillas", "bota", "botas", "bototo",
                     "bototos", "sandalia", "sandalias", "taco", "tacos", "mocasin",
                     "mocasín", "mocasines", "zueco", "pantufla", "calzado", "tenis",
                     "sneaker", "sneakers"],
        "subcategorias": {
            "Deportivo": ["zapatilla", "zapatillas", "tenis", "sneaker", "sneakers", "running"],
            "Casual": ["zapato", "mocasin", "mocasín", "mocasines", "zueco", "pantufla"],
            "Formal": ["taco", "tacos"],
            "Botas y sandalias": ["bota", "botas", "bototo", "bototos", "sandalia", "sandalias"],
        },
    },
    {
        "categoria": "Automotriz",
        "keywords": ["auto", "carro", "vehiculo", "motor", "repuesto", "llanta", "moto",
                     "camion", "freno", "aceite", "filtro", "bujia", "bateria auto",
                     "parabrisas", "espejo retrovisor", "carroceria"],
        "subcategorias": {
            "Repuestos": ["repuesto", "freno", "llanta", "aceite", "filtro", "bujia"],
            "Autos": ["auto", "carro", "sedan", "suv", "camioneta"],
            "Motos": ["moto", "motocicleta", "scooter"],
            "Camiones": ["camion", "truck", "trailer"],
        },
    },
    {
        "categoria": "Hogar",
        "keywords": ["silla", "mesa", "sofa", "cama", "refrigerador", "lavadora",
                     "microondas", "cocina", "mueble", "decoracion", "lampara",
                     "cuadro", "alfombra", "cortina", "colchon", "escritorio",
                     "estante", "ropero", "vajilla", "ollas"],
        "subcategorias": {
            "Muebles": ["silla", "mesa", "sofa", "cama", "mueble", "estante", "escritorio", "ropero", "colchon"],
            "Decoración": ["decoracion", "lampara", "cuadro", "alfombra", "cortina", "florero", "espejo"],
            "Electrodomésticos": ["refrigerador", "lavadora", "microondas", "cocina", "lavavajillas", "horno"],
        },
    },
    {
        "categoria": "Ocio",
        "keywords": ["bicicleta", "pelota", "juego", "juguete", "consola", "playstation",
                     "xbox", "nintendo", "libro", "deporte", "raqueta", "guante",
                     "pesas", "kayak", "surf", "ski", "guitarra", "piano"],
        "subcategorias": {
            "Deportes": ["bicicleta", "pelota", "raqueta", "guante", "deporte", "futbol", "tenis", "pesas", "kayak"],
            "Juguetes": ["juguete", "muñeca", "lego", "puzzle", "peluche"],
            "Entretenimiento": ["consola", "playstation", "xbox", "nintendo", "libro", "guitarra", "piano"],
        },
    },
    {
        "categoria": "Mascotas",
        "keywords": ["perro", "gato", "mascota", "alimento", "collar", "jaula",
                     "acuario", "correa", "croqueta", "arena gato", "pecera"],
        "subcategorias": {
            "Alimentos": ["alimento", "comida", "croqueta", "snack"],
            "Accesorios": ["collar", "correa", "jaula", "acuario", "pecera", "cama mascota"],
            "Servicios": ["veterinario", "peluqueria", "guarderia"],
        },
    },
]


def detectar_categoria(titulo: str) -> tuple:
    """Detecta categoría y subcategoría a partir del título del producto."""
    t = titulo.lower()

    for cat_data in _CATEGORIA_MAP:
        for keyword in cat_data["keywords"]:
            if keyword in t:
                # Buscar subcategoría más específica
                for sub_nombre, sub_keys in cat_data["subcategorias"].items():
                    for sk in sub_keys:
                        if sk in t:
                            return cat_data["categoria"], sub_nombre
                # Subcategoría por defecto (primera)
                primera = next(iter(cat_data["subcategorias"]))
                return cat_data["categoria"], primera

    return "General", "Otros"


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

app = FastAPI(default_response_class=UTF8JSONResponse)

# Exponer carpeta uploads como pública
app.mount("/uploads", StaticFiles(directory=UPLOADS_DIR), name="uploads")

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
init_ordenes_db()
init_servicios_db()
init_delivery_db()
init_ayuda_db()
init_entregas_db()

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

# Flujo OkDelivery (retiro, tracking, entrega, evidencia y auto-cierre)
app.include_router(okdelivery_router)

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


class FirebaseLoginRequest(BaseModel):
    firebase_uid: str
    email: str
    nombre: Optional[str] = None
    apellido: Optional[str] = None
    foto_url: Optional[str] = None
    guest_id: Optional[str] = None


# EditarPublicacion: ahora usa Form + File (multipart) — ver endpoint PUT /publicaciones/{id}


class UbicacionUsuario(BaseModel):
    lat: float
    lng: float
    direccion: Optional[str] = None
    comuna: Optional[str] = None
    ciudad: Optional[str] = None


# --------------------------------------------------
# LOGIN FIREBASE (Google Sign-In + Email/Password vía Firebase)
# --------------------------------------------------

@app.post("/login/firebase")
def login_firebase(data: FirebaseLoginRequest):
    """
    Recibe firebase_uid + email + nombre desde Flutter después de que
    Firebase autentica al usuario. Crea o recupera el user_id del backend
    y migra las publicaciones guest si se provee guest_id.
    """
    try:
        nombre = data.nombre or (data.email.split("@")[0] if data.email else "Usuario")

        usuario = crear_o_obtener_usuario_firebase(
            firebase_uid=data.firebase_uid,
            email=data.email,
            nombre=nombre,
            apellido=data.apellido or "",
            foto_url=data.foto_url or "",
        )

        if data.guest_id and data.guest_id.strip():
            migrar_publicaciones_guest(data.guest_id, usuario["id"])

        return {
            "user_id": usuario["id"],
            "nombre": usuario["nombre"],
            "apellido": usuario.get("apellido", ""),
            "foto_url": usuario.get("foto_url", ""),
            "email": data.email,
            "mensaje": "Sesión iniciada correctamente",
        }

    except Exception as e:
        print("ERROR EN /login/firebase:", repr(e))
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))


# --------------------------------------------------
# ENVIAR PLANTILLA CARGA MASIVA
# --------------------------------------------------

@app.post("/enviar_plantilla")
def enviar_plantilla(email: str):
    """
    Envía la plantilla Excel de carga masiva al correo indicado.
    """
    try:
        enviar_plantilla_carga_masiva(email)
        return {"mensaje": f"Plantilla enviada a {email}"}
    except FileNotFoundError as e:
        raise HTTPException(status_code=500, detail=str(e))
    except Exception as e:
        print("ERROR EN /enviar_plantilla:", repr(e))
        traceback.print_exc()
        raise HTTPException(status_code=500, detail="No se pudo enviar el correo. Verifica la configuración SMTP.")


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
            titulo, descripcion, _, precio_min, precio_max, moneda, confianza = cached
            dimensiones = "No determinado"
            print(f"Cache hit: {titulo} | precio {precio_min}–{precio_max} {moneda}")
        else:
            # GPT-4o Vision detecta, titula, describe, estima dimensiones y precio
            titulo, descripcion, dimensiones, precio_min, precio_max, moneda, confianza = \
                detectar_producto(original_bytes)

            # Guardar en cache (incluyendo precio)
            save_cached_analisis(
                image_hash, titulo, descripcion, False,
                precio_min=precio_min,
                precio_max=precio_max,
                moneda=moneda,
                confianza=confianza,
            )

        # Categorización automática por palabras clave
        categoria, subcategoria = detectar_categoria(titulo)

        # Quitar fondo y guardar imagen
        imagen_procesada = quitar_fondo(original_bytes)
        imagen_url = guardar_imagen_procesada(imagen_procesada)

        return {
            "titulo":       titulo,
            "descripcion":  descripcion,
            "dimensiones":  dimensiones,
            "imagen_url":   imagen_url,
            "categoria":    categoria,
            "subcategoria": subcategoria,
            "precio_min":   precio_min,
            "precio_max":   precio_max,
            "moneda":       moneda,
            "confianza":    confianza,
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
    file2: Optional[UploadFile] = File(None),
    file3: Optional[UploadFile] = File(None),
    file4: Optional[UploadFile] = File(None),
    guest_id: Optional[str] = Form(None),
    user_id: Optional[int] = Form(None),
    dimensiones: Optional[str] = Form(None),
    categoria: Optional[str] = Form(None),
    subcategoria: Optional[str] = Form(None),
    lat: Optional[float] = Form(None),
    lng: Optional[float] = Form(None),
    delivery_id: Optional[int] = Form(None),
    condicion: Optional[str] = Form("nuevo"),
    acepta_ofertas: int = Form(1),
    tallas: Optional[str] = Form(None),
):
    if not guest_id and not user_id:
        raise HTTPException(
            status_code=400,
            detail="Se requiere guest_id o user_id",
        )

    try:
        # Procesar imagen principal
        image_bytes = await file.read()
        imagen_sin_fondo = quitar_fondo(image_bytes)
        imagen_url = guardar_imagen_procesada(imagen_sin_fondo)

        # Procesar imágenes extras (hasta 3 adicionales)
        import json as _json
        imagenes_extra_urls = []
        for extra_file in [file2, file3, file4]:
            if extra_file is not None:
                extra_bytes = await extra_file.read()
                if extra_bytes:
                    extra_sin_fondo = quitar_fondo(extra_bytes)
                    extra_url = guardar_imagen_procesada(extra_sin_fondo)
                    imagenes_extra_urls.append(extra_url)

        imagenes_extra = _json.dumps(imagenes_extra_urls) if imagenes_extra_urls else None

        # Si no viene categoría del cliente, detectar automáticamente
        if not categoria:
            categoria, subcategoria = detectar_categoria(titulo)

        guardar_publicacion(
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
        )

        return {
            "mensaje": "Producto publicado correctamente",
            "imagen_url": imagen_url,
            "imagenes_urls": [imagen_url] + imagenes_extra_urls,
            "categoria": categoria,
            "subcategoria": subcategoria,
        }

    except Exception as e:
        print("ERROR EN /publicar:", repr(e))
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))


# --------------------------------------------------
# LISTAR PUBLICACIONES
# --------------------------------------------------

@app.get("/publicaciones")
def listar_publicaciones(
    categoria: Optional[str] = None,
    subcategoria: Optional[str] = None,
):
    try:
        publicaciones = obtener_publicaciones()

        if categoria:
            publicaciones = [
                p for p in publicaciones
                if p.get("categoria", "").lower() == categoria.lower()
            ]

        if subcategoria:
            publicaciones = [
                p for p in publicaciones
                if p.get("subcategoria", "").lower() == subcategoria.lower()
            ]

        return publicaciones

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

    stored = usuario["password"] or ""
    # Soporta contraseñas en texto plano (legacy) y hashes bcrypt
    if stored.startswith("$2b$") or stored.startswith("$2a$"):
        password_ok = bcrypt.checkpw(data.password.encode(), stored.encode())
    else:
        password_ok = (data.password == stored)

    if not password_ok:
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

    # También guardar como mensaje de chat para que aparezca en la bandeja
    if pregunta.user_id:
        guardar_mensaje(pregunta.publicacion_id, pregunta.user_id, pregunta.mensaje)

    if vendedor_id:
        crear_notificacion(
            vendedor_id,
            "pregunta",
            f"Nueva pregunta: \"{pregunta.mensaje}\"",
            publicacion_id=pregunta.publicacion_id,
        )
        # Push al vendedor
        try:
            fcm_token = obtener_fcm_token(vendedor_id)
            if fcm_token:
                pub = obtener_publicacion_por_id(pregunta.publicacion_id)
                titulo = pub["titulo"] if pub else "tu publicación"
                enviar_push(
                    fcm_token,
                    "Nueva pregunta",
                    f"{pregunta.mensaje}",
                    {"publicacion_id": str(pregunta.publicacion_id), "tipo": "pregunta"},
                )
        except Exception as e:
            print(f"Push pregunta error: {e}")

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
                publicacion_id=publicacion_id,
            )

    return {"mensaje": "Precio actualizado"}


# --------------------------------------------------
# ENVIAR MENSAJE CHAT
# --------------------------------------------------

@app.post("/usuarios/{user_id}/fcm_token")
def registrar_fcm_token(user_id: int, body: dict):
    token = body.get("token", "").strip()
    if not token:
        raise HTTPException(status_code=400, detail="Token requerido")
    guardar_fcm_token(user_id, token)
    return {"ok": True}


@app.post("/chat/enviar")
def enviar_mensaje(data: Mensaje):
    guardar_mensaje(
        data.publicacion_id,
        data.remitente_id,
        data.mensaje,
    )

    # ── Notificación push al dueño del producto ──────────────────────
    try:
        pub = obtener_publicacion_por_id(data.publicacion_id)
        if pub:
            owner_id = pub.get("user_id")
            if owner_id and owner_id != data.remitente_id:
                fcm_token = obtener_fcm_token(owner_id)
                if fcm_token:
                    remitente = obtener_usuario_por_id(data.remitente_id)
                    nombre_remitente = remitente.get("nombre", "Alguien") if remitente else "Alguien"
                    enviar_push(
                        fcm_token=fcm_token,
                        titulo=f"Nuevo mensaje de {nombre_remitente}",
                        cuerpo=data.mensaje[:100],
                        data={"publicacion_id": str(data.publicacion_id), "tipo": "chat"},
                    )
    except Exception as e:
        print(f"Push chat error: {e}")

    return {"mensaje": "Mensaje enviado"}


# --------------------------------------------------
# VER CHAT
# --------------------------------------------------

@app.get("/chat/conversaciones/{user_id}")
def ver_conversaciones(user_id: int):
    return obtener_conversaciones(user_id)

@app.get("/chat/{publicacion_id}")
def ver_chat(publicacion_id: int):
    return obtener_chat(publicacion_id)


@app.post("/chat/{publicacion_id}/imagen")
async def enviar_imagen_chat(
    publicacion_id: int,
    remitente_id: int = Form(...),
    imagen: UploadFile = File(...),
):
    import time as _time
    ext = os.path.splitext(imagen.filename or "img.jpg")[1] or ".jpg"
    nombre = f"chat_{publicacion_id}_{remitente_id}_{int(_time.time())}{ext}"
    ruta = os.path.join(UPLOADS_DIR, nombre)
    contenido = await imagen.read()
    with open(ruta, "wb") as f:
        f.write(contenido)
    imagen_url = f"/uploads/{nombre}"
    guardar_mensaje(publicacion_id, remitente_id, "", imagen_url=imagen_url)
    return {"imagen_url": imagen_url}


# --------------------------------------------------
# EDITAR PUBLICACION
# --------------------------------------------------

@app.put("/publicaciones/{publicacion_id}")
async def editar_pub(
    publicacion_id: int,
    titulo: str = Form(...),
    descripcion: str = Form(...),
    precio: float = Form(...),
    fotos_mantener: Optional[str] = Form(None),   # JSON array de URLs a conservar
    file1: Optional[UploadFile] = File(None),
    file2: Optional[UploadFile] = File(None),
    file3: Optional[UploadFile] = File(None),
    condicion: Optional[str] = Form(None),
    acepta_ofertas: Optional[int] = Form(None),
):
    import json as _json

    pub = obtener_publicacion_por_id(publicacion_id)
    if not pub:
        raise HTTPException(status_code=404, detail="Publicación no encontrada")

    # ── Fotos existentes que el usuario quiere conservar ──
    urls_mantener = _json.loads(fotos_mantener) if fotos_mantener else []

    # ── Nuevas fotos: procesar con rembg ──
    nuevas_urls = []
    for f in [file1, file2, file3]:
        if f is not None:
            data_bytes = await f.read()
            if data_bytes:
                procesada = quitar_fondo(data_bytes)
                url = guardar_imagen_procesada(procesada)
                nuevas_urls.append(url)

    # ── Combinar (mantener primero, nuevas después) ──
    todas = urls_mantener + nuevas_urls

    if todas:
        imagen_url    = todas[0]
        imagenes_extra = _json.dumps(todas[1:]) if len(todas) > 1 else None
        editar_publicacion(publicacion_id, titulo, descripcion, precio,
                           imagen_url, imagenes_extra, condicion, acepta_ofertas)
    else:
        editar_publicacion(publicacion_id, titulo, descripcion, precio,
                           condicion=condicion, acepta_ofertas=acepta_ofertas)

    return {"mensaje": "Publicación actualizada"}


# --------------------------------------------------
# INFO ADICIONAL (SKU / STOCK / CÓDIGO UNIVERSAL)
# --------------------------------------------------

class InfoAdicionalBody(BaseModel):
    sku:              Optional[str] = None
    stock:            Optional[int] = None
    codigo_universal: Optional[str] = None

@app.patch("/publicaciones/{publicacion_id}/info-adicional")
def actualizar_info_adicional(publicacion_id: int, body: InfoAdicionalBody):
    pub = obtener_publicacion_por_id(publicacion_id)
    if not pub:
        raise HTTPException(status_code=404, detail="Publicación no encontrada")
    guardar_info_adicional(
        publicacion_id,
        sku=body.sku,
        stock=body.stock,
        codigo_universal=body.codigo_universal,
    )
    return {"mensaje": "Información adicional actualizada"}


# --------------------------------------------------
# ELIMINAR PUBLICACION
# --------------------------------------------------

@app.delete("/publicaciones/{publicacion_id}")
def eliminar_pub(publicacion_id: int, user_id: Optional[int] = None):
    pub = obtener_publicacion_por_id(publicacion_id)
    if not pub:
        # Ya fue eliminada antes — respuesta idempotente
        return {"mensaje": "Publicación eliminada"}
    if user_id and pub["user_id"] != user_id:
        raise HTTPException(status_code=403, detail="No autorizado")
    eliminar_publicacion(publicacion_id)
    return {"mensaje": "Publicación eliminada"}


# --------------------------------------------------
# PUBLICACIONES CERCANAS
# --------------------------------------------------

@app.get("/publicaciones/cercanas")
def publicaciones_cercanas(lat: float, lng: float, radio_km: float = 5.0):
    try:
        return obtener_publicaciones_cercanas(lat, lng, radio_km)
    except Exception as e:
        print("ERROR /publicaciones/cercanas:", repr(e))
        raise HTTPException(status_code=500, detail=str(e))


# --------------------------------------------------
# ACTUALIZAR UBICACIÓN USUARIO
# --------------------------------------------------

@app.put("/usuarios/{user_id}/ubicacion")
def actualizar_ubicacion(user_id: int, data: UbicacionUsuario):
    actualizar_ubicacion_usuario(user_id, data.lat, data.lng, data.direccion, data.comuna, data.ciudad)
    return {"mensaje": "Ubicación actualizada"}


@app.get("/usuarios/{user_id}/ubicacion")
def ver_ubicacion(user_id: int):
    return obtener_ubicacion_usuario(user_id) or {}


# --------------------------------------------------
# MÚLTIPLES DIRECCIONES POR USUARIO
# --------------------------------------------------

class DireccionBody(BaseModel):
    etiqueta: str = "Casa"
    direccion: str
    comuna: str = ""
    ciudad: str = ""
    lat: Optional[float] = None
    lng: Optional[float] = None

@app.get("/usuarios/{user_id}/direcciones")
def listar_direcciones(user_id: int):
    return obtener_direcciones_usuario(user_id)

@app.post("/usuarios/{user_id}/direcciones")
def nueva_direccion(user_id: int, body: DireccionBody):
    new_id = agregar_direccion(user_id, body.etiqueta, body.direccion,
                               body.comuna, body.ciudad, body.lat, body.lng)
    return {"id": new_id, "mensaje": "Dirección agregada"}

@app.put("/usuarios/{user_id}/direcciones/{address_id}")
def editar_direccion(user_id: int, address_id: int, body: DireccionBody):
    actualizar_direccion(address_id, user_id, body.etiqueta, body.direccion,
                         body.comuna, body.ciudad, body.lat, body.lng)
    return {"mensaje": "Dirección actualizada"}

@app.delete("/usuarios/{user_id}/direcciones/{address_id}")
def borrar_direccion(user_id: int, address_id: int):
    eliminar_direccion(address_id, user_id)
    return {"mensaje": "Dirección eliminada"}

@app.patch("/usuarios/{user_id}/direcciones/{address_id}/principal")
def marcar_principal(user_id: int, address_id: int):
    establecer_principal(address_id, user_id)
    return {"mensaje": "Dirección principal actualizada"}


@app.post("/usuarios/{user_id}/foto")
async def subir_foto_perfil(user_id: int, foto: UploadFile = File(...)):
    ext = os.path.splitext(foto.filename or "foto.jpg")[1] or ".jpg"
    nombre = f"perfil_{user_id}{ext}"
    ruta = os.path.join(UPLOADS_DIR, nombre)
    contenido = await foto.read()
    with open(ruta, "wb") as f:
        f.write(contenido)
    foto_url = f"/uploads/{nombre}"
    actualizar_foto_perfil(user_id, foto_url)
    return {"foto_url": foto_url}


# --------------------------------------------------
# TOGGLE FAVORITO (guardar / quitar)
# --------------------------------------------------

@app.delete("/favorito")
def quitar_favorito(user_id: int, publicacion_id: int):
    eliminar_favorito(user_id, publicacion_id)
    return {"mensaje": "Quitado de favoritos"}


@app.get("/favorito/check")
def check_favorito(user_id: int, publicacion_id: int):
    return {"es_favorito": es_favorito(user_id, publicacion_id)}


@app.get("/favoritos/{user_id}/completos")
def ver_favoritos_completos(user_id: int):
    return obtener_favoritos_completos(user_id)


# --------------------------------------------------
# INTERÉS DE COMPRA (comprador interesado → notifica vendedor)
# --------------------------------------------------

@app.post("/oferta/responder")
def responder_oferta(body: dict):
    """El vendedor acepta, rechaza o contraoferta. Notifica al comprador."""
    publicacion_id = body.get("publicacion_id")
    vendedor_id    = body.get("vendedor_id")
    comprador_id   = body.get("comprador_id")
    accion         = body.get("accion")  # aceptar | rechazar | contraofertar
    monto_contra   = body.get("monto_contra")
    mensaje_extra  = body.get("mensaje", "")

    if not all([publicacion_id, vendedor_id, comprador_id, accion]):
        raise HTTPException(status_code=400, detail="Faltan datos")

    pub = obtener_publicacion_por_id(publicacion_id)
    titulo = pub["titulo"] if pub else "tu publicación"

    if accion == "aceptar":
        msg_chat  = f"✅ Oferta aceptada"
        msg_notif = f"¡Tu oferta fue aceptada! Coordina con el vendedor."
        if mensaje_extra:
            msg_chat += f" — {mensaje_extra}"
    elif accion == "rechazar":
        msg_chat  = f"❌ Oferta rechazada"
        msg_notif = f"Tu oferta por '{titulo}' fue rechazada."
        if mensaje_extra:
            msg_chat += f" — {mensaje_extra}"
    elif accion == "contraofertar":
        msg_chat  = f"↩️ Contraoferta: ${float(monto_contra):,.0f}"
        msg_notif = f"Nueva contraoferta de ${float(monto_contra):,.0f} por '{titulo}'"
        if mensaje_extra:
            msg_chat += f" — {mensaje_extra}"
    else:
        raise HTTPException(status_code=400, detail="Acción inválida")

    guardar_mensaje(publicacion_id, vendedor_id, msg_chat)

    crear_notificacion(comprador_id, "oferta_respuesta", msg_notif, publicacion_id=publicacion_id)

    try:
        fcm_token = obtener_fcm_token(comprador_id)
        if fcm_token:
            enviar_push(fcm_token, "Respuesta a tu oferta", msg_notif,
                        {"publicacion_id": str(publicacion_id), "tipo": "oferta_respuesta"})
    except Exception as e:
        print(f"Push respuesta oferta error: {e}")

    return {"ok": True}


@app.post("/ofertar")
def hacer_oferta(body: dict):
    """El comprador hace una oferta. Se guarda como mensaje de chat y se notifica al vendedor."""
    publicacion_id = body.get("publicacion_id")
    comprador_id   = body.get("comprador_id")
    monto          = body.get("monto")

    if not publicacion_id or not comprador_id or monto is None:
        raise HTTPException(status_code=400, detail="Faltan datos")

    pub = obtener_publicacion_por_id(publicacion_id)
    if not pub:
        raise HTTPException(status_code=404, detail="Publicación no encontrada")

    mensaje_oferta = f"💰 Oferta: ${monto:,.0f}"
    guardar_mensaje(publicacion_id, comprador_id, mensaje_oferta)

    vendedor_id = pub.get("user_id")
    if vendedor_id:
        crear_notificacion(
            vendedor_id,
            "oferta",
            f"Nueva oferta de ${monto:,.0f} por '{pub['titulo']}'",
            publicacion_id=publicacion_id,
            remitente_id=comprador_id,
        )
        try:
            fcm_token = obtener_fcm_token(vendedor_id)
            if fcm_token:
                enviar_push(
                    fcm_token,
                    "💰 Nueva oferta",
                    f"${monto:,.0f} por {pub['titulo']}",
                    {"publicacion_id": str(publicacion_id), "tipo": "oferta"},
                )
        except Exception as e:
            print(f"Push oferta error: {e}")

    return {"ok": True}


@app.post("/interes_compra/{publicacion_id}")
def registrar_interes(publicacion_id: int, comprador_id: int):
    """El comprador marca interés en un producto. Se notifica al vendedor."""
    pub = obtener_publicacion_por_id(publicacion_id)
    if not pub:
        raise HTTPException(status_code=404, detail="Publicación no encontrada")

    vendedor_id = pub.get("user_id")
    if vendedor_id:
        crear_notificacion(
            vendedor_id,
            "interes_compra",
            f"¡Alguien quiere comprar '{pub['titulo']}'! Revisa el chat para coordinar.",
            publicacion_id=publicacion_id,
        )

    return {"mensaje": "Interés registrado. El vendedor fue notificado."}


# --------------------------------------------------
# PUBLICACION POR ID
# --------------------------------------------------

@app.get("/publicaciones/{publicacion_id}")
def obtener_pub(publicacion_id: int):
    pub = obtener_publicacion_por_id(publicacion_id)
    if not pub:
        raise HTTPException(status_code=404, detail="Publicación no encontrada")
    return pub


# --------------------------------------------------
# PERFIL PÚBLICO DEL VENDEDOR
# --------------------------------------------------

@app.get("/usuarios/{user_id}/perfil_publico")
def perfil_publico(user_id: int):
    """
    Retorna nombre del usuario y sus publicaciones activas.
    NO expone email, teléfono, dirección ni datos bancarios.
    """
    usuario = obtener_usuario_por_id(user_id)
    if not usuario:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")

    nombre = usuario.get("nombre") or "Usuario"
    publicaciones = obtener_publicaciones_por_usuario(user_id)

    return {
        "user_id": user_id,
        "nombre": nombre,
        "publicaciones": publicaciones,
    }


# --------------------------------------------------
# RESET DE CONTRASEÑA
# --------------------------------------------------

class SolicitarResetData(BaseModel):
    email: str

@app.post("/solicitar_reset")
def solicitar_reset(data: SolicitarResetData):
    email = data.email.lower().strip()
    usuario = obtener_usuario_por_email(email)
    # Siempre responder OK para no revelar si el email existe
    if usuario:
        token = secrets.token_urlsafe(32)
        crear_reset_token(email, token)
        reset_url = f"https://okventa-backend.onrender.com/reset_password?token={token}"
        try:
            enviar_email_reset_password(email, reset_url)
        except Exception as e:
            print(f"Error enviando email reset: {e}")
    return {"mensaje": "Si el correo está registrado, recibirás un enlace para restablecer tu contraseña."}


@app.get("/reset_password")
def reset_password_form(token: str):
    from fastapi.responses import HTMLResponse
    email = validar_reset_token(token)
    if not email:
        return HTMLResponse("""
        <html><body style='font-family:sans-serif;text-align:center;padding:60px'>
        <h2>❌ Enlace inválido o expirado</h2>
        <p>Solicita un nuevo enlace desde la app OkVenta.</p>
        </body></html>
        """)
    return HTMLResponse(f"""
    <html>
    <head><meta name='viewport' content='width=device-width,initial-scale=1'>
    <style>
      body{{font-family:sans-serif;max-width:400px;margin:60px auto;padding:20px}}
      input{{width:100%;padding:12px;margin:8px 0;border:1px solid #ddd;border-radius:8px;font-size:16px;box-sizing:border-box}}
      button{{width:100%;padding:14px;background:#00B4A0;color:white;border:none;border-radius:8px;font-size:16px;cursor:pointer}}
      h2{{color:#333}}p{{color:#666}}
    </style>
    </head>
    <body>
    <h2>Nueva contraseña</h2>
    <p>Ingresa tu nueva contraseña para <b>{email}</b></p>
    <form method='post' action='/reset_password'>
      <input type='hidden' name='token' value='{token}'>
      <input type='password' name='password' placeholder='Nueva contraseña' required minlength='6'>
      <input type='password' name='password2' placeholder='Confirmar contraseña' required minlength='6'>
      <button type='submit'>Guardar contraseña</button>
    </form>
    </body></html>
    """)


@app.post("/reset_password")
async def reset_password_submit(request: Request):
    from fastapi.responses import HTMLResponse
    from fastapi.datastructures import FormData
    form = await request.form()
    token = form.get("token", "")
    password = form.get("password", "")
    password2 = form.get("password2", "")

    if password != password2:
        return HTMLResponse("<html><body style='font-family:sans-serif;text-align:center;padding:60px'><h2>❌ Las contraseñas no coinciden</h2><a href='javascript:history.back()'>Volver</a></body></html>")

    if len(password) < 6:
        return HTMLResponse("<html><body style='font-family:sans-serif;text-align:center;padding:60px'><h2>❌ La contraseña debe tener al menos 6 caracteres</h2><a href='javascript:history.back()'>Volver</a></body></html>")

    hashed = bcrypt.hashpw(password.encode(), bcrypt.gensalt()).decode()
    ok = usar_reset_token(token, hashed)

    if not ok:
        return HTMLResponse("<html><body style='font-family:sans-serif;text-align:center;padding:60px'><h2>❌ Enlace inválido o expirado</h2></body></html>")

    return HTMLResponse("""
    <html><body style='font-family:sans-serif;text-align:center;padding:60px'>
    <h2>✅ Contraseña actualizada</h2>
    <p>Ya puedes iniciar sesión en la app OkVenta con tu nueva contraseña.</p>
    </body></html>
    """)

# ==============================================================================
# SERVICIOS
# ==============================================================================

# Detección de QR en certificados con Pillow (sin dependencias extra).
# Usamos pyzbar si está disponible; si no, el certificado queda pendiente.
try:
    from pyzbar.pyzbar import decode as _pyzbar_decode
    from PIL import Image as _PilImage
    _QR_OK = True
except Exception:
    try:
        from PIL import Image as _PilImage
        _QR_OK = False          # Pillow sí, pyzbar no
    except Exception:
        _QR_OK = False


def _tiene_qr_valido(filepath: str) -> bool:
    """Devuelve True si la imagen contiene un QR que apunta a una URL."""
    if not _QR_OK:
        return False
    try:
        img = _PilImage.open(filepath).convert("RGB")
        codes = _pyzbar_decode(img)
        for code in codes:
            data = code.data.decode("utf-8", errors="ignore")
            if data.startswith("http"):
                return True
    except Exception:
        pass
    return False


# ── CRUD servicios ────────────────────────────────────────────────────────────

@app.post("/servicios")
async def crear_servicio_endpoint(
    user_id:     int   = Form(...),
    tipo:        str   = Form(...),    # 'ofrezco' | 'busco'
    titulo:      str   = Form(...),
    descripcion: str   = Form(""),
    comunas:     str   = Form(""),
    valor:       float = Form(0),
    modalidad:   str   = Form("servicio"),  # 'hora' | 'servicio'
    telefono:    str   = Form(""),
    whatsapp:    str   = Form(""),
    lat:         float = Form(None),
    lng:         float = Form(None),
    radio_km:    float = Form(5.0),
    categoria:   str   = Form("Otros"),
    color_hex:   str   = Form("#007AFF"),
    fotos: Optional[List[UploadFile]] = File(default=None),
):
    saved_paths = []
    for foto in (fotos or [])[:2]:  # máximo 2 archivos
        if not foto.filename:
            continue
        ext  = os.path.splitext(foto.filename)[1].lower() or ".jpg"
        name = f"srv_{user_id}_{secrets.token_hex(8)}{ext}"
        path = os.path.join(UPLOADS_DIR, name)
        with open(path, "wb") as f:
            f.write(await foto.read())
        saved_paths.append(f"/uploads/{name}")

    sid = crear_servicio(
        user_id=user_id, tipo=tipo, titulo=titulo,
        descripcion=descripcion, comunas=comunas,
        valor=valor, modalidad=modalidad,
        fotos=saved_paths,
        lat=lat, lng=lng, radio_km=radio_km,
        categoria=categoria, color_hex=color_hex,
        telefono=telefono, whatsapp=whatsapp,
    )
    return {"id": sid, "ok": True}


@app.patch("/servicios/{servicio_id}/ubicacion")
def actualizar_ubicacion_endpoint(servicio_id: int, body: dict):
    user_id  = body.get("user_id")
    lat      = body.get("lat")
    lng      = body.get("lng")
    radio_km = float(body.get("radio_km", 5))
    if not user_id or lat is None or lng is None:
        raise HTTPException(status_code=400, detail="Datos incompletos")
    actualizar_ubicacion(servicio_id, user_id, lat, lng, radio_km)
    return {"ok": True}


@app.get("/servicios")
def listar_servicios(tipo: str = None):
    return obtener_servicios(tipo)


@app.get("/servicios/usuario/{user_id}")
def servicios_de_usuario(user_id: int):
    return obtener_servicios_usuario(user_id)


@app.get("/servicios/usuario/{user_id}/mis_servicios")
def mis_servicios(user_id: int):
    """Servicios propios con conteo de contactos (para el panel del dueño)."""
    return obtener_servicios_usuario_con_contactos(user_id)


@app.post("/servicios/{servicio_id}/contacto")
def registrar_contacto_servicio(servicio_id: int, body: dict):
    """Registra que alguien tocó WhatsApp/Llamar en un servicio."""
    contactante_id = body.get("contactante_id")
    tipo           = body.get("tipo", "whatsapp")
    nombre         = body.get("nombre", "")
    registrar_contacto(servicio_id, contactante_id, tipo, nombre)
    return {"ok": True}


@app.get("/servicios/{servicio_id}/contactos")
def contactos_servicio(servicio_id: int, owner_id: int):
    """Lista de contactos de un servicio (solo el dueño puede verla)."""
    srv = obtener_servicio_por_id(servicio_id)
    if not srv or srv["user_id"] != owner_id:
        raise HTTPException(status_code=403, detail="Sin permiso")
    return {"contactos": obtener_contactos_servicio(servicio_id)}


@app.get("/servicios/{servicio_id}")
def detalle_servicio(servicio_id: int):
    srv = obtener_servicio_por_id(servicio_id)
    if not srv:
        raise HTTPException(status_code=404, detail="Servicio no encontrado")
    return srv


@app.delete("/servicios/{servicio_id}")
def borrar_servicio(servicio_id: int, user_id: int):
    eliminar_servicio(servicio_id, user_id)
    return {"ok": True}


# ── Valorar ───────────────────────────────────────────────────────────────────

@app.post("/servicios/{servicio_id}/valorar")
def valorar(servicio_id: int, body: dict):
    user_id  = body.get("user_id")
    estrellas = int(body.get("estrellas", 5))
    if not user_id or not (1 <= estrellas <= 5):
        raise HTTPException(status_code=400, detail="Datos inválidos")
    valorar_servicio(servicio_id, user_id, estrellas)
    srv = obtener_servicio_por_id(servicio_id)
    return {"rating": srv["rating"], "num_valoraciones": srv["num_valoraciones"]}


# ── Certificado profesional ───────────────────────────────────────────────────

@app.post("/servicios/{servicio_id}/certificado")
async def subir_certificado(
    servicio_id: int,
    user_id: int = Form(...),
    archivo: UploadFile = File(...),
):
    ext  = os.path.splitext(archivo.filename)[1].lower() or ".jpg"
    name = f"cert_{servicio_id}_{secrets.token_hex(8)}{ext}"
    path = os.path.join(UPLOADS_DIR, name)
    with open(path, "wb") as f:
        f.write(await archivo.read())

    url        = f"/uploads/{name}"
    verificado = _tiene_qr_valido(path)
    actualizar_certificado(servicio_id, user_id, url, verificado)

    return {
        "url":        url,
        "verificado": verificado,
        "mensaje":    "Certificado validado automáticamente ✅" if verificado
                      else "Certificado recibido. Verificación en proceso 🔄",
    }


# ── CRUD delivery ─────────────────────────────────────────────────────────────

@app.post("/delivery")
async def registrar_delivery(
    user_id:       int   = Form(...),
    nombre:        str   = Form(...),
    edad:          int   = Form(0),
    email:         str   = Form(""),
    rut:           str   = Form(""),
    telefono:      str   = Form(""),
    direccion:     str   = Form(""),
    tipo_vehiculo: str   = Form("bicicleta"),
    patente:       str   = Form(""),
    banco:         str   = Form(""),
    cuenta_banco:  str   = Form(""),
    lat:           float = Form(None),
    lng:           float = Form(None),
    radio_km:      float = Form(5.0),
    foto_perfil:     Optional[UploadFile] = File(default=None),
    foto_vehiculo:   Optional[UploadFile] = File(default=None),
    foto_ci_frente:  Optional[UploadFile] = File(default=None),
    foto_ci_reverso: Optional[UploadFile] = File(default=None),
    selfie_ci:       Optional[UploadFile] = File(default=None),
):
    async def _save(upload: Optional[UploadFile], prefix: str) -> Optional[str]:
        if upload is None or not upload.filename:
            return None
        ext  = os.path.splitext(upload.filename)[1].lower() or ".jpg"
        name = f"{prefix}_{user_id}_{secrets.token_hex(8)}{ext}"
        path = os.path.join(UPLOADS_DIR, name)
        with open(path, "wb") as f:
            f.write(await upload.read())
        return f"/uploads/{name}"

    p_perfil    = await _save(foto_perfil,     "dlv_perfil")
    p_vehiculo  = await _save(foto_vehiculo,   "dlv_vehiculo")
    p_ci_frente = await _save(foto_ci_frente,  "dlv_ci_f")
    p_ci_rev    = await _save(foto_ci_reverso, "dlv_ci_r")
    p_selfie    = await _save(selfie_ci,       "dlv_selfie")

    did = crear_perfil_delivery(
        user_id=user_id, nombre=nombre, edad=edad, email=email,
        rut=rut, telefono=telefono, direccion=direccion,
        tipo_vehiculo=tipo_vehiculo, patente=patente,
        banco=banco, cuenta_banco=cuenta_banco,
        foto_perfil=p_perfil, foto_vehiculo=p_vehiculo,
        foto_ci_frente=p_ci_frente, foto_ci_reverso=p_ci_rev, selfie_ci=p_selfie,
        lat=lat, lng=lng, radio_km=radio_km,
    )
    return {"id": did, "ok": True}


@app.get("/delivery")
def listar_delivery(solo_activos: bool = True):
    return obtener_perfiles_delivery(solo_activos=solo_activos)


@app.get("/delivery/usuario/{user_id}")
def delivery_de_usuario(user_id: int):
    perfil = obtener_perfil_delivery_usuario(user_id)
    if not perfil:
        raise HTTPException(status_code=404, detail="Sin perfil de delivery")
    return perfil


@app.get("/delivery/{delivery_id}")
def detalle_delivery(delivery_id: int):
    perfil = obtener_perfil_delivery_por_id(delivery_id)
    if not perfil:
        raise HTTPException(status_code=404, detail="No encontrado")
    return perfil


@app.patch("/delivery/{delivery_id}/estado")
def toggle_delivery(delivery_id: int, body: dict):
    user_id = body.get("user_id")
    activo  = body.get("activo", True)
    if not user_id:
        raise HTTPException(status_code=400, detail="user_id requerido")
    actualizar_estado_delivery(delivery_id, user_id, activo)
    return {"ok": True}


@app.patch("/delivery/{delivery_id}/ubicacion")
def ubicacion_delivery(delivery_id: int, body: dict):
    user_id  = body.get("user_id")
    lat      = body.get("lat")
    lng      = body.get("lng")
    radio_km = float(body.get("radio_km", 5))
    if not user_id or lat is None or lng is None:
        raise HTTPException(status_code=400, detail="Datos incompletos")
    actualizar_ubicacion_delivery(delivery_id, user_id, lat, lng, radio_km)
    return {"ok": True}


# ── Blue Express ─────────────────────────────────────────────────────────────

@app.get("/blue-express/puntos")
def puntos_blue_express(comuna: str = "", limite: int = 5):
    """
    Devuelve hasta `limite` puntos de despacho Blue Express filtrados por comuna.
    """
    resultados = be_buscar_puntos(comuna, limite=min(limite, 10))
    return {"puntos": resultados, "total": len(resultados)}


# ── Ayuda / Soporte ───────────────────────────────────────────────────────────

import threading
import requests as _requests

def _notificar_n8n(ticket_id: int, user_id: int, tipo: str,
                   numero_referencia: str, detalle: str):
    """Llama al webhook de n8n en background (no bloquea la respuesta)."""
    webhook_url = os.environ.get("N8N_WEBHOOK_AYUDA", "")
    if not webhook_url:
        return
    try:
        _requests.post(webhook_url, json={
            "ticket_id":         ticket_id,
            "user_id":           user_id,
            "tipo":              tipo,
            "numero_referencia": numero_referencia,
            "detalle":           detalle,
        }, timeout=8)
    except Exception:
        pass  # no interrumpir si n8n no responde


@app.post("/ayuda")
def crear_ticket_ayuda(body: dict):
    user_id           = body.get("user_id")
    tipo              = body.get("tipo", "otros")
    numero_referencia = body.get("numero_referencia", "")
    detalle           = body.get("detalle", "")

    if not user_id or not detalle:
        raise HTTPException(status_code=400, detail="Faltan campos obligatorios")

    resultado = crear_ticket(user_id, tipo, numero_referencia, detalle)

    # Notificar a n8n en hilo aparte
    threading.Thread(
        target=_notificar_n8n,
        args=(resultado["id"], user_id, tipo, numero_referencia, detalle),
        daemon=True,
    ).start()

    return {"ok": True, "ticket_id": resultado["id"], "estado": resultado["estado"]}


@app.post("/ayuda/chat_directo")
def chat_directo_ayuda(body: dict):
    """Abre un chat directo con soporte, sin formulario previo."""
    user_id = body.get("user_id")
    if not user_id:
        raise HTTPException(status_code=400, detail="user_id requerido")

    resultado = crear_ticket_chat_directo(user_id)

    threading.Thread(
        target=_notificar_n8n,
        args=(resultado["id"], user_id, "chat_directo",
              resultado["caso_numero"], "Chat directo iniciado desde la app"),
        daemon=True,
    ).start()

    return {
        "ok":         True,
        "ticket_id":  resultado["id"],
        "caso_numero": resultado["caso_numero"],
        "estado":     resultado["estado"],
    }


@app.get("/ayuda/usuario/{user_id}")
def tickets_usuario(user_id: int):
    tickets = obtener_tickets_usuario(user_id)
    return {"tickets": tickets}


@app.get("/ayuda/{ticket_id}/mensajes")
def mensajes_ticket(ticket_id: int):
    ticket = obtener_ticket(ticket_id)
    if not ticket:
        raise HTTPException(status_code=404, detail="Ticket no encontrado")
    mensajes = obtener_mensajes_ticket(ticket_id)
    return {"ticket": ticket, "mensajes": mensajes}


@app.post("/ayuda/{ticket_id}/mensaje_usuario")
def mensaje_usuario(ticket_id: int, body: dict):
    """El usuario envía un follow-up desde la app."""
    mensaje = body.get("mensaje", "").strip()
    if not mensaje:
        raise HTTPException(status_code=400, detail="Mensaje vacío")
    ok = agregar_mensaje(ticket_id, mensaje, remitente="usuario")
    if not ok:
        raise HTTPException(status_code=404, detail="Ticket no encontrado")

    # Reenviar a n8n para que notifique al soporte
    ticket = obtener_ticket(ticket_id)
    webhook_url = os.environ.get("N8N_WEBHOOK_AYUDA", "")
    if webhook_url and ticket:
        threading.Thread(
            target=_notificar_n8n,
            args=(ticket_id, ticket["user_id"], ticket["tipo"],
                  ticket["numero_referencia"] or "", f"[FOLLOW-UP] {mensaje}"),
            daemon=True,
        ).start()

    return {"ok": True}


@app.post("/ayuda/{ticket_id}/respuesta")
def respuesta_soporte(ticket_id: int, body: dict, request: Request):
    """
    Llamado por n8n cuando el admin responde en Telegram.
    Protegido con header X-N8N-Secret.
    """
    secret = os.environ.get("N8N_SECRET", "")
    if secret and request.headers.get("X-N8N-Secret") != secret:
        raise HTTPException(status_code=401, detail="No autorizado")

    mensaje = body.get("mensaje", "").strip()
    if not mensaje:
        raise HTTPException(status_code=400, detail="Mensaje vacío")

    ok = agregar_mensaje(ticket_id, mensaje, remitente="soporte")
    if not ok:
        raise HTTPException(status_code=404, detail="Ticket no encontrado")

    # Notificación push al usuario (si tiene token FCM)
    ticket = obtener_ticket(ticket_id)
    if ticket:
        fcm_tok = obtener_fcm_token(ticket["user_id"])
        if fcm_tok:
            try:
                enviar_push(fcm_tok, "💬 Respuesta de soporte OkVenta",
                            mensaje[:120],
                            {"tipo": "ayuda_respuesta",
                             "ticket_id": str(ticket_id)})
            except Exception:
                pass

    return {"ok": True}


@app.patch("/ayuda/{ticket_id}/cerrar")
def cerrar_ticket_endpoint(ticket_id: int, body: dict):
    user_id = body.get("user_id")
    ticket  = obtener_ticket(ticket_id)
    if not ticket:
        raise HTTPException(status_code=404, detail="Ticket no encontrado")
    if user_id and ticket["user_id"] != user_id:
        raise HTTPException(status_code=403, detail="No autorizado")
    cerrar_ticket(ticket_id)
    return {"ok": True}


# ==============================================================================
# PAGOS — MercadoPago
# ==============================================================================

# ── Crear preferencia (los 3 flujos) ─────────────────────────────────────────

@app.post("/pagos/crear-preferencia")
def crear_preferencia_endpoint(body: dict):
    """
    Crea una orden en nuestra DB y una preferencia en MP.
    Body:
      comprador_id, vendedor_id, tipo ('producto'|'servicio'),
      titulo, monto, comprador_email,
      publicacion_id? (producto), servicio_id? (servicio),
      imagen_url?
    """
    comprador_id  = body.get("comprador_id")
    vendedor_id   = body.get("vendedor_id")
    tipo          = body.get("tipo", "producto")
    titulo        = body.get("titulo", "Producto OkVenta")
    monto         = float(body.get("monto", 0))
    email         = body.get("comprador_email", "")
    pub_id        = body.get("publicacion_id")
    srv_id        = body.get("servicio_id")
    imagen_url    = body.get("imagen_url", "")

    if not comprador_id or not vendedor_id or monto <= 0:
        raise HTTPException(status_code=400, detail="Datos incompletos")

    from services.mp_service import _comision_pct
    comision = round(monto * _comision_pct() / 100, 2)

    # 1. Crear orden en nuestra DB
    orden_id = crear_orden(
        comprador_id=comprador_id,
        vendedor_id=vendedor_id,
        tipo=tipo,
        titulo=titulo,
        monto=monto,
        publicacion_id=pub_id,
        servicio_id=srv_id,
        comision=comision,
    )

    # 2. Crear preferencia en MP
    try:
        mp = mp_crear_preferencia(
            orden_id=orden_id,
            titulo=titulo,
            monto=monto,
            comprador_email=email,
            imagen_url=imagen_url,
        )
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Error MP: {e}")

    # 3. Guardar preference_id
    guardar_preference(orden_id, mp["preference_id"])

    return {
        "orden_id":           orden_id,
        "preference_id":      mp["preference_id"],
        "init_point":         mp["init_point"],
        "sandbox_init_point": mp["sandbox_init_point"],
    }


# ── Webhook de MercadoPago ────────────────────────────────────────────────────

@app.post("/pagos/webhook")
async def mp_webhook(request: Request):
    """
    MP envía notificaciones de pago aquí.
    Actualizamos el estado de la orden y notificamos al vendedor.
    """
    try:
        data = await request.json()
    except Exception:
        return {"ok": True}  # devolver 200 siempre para que MP no reintente

    # MP puede enviar topic=payment o type=payment
    topic = data.get("topic") or data.get("type", "")
    if topic not in ("payment", "merchant_order"):
        return {"ok": True}

    payment_id = None
    if "data" in data and isinstance(data["data"], dict):
        payment_id = str(data["data"].get("id", ""))
    elif "id" in data:
        payment_id = str(data["id"])

    if not payment_id:
        return {"ok": True}

    try:
        pago = mp_obtener_pago(payment_id)
    except Exception:
        return {"ok": True}

    status          = pago.get("status", "")
    external_ref    = pago.get("external_reference", "")

    if not external_ref:
        return {"ok": True}

    orden = obtener_por_external_ref(external_ref)
    if not orden:
        return {"ok": True}

    orden_id = orden["id"]

    if status == "approved":
        confirmar_pago(orden_id, payment_id)
        # Obtener ubicación del comprador para informar al vendedor
        comprador = obtener_usuario_por_id(orden["comprador_id"])
        ubicacion_str = ""
        if comprador:
            ciudad = comprador.get("ciudad") or comprador.get("comuna") or ""
            if ciudad:
                ubicacion_str = ciudad
        push_body = (
            f"Tu comprador está en {ubicacion_str}. "
            f"¿Cómo entregas '{orden['titulo']}'?"
            if ubicacion_str else
            f"Elige cómo entregarás '{orden['titulo']}'"
        )
        # Notificar al vendedor con acción de elegir entrega
        fcm_tok = obtener_fcm_token(orden["vendedor_id"])
        if fcm_tok:
            try:
                enviar_push(
                    fcm_tok,
                    "📦 ¡Tienes una venta!",
                    push_body,
                    {
                        "tipo":               "elegir_entrega",
                        "orden_id":           str(orden_id),
                        "titulo":             orden["titulo"],
                        "comprador_ubicacion": ubicacion_str,
                        "monto":              str(orden["monto"]),
                    },
                )
            except Exception:
                pass
        crear_notificacion(
            orden["vendedor_id"], "pago",
            f"💳 Pago confirmado por '{orden['titulo']}'. Elige cómo entregar.",
        )

    return {"ok": True}


# ── Páginas de retorno (back_urls de MP) ─────────────────────────────────────

@app.get("/pagos/resultado")
def resultado_pago(estado: str = "aprobado", orden: int = 0):
    from fastapi.responses import HTMLResponse
    msgs = {
        "aprobado": ("✅ Pago aprobado", "Tu pago fue procesado exitosamente. Vuelve a la app OkVenta.", "#27ae60"),
        "pendiente": ("⏳ Pago pendiente", "Tu pago está siendo procesado. Te notificaremos cuando se confirme.", "#f39c12"),
        "fallido": ("❌ Pago rechazado", "Hubo un problema con tu pago. Intenta de nuevo en la app.", "#e74c3c"),
    }
    titulo, msg, color = msgs.get(estado, msgs["fallido"])
    return HTMLResponse(f"""
    <html><head><meta name='viewport' content='width=device-width,initial-scale=1'>
    <style>body{{font-family:sans-serif;text-align:center;padding:60px 20px;background:#f5f5f5}}
    .card{{background:white;border-radius:16px;padding:40px 24px;max-width:400px;margin:auto;box-shadow:0 4px 20px rgba(0,0,0,.08)}}
    h2{{color:{color}}}p{{color:#555}}a{{display:inline-block;margin-top:20px;padding:12px 24px;background:#00B4A0;color:white;border-radius:8px;text-decoration:none}}</style>
    </head><body><div class='card'><h2>{titulo}</h2><p>{msg}</p>
    <a href='okventa://mis-compras'>Volver a OkVenta</a></div></body></html>
    """)


# ── Mis compras / Mis ventas ──────────────────────────────────────────────────

@app.get("/mis-compras/{user_id}")
def mis_compras(user_id: int):
    return obtener_mis_compras(user_id)


@app.get("/mis-ventas/{user_id}")
def mis_ventas(user_id: int):
    return obtener_mis_ventas(user_id)


# ── Vendedor elige método de entrega ─────────────────────────────────────────

@app.patch("/ordenes/{orden_id}/entrega")
def elegir_entrega(orden_id: int, body: dict):
    method = body.get("delivery_method", "")
    if method not in ("yo", "okventa", "blueexpress"):
        raise HTTPException(status_code=400, detail="Método inválido")
    orden = obtener_orden(orden_id)
    if not orden:
        raise HTTPException(status_code=404, detail="Orden no encontrada")
    _guardar_delivery(orden_id, method)

    if method == "okventa":
        try:
            crear_y_notificar_entrega(orden, delivery_id_sugerido=body.get("delivery_id"))
        except Exception:
            traceback.print_exc()

    # Notificar al comprador
    fcm_tok = obtener_fcm_token(orden["comprador_id"])
    labels = {"yo": "el vendedor", "okventa": "OkVenta Delivery", "blueexpress": "Blue Express"}
    if fcm_tok:
        try:
            enviar_push(
                fcm_tok,
                "🚚 Tu pedido está en camino",
                f"'{orden['titulo']}' será entregado por {labels.get(method, method)}",
                {"tipo": "en_camino", "orden_id": str(orden_id)},
            )
        except Exception:
            pass
    crear_notificacion(
        orden["comprador_id"], "entrega",
        f"🚚 '{orden['titulo']}' será entregado por {labels.get(method, method)}",
    )
    return {"ok": True}


# ── Confirmar entrega ─────────────────────────────────────────────────────────

@app.post("/ordenes/{orden_id}/confirmar")
def confirmar_orden(orden_id: int, body: dict):
    orden = obtener_orden(orden_id)
    if not orden:
        raise HTTPException(status_code=404, detail="Orden no encontrada")
    if orden["estado"] not in ("pago_confirmado", "en_camino"):
        raise HTTPException(status_code=400,
                            detail=f"Estado actual '{orden['estado']}' no permite confirmar")
    confirmar_entrega(orden_id)
    # Notificar al vendedor que puede recibir el dinero
    fcm_tok = obtener_fcm_token(orden["vendedor_id"])
    if fcm_tok:
        try:
            enviar_push(
                fcm_tok,
                "🎉 Entrega confirmada",
                f"El comprador confirmó recepción de '{orden['titulo']}'",
                {"tipo": "entrega_confirmada", "orden_id": str(orden_id)},
            )
        except Exception:
            pass
    crear_notificacion(
        orden["vendedor_id"], "entrega",
        f"🎉 Entrega confirmada por '{orden['titulo']}'. El pago será liberado.",
    )
    return {"ok": True, "estado": "entregado"}


# ── Abrir disputa ─────────────────────────────────────────────────────────────

@app.post("/ordenes/{orden_id}/disputar")
def disputar_orden(orden_id: int, body: dict):
    motivo = body.get("motivo", "Sin descripción")
    orden = obtener_orden(orden_id)
    if not orden:
        raise HTTPException(status_code=404, detail="Orden no encontrada")
    if orden["estado"] not in ("pago_confirmado", "en_camino"):
        raise HTTPException(status_code=400,
                            detail=f"Estado '{orden['estado']}' no permite disputar")
    abrir_disputa(orden_id)
    # Notificar al equipo OkVenta (vendedor_id=1 es el admin por convención)
    crear_notificacion(
        1, "disputa",
        f"⚠️ Disputa en orden #{orden_id}: '{orden['titulo']}' — {motivo}",
    )
    # Notificar al vendedor
    fcm_tok = obtener_fcm_token(orden["vendedor_id"])
    if fcm_tok:
        try:
            enviar_push(
                fcm_tok,
                "⚠️ Disputa abierta",
                f"El comprador reportó un problema con '{orden['titulo']}'",
                {"tipo": "disputa", "orden_id": str(orden_id)},
            )
        except Exception:
            pass
    return {"ok": True, "estado": "en_disputa"}


# ── Reembolso (uso interno / admin) ──────────────────────────────────────────

@app.post("/admin/procesar-imagenes")
def admin_procesar_imagenes(token: str = ""):
    """Reprocesa todas las imágenes de uploads: fondo blanco + bounding box + canvas cuadrado."""
    import io as _io
    import numpy as _np
    from pathlib import Path as _Path
    from rembg import remove as _remove
    from PIL import Image as _Image

    SECRET = os.environ.get("ADMIN_TOKEN", "okventa-admin-2026")
    if token != SECRET:
        raise HTTPException(status_code=403, detail="Token inválido")

    uploads = _Path(UPLOADS_DIR)
    exts = {".png", ".jpg", ".jpeg", ".webp"}
    archivos = [p for p in uploads.iterdir() if p.suffix.lower() in exts and p.is_file()]

    def _margen(lado: int) -> float:
        if lado < 300: return 0.15
        if lado < 800: return 0.12
        if lado < 1500: return 0.10
        return 0.08

    ok = err = 0
    errores = []
    for archivo in archivos:
        try:
            img = _Image.open(archivo).convert("RGBA")
            buf = _io.BytesIO()
            img.save(buf, format="PNG")
            sin_fondo = _Image.open(_io.BytesIO(_remove(buf.getvalue()))).convert("RGBA")

            alpha = _np.array(sin_fondo)[:, :, 3]
            rows = _np.any(alpha > 10, axis=1)
            cols = _np.any(alpha > 10, axis=0)
            if not rows.any() or not cols.any():
                continue

            y1, y2 = int(_np.where(rows)[0][0]), int(_np.where(rows)[0][-1])
            x1, x2 = int(_np.where(cols)[0][0]), int(_np.where(cols)[0][-1])
            producto = sin_fondo.crop((x1, y1, x2 + 1, y2 + 1))
            w, h = producto.size

            lado_mayor = max(w, h)
            margen = int(lado_mayor * _margen(lado_mayor))
            lado = lado_mayor + 2 * margen
            canvas = _Image.new("RGB", (lado, lado), (255, 255, 255))
            canvas.paste(producto, ((lado - w) // 2, (lado - h) // 2), mask=producto.split()[3])
            canvas.save(str(archivo), format="JPEG", quality=92, optimize=True)
            ok += 1
        except Exception as e:
            err += 1
            errores.append(f"{archivo.name}: {e}")

    return {"ok": ok, "errores": err, "detalle_errores": errores}


@app.post("/ordenes/{orden_id}/reembolsar")
def reembolsar_orden(orden_id: int):
    orden = obtener_orden(orden_id)
    if not orden or not orden.get("mp_payment_id"):
        raise HTTPException(status_code=404,
                            detail="Orden no encontrada o sin pago registrado")
    try:
        mp_reembolsar_pago(orden["mp_payment_id"])
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Error MP refund: {e}")
    marcar_reembolsado(orden_id)
    return {"ok": True, "estado": "reembolsado"}
