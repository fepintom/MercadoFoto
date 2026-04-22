import sqlite3
import os

# --------------------------------------------------
# DB PATH (UNIFICADO → publicaciones.db)
# --------------------------------------------------

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB = os.path.join(BASE_DIR, "database", "publicaciones.db")


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
    for col in ["google_id TEXT", "firebase_uid TEXT", "lat REAL", "lng REAL", "direccion TEXT", "comuna TEXT", "ciudad TEXT"]:
        try:
            cursor.execute(f"ALTER TABLE users ADD COLUMN {col}")
        except Exception:
            pass

    conn.commit()
    conn.close()


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

def crear_o_obtener_usuario_firebase(firebase_uid: str, email: str, nombre: str) -> dict:
    """
    Busca usuario por firebase_uid. Si no existe, busca por email.
    Si tampoco existe, lo crea. Devuelve dict con id y nombre.
    """
    conn = sqlite3.connect(DB)
    cursor = conn.cursor()

    try:
        # 1. Buscar por firebase_uid
        cursor.execute(
            "SELECT id, nombre FROM users WHERE firebase_uid = ?",
            (firebase_uid,)
        )
        row = cursor.fetchone()
        if row:
            return {"id": row[0], "nombre": row[1]}

        # 2. Buscar por email (login previo con email/password)
        cursor.execute(
            "SELECT id, nombre FROM users WHERE email = ?",
            (email,)
        )
        row = cursor.fetchone()
        if row:
            # Vincular firebase_uid al usuario existente
            cursor.execute(
                "UPDATE users SET firebase_uid = ? WHERE id = ?",
                (firebase_uid, row[0])
            )
            conn.commit()
            return {"id": row[0], "nombre": row[1]}

        # 3. Crear usuario nuevo
        cursor.execute("""
            INSERT INTO users (nombre, email, firebase_uid, rut)
            VALUES (?, ?, ?, ?)
        """, (nombre, email, firebase_uid, ""))

        conn.commit()
        return {"id": cursor.lastrowid, "nombre": nombre}

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
