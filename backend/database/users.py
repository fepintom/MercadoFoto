import sqlite3
import os
from config import PUBLICACIONES_DB as DB


# --------------------------------------------------
# INIT USERS TABLE
# --------------------------------------------------

def init_users_db():

    conn = sqlite3.connect(DB)
    cursor = conn.cursor()

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        rut TEXT UNIQUE,
        nombre TEXT,
        email TEXT UNIQUE,
        password TEXT,
        google_id TEXT,
        firebase_uid TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
    """)

    # Migraciones seguras para columnas nuevas
    for col in ["google_id TEXT", "firebase_uid TEXT", "lat REAL", "lng REAL", "direccion TEXT", "comuna TEXT", "ciudad TEXT", "apellido TEXT", "foto_url TEXT", "fcm_token TEXT"]:
        try:
            cursor.execute(f"ALTER TABLE users ADD COLUMN {col}")
        except Exception:
            pass

    # Tabla de tokens para reset de contraseña
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS password_reset_tokens (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        email TEXT NOT NULL,
        token TEXT UNIQUE NOT NULL,
        expires_at TIMESTAMP NOT NULL,
        used INTEGER DEFAULT 0,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
    """)

    conn.commit()
    conn.close()


# --------------------------------------------------
# FCM TOKENS (notificaciones push)
# --------------------------------------------------

def guardar_fcm_token(user_id: int, token: str):
    conn = sqlite3.connect(DB)
    cursor = conn.cursor()
    cursor.execute("UPDATE users SET fcm_token = ? WHERE id = ?", (token, user_id))
    conn.commit()
    conn.close()


def obtener_fcm_token(user_id: int) -> str | None:
    conn = sqlite3.connect(DB)
    cursor = conn.cursor()
    cursor.execute("SELECT fcm_token FROM users WHERE id = ?", (user_id,))
    row = cursor.fetchone()
    conn.close()
    return row[0] if row else None


# --------------------------------------------------
# RESET DE CONTRASEÑA
# --------------------------------------------------

def crear_reset_token(email: str, token: str):
    import datetime
    conn = sqlite3.connect(DB)
    cursor = conn.cursor()
    expires = datetime.datetime.utcnow() + datetime.timedelta(hours=1)
    cursor.execute("DELETE FROM password_reset_tokens WHERE email = ?", (email,))
    cursor.execute(
        "INSERT INTO password_reset_tokens (email, token, expires_at) VALUES (?, ?, ?)",
        (email, token, expires.isoformat())
    )
    conn.commit()
    conn.close()


def validar_reset_token(token: str):
    import datetime
    conn = sqlite3.connect(DB)
    cursor = conn.cursor()
    cursor.execute(
        "SELECT email, expires_at, used FROM password_reset_tokens WHERE token = ?",
        (token,)
    )
    row = cursor.fetchone()
    conn.close()
    if not row:
        return None
    email, expires_at, used = row
    if used:
        return None
    if datetime.datetime.utcnow() > datetime.datetime.fromisoformat(expires_at):
        return None
    return email


def usar_reset_token(token: str, nueva_password_hash: str):
    conn = sqlite3.connect(DB)
    cursor = conn.cursor()
    email = validar_reset_token(token)
    if not email:
        conn.close()
        return False
    cursor.execute("UPDATE users SET password = ? WHERE email = ?", (nueva_password_hash, email))
    cursor.execute("UPDATE password_reset_tokens SET used = 1 WHERE token = ?", (token,))
    conn.commit()
    conn.close()
    return True


# --------------------------------------------------
# NORMALIZAR RUT
# --------------------------------------------------

def normalizar_rut(rut):
    return rut.replace(".", "").replace("-", "").upper()


# --------------------------------------------------
# CREAR USUARIO (email/password — flujo legacy)
# --------------------------------------------------

def crear_usuario(rut, nombre, email, password):

    conn = sqlite3.connect(DB)
    cursor = conn.cursor()

    # Buscar si ya existe
    cursor.execute("SELECT id FROM users WHERE email = ?", (email,))
    existente = cursor.fetchone()

    if existente:
        conn.close()
        return existente[0]

    try:
        cursor.execute("""
            INSERT INTO users (rut, nombre, email, password)
            VALUES (?, ?, ?, ?)
        """, (rut, nombre, email, password))

        conn.commit()
        return cursor.lastrowid

    except sqlite3.IntegrityError:
        raise ValueError("Error al crear usuario")

    finally:
        conn.close()


# --------------------------------------------------
# CREAR O RECUPERAR USUARIO VÍA FIREBASE
# --------------------------------------------------

def crear_o_obtener_usuario_firebase(
    firebase_uid: str,
    email: str,
    nombre: str,
    apellido: str = "",
    foto_url: str = "",
) -> dict:
    """
    Busca usuario por firebase_uid. Si no existe, busca por email.
    Si tampoco existe, lo crea. Devuelve dict con id, nombre, apellido y foto_url.
    """
    conn = sqlite3.connect(DB)
    cursor = conn.cursor()

    try:
        # 1. Buscar por firebase_uid
        cursor.execute(
            "SELECT id, nombre, apellido, foto_url FROM users WHERE firebase_uid = ?",
            (firebase_uid,)
        )
        row = cursor.fetchone()
        if row:
            # Actualizar apellido y foto si vienen y no estaban
            if apellido or foto_url:
                cursor.execute(
                    "UPDATE users SET apellido = COALESCE(NULLIF(apellido,''), ?), foto_url = COALESCE(NULLIF(foto_url,''), ?) WHERE id = ?",
                    (apellido, foto_url, row[0])
                )
                conn.commit()
            return {"id": row[0], "nombre": row[1], "apellido": row[2] or apellido, "foto_url": row[3] or foto_url}

        # 2. Buscar por email (login previo con email/password)
        cursor.execute(
            "SELECT id, nombre, apellido, foto_url FROM users WHERE email = ?",
            (email,)
        )
        row = cursor.fetchone()
        if row:
            cursor.execute(
                "UPDATE users SET firebase_uid = ?, apellido = COALESCE(NULLIF(apellido,''), ?), foto_url = COALESCE(NULLIF(foto_url,''), ?) WHERE id = ?",
                (firebase_uid, apellido, foto_url, row[0])
            )
            conn.commit()
            return {"id": row[0], "nombre": row[1], "apellido": row[2] or apellido, "foto_url": row[3] or foto_url}

        # 3. Crear usuario nuevo
        cursor.execute("""
            INSERT INTO users (nombre, apellido, foto_url, email, firebase_uid)
            VALUES (?, ?, ?, ?, ?)
        """, (nombre, apellido, foto_url, email, firebase_uid))

        conn.commit()
        return {"id": cursor.lastrowid, "nombre": nombre, "apellido": apellido, "foto_url": foto_url}

    finally:
        conn.close()


# --------------------------------------------------
# OBTENER USUARIO POR FIREBASE UID
# --------------------------------------------------

def obtener_usuario_por_firebase_uid(firebase_uid: str):
    conn = sqlite3.connect(DB)
    cursor = conn.cursor()
    cursor.execute(
        "SELECT id, nombre, email FROM users WHERE firebase_uid = ?",
        (firebase_uid,)
    )
    row = cursor.fetchone()
    conn.close()
    if not row:
        return None
    return {"id": row[0], "nombre": row[1], "email": row[2]}


# --------------------------------------------------
# OBTENER USUARIO POR EMAIL
# --------------------------------------------------

def obtener_usuario_por_email(email):

    conn = sqlite3.connect(DB)
    cursor = conn.cursor()

    cursor.execute("""
        SELECT id, nombre, email, password
        FROM users
        WHERE email = ?
    """, (email,))

    row = cursor.fetchone()
    conn.close()

    if not row:
        return None

    return {
        "id": row[0],
        "nombre": row[1],
        "email": row[2],
        "password": row[3]
    }


# --------------------------------------------------
# OBTENER USUARIO POR ID
# --------------------------------------------------

def obtener_usuario_por_id(user_id):

    conn = sqlite3.connect(DB)
    cursor = conn.cursor()

    cursor.execute("""
        SELECT id, nombre, email
        FROM users
        WHERE id = ?
    """, (user_id,))

    row = cursor.fetchone()
    conn.close()

    if not row:
        return None

    return {
        "id": row[0],
        "nombre": row[1],
        "email": row[2]
    }


# --------------------------------------------------
# ACTUALIZAR UBICACIÓN USUARIO
# --------------------------------------------------

def actualizar_ubicacion_usuario(user_id, lat, lng, direccion=None, comuna=None, ciudad=None):

    conn = sqlite3.connect(DB)
    cursor = conn.cursor()

    cursor.execute("""
        UPDATE users
        SET lat = ?, lng = ?, direccion = ?, comuna = ?, ciudad = ?
        WHERE id = ?
    """, (lat, lng, direccion, comuna, ciudad, user_id))

    conn.commit()
    conn.close()


# --------------------------------------------------
# OBTENER UBICACIÓN USUARIO
# --------------------------------------------------

def obtener_ubicacion_usuario(user_id):

    conn = sqlite3.connect(DB)
    cursor = conn.cursor()

    cursor.execute("""
        SELECT lat, lng, direccion, comuna, ciudad
        FROM users WHERE id = ?
    """, (user_id,))

    row = cursor.fetchone()
    conn.close()

    if not row:
        return None

    return {
        "lat": row[0], "lng": row[1],
        "direccion": row[2], "comuna": row[3], "ciudad": row[4],
    }


# --------------------------------------------------
# ACTUALIZAR FOTO DE PERFIL
# --------------------------------------------------

def actualizar_foto_perfil(user_id: int, foto_url: str):
    conn = sqlite3.connect(DB)
    cursor = conn.cursor()
    cursor.execute("UPDATE users SET foto_url = ? WHERE id = ?", (foto_url, user_id))
    conn.commit()
    conn.close()
