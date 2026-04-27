# backend/config.py
# ─────────────────────────────────────────────────────────────────
#  Centraliza rutas de datos (DBs + uploads) para que funcione
#  igual en local y en Render (disco persistente montado en /data).
#
#  Render setea automáticamente RENDER=true en el entorno.
# ─────────────────────────────────────────────────────────────────
import os

_ON_RENDER = os.environ.get("RENDER", "").lower() in ("true", "1")

if _ON_RENDER:
    # Disco persistente de Render montado en /data
    DATA_DIR = "/data"
else:
    # Local: directorio backend/ (donde está este archivo)
    DATA_DIR = os.path.dirname(os.path.abspath(__file__))

# ── Subdirectorios ────────────────────────────────────────────────
DB_DIR      = os.path.join(DATA_DIR, "database")
UPLOADS_DIR = os.path.join(DATA_DIR, "uploads")

# ── Archivos SQLite ───────────────────────────────────────────────
PUBLICACIONES_DB    = os.path.join(DB_DIR, "publicaciones.db")
ANALISIS_CACHE_DB   = os.path.join(DB_DIR, "analisis_cache.db")
GENERAL_CACHE_DB    = os.path.join(DB_DIR, "cache.db")

# ── Crear directorios si no existen (idempotente) ─────────────────
os.makedirs(DB_DIR, exist_ok=True)
os.makedirs(UPLOADS_DIR, exist_ok=True)
