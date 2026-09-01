import sqlite3
import os
from config import PUBLICACIONES_DB as DB


def init_chat_db():

    conn = sqlite3.connect(DB)
    cursor = conn.cursor()

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS chat (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        publicacion_id INTEGER,
        remitente_id INTEGER,
        mensaje TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
    """)

    # Migración: columna para imágenes en chat
    try:
        cursor.execute("ALTER TABLE chat ADD COLUMN imagen_url TEXT")
    except Exception:
        pass

    # Migración: videos en chat (se eliminan automáticamente a las 48h,
    # ver limpiar_videos_expirados()).
    for col in ["video_url TEXT", "video_expira_en TIMESTAMP"]:
        try:
            cursor.execute(f"ALTER TABLE chat ADD COLUMN {col}")
        except Exception:
            pass

    # Migración: el chat nació atado a una publicación. Ahora también sirve
    # para servicios, así que un mensaje pertenece a UNA de las dos cosas:
    # publicacion_id o servicio_id (la otra queda en NULL).
    #
    # `tipo` reemplaza al truco de detectar mensajes especiales por el emoji
    # con el que empiezan ('💰 Oferta:'). Los valores son:
    #   texto | imagen | video | cotizacion
    # `cotizacion_id` apunta a la fila de `cotizaciones` cuando tipo =
    # 'cotizacion', para poder pintar la tarjeta con aceptar/rechazar.
    # `cliente_id` identifica CON QUIÉN conversa el proveedor. Sin esto todos
    # los clientes de un mismo servicio caían en un solo hilo compartido: se
    # veían los mensajes entre ellos y el proveedor no podía cotizarle a una
    # persona en concreto.
    for col in ["servicio_id INTEGER",
                "cliente_id INTEGER",
                "tipo TEXT DEFAULT 'texto'",
                "cotizacion_id INTEGER"]:
        try:
            cursor.execute(f"ALTER TABLE chat ADD COLUMN {col}")
        except Exception:
            pass

    conn.commit()
    conn.close()



def guardar_mensaje(publicacion_id, remitente_id, mensaje, imagen_url=None,
                    video_url=None, video_expira_en=None,
                    servicio_id=None, cliente_id=None, tipo=None,
                    cotizacion_id=None):
    """Guarda un mensaje. Va atado a una publicación O a un servicio.

    Devuelve el id del mensaje creado."""
    if tipo is None:
        tipo = ("video" if video_url else
                "imagen" if imagen_url else
                "cotizacion" if cotizacion_id else "texto")

    conn = sqlite3.connect(DB)
    cursor = conn.cursor()

    cursor.execute("""
        INSERT INTO chat (
            publicacion_id,
            servicio_id,
            cliente_id,
            remitente_id,
            mensaje,
            imagen_url,
            video_url,
            video_expira_en,
            tipo,
            cotizacion_id
        )
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    """, (
        publicacion_id,
        servicio_id,
        cliente_id,
        remitente_id,
        mensaje,
        imagen_url,
        video_url,
        video_expira_en,
        tipo,
        cotizacion_id,
    ))

    mensaje_id = cursor.lastrowid
    conn.commit()
    conn.close()
    return mensaje_id



def obtener_conversaciones(user_id: int):
    """Retorna todas las conversaciones donde el usuario es comprador o vendedor."""
    conn = sqlite3.connect(DB)
    cursor = conn.cursor()
    cursor.execute("""
        SELECT
            p.id            AS publicacion_id,
            p.titulo,
            p.imagen_url,
            p.user_id       AS vendedor_id,
            uv.nombre       AS nombre_vendedor,
            uv.foto_url     AS foto_vendedor,
            uc.id           AS comprador_id,
            uc.nombre       AS nombre_comprador,
            uc.foto_url     AS foto_comprador,
            MAX(c.created_at) AS ultimo_at,
            (SELECT mensaje FROM chat
             WHERE publicacion_id = p.id
             ORDER BY id DESC LIMIT 1) AS ultimo_mensaje
        FROM chat c
        JOIN publicaciones p ON c.publicacion_id = p.id
        JOIN users uv ON p.user_id = uv.id
        JOIN users uc ON c.remitente_id = uc.id AND uc.id != p.user_id
        WHERE c.remitente_id = ? OR p.user_id = ?
        GROUP BY p.id
        ORDER BY ultimo_at DESC
    """, (user_id, user_id))
    rows = cursor.fetchall()
    conn.close()

    result = []
    for r in rows:
        result.append({
            "publicacion_id":   r[0],
            "titulo":           r[1],
            "imagen_url":       r[2],
            "vendedor_id":      r[3],
            "nombre_vendedor":  r[4],
            "foto_vendedor":    r[5],
            "comprador_id":     r[6],
            "nombre_comprador": r[7],
            "foto_comprador":   r[8],
            "ultimo_at":        r[9],
            "ultimo_mensaje":   r[10],
        })
    return result


def obtener_chat(publicacion_id=None, servicio_id=None, cliente_id=None):
    """Mensajes de un hilo.

    Producto: se pasa publicacion_id.
    Servicio: se pasan servicio_id Y cliente_id — el hilo es el par, para que
    cada cliente tenga su propia conversación con el proveedor.
    """
    if publicacion_id is None and servicio_id is None:
        return []

    conn = sqlite3.connect(DB)
    cursor = conn.cursor()

    if servicio_id is not None:
        if cliente_id is not None:
            where, params = "servicio_id = ? AND cliente_id = ?", (servicio_id, cliente_id)
        else:
            # Sin cliente: se devuelve el servicio completo (uso interno).
            where, params = "servicio_id = ?", (servicio_id,)
    else:
        where, params = "publicacion_id = ?", (publicacion_id,)

    cursor.execute(f"""
        SELECT id, remitente_id, mensaje, created_at, imagen_url, video_url,
               COALESCE(tipo, 'texto'), cotizacion_id
        FROM chat
        WHERE {where}
        ORDER BY id ASC
    """, params)

    rows = cursor.fetchall()
    conn.close()

    return [{
        "id": r[0],
        "remitente": r[1],
        "mensaje": r[2],
        "fecha": r[3],
        "imagen_url": r[4],
        "video_url": r[5],
        "tipo": r[6],
        "cotizacion_id": r[7],
    } for r in rows]


def limpiar_videos_expirados():
    """Videos de chat con más de 48h: borra la referencia en la DB y
    devuelve las URLs para que quien llame elimine los archivos físicos
    (permanencia máxima de 48h para no acumular memoria)."""
    conn = sqlite3.connect(DB)
    cursor = conn.cursor()

    cursor.execute("""
        SELECT id, video_url FROM chat
        WHERE video_url IS NOT NULL
          AND video_expira_en IS NOT NULL
          AND video_expira_en <= datetime('now')
    """)
    rows = cursor.fetchall()

    urls = []
    for mensaje_id, video_url in rows:
        urls.append(video_url)
        cursor.execute("""
            UPDATE chat
            SET video_url = NULL,
                mensaje = '🎥 Video eliminado (48 h)'
            WHERE id = ?
        """, (mensaje_id,))

    conn.commit()
    conn.close()
    return urls

def obtener_conversaciones_servicio(user_id: int):
    """Hilos de servicios en los que participa el usuario, sea como
    proveedor o como cliente. Un hilo = (servicio_id, cliente_id).

    Devuelve las mismas claves que obtener_conversaciones para que la
    bandeja pueda mostrar ambos tipos en una sola lista, más `servicio_id`
    y `tipo_hilo` para saber qué pantalla abrir.
    """
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    c.execute("""
        SELECT s.id, s.titulo, s.fotos, s.user_id,
               COALESCE(up.nombre, 'Proveedor'),
               up.foto_url,
               ch.cliente_id,
               COALESCE(uc.nombre, 'Cliente'),
               uc.foto_url,
               MAX(ch.created_at),
               (SELECT mensaje FROM chat
                 WHERE servicio_id = ch.servicio_id
                   AND cliente_id = ch.cliente_id
                 ORDER BY id DESC LIMIT 1)
        FROM chat ch
        JOIN servicios s ON ch.servicio_id = s.id
        LEFT JOIN users up ON s.user_id = up.id
        LEFT JOIN users uc ON ch.cliente_id = uc.id
        WHERE ch.servicio_id IS NOT NULL
          AND ch.cliente_id IS NOT NULL
          AND (s.user_id = ? OR ch.cliente_id = ?)
        GROUP BY ch.servicio_id, ch.cliente_id
        ORDER BY MAX(ch.created_at) DESC
    """, (user_id, user_id))
    filas = c.fetchall()
    conn.close()

    resultado = []
    for r in filas:
        # `fotos` es un JSON de rutas; la bandeja solo necesita la primera.
        imagen = None
        try:
            import json as _json
            lista = _json.loads(r[2] or "[]")
            if lista:
                imagen = lista[0]
        except Exception:
            imagen = None
        resultado.append({
            "tipo_hilo":        "servicio",
            "servicio_id":      r[0],
            "publicacion_id":   None,
            "titulo":           r[1],
            "imagen_url":       imagen,
            "vendedor_id":      r[3],
            "nombre_vendedor":  r[4],
            "foto_vendedor":    r[5],
            "comprador_id":     r[6],
            "nombre_comprador": r[7],
            "foto_comprador":   r[8],
            "ultimo_at":        r[9],
            "ultimo_mensaje":   r[10],
        })
    return resultado
