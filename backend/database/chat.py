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

# ── Borrado ───────────────────────────────────────────────────────────────────

# Ventana en la que el autor puede arrepentirse. Pasada, el mensaje queda
# permanente: el chat es también la prueba de lo conversado si hay disputa,
# y si se pudiera borrar a cualquier hora esa prueba no valdría nada.
SEGUNDOS_PARA_BORRAR = 60


def eliminar_mensaje(mensaje_id: int, user_id: int):
    """Borra un mensaje propio dentro del plazo.

    Devuelve (ok, motivo, archivos). `archivos` son las URLs de imagen/video
    que quedaron huérfanas, para que quien llame borre el archivo físico.
    El plazo se calcula en SQLite y no en Python a propósito: created_at se
    escribe con CURRENT_TIMESTAMP (UTC del motor), así que comparar contra el
    reloj del proceso podía dar diferencias de horas según la zona del server.
    """
    conn = sqlite3.connect(DB)
    cursor = conn.cursor()
    cursor.execute("""
        SELECT remitente_id, imagen_url, video_url, tipo,
               (strftime('%s', 'now') - strftime('%s', created_at))
        FROM chat WHERE id = ?
    """, (mensaje_id,))
    row = cursor.fetchone()

    if not row:
        conn.close()
        return False, "no_existe", []

    remitente, imagen_url, video_url, tipo, antiguedad = row

    if remitente != user_id:
        conn.close()
        return False, "no_es_tuyo", []

    # Una cotización no se borra: tiene un PDF firmado y puede estar pagada.
    # Para deshacerla existe rechazar/anular, que deja rastro.
    if tipo == "cotizacion":
        conn.close()
        return False, "es_cotizacion", []

    if antiguedad is None or antiguedad > SEGUNDOS_PARA_BORRAR:
        conn.close()
        return False, "fuera_de_plazo", []

    cursor.execute("DELETE FROM chat WHERE id = ?", (mensaje_id,))
    conn.commit()
    conn.close()

    return True, "ok", [u for u in (imagen_url, video_url) if u]


def media_servicios_vencida(dias: int = 30):
    """Fotos y videos de chats de servicio con más de `dias`.

    Borra la referencia y devuelve las URLs para eliminar los archivos.
    Se salta los hilos con garantía reclamada: ahí las evidencias son
    justamente lo que hay que mirar para resolver la disputa.

    El texto de los mensajes NO se toca: ocupa casi nada y es el historial
    de lo acordado. Lo que pesa —y lo que se limpia— son los archivos.
    """
    conn = sqlite3.connect(DB)
    cursor = conn.cursor()

    # Servicios con alguna orden en disputa. Se consulta con tolerancia a
    # fallo porque `ordenes` vive en la misma DB pero podría no existir aún
    # en una instalación nueva, y esta limpieza no debe tumbar al worker.
    en_disputa = set()
    try:
        cursor.execute("""
            SELECT DISTINCT servicio_id FROM ordenes
            WHERE garantia_reclamada = 1 AND servicio_id IS NOT NULL
        """)
        en_disputa = {r[0] for r in cursor.fetchall()}
    except Exception:
        pass

    cursor.execute("""
        SELECT id, servicio_id, imagen_url, video_url FROM chat
        WHERE servicio_id IS NOT NULL
          AND (imagen_url IS NOT NULL OR video_url IS NOT NULL)
          AND created_at <= datetime('now', ?)
    """, (f"-{int(dias)} days",))
    rows = cursor.fetchall()

    urls = []
    for mensaje_id, servicio_id, imagen_url, video_url in rows:
        if servicio_id in en_disputa:
            continue
        urls.extend(u for u in (imagen_url, video_url) if u)
        cursor.execute("""
            UPDATE chat
            SET imagen_url = NULL,
                video_url = NULL,
                mensaje = ?
            WHERE id = ?
        """, (f"\U0001F5BC Archivo eliminado ({int(dias)} días)", mensaje_id))

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
