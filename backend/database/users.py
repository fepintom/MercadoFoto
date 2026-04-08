import sqlite3
import os

# --------------------------------------------------
# DB PATH (UNIFICADO → publicaciones.db)
# --------------------------------------------------

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB = os.path.join(BASE_DIR, "database", "publicaciones.db")


# --------------------------------------------------
# INIT USERS TABLE (CORREGIDO → users)
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
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
    """)

    conn.commit()
    conn.close()


# --------------------------------------------------
# NORMALIZAR RUT
# --------------------------------------------------

def normalizar_rut(rut):
    return rut.replace(".", "").replace("-", "").upper()


# --------------------------------------------------
# CREAR USUARIO (REGISTRO INTELIGENTE)
# --------------------------------------------------

def crear_usuario(rut, nombre, email, password):

    conn = sqlite3.connect(DB)
    cursor = conn.cursor()

    # 🔥 1. BUSCAR SI YA EXISTE
    cursor.execute("""
        SELECT id, nombre, email
        FROM users
        WHERE email = ?
    """, (email,))

    existente = cursor.fetchone()

    if existente:
        conn.close()
        # 🔥 LOGIN AUTOMÁTICO
        return existente[0]

    # 🔥 2. CREAR NUEVO
    try:
        cursor.execute("""
            INSERT INTO users (rut, nombre, email, password)
            VALUES (?, ?, ?, ?)
        """, (rut, nombre, email, password))

        conn.commit()
        user_id = cursor.lastrowid

        return user_id

    except sqlite3.IntegrityError as e:
        raise ValueError("Error al crear usuario")

    finally:
        conn.close()


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