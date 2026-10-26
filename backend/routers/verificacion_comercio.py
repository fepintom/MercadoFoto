"""
routers/verificacion_comercio.py
================================
Verificación de pymes y empresas ("Comercio verificado").

Flujo:
  1. Al crear el perfil (o desde Mi OkVenta) el usuario marca si vende con
     giro comercial:            PUT  /usuarios/{id}/giro {"tiene_giro": true}
  2. Si tiene giro, llena el formulario "Verificar mi comercio":
                                POST /comercio/verificacion (multipart)
       - Datos: RUT empresa, razón social, nombre comercial, dirección y
         ubicación (lat/lng).
       - Responsable: documento de identidad + certificado de vigencia de
         poderes (foto o PDF). PRIVADOS: se guardan fuera de /uploads y
         solo los ve el backoffice con el token de administración.
       - Fotos del local: fachada, letrero e interior (tomadas en la app).
         Son PÚBLICAS: se muestran en el perfil del comercio verificado.
  3. Estado para la app:        GET  /comercio/verificacion/{user_id}
  4. Backoffice (token = ADMIN_TOKEN):
       GET  /admin/comercio                    página para revisar (HTML)
       GET  /admin/comercio/verificaciones     lista JSON (?estado=)
       GET  /admin/comercio/archivo/{id}/{campo}   ver un documento
       POST /admin/comercio/verificaciones/{id}/aprobar
       POST /admin/comercio/verificaciones/{id}/rechazar  {"motivo": "..."}
     Al aprobar/rechazar se avisa al usuario (notificación + push).
  5. Público:
       GET  /comercios/verificados        ids de vendedores verificados
                                          (la app pinta la insignia)
       GET  /comercios/{user_id}/perfil   perfil del comercio (insignia →
                                          tocar → perfil, estilo Alibaba)

Estados: pendiente → aprobada | rechazada (puede volver a enviar).
"""
import os
import re
import sqlite3
import uuid
from datetime import datetime
from typing import Optional

from fastapi import APIRouter, BackgroundTasks, File, Form, HTTPException, UploadFile
from fastapi.responses import FileResponse, HTMLResponse
from pydantic import BaseModel

from config import DATA_DIR, PUBLICACIONES_DB as DB, UPLOADS_DIR

router = APIRouter()

# Documentos privados (fuera de /uploads, que es público).
PRIVADO_DIR = os.path.join(DATA_DIR, "privado", "comercios")
PUBLICO_DIR = os.path.join(UPLOADS_DIR, "comercios")

_DOCS = ("doc_identidad", "doc_poderes")
_FOTOS = ("foto_fachada", "foto_letrero", "foto_interior")
_EXT_DOC = {".jpg", ".jpeg", ".png", ".heic", ".heif", ".webp", ".pdf"}
_EXT_FOTO = {".jpg", ".jpeg", ".png", ".heic", ".heif", ".webp"}
MAX_BYTES = 12 * 1024 * 1024


def _token_ok(token: Optional[str]) -> bool:
    return token == os.environ.get("ADMIN_TOKEN", "okventa-admin-2026")


def _conn():
    c = sqlite3.connect(DB)
    c.row_factory = sqlite3.Row
    return c


def init_verificacion_comercio_db():
    os.makedirs(PRIVADO_DIR, exist_ok=True)
    os.makedirs(PUBLICO_DIR, exist_ok=True)
    c = sqlite3.connect(DB)
    c.execute("""
        CREATE TABLE IF NOT EXISTS verificaciones_comercio (
            id               INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id          INTEGER NOT NULL,
            rut              TEXT NOT NULL,
            razon_social     TEXT NOT NULL,
            nombre_comercial TEXT NOT NULL,
            direccion        TEXT NOT NULL,
            comuna           TEXT,
            lat              REAL,
            lng              REAL,
            doc_identidad    TEXT,
            doc_poderes      TEXT,
            foto_fachada     TEXT,
            foto_letrero     TEXT,
            foto_interior    TEXT,
            estado           TEXT NOT NULL DEFAULT 'pendiente',
            motivo_rechazo   TEXT,
            revisado_por     TEXT,
            revisado_en      TIMESTAMP,
            created_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)
    c.execute("CREATE INDEX IF NOT EXISTS idx_verif_com_user "
              "ON verificaciones_comercio(user_id)")
    c.execute("CREATE INDEX IF NOT EXISTS idx_verif_com_estado "
              "ON verificaciones_comercio(estado)")
    for col in ("tiene_giro INTEGER DEFAULT 0",
                "comercio_verificado INTEGER DEFAULT 0",
                "comercio_verificado_en TIMESTAMP",
                "nombre_comercial TEXT"):
        try:
            c.execute(f"ALTER TABLE users ADD COLUMN {col}")
        except sqlite3.OperationalError:
            pass
    c.commit()
    c.close()


# ── RUT chileno ──────────────────────────────────────────────────────────────

def normalizar_rut(rut: str) -> Optional[str]:
    """'76.123.456-k' → '76123456-K' si el dígito verificador es correcto."""
    limpio = re.sub(r"[^0-9kK]", "", rut or "").upper()
    if len(limpio) < 8 or len(limpio) > 9:
        return None
    cuerpo, dv = limpio[:-1], limpio[-1]
    if not cuerpo.isdigit():
        return None
    suma, factor = 0, 2
    for d in reversed(cuerpo):
        suma += int(d) * factor
        factor = 2 if factor == 7 else factor + 1
    resto = 11 - (suma % 11)
    esperado = "0" if resto == 11 else "K" if resto == 10 else str(resto)
    if dv != esperado:
        return None
    return f"{int(cuerpo)}-{dv}"


def formatear_rut(rut: str) -> str:
    cuerpo, dv = rut.split("-")
    return f"{int(cuerpo):,}".replace(",", ".") + "-" + dv


# ── Archivos ─────────────────────────────────────────────────────────────────

async def _guardar(archivo: UploadFile, carpeta: str, permitidas: set,
                   nombre: str) -> str:
    ext = os.path.splitext(archivo.filename or "")[1].lower() or ".jpg"
    if ext not in permitidas:
        raise HTTPException(400, f"Formato no permitido para {nombre} ({ext})")
    datos = await archivo.read()
    if not datos:
        raise HTTPException(400, f"El archivo de {nombre} está vacío")
    if len(datos) > MAX_BYTES:
        raise HTTPException(400, f"{nombre}: el archivo supera 12 MB")
    os.makedirs(carpeta, exist_ok=True)
    fn = f"{nombre}_{uuid.uuid4().hex[:12]}{ext}"
    with open(os.path.join(carpeta, fn), "wb") as f:
        f.write(datos)
    return fn


def _ultima(c, user_id: int):
    return c.execute(
        "SELECT * FROM verificaciones_comercio WHERE user_id = ? "
        "ORDER BY id DESC LIMIT 1", (user_id,)).fetchone()


def _url_foto(user_id: int, fn: Optional[str]) -> Optional[str]:
    return f"/uploads/comercios/{user_id}/{fn}" if fn else None


# ── Giro comercial ───────────────────────────────────────────────────────────

class GiroData(BaseModel):
    tiene_giro: bool


@router.put("/usuarios/{user_id}/giro")
def guardar_giro(user_id: int, data: GiroData):
    c = _conn()
    try:
        c.execute("UPDATE users SET tiene_giro = ? WHERE id = ?",
                  (1 if data.tiene_giro else 0, user_id))
        c.commit()
    finally:
        c.close()
    return {"ok": True, "tiene_giro": data.tiene_giro}


# ── Estado para la app ───────────────────────────────────────────────────────

@router.get("/comercio/verificacion/{user_id}")
def estado_verificacion(user_id: int):
    c = _conn()
    try:
        u = c.execute("SELECT tiene_giro, comercio_verificado FROM users "
                      "WHERE id = ?", (user_id,)).fetchone()
        v = _ultima(c, user_id)
    finally:
        c.close()
    if not v:
        estado = "ninguna"
    else:
        estado = v["estado"]
    return {
        "tiene_giro": bool(u and u["tiene_giro"]),
        "verificado": bool(u and u["comercio_verificado"]),
        "estado": estado,
        "motivo_rechazo": v["motivo_rechazo"] if v else None,
        "enviado_en": v["created_at"] if v else None,
        "revisado_en": v["revisado_en"] if v else None,
        "datos": None if not v else {
            "rut": formatear_rut(v["rut"]),
            "razon_social": v["razon_social"],
            "nombre_comercial": v["nombre_comercial"],
            "direccion": v["direccion"],
            "lat": v["lat"],
            "lng": v["lng"],
        },
    }


# ── Envío del formulario ─────────────────────────────────────────────────────

@router.post("/comercio/verificacion")
async def enviar_verificacion(
    user_id: int = Form(...),
    rut: str = Form(...),
    razon_social: str = Form(...),
    nombre_comercial: str = Form(...),
    direccion: str = Form(...),
    comuna: str = Form(""),
    lat: Optional[float] = Form(None),
    lng: Optional[float] = Form(None),
    doc_identidad: UploadFile = File(...),
    doc_poderes: UploadFile = File(...),
    foto_fachada: UploadFile = File(...),
    foto_letrero: UploadFile = File(...),
    foto_interior: UploadFile = File(...),
):
    rut_ok = normalizar_rut(rut)
    if not rut_ok:
        raise HTTPException(400, "El RUT de la empresa no es válido")
    razon_social = (razon_social or "").strip()[:200]
    nombre_comercial = (nombre_comercial or "").strip()[:120]
    direccion = (direccion or "").strip()[:250]
    if len(razon_social) < 3:
        raise HTTPException(400, "Falta la razón social")
    if len(nombre_comercial) < 2:
        raise HTTPException(400, "Falta el nombre comercial")
    if len(direccion) < 5:
        raise HTTPException(400, "Falta la dirección del comercio")

    c = _conn()
    try:
        if not c.execute("SELECT 1 FROM users WHERE id = ?",
                         (user_id,)).fetchone():
            raise HTTPException(404, "Usuario no encontrado")
        previa = _ultima(c, user_id)
        if previa and previa["estado"] == "pendiente":
            raise HTTPException(409, "Ya tienes una verificación en revisión")
        if previa and previa["estado"] == "aprobada":
            raise HTTPException(409, "Tu comercio ya está verificado")
        otro = c.execute(
            "SELECT user_id FROM verificaciones_comercio WHERE rut = ? AND "
            "estado = 'aprobada' AND user_id != ?", (rut_ok, user_id)).fetchone()
        if otro:
            raise HTTPException(
                409, "Ese RUT ya está verificado en otra cuenta. "
                     "Escríbenos a soporte si es un error.")
    finally:
        c.close()

    privado = os.path.join(PRIVADO_DIR, str(user_id))
    publico = os.path.join(PUBLICO_DIR, str(user_id))
    archivos = {
        "doc_identidad": await _guardar(doc_identidad, privado, _EXT_DOC,
                                        "doc_identidad"),
        "doc_poderes": await _guardar(doc_poderes, privado, _EXT_DOC,
                                      "doc_poderes"),
        "foto_fachada": await _guardar(foto_fachada, publico, _EXT_FOTO,
                                       "foto_fachada"),
        "foto_letrero": await _guardar(foto_letrero, publico, _EXT_FOTO,
                                       "foto_letrero"),
        "foto_interior": await _guardar(foto_interior, publico, _EXT_FOTO,
                                        "foto_interior"),
    }

    c = _conn()
    try:
        cur = c.execute("""
            INSERT INTO verificaciones_comercio
              (user_id, rut, razon_social, nombre_comercial, direccion, comuna,
               lat, lng, doc_identidad, doc_poderes, foto_fachada,
               foto_letrero, foto_interior, estado)
            VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?, 'pendiente')
        """, (user_id, rut_ok, razon_social, nombre_comercial, direccion,
              (comuna or "").strip()[:80], lat, lng,
              archivos["doc_identidad"], archivos["doc_poderes"],
              archivos["foto_fachada"], archivos["foto_letrero"],
              archivos["foto_interior"]))
        c.execute("UPDATE users SET tiene_giro = 1 WHERE id = ?", (user_id,))
        c.commit()
        vid = cur.lastrowid
    finally:
        c.close()
    return {"ok": True, "id": vid, "estado": "pendiente"}


# ── Público: insignia y perfil del comercio ──────────────────────────────────

@router.get("/comercios/verificados")
def comercios_verificados():
    c = _conn()
    try:
        ids = [r[0] for r in c.execute(
            "SELECT id FROM users WHERE comercio_verificado = 1")]
    finally:
        c.close()
    return {"ids": ids}


def _contar(c, sql: str, args=()) -> int:
    try:
        r = c.execute(sql, args).fetchone()
        return int(r[0] or 0) if r else 0
    except sqlite3.OperationalError:
        return 0


@router.get("/comercios/{user_id}/perfil")
def perfil_comercio(user_id: int):
    c = _conn()
    try:
        u = c.execute("SELECT id, nombre, foto_url, created_at, "
                      "comercio_verificado, comercio_verificado_en "
                      "FROM users WHERE id = ?", (user_id,)).fetchone()
        if not u or not u["comercio_verificado"]:
            raise HTTPException(404, "Este vendedor no es un comercio verificado")
        v = c.execute(
            "SELECT * FROM verificaciones_comercio WHERE user_id = ? AND "
            "estado = 'aprobada' ORDER BY id DESC LIMIT 1", (user_id,)).fetchone()
        if not v:
            raise HTTPException(404, "Este vendedor no es un comercio verificado")

        # Reputación (reseñas a vendedor)
        prom, total = 0.0, 0
        try:
            r = c.execute("SELECT AVG(estrellas), COUNT(*) FROM reviews "
                          "WHERE vendedor_id = ?", (user_id,)).fetchone()
            prom, total = float(r[0] or 0), int(r[1] or 0)
        except sqlite3.OperationalError:
            pass

        ventas = _contar(c, "SELECT COUNT(*) FROM ordenes WHERE vendedor_id = ? "
                            "AND estado = 'entregado' AND COALESCE(es_test,0)=0",
                         (user_id,))
        problemas = _contar(c, "SELECT COUNT(*) FROM ordenes WHERE vendedor_id = ?"
                               " AND estado IN ('en_disputa','reembolsado') "
                               "AND COALESCE(es_test,0)=0", (user_id,))
        compradores = _contar(c, "SELECT COUNT(DISTINCT comprador_id) FROM ordenes "
                                 "WHERE vendedor_id = ? AND estado = 'entregado'",
                              (user_id,))
        repiten = _contar(c, "SELECT COUNT(*) FROM (SELECT comprador_id FROM "
                             "ordenes WHERE vendedor_id = ? AND estado = "
                             "'entregado' GROUP BY comprador_id HAVING "
                             "COUNT(*) > 1)", (user_id,))
        productos = _contar(c, "SELECT COUNT(*) FROM publicaciones WHERE "
                               "user_id = ? AND COALESCE(estado,'disponible') = "
                               "'disponible'", (user_id,))
        servicios = _contar(c, "SELECT COUNT(*) FROM servicios WHERE user_id = ?",
                            (user_id,))
    finally:
        c.close()

    def anios(desde) -> float:
        try:
            d = datetime.fromisoformat(str(desde).replace("Z", "")[:19])
            return round((datetime.now() - d).days / 365.25, 1)
        except Exception:
            return 0.0

    cerradas = ventas + problemas
    return {
        "user_id": user_id,
        "nombre_comercial": v["nombre_comercial"],
        "razon_social": v["razon_social"],
        "rut": formatear_rut(v["rut"]),
        "comuna": v["comuna"] or "",
        "direccion": v["direccion"],
        "lat": v["lat"],
        "lng": v["lng"],
        "foto_url": u["foto_url"] or "",
        "fotos": [x for x in (_url_foto(user_id, v["foto_fachada"]),
                              _url_foto(user_id, v["foto_letrero"]),
                              _url_foto(user_id, v["foto_interior"])) if x],
        "verificado_en": u["comercio_verificado_en"] or v["revisado_en"],
        "en_okventa_desde": u["created_at"],
        "anios_en_okventa": anios(u["created_at"]),
        "reputacion": round(prom, 1),
        "total_resenas": total,
        "ventas_completadas": ventas,
        # % de ventas cerradas sin disputa ni reembolso.
        "tasa_entregas_exitosas": round(100.0 * ventas / cerradas, 1)
        if cerradas else None,
        # % de compradores que volvieron a comprar.
        "tasa_recompra": round(100.0 * repiten / compradores, 1)
        if compradores else None,
        "productos_activos": productos,
        "servicios": servicios,
        "verificaciones": {
            "rut": True,
            "razon_social": True,
            "representante_legal": True,
            "direccion": True,
            "fotos_del_local": True,
        },
    }


# ── Backoffice ───────────────────────────────────────────────────────────────

def _avisar(user_id: int, titulo: str, texto: str):
    try:
        from database.notifications import crear_notificacion
        from database.users import obtener_fcm_token
        from services.fcm_service import enviar_push
        crear_notificacion(user_id, "comercio_verificacion", texto)
        tok = obtener_fcm_token(user_id)
        if tok:
            enviar_push(tok, titulo, texto, {"tipo": "comercio_verificacion"})
    except Exception as e:
        print(f"WARN aviso verificación comercio: {e}")


def _fila_admin(r) -> dict:
    d = dict(r)
    d["rut"] = formatear_rut(d["rut"])
    for k in _FOTOS:
        d[k] = _url_foto(d["user_id"], d[k])
    for k in _DOCS:
        d[k] = f"/admin/comercio/archivo/{d['id']}/{k}" if d[k] else None
    return d


@router.get("/admin/comercio/verificaciones")
def admin_listar(token: str, estado: Optional[str] = None, limite: int = 200):
    if not _token_ok(token):
        raise HTTPException(403, "Token inválido")
    c = _conn()
    try:
        sql = ("SELECT v.*, u.nombre AS nombre_usuario, u.email AS email_usuario "
               "FROM verificaciones_comercio v LEFT JOIN users u "
               "ON u.id = v.user_id")
        args: tuple = ()
        if estado:
            sql += " WHERE v.estado = ?"
            args = (estado,)
        sql += " ORDER BY v.id DESC LIMIT ?"
        filas = c.execute(sql, args + (max(1, min(limite, 1000)),)).fetchall()
    finally:
        c.close()
    return {"verificaciones": [_fila_admin(r) for r in filas]}


@router.get("/admin/comercio/archivo/{vid}/{campo}")
def admin_archivo(vid: int, campo: str, token: str):
    if not _token_ok(token):
        raise HTTPException(403, "Token inválido")
    if campo not in _DOCS:
        raise HTTPException(400, "Campo inválido")
    c = _conn()
    try:
        r = c.execute(f"SELECT user_id, {campo} FROM verificaciones_comercio "
                      "WHERE id = ?", (vid,)).fetchone()
    finally:
        c.close()
    if not r or not r[campo]:
        raise HTTPException(404, "No existe")
    ruta = os.path.join(PRIVADO_DIR, str(r["user_id"]), r[campo])
    if not os.path.isfile(ruta):
        raise HTTPException(404, "Archivo no encontrado")
    return FileResponse(ruta)


class RechazoData(BaseModel):
    motivo: str = ""
    revisor: str = "backoffice"


@router.post("/admin/comercio/verificaciones/{vid}/aprobar")
def admin_aprobar(vid: int, token: str, tareas: BackgroundTasks,
                  revisor: str = "backoffice"):
    if not _token_ok(token):
        raise HTTPException(403, "Token inválido")
    c = _conn()
    try:
        v = c.execute("SELECT * FROM verificaciones_comercio WHERE id = ?",
                      (vid,)).fetchone()
        if not v:
            raise HTTPException(404, "No existe")
        c.execute("UPDATE verificaciones_comercio SET estado = 'aprobada', "
                  "motivo_rechazo = NULL, revisado_por = ?, revisado_en = "
                  "CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP "
                  "WHERE id = ?", (revisor, vid))
        c.execute("UPDATE users SET comercio_verificado = 1, tiene_giro = 1, "
                  "comercio_verificado_en = CURRENT_TIMESTAMP, "
                  "nombre_comercial = ? WHERE id = ?",
                  (v["nombre_comercial"], v["user_id"]))
        c.commit()
        uid = v["user_id"]
        nombre = v["nombre_comercial"]
    finally:
        c.close()
    tareas.add_task(_avisar, uid, "¡Comercio verificado! ✅",
                    f"{nombre} ya tiene la insignia de Comercio verificado "
                    "en OkVenta.")
    return {"ok": True, "estado": "aprobada"}


@router.post("/admin/comercio/verificaciones/{vid}/rechazar")
def admin_rechazar(vid: int, token: str, data: RechazoData,
                   tareas: BackgroundTasks):
    if not _token_ok(token):
        raise HTTPException(403, "Token inválido")
    motivo = (data.motivo or "").strip()[:500] or \
        "Revisa que los documentos y las fotos se vean claros."
    c = _conn()
    try:
        v = c.execute("SELECT user_id FROM verificaciones_comercio WHERE id = ?",
                      (vid,)).fetchone()
        if not v:
            raise HTTPException(404, "No existe")
        c.execute("UPDATE verificaciones_comercio SET estado = 'rechazada', "
                  "motivo_rechazo = ?, revisado_por = ?, revisado_en = "
                  "CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP "
                  "WHERE id = ?", (motivo, data.revisor, vid))
        # Si estaba verificado y se revoca, se quita la insignia.
        c.execute("UPDATE users SET comercio_verificado = 0 WHERE id = ?",
                  (v["user_id"],))
        c.commit()
        uid = v["user_id"]
    finally:
        c.close()
    tareas.add_task(_avisar, uid, "Verificación de comercio",
                    f"No pudimos verificar tu comercio: {motivo} "
                    "Puedes corregirlo y enviarlo de nuevo.")
    return {"ok": True, "estado": "rechazada"}


@router.get("/admin/comercio", response_class=HTMLResponse)
def admin_pagina(token: str, estado: str = "pendiente"):
    """Backoffice simple para revisar verificaciones desde el navegador."""
    if not _token_ok(token):
        raise HTTPException(403, "Token inválido")
    filas = admin_listar(token=token, estado=estado or None)["verificaciones"]
    import html as _h

    def e(x):
        return _h.escape(str(x if x is not None else ""))

    tarjetas = []
    for f in filas:
        fotos = "".join(
            f'<a href="{e(f[k])}" target="_blank"><img src="{e(f[k])}"></a>'
            for k in _FOTOS if f.get(k))
        docs = " · ".join(
            f'<a href="{e(f[k])}?token={e(token)}" target="_blank">{n}</a>'
            for k, n in (("doc_identidad", "Documento de identidad"),
                         ("doc_poderes", "Vigencia de poderes")) if f.get(k))
        mapa = (f'<a target="_blank" href="https://maps.apple.com/?ll='
                f'{f["lat"]},{f["lng"]}&q={e(f["nombre_comercial"])}">Ver en mapa</a>'
                if f.get("lat") is not None else "")
        acciones = ""
        if f["estado"] == "pendiente":
            acciones = f"""
            <button onclick="aprobar({f['id']})" class="ok">Aprobar</button>
            <button onclick="rechazar({f['id']})" class="no">Rechazar</button>"""
        tarjetas.append(f"""
        <div class="t">
          <div class="h"><b>#{f['id']} · {e(f['nombre_comercial'])}</b>
            <span class="e {e(f['estado'])}">{e(f['estado'])}</span></div>
          <div>{e(f['razon_social'])} · RUT {e(f['rut'])}</div>
          <div>{e(f['direccion'])} {mapa}</div>
          <div class="m">Usuario #{f['user_id']} · {e(f.get('nombre_usuario'))}
            · {e(f.get('email_usuario'))} · enviado {e(f['created_at'])}</div>
          <div class="f">{fotos}</div>
          <div>{docs}</div>
          {('<div class="m">Motivo: ' + e(f['motivo_rechazo']) + '</div>') if f.get('motivo_rechazo') else ''}
          <div>{acciones}</div>
        </div>""")
    filtros = " ".join(
        f'<a href="?token={e(token)}&estado={x}">{x or "todas"}</a>'
        for x in ("pendiente", "aprobada", "rechazada", ""))
    return f"""<!doctype html><html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>OkVenta · Verificación de comercios</title>
<style>
body{{font-family:-apple-system,Segoe UI,sans-serif;margin:0;background:#f4f4f6;color:#1c1c1e}}
header{{background:#d62b2b;color:#fff;padding:14px 18px;font-weight:700}}
main{{max-width:900px;margin:0 auto;padding:14px}}
.t{{background:#fff;border-radius:14px;padding:14px;margin:12px 0;box-shadow:0 1px 4px #0001;line-height:1.5}}
.h{{display:flex;justify-content:space-between}}
.e{{font-size:12px;padding:2px 8px;border-radius:10px;background:#eee}}
.e.pendiente{{background:#fff3cd}}.e.aprobada{{background:#d4f5dd}}.e.rechazada{{background:#fbd5d5}}
.m{{color:#777;font-size:13px}}
.f img{{height:110px;border-radius:8px;margin:6px 6px 0 0;object-fit:cover}}
button{{border:0;border-radius:8px;padding:9px 16px;font-weight:700;margin:8px 8px 0 0;cursor:pointer}}
.ok{{background:#34c759;color:#fff}}.no{{background:#d62b2b;color:#fff}}
nav a{{margin-right:12px}}
</style></head><body>
<header>OkVenta · Verificación de comercios</header>
<main><nav>{filtros}</nav>
{''.join(tarjetas) or '<p>No hay solicitudes en este estado.</p>'}
</main>
<script>
const T={e(token)!r};
async function aprobar(id){{
  if(!confirm('¿Aprobar el comercio #'+id+'?'))return;
  const r=await fetch('/admin/comercio/verificaciones/'+id+'/aprobar?token='+encodeURIComponent(T),{{method:'POST'}});
  if(r.ok)location.reload();else alert('Error '+r.status);
}}
async function rechazar(id){{
  const m=prompt('Motivo del rechazo (lo verá el usuario):');
  if(m===null)return;
  const r=await fetch('/admin/comercio/verificaciones/'+id+'/rechazar?token='+encodeURIComponent(T),
    {{method:'POST',headers:{{'Content-Type':'application/json'}},body:JSON.stringify({{motivo:m}})}});
  if(r.ok)location.reload();else alert('Error '+r.status);
}}
</script></body></html>"""
