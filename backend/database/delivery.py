import sqlite3
from config import PUBLICACIONES_DB as DB


def init_delivery_db():
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    c.execute("""
    CREATE TABLE IF NOT EXISTS delivery_perfiles (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id          INTEGER NOT NULL,
        nombre           TEXT    NOT NULL,
        edad             INTEGER,
        email            TEXT,
        rut              TEXT,
        telefono         TEXT,
        direccion        TEXT,
        tipo_vehiculo    TEXT,
        patente          TEXT,
        banco            TEXT,
        cuenta_banco     TEXT,
        foto_perfil      TEXT,
        foto_vehiculo    TEXT,
        foto_ci_frente   TEXT,
        foto_ci_reverso  TEXT,
        selfie_ci        TEXT,
        lat              REAL,
        lng              REAL,
        radio_km         REAL    DEFAULT 5,
        activo           INTEGER DEFAULT 1,
        acepto_terminos  INTEGER DEFAULT 0,
        created_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
    """)
    conn.commit()
    conn.close()


# ── Crear / actualizar ────────────────────────────────────────────────────────

def crear_perfil_delivery(
    user_id, nombre, edad, email, rut, telefono, direccion,
    tipo_vehiculo, patente, banco, cuenta_banco,
    foto_perfil=None, foto_vehiculo=None,
    foto_ci_frente=None, foto_ci_reverso=None, selfie_ci=None,
    lat=None, lng=None, radio_km=5.0,
):
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    # Si ya existe un perfil para este user_id, lo actualiza
    c.execute("SELECT id FROM delivery_perfiles WHERE user_id = ?", (user_id,))
    existing = c.fetchone()
    if existing:
        c.execute("""
            UPDATE delivery_perfiles
            SET nombre=?, edad=?, email=?, rut=?, telefono=?, direccion=?,
                tipo_vehiculo=?, patente=?, banco=?, cuenta_banco=?,
                foto_perfil=COALESCE(?, foto_perfil),
                foto_vehiculo=COALESCE(?, foto_vehiculo),
                foto_ci_frente=COALESCE(?, foto_ci_frente),
                foto_ci_reverso=COALESCE(?, foto_ci_reverso),
                selfie_ci=COALESCE(?, selfie_ci),
                lat=COALESCE(?, lat), lng=COALESCE(?, lng),
                radio_km=?, acepto_terminos=1
            WHERE user_id=?
        """, (nombre, edad, email, rut, telefono, direccion,
              tipo_vehiculo, patente, banco, cuenta_banco,
              foto_perfil, foto_vehiculo, foto_ci_frente, foto_ci_reverso, selfie_ci,
              lat, lng, radio_km, user_id))
        did = existing[0]
    else:
        c.execute("""
            INSERT INTO delivery_perfiles
                (user_id, nombre, edad, email, rut, telefono, direccion,
                 tipo_vehiculo, patente, banco, cuenta_banco,
                 foto_perfil, foto_vehiculo, foto_ci_frente, foto_ci_reverso, selfie_ci,
                 lat, lng, radio_km, activo, acepto_terminos)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, 1)
        """, (user_id, nombre, edad, email, rut, telefono, direccion,
              tipo_vehiculo, patente, banco, cuenta_banco,
              foto_perfil, foto_vehiculo, foto_ci_frente, foto_ci_reverso, selfie_ci,
              lat, lng, radio_km))
        did = c.lastrowid
    conn.commit()
    conn.close()
    return did


def actualizar_estado_delivery(delivery_id, user_id, activo: bool):
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    c.execute(
        "UPDATE delivery_perfiles SET activo = ? WHERE id = ? AND user_id = ?",
        (1 if activo else 0, delivery_id, user_id),
    )
    conn.commit()
    conn.close()


def actualizar_ubicacion_delivery(delivery_id, user_id, lat, lng, radio_km):
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    c.execute(
        "UPDATE delivery_perfiles SET lat=?, lng=?, radio_km=? WHERE id=? AND user_id=?",
        (lat, lng, radio_km, delivery_id, user_id),
    )
    conn.commit()
    conn.close()


# ── Leer ──────────────────────────────────────────────────────────────────────

_COLS = [
    "id", "user_id", "nombre", "edad", "email", "rut", "telefono", "direccion",
    "tipo_vehiculo", "patente", "banco", "cuenta_banco",
    "foto_perfil", "foto_vehiculo", "foto_ci_frente", "foto_ci_reverso", "selfie_ci",
    "lat", "lng", "radio_km", "activo", "acepto_terminos", "created_at",
]


def _to_dict(row):
    if not row:
        return None
    return dict(zip(_COLS, row))


def obtener_perfiles_delivery(solo_activos=True):
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    q = "SELECT " + ", ".join(_COLS) + " FROM delivery_perfiles"
    if solo_activos:
        q += " WHERE activo = 1"
    q += " ORDER BY created_at DESC"
    c.execute(q)
    rows = c.fetchall()
    conn.close()
    return [_to_dict(r) for r in rows]


def obtener_perfil_delivery_usuario(user_id):
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    c.execute(
        "SELECT " + ", ".join(_COLS) +
        " FROM delivery_perfiles WHERE user_id = ? ORDER BY created_at DESC LIMIT 1",
        (user_id,),
    )
    row = c.fetchone()
    conn.close()
    return _to_dict(row)


def obtener_perfil_delivery_por_id(delivery_id):
    conn = sqlite3.connect(DB)
    c = conn.cursor()
    c.execute(
        "SELECT " + ", ".join(_COLS) +
        " FROM delivery_perfiles WHERE id = ?",
        (delivery_id,),
    )
    row = c.fetchone()
    conn.close()
    return _to_dict(row)
