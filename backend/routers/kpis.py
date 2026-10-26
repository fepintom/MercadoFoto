"""
routers/kpis.py
===============
Indicadores de OkVenta para el backoffice y para Tableau.

1. Tráfico de la app (lo envía la app, sin datos personales):
     POST /eventos   {"evento": "app_abierta", "visitante": "<id del
                      dispositivo>", "user_id": 12, "plataforma": "ios",
                      "version": "1.0.0+267", "detalle": "Encontrar"}
   Eventos: app_abierta, pestana (cambio de pestaña), busqueda, ...

2. Lectura (token = ADMIN_TOKEN):
     GET /admin/kpi/resumen?token=...            foto del día (JSON)
     GET /admin/kpi/diario.csv?token=...&dias=180
         una fila por día: usuarios nuevos, activos, aperturas, órdenes,
         GMV, publicaciones, servicios, verificaciones enviadas/aprobadas…
     GET /admin/export/{tabla}.csv?token=...
         tablas para cruzar en Tableau, SIN datos sensibles (contraseñas,
         tokens, documentos). Tablas: usuarios, ordenes, publicaciones,
         servicios, verificaciones_comercio, eventos, reviews, cotizaciones.

Cómo conectarlo a Tableau: las URLs .csv se pueden leer con la conexión
"Web Data Connector"/"Texto" o, lo más simple y con actualización
automática, importándolas en Google Sheets (=IMPORTDATA(url)) y conectando
Tableau a esa hoja.
"""
import csv
import io
import os
import sqlite3
from datetime import date, timedelta
from typing import Optional

from fastapi import APIRouter, HTTPException
from fastapi.responses import Response
from pydantic import BaseModel

from config import PUBLICACIONES_DB as DB

router = APIRouter()


def _token_ok(token: Optional[str]) -> bool:
    return token == os.environ.get("ADMIN_TOKEN", "okventa-admin-2026")


def _conn():
    c = sqlite3.connect(DB)
    c.row_factory = sqlite3.Row
    return c


def init_kpis_db():
    c = sqlite3.connect(DB)
    c.execute("""
        CREATE TABLE IF NOT EXISTS eventos_app (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            evento      TEXT NOT NULL,
            visitante   TEXT,
            user_id     INTEGER,
            plataforma  TEXT,
            version     TEXT,
            detalle     TEXT,
            dia         TEXT NOT NULL DEFAULT (date('now')),
            created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)
    c.execute("CREATE INDEX IF NOT EXISTS idx_eventos_dia ON eventos_app(dia)")
    c.execute("CREATE INDEX IF NOT EXISTS idx_eventos_evento "
              "ON eventos_app(evento, dia)")
    c.commit()
    c.close()


# ── Registro de eventos ──────────────────────────────────────────────────────

class Evento(BaseModel):
    evento: str
    visitante: Optional[str] = None
    user_id: Optional[int] = None
    plataforma: Optional[str] = None
    version: Optional[str] = None
    detalle: Optional[str] = None


@router.post("/eventos")
def registrar_evento(e: Evento):
    nombre = (e.evento or "").strip()[:40]
    if not nombre:
        raise HTTPException(400, "Falta el evento")
    c = sqlite3.connect(DB)
    try:
        c.execute("INSERT INTO eventos_app (evento, visitante, user_id, "
                  "plataforma, version, detalle) VALUES (?,?,?,?,?,?)",
                  (nombre, (e.visitante or "")[:64] or None, e.user_id,
                   (e.plataforma or "")[:12] or None,
                   (e.version or "")[:24] or None,
                   (e.detalle or "")[:80] or None))
        c.commit()
    finally:
        c.close()
    return {"ok": True}


# ── Helpers ──────────────────────────────────────────────────────────────────

def _uno(c, sql: str, args=()) -> float:
    try:
        r = c.execute(sql, args).fetchone()
        return (r[0] or 0) if r else 0
    except sqlite3.OperationalError:
        return 0


def _por_dia(c, sql: str, args=()) -> dict:
    """sql debe devolver (dia, valor)."""
    try:
        return {str(r[0]): r[1] or 0 for r in c.execute(sql, args)}
    except sqlite3.OperationalError:
        return {}


def _csv(filas: list, columnas: list, nombre: str) -> Response:
    buf = io.StringIO()
    w = csv.writer(buf)
    w.writerow(columnas)
    for f in filas:
        w.writerow([f.get(k) if isinstance(f, dict) else f[k] for k in columnas])
    return Response(
        content=buf.getvalue().encode("utf-8-sig"),  # BOM: tildes en Excel
        media_type="text/csv; charset=utf-8",
        headers={"Content-Disposition": f'inline; filename="{nombre}"',
                 "Cache-Control": "no-store"})


_NO_TEST = "COALESCE(es_test,0)=0"


# ── Resumen ──────────────────────────────────────────────────────────────────

@router.get("/admin/kpi/resumen")
def kpi_resumen(token: str):
    if not _token_ok(token):
        raise HTTPException(403, "Token inválido")
    c = _conn()
    try:
        hoy = date.today().isoformat()
        d7 = (date.today() - timedelta(days=6)).isoformat()
        d30 = (date.today() - timedelta(days=29)).isoformat()

        def activos(desde: str) -> int:
            return int(_uno(c, "SELECT COUNT(DISTINCT COALESCE(CAST(user_id AS "
                               "TEXT), visitante)) FROM eventos_app "
                               "WHERE dia >= ?", (desde,)))

        ordenes_estado = {}
        try:
            for r in c.execute(f"SELECT estado, COUNT(*), SUM(monto) FROM ordenes "
                               f"WHERE {_NO_TEST} GROUP BY estado"):
                ordenes_estado[r[0]] = {"cantidad": r[1], "monto": r[2] or 0}
        except sqlite3.OperationalError:
            pass

        verif = {}
        try:
            for r in c.execute("SELECT estado, COUNT(*) FROM "
                               "verificaciones_comercio GROUP BY estado"):
                verif[r[0]] = r[1]
        except sqlite3.OperationalError:
            pass

        return {
            "fecha": hoy,
            "usuarios": {
                "total": int(_uno(c, "SELECT COUNT(*) FROM users")),
                "nuevos_hoy": int(_uno(c, "SELECT COUNT(*) FROM users WHERE "
                                          "date(created_at) = ?", (hoy,))),
                "nuevos_7d": int(_uno(c, "SELECT COUNT(*) FROM users WHERE "
                                         "date(created_at) >= ?", (d7,))),
                "nuevos_30d": int(_uno(c, "SELECT COUNT(*) FROM users WHERE "
                                          "date(created_at) >= ?", (d30,))),
                "con_giro": int(_uno(c, "SELECT COUNT(*) FROM users WHERE "
                                        "tiene_giro = 1")),
                "comercios_verificados": int(_uno(
                    c, "SELECT COUNT(*) FROM users WHERE comercio_verificado = 1")),
            },
            "trafico": {
                "activos_hoy": activos(hoy),
                "activos_7d": activos(d7),
                "activos_30d": activos(d30),
                "aperturas_hoy": int(_uno(c, "SELECT COUNT(*) FROM eventos_app "
                                             "WHERE evento='app_abierta' AND "
                                             "dia = ?", (hoy,))),
                "aperturas_7d": int(_uno(c, "SELECT COUNT(*) FROM eventos_app "
                                            "WHERE evento='app_abierta' AND "
                                            "dia >= ?", (d7,))),
                "vistas_items_7d": int(_uno(c, "SELECT COUNT(*) FROM vistas_items "
                                               "WHERE dia >= ?", (d7,))),
            },
            "catalogo": {
                "publicaciones_disponibles": int(_uno(
                    c, "SELECT COUNT(*) FROM publicaciones WHERE "
                       "COALESCE(estado,'disponible')='disponible'")),
                "publicaciones_nuevas_7d": int(_uno(
                    c, "SELECT COUNT(*) FROM publicaciones WHERE "
                       "date(created_at) >= ?", (d7,))),
                "servicios": int(_uno(c, "SELECT COUNT(*) FROM servicios")),
            },
            "ventas": {
                "ordenes_por_estado": ordenes_estado,
                "gmv_30d": _uno(c, f"SELECT SUM(monto) FROM ordenes WHERE "
                                   f"{_NO_TEST} AND estado IN ('pago_confirmado',"
                                   f"'en_camino','entregado') AND "
                                   f"date(created_at) >= ?", (d30,)),
                "comision_30d": _uno(c, f"SELECT SUM(comision_okventa) FROM "
                                        f"ordenes WHERE {_NO_TEST} AND estado IN "
                                        f"('pago_confirmado','en_camino',"
                                        f"'entregado') AND date(created_at) >= ?",
                                     (d30,)),
            },
            "verificacion_comercios": verif,
        }
    finally:
        c.close()


# ── Serie diaria (para gráficos en Tableau) ─────────────────────────────────

_COLS_DIARIO = [
    "dia", "usuarios_nuevos", "usuarios_activos", "aperturas_app",
    "publicaciones_nuevas", "servicios_nuevos", "ordenes_creadas",
    "ordenes_pagadas", "gmv", "comision", "vistas_items",
    "mensajes_comunidad", "verificaciones_enviadas", "verificaciones_aprobadas",
]


@router.get("/admin/kpi/diario.csv")
def kpi_diario(token: str, dias: int = 180):
    if not _token_ok(token):
        raise HTTPException(403, "Token inválido")
    dias = max(1, min(dias, 1095))
    desde = (date.today() - timedelta(days=dias - 1)).isoformat()
    c = _conn()
    try:
        series = {
            "usuarios_nuevos": _por_dia(c, "SELECT date(created_at), COUNT(*) FROM "
                                           "users WHERE date(created_at) >= ? "
                                           "GROUP BY 1", (desde,)),
            "usuarios_activos": _por_dia(c, "SELECT dia, COUNT(DISTINCT COALESCE("
                                            "CAST(user_id AS TEXT), visitante)) "
                                            "FROM eventos_app WHERE dia >= ? "
                                            "GROUP BY 1", (desde,)),
            "aperturas_app": _por_dia(c, "SELECT dia, COUNT(*) FROM eventos_app "
                                         "WHERE evento='app_abierta' AND dia >= ? "
                                         "GROUP BY 1", (desde,)),
            "publicaciones_nuevas": _por_dia(c, "SELECT date(created_at), COUNT(*) "
                                                "FROM publicaciones WHERE "
                                                "date(created_at) >= ? GROUP BY 1",
                                             (desde,)),
            "servicios_nuevos": _por_dia(c, "SELECT date(created_at), COUNT(*) FROM "
                                            "servicios WHERE date(created_at) >= ? "
                                            "GROUP BY 1", (desde,)),
            "ordenes_creadas": _por_dia(c, f"SELECT date(created_at), COUNT(*) FROM "
                                           f"ordenes WHERE {_NO_TEST} AND "
                                           f"date(created_at) >= ? GROUP BY 1",
                                        (desde,)),
            "ordenes_pagadas": _por_dia(c, f"SELECT date(created_at), COUNT(*) FROM "
                                           f"ordenes WHERE {_NO_TEST} AND estado IN "
                                           f"('pago_confirmado','en_camino',"
                                           f"'entregado') AND date(created_at) >= ? "
                                           f"GROUP BY 1", (desde,)),
            "gmv": _por_dia(c, f"SELECT date(created_at), SUM(monto) FROM ordenes "
                               f"WHERE {_NO_TEST} AND estado IN ('pago_confirmado',"
                               f"'en_camino','entregado') AND date(created_at) >= ?"
                               f" GROUP BY 1", (desde,)),
            "comision": _por_dia(c, f"SELECT date(created_at), SUM(comision_okventa)"
                                    f" FROM ordenes WHERE {_NO_TEST} AND estado IN "
                                    f"('pago_confirmado','en_camino','entregado') "
                                    f"AND date(created_at) >= ? GROUP BY 1",
                                 (desde,)),
            "vistas_items": _por_dia(c, "SELECT dia, COUNT(*) FROM vistas_items "
                                        "WHERE dia >= ? GROUP BY 1", (desde,)),
            "mensajes_comunidad": _por_dia(c, "SELECT date(created_at), COUNT(*) "
                                              "FROM comunidad_mensajes WHERE "
                                              "date(created_at) >= ? AND "
                                              "COALESCE(es_bot,0)=0 GROUP BY 1",
                                           (desde,)),
            "verificaciones_enviadas": _por_dia(
                c, "SELECT date(created_at), COUNT(*) FROM verificaciones_comercio "
                   "WHERE date(created_at) >= ? GROUP BY 1", (desde,)),
            "verificaciones_aprobadas": _por_dia(
                c, "SELECT date(revisado_en), COUNT(*) FROM verificaciones_comercio "
                   "WHERE estado='aprobada' AND date(revisado_en) >= ? GROUP BY 1",
                (desde,)),
        }
    finally:
        c.close()
    filas = []
    d = date.today() - timedelta(days=dias - 1)
    while d <= date.today():
        k = d.isoformat()
        fila = {"dia": k}
        for col in _COLS_DIARIO[1:]:
            fila[col] = series[col].get(k, 0)
        filas.append(fila)
        d += timedelta(days=1)
    return _csv(filas, _COLS_DIARIO, "okventa_kpi_diario.csv")


# ── Exportación de tablas (sin datos sensibles) ─────────────────────────────

_EXPORTS = {
    "usuarios": ("users", [
        "id", "nombre", "comuna", "ciudad", "created_at", "tiene_giro",
        "comercio_verificado", "comercio_verificado_en", "nombre_comercial"]),
    "ordenes": ("ordenes", [
        "id", "comprador_id", "vendedor_id", "tipo", "publicacion_id",
        "servicio_id", "titulo", "monto", "comision_okventa", "estado",
        "delivery_method", "es_test", "created_at", "updated_at",
        "entrega_reportada_en", "mp_medio_pago"]),
    "publicaciones": ("publicaciones", [
        "id", "user_id", "titulo", "precio", "categoria", "subcategoria",
        "condicion", "estado", "created_at"]),
    "servicios": ("servicios", [
        "id", "user_id", "tipo", "titulo", "categoria", "valor", "modalidad",
        "certificado_verificado", "created_at"]),
    "verificaciones_comercio": ("verificaciones_comercio", [
        "id", "user_id", "nombre_comercial", "razon_social", "comuna",
        "estado", "motivo_rechazo", "revisado_por", "revisado_en",
        "created_at"]),
    "eventos": ("eventos_app", [
        "id", "evento", "visitante", "user_id", "plataforma", "version",
        "detalle", "dia", "created_at"]),
    "reviews": ("reviews", [
        "id", "vendedor_id", "comprador_id", "estrellas", "created_at"]),
    "cotizaciones": ("cotizaciones", [
        "id", "servicio_id", "proveedor_id", "cliente_id", "monto", "estado",
        "created_at"]),
    "vistas": ("vistas_items", ["tipo", "item_id", "dia"]),
}


@router.get("/admin/export/{nombre}.csv")
def exportar(nombre: str, token: str, limite: int = 200000):
    if not _token_ok(token):
        raise HTTPException(403, "Token inválido")
    if nombre not in _EXPORTS:
        raise HTTPException(404, "Tabla no disponible. Opciones: "
                                 + ", ".join(sorted(_EXPORTS)))
    tabla, columnas = _EXPORTS[nombre]
    c = _conn()
    try:
        try:
            existentes = {r[1] for r in c.execute(f"PRAGMA table_info({tabla})")}
        except sqlite3.OperationalError:
            existentes = set()
        cols = [x for x in columnas if x in existentes]
        if not cols:
            return _csv([], columnas, f"okventa_{nombre}.csv")
        filas = [dict(r) for r in c.execute(
            f"SELECT {', '.join(cols)} FROM {tabla} LIMIT ?",
            (max(1, min(limite, 1000000)),))]
    finally:
        c.close()
    return _csv(filas, cols, f"okventa_{nombre}.csv")
