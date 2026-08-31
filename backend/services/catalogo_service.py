"""Absorción de catálogos: convierte un PDF o una página web en productos
y en la identidad visual de la tienda.

Tres piezas:

  1. EXTRACCIÓN DE PRODUCTOS
     - PDF  : se renderiza cada página a imagen y GPT-4o Vision lee la
              página completa (un catálogo es un documento visual: el
              texto suelto pierde qué precio va con qué foto). Además de
              los datos, el modelo devuelve un recuadro normalizado por
              producto, con el que recortamos su foto de la página.
     - Web  : primero se intentan los datos estructurados que el propio
              sitio publica (JSON-LD schema.org/Product y OpenGraph), que
              son exactos y gratis. Solo si no hay nada de eso se cae a
              GPT sobre el texto visible.

  2. IDENTIDAD VISUAL
     Se saca la paleta dominante de la portada (PDF) o del og:image /
     logo (web). Se guardan dos colores en crudo; la app es la que decide
     cómo pintarlos y les aplica su propia regla de contraste, así una
     tienda con colores extremos nunca deja texto ilegible.

  3. TOLERANCIA A FALLOS
     Igual que vision_service, ninguna función revienta hacia afuera: si
     algo falla se devuelve lo que se alcanzó a extraer. Procesar un
     catálogo es lento y se corre en segundo plano, así que un error debe
     quedar registrado, no tumbar la request.

Nota sobre Instagram: IG no permite leer los posts de un perfil sin la
Graph API (cuenta de empresa + app de Meta + token). Una URL de IG se
acepta y se procesa como página web: se obtiene el nombre, la foto y los
colores del perfil desde las metaetiquetas públicas, pero NO los posts.
Para importar publicaciones de IG hay que conectar la Graph API, que es
un trabajo aparte.
"""
import base64
import io
import json
import os
import re
import secrets
from urllib.parse import urljoin, urlparse

import requests
from openai import OpenAI
from PIL import Image

from config import UPLOADS_DIR

client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))

MAX_PAGINAS_PDF = 12        # tope para no dispararle el costo a un PDF enorme
MAX_PRODUCTOS = 60
TIMEOUT_HTTP = 15
UA = ("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/122.0 Safari/537.36")


# ── utilidades ──────────────────────────────────────────────────────────────

def _guardar_bytes(data: bytes, prefijo: str, ext: str = ".jpg") -> str:
    os.makedirs(UPLOADS_DIR, exist_ok=True)
    nombre = f"{prefijo}_{secrets.token_hex(8)}{ext}"
    with open(os.path.join(UPLOADS_DIR, nombre), "wb") as f:
        f.write(data)
    return f"/uploads/{nombre}"


def _guardar_imagen(img: Image.Image, prefijo: str) -> str:
    buf = io.BytesIO()
    img.convert("RGB").save(buf, format="JPEG", quality=85)
    return _guardar_bytes(buf.getvalue(), prefijo)


def _a_hex(rgb) -> str:
    return "#{:02X}{:02X}{:02X}".format(*[max(0, min(255, int(c))) for c in rgb[:3]])


def paleta_de_imagen(img: Image.Image):
    """Devuelve (color_primario, color_fondo) en hex.

    Primario = el color más saturado con presencia real (la marca).
    Fondo    = el color más frecuente (normalmente el papel del catálogo).
    """
    try:
        chico = img.convert("RGB").resize((160, 160))
        reducida = chico.quantize(colors=8, method=Image.MEDIANCUT).convert("RGB")
        cuentas = sorted(reducida.getcolors(160 * 160) or [], reverse=True)
        if not cuentas:
            return None, None

        fondo = cuentas[0][1]
        total = sum(c for c, _ in cuentas)

        def saturacion(c):
            return (max(c) - min(c)) / 255.0

        candidatos = [
            (saturacion(col), col)
            for cuenta, col in cuentas
            if cuenta / total > 0.03 and saturacion(col) > 0.20
        ]
        primario = max(candidatos)[1] if candidatos else None
        return (_a_hex(primario) if primario else None), _a_hex(fondo)
    except Exception as e:
        print("WARN paleta_de_imagen:", e)
        return None, None


def _pedir_json(prompt: str, imagenes_b64=None, max_tokens=1600):
    """Llama a GPT-4o y devuelve el JSON parseado, o None si algo falla."""
    try:
        contenido = []
        for b64 in (imagenes_b64 or []):
            contenido.append({
                "type": "image_url",
                "image_url": {"url": f"data:image/jpeg;base64,{b64}", "detail": "high"},
            })
        contenido.append({"type": "text", "text": prompt})
        r = client.chat.completions.create(
            model="gpt-4o",
            messages=[{"role": "user", "content": contenido}],
            max_tokens=max_tokens,
            temperature=0.2,
        )
        txt = r.choices[0].message.content.strip()
        txt = txt.replace("```json", "").replace("```", "").strip()
        return json.loads(txt)
    except Exception as e:
        print("WARN _pedir_json:", e)
        return None


PROMPT_PAGINA = """
Eres un asistente que digitaliza catálogos de tiendas chilenas.

Analiza esta página de catálogo y extrae SOLO los productos que se ofrecen
a la venta. Ignora portadas, índices, datos de contacto, condiciones y
publicidad que no sea un producto.

Para cada producto entrega también "caja": el recuadro donde aparece su
FOTO en esta página, en coordenadas normalizadas de 0 a 1 con el origen
arriba a la izquierda, como [x0, y0, x1, y1]. Si no distingues una foto
propia del producto, deja "caja" en null.

Responde SOLO JSON con esta forma exacta:
{
  "productos": [
    {"titulo": "...", "descripcion": "...", "precio": 0, "moneda": "CLP",
     "caja": [0.0, 0.0, 0.0, 0.0]}
  ]
}

Reglas:
- titulo: máximo 8 palabras, en español, sin el precio adentro.
- descripcion: máximo 90 caracteres; "" si la página no da ninguna.
- precio: número entero sin puntos ni símbolos. Si no hay precio, null.
- No inventes productos ni precios que no estén en la página.
- Si la página no tiene productos, devuelve {"productos": []}.
"""


# ── 1. PDF ──────────────────────────────────────────────────────────────────

def extraer_de_pdf(ruta_pdf: str):
    """Devuelve (productos, marca). `marca` es un dict con color_primario,
    color_fondo y logo_url sacados de la portada."""
    productos, marca = [], {}
    try:
        import fitz  # PyMuPDF
    except ImportError:
        print("ERROR: falta PyMuPDF; no se puede leer el PDF")
        return [], {}

    try:
        doc = fitz.open(ruta_pdf)
    except Exception as e:
        print("ERROR abriendo PDF:", e)
        return [], {}

    try:
        for n in range(min(len(doc), MAX_PAGINAS_PDF)):
            try:
                pix = doc[n].get_pixmap(dpi=130)
                pagina = Image.open(io.BytesIO(pix.tobytes("png"))).convert("RGB")
            except Exception as e:
                print(f"WARN pagina {n}:", e)
                continue

            # La portada define la identidad visual de la tienda.
            if n == 0:
                prim, fondo = paleta_de_imagen(pagina)
                marca = {
                    "color_primario": prim,
                    "color_fondo": fondo,
                    "logo_url": _guardar_imagen(pagina, "catalogo_portada"),
                }

            buf = io.BytesIO()
            copia = pagina.copy()
            copia.thumbnail((1400, 1400))
            copia.save(buf, format="JPEG", quality=80)
            datos = _pedir_json(PROMPT_PAGINA,
                                [base64.b64encode(buf.getvalue()).decode()])
            if not datos:
                continue

            for p in (datos.get("productos") or []):
                if len(productos) >= MAX_PRODUCTOS:
                    break
                imagen_url = _recortar_producto(pagina, p.get("caja"), n)
                productos.append({
                    "titulo": (p.get("titulo") or "").strip(),
                    "descripcion": (p.get("descripcion") or "").strip(),
                    "precio": _num(p.get("precio")),
                    "moneda": p.get("moneda") or "CLP",
                    "imagen_url": imagen_url,
                })
            if len(productos) >= MAX_PRODUCTOS:
                break
    finally:
        try:
            doc.close()
        except Exception:
            pass

    return productos, marca


def _recortar_producto(pagina: Image.Image, caja, n_pagina: int):
    """Recorta la foto del producto usando el recuadro que devolvió la IA.
    Si el recuadro no sirve, se guarda la página entera: es preferible una
    imagen de más que una tarjeta sin imagen."""
    W, H = pagina.size
    try:
        if (isinstance(caja, (list, tuple)) and len(caja) == 4
                and all(isinstance(v, (int, float)) for v in caja)):
            x0, y0, x1, y1 = [float(v) for v in caja]
            if 0 <= x0 < x1 <= 1 and 0 <= y0 < y1 <= 1:
                # Un poco de aire alrededor del recuadro.
                mx, my = (x1 - x0) * 0.06, (y1 - y0) * 0.06
                caja_px = (max(0, int((x0 - mx) * W)), max(0, int((y0 - my) * H)),
                           min(W, int((x1 + mx) * W)), min(H, int((y1 + my) * H)))
                if (caja_px[2] - caja_px[0]) > 60 and (caja_px[3] - caja_px[1]) > 60:
                    return _guardar_imagen(pagina.crop(caja_px), "catalogo_prod")
    except Exception as e:
        print("WARN recorte:", e)
    completa = pagina.copy()
    completa.thumbnail((900, 900))
    return _guardar_imagen(completa, f"catalogo_pag{n_pagina}")


def _num(v):
    if v is None:
        return None
    try:
        if isinstance(v, str):
            v = re.sub(r"[^\d]", "", v)
            if not v:
                return None
        return float(v)
    except Exception:
        return None


# ── 2. Página web ───────────────────────────────────────────────────────────

def extraer_de_web(url: str):
    """Devuelve (productos, marca). Prioriza los datos estructurados que el
    sitio ya publica; solo cae a la IA si no hay ninguno."""
    try:
        from bs4 import BeautifulSoup
    except ImportError:
        print("ERROR: falta beautifulsoup4")
        return [], {}

    try:
        r = requests.get(url, timeout=TIMEOUT_HTTP, headers={"User-Agent": UA})
        r.raise_for_status()
        sopa = BeautifulSoup(r.text, "html.parser")
    except Exception as e:
        print("ERROR descargando la página:", e)
        return [], {}

    marca = _marca_de_web(sopa, url)
    productos = _productos_jsonld(sopa, url)

    if not productos:
        productos = _productos_por_ia(sopa, url)

    # Bajar las fotos a nuestro disco: las URLs de terceros se caen o
    # cambian, y necesitamos servirlas desde la app.
    for p in productos[:MAX_PRODUCTOS]:
        if p.get("imagen_url", "").startswith("http"):
            p["imagen_url"] = _descargar_imagen(p["imagen_url"]) or None

    return productos[:MAX_PRODUCTOS], marca


def _marca_de_web(sopa, url):
    def meta(prop):
        t = (sopa.find("meta", property=prop)
             or sopa.find("meta", attrs={"name": prop}))
        return (t.get("content") or "").strip() if t else ""

    nombre = meta("og:site_name") or meta("og:title")
    if not nombre and sopa.title:
        nombre = sopa.title.get_text(strip=True)

    logo_remoto = meta("og:image")
    logo_url, prim, fondo = None, None, None
    if logo_remoto:
        logo_url = _descargar_imagen(urljoin(url, logo_remoto), "catalogo_logo")
        if logo_url:
            try:
                ruta = os.path.join(UPLOADS_DIR, logo_url.rsplit("/", 1)[-1])
                prim, fondo = paleta_de_imagen(Image.open(ruta))
            except Exception as e:
                print("WARN paleta del logo:", e)

    # Muchos sitios declaran su color de marca en esta metaetiqueta.
    tema = meta("theme-color")
    if tema and re.fullmatch(r"#[0-9a-fA-F]{6}", tema.strip()):
        prim = tema.strip().upper()

    return {
        "nombre_tienda": (nombre or "")[:120] or None,
        "logo_url": logo_url,
        "color_primario": prim,
        "color_fondo": fondo,
    }


def _productos_jsonld(sopa, url):
    """Lee schema.org/Product desde los <script type="application/ld+json">."""
    encontrados = []
    for tag in sopa.find_all("script", type="application/ld+json"):
        try:
            datos = json.loads(tag.string or "{}")
        except Exception:
            continue
        for nodo in _aplanar_jsonld(datos):
            if not isinstance(nodo, dict):
                continue
            if str(nodo.get("@type", "")).lower() != "product":
                continue
            ofertas = nodo.get("offers") or {}
            if isinstance(ofertas, list):
                ofertas = ofertas[0] if ofertas else {}
            imagen = nodo.get("image")
            if isinstance(imagen, list):
                imagen = imagen[0] if imagen else None
            encontrados.append({
                "titulo": str(nodo.get("name") or "").strip()[:200],
                "descripcion": str(nodo.get("description") or "").strip()[:300],
                "precio": _num(ofertas.get("price") if isinstance(ofertas, dict) else None),
                "moneda": (ofertas.get("priceCurrency") if isinstance(ofertas, dict) else None) or "CLP",
                "imagen_url": urljoin(url, imagen) if isinstance(imagen, str) else "",
            })
    return [p for p in encontrados if p["titulo"]]


def _aplanar_jsonld(nodo):
    """JSON-LD viene anidado de mil formas (@graph, listas, itemListElement)."""
    if isinstance(nodo, list):
        for x in nodo:
            yield from _aplanar_jsonld(x)
    elif isinstance(nodo, dict):
        yield nodo
        for clave in ("@graph", "itemListElement", "item", "mainEntity"):
            if clave in nodo:
                yield from _aplanar_jsonld(nodo[clave])


def _productos_por_ia(sopa, url):
    """Último recurso: se le pasa el texto visible de la página a GPT."""
    for basura in sopa(["script", "style", "noscript", "svg"]):
        basura.decompose()
    texto = re.sub(r"\n{2,}", "\n", sopa.get_text("\n", strip=True))[:9000]
    if len(texto) < 120:
        return []

    datos = _pedir_json(f"""
Este es el texto visible de la tienda online {url}.

Extrae los productos a la venta. Responde SOLO JSON:
{{"productos":[{{"titulo":"...","descripcion":"...","precio":0,"moneda":"CLP"}}]}}

Reglas:
- titulo: máximo 8 palabras, en español.
- descripcion: máximo 90 caracteres, "" si no hay.
- precio: entero sin puntos ni símbolos; null si no aparece.
- No inventes nada que no esté en el texto.
- Si no hay productos, devuelve {{"productos": []}}.

TEXTO:
{texto}
""")
    if not datos:
        return []
    return [{
        "titulo": (p.get("titulo") or "").strip(),
        "descripcion": (p.get("descripcion") or "").strip(),
        "precio": _num(p.get("precio")),
        "moneda": p.get("moneda") or "CLP",
        "imagen_url": "",
    } for p in (datos.get("productos") or []) if (p.get("titulo") or "").strip()]


def _descargar_imagen(url: str, prefijo: str = "catalogo_prod"):
    try:
        if not urlparse(url).scheme.startswith("http"):
            return None
        r = requests.get(url, timeout=TIMEOUT_HTTP, headers={"User-Agent": UA})
        r.raise_for_status()
        img = Image.open(io.BytesIO(r.content))
        img.thumbnail((1000, 1000))
        return _guardar_imagen(img, prefijo)
    except Exception as e:
        print("WARN descargando imagen:", e)
        return None
