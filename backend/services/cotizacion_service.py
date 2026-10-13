"""Genera el PDF de una cotización de servicio, con el diseño OkVenta:

    OK VENTA                                   COTIZACIÓN  N.º 0001
    EMISOR / CLIENTE, fechas
    tabla de ítems (Producto o servicio | Cantidad | Precio unitario | Importe)
    Subtotal, Descuento, Impuestos, TOTAL, Retención de garantía, Pago inicial
    GARANTÍA DEL SERVICIO · CONDICIONES · OBSERVACIONES
    Okventín al pie ("Pago protegido con OkVenta")

Si la cotización trae `datos` (JSON del editor de la app) se usan sus ítems,
condiciones y observaciones; si es una cotización antigua (un solo monto),
se arma con un único ítem.

Se dibuja con PyMuPDF (ya está en el proyecto) y las fuentes DejaVu de
assets/fonts (tildes y ñ sin problemas). Nunca levanta excepción hacia
afuera: si algo falla devuelve "" y la cotización se envía sin adjunto.
"""
import json
import os
import secrets
from datetime import datetime, timedelta

from config import UPLOADS_DIR

ANCHO, ALTO = 595.0, 842.0
M = 48.0  # margen

ROJO = (192 / 255, 84 / 255, 92 / 255)       # rojo del logo del PDF
TINTA = (34 / 255, 38 / 255, 46 / 255)
GRIS = (110 / 255, 116 / 255, 128 / 255)
LINEA = (226 / 255, 228 / 255, 233 / 255)
FONDO_TABLA = (242 / 255, 243 / 255, 245 / 255)

_BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
_FUENTE = os.path.join(_BASE, "assets", "fonts", "DejaVuSans.ttf")
_FUENTE_B = os.path.join(_BASE, "assets", "fonts", "DejaVuSans-Bold.ttf")
OKVENTIN = os.path.join(_BASE, "assets", "okventin_servicios.png")

# Mismos valores que el Seguro Garantía de database/ordenes.py
try:
    from database.ordenes import (DIAS_RETENCION_GARANTIA,
                                  PORCENTAJE_LIBERACION_INICIAL)
except Exception:  # pragma: no cover
    PORCENTAJE_LIBERACION_INICIAL, DIAS_RETENCION_GARANTIA = 0.80, 30


_okventin_cache = None


def _okventin_chico() -> bytes:
    """Okventín achicado (el original pesa ~1 MB)."""
    global _okventin_cache
    if _okventin_cache is None:
        import io
        from PIL import Image
        im = Image.open(OKVENTIN).convert("RGBA")
        im.thumbnail((220, 220))
        buf = io.BytesIO()
        im.save(buf, format="PNG", optimize=True)
        _okventin_cache = buf.getvalue()
    return _okventin_cache


def _fmt(monto) -> str:
    try:
        return "$" + f"{float(monto):,.0f}".replace(",", ".")
    except Exception:
        return str(monto)


def _fecha(txt, por_defecto: datetime) -> str:
    if txt:
        for f in ("%Y-%m-%d", "%d/%m/%Y"):
            try:
                return datetime.strptime(str(txt)[:10], f).strftime("%d/%m/%Y")
            except Exception:
                pass
    return por_defecto.strftime("%d/%m/%Y")


def datos_de(cotizacion: dict) -> dict:
    """Los datos estructurados (o el equivalente de una cotización antigua)."""
    d = {}
    try:
        d = json.loads(cotizacion.get("datos") or "{}") or {}
    except Exception:
        d = {}
    if not d.get("items"):
        monto = float(cotizacion.get("monto") or 0)
        d = {
            "items": [{"nombre": cotizacion.get("servicio_cotizado") or "Servicio",
                       "cantidad": 1, "precio": monto}],
            "subtotal": monto, "descuento": 0, "impuestos": 0, "total": monto,
            "observaciones": cotizacion.get("detalle") or "",
        }
    return d


def generar_pdf_cotizacion(cotizacion: dict, nombre_proveedor: str = "",
                           nombre_cliente: str = "") -> str:
    try:
        import fitz  # PyMuPDF
    except ImportError:
        print("ERROR: falta PyMuPDF, no se puede generar el PDF de cotización")
        return ""

    try:
        d = datos_de(cotizacion)
        items = d["items"]
        subtotal = float(d.get("subtotal") or sum(
            i["cantidad"] * i["precio"] for i in items))
        descuento = float(d.get("descuento") or 0)
        impuestos = float(d.get("impuestos") or 0)
        total = float(d.get("total") or (subtotal - descuento + impuestos))
        pct_ret = 1 - PORCENTAJE_LIBERACION_INICIAL
        retencion = round(total * pct_ret)
        emision = datetime.now()

        doc = fitz.open()
        estado = {"page": None}

        def nueva_pagina():
            p = doc.new_page(width=ANCHO, height=ALTO)
            for nombre, archivo in (("dv", _FUENTE), ("dvb", _FUENTE_B)):
                try:
                    p.insert_font(fontname=nombre, fontfile=archivo)
                except Exception:
                    pass
            estado["page"] = p
            return p

        def fuente(b):
            return "dvb" if b else "dv"

        def texto(x, y, t, tam=10, b=False, color=TINTA):
            estado["page"].insert_text(fitz.Point(x, y), str(t), fontsize=tam,
                                       fontname=fuente(b), color=color)

        try:
            medidas = {False: fitz.Font(fontfile=_FUENTE),
                       True: fitz.Font(fontfile=_FUENTE_B)}
        except Exception:
            medidas = {}

        def derecha(x_der, y, t, tam=10, b=False, color=TINTA):
            f = medidas.get(b)
            ancho = (f.text_length(str(t), fontsize=tam) if f else
                     fitz.get_text_length(str(t), fontname="helv",
                                          fontsize=tam) * 1.1)
            texto(x_der - ancho, y, t, tam, b, color)

        def linea(y):
            estado["page"].draw_line(fitz.Point(M, y), fitz.Point(ANCHO - M, y),
                                     color=LINEA, width=0.8)

        def caja_texto(x0, y0, x1, y1, t, tam=9.5, color=GRIS):
            return estado["page"].insert_textbox(
                fitz.Rect(x0, y0, x1, y1), str(t), fontsize=tam,
                fontname="dv", color=color, lineheight=1.35)

        page = nueva_pagina()

        # ── Encabezado ────────────────────────────────────────────────────
        texto(M, 70, "OK", 26, True, ROJO)
        texto(M + 50, 70, "VENTA", 26, True, TINTA)
        derecha(ANCHO - M, 62, "COTIZACIÓN", 20, True)
        derecha(ANCHO - M, 82, f"N.º {int(cotizacion.get('id') or 0):04d}", 10)
        linea(100)

        # ── Emisor / Cliente ──────────────────────────────────────────────
        col2 = ANCHO / 2 + 10
        texto(M, 124, "EMISOR", 8.5, True, GRIS)
        texto(col2, 124, "CLIENTE", 8.5, True, GRIS)
        emisor = (cotizacion.get("empresa") or nombre_proveedor or "—")[:40]
        cliente = (d.get("cliente_nombre") or nombre_cliente or "—")[:40]
        texto(M, 146, emisor, 12.5, True)
        texto(col2, 146, cliente, 12.5, True)
        texto(M, 166, f"Fecha de emisión: {emision.strftime('%d/%m/%Y')}", 9.5)
        texto(col2, 166, "Válida hasta: "
              f"{_fecha(d.get('valida_hasta'), emision + timedelta(days=7))}", 9.5)
        linea(186)

        # ── Tabla de ítems ────────────────────────────────────────────────
        x_cant, x_unit, x_imp = 395, 480, ANCHO - M - 10

        def cabecera_tabla(y):
            estado["page"].draw_rect(fitz.Rect(M, y, ANCHO - M, y + 30),
                                     color=None, fill=FONDO_TABLA)
            texto(M + 10, y + 19, "Producto o servicio", 9.5, True)
            derecha(x_cant, y + 19, "Cantidad", 8.5, True)
            derecha(x_unit, y + 19, "Precio unitario", 8.5, True)
            derecha(x_imp, y + 19, "Importe", 8.5, True)
            return y + 30

        y = cabecera_tabla(200)
        for it in items:
            if y > ALTO - 140:
                page = nueva_pagina()
                y = cabecera_tabla(60)
            nombre = str(it["nombre"])
            texto(M + 10, y + 26, nombre[:52] + ("…" if len(nombre) > 52 else ""), 10)
            derecha(x_cant, y + 26, int(it["cantidad"]), 10)
            derecha(x_unit, y + 26, _fmt(it["precio"]), 10)
            derecha(x_imp, y + 26, _fmt(it["cantidad"] * it["precio"]), 10)
            y += 42
            linea(y)

        # ── Totales ───────────────────────────────────────────────────────
        if y > ALTO - 330:
            page = nueva_pagina()
            y = 60
        xl = col2
        y += 28
        for etiqueta, valor in (("Subtotal", _fmt(subtotal)),
                                ("Descuento", ("-" if descuento else "") + _fmt(descuento)),
                                ("Impuestos (según corresponda)", _fmt(impuestos))):
            texto(xl, y, etiqueta, 9)
            derecha(x_imp, y, valor, 9.5)
            y += 24
        estado["page"].draw_line(fitz.Point(M, y - 6), fitz.Point(ANCHO - M, y - 6),
                                 color=LINEA, width=0.8)
        y += 16
        texto(xl, y, "TOTAL", 12.5, True)
        derecha(x_imp, y + 1, _fmt(total), 18, True)
        y += 28
        texto(xl, y, f"Retención de garantía ({round(pct_ret * 100)} %)", 9)
        derecha(x_imp, y, _fmt(retencion), 9.5)
        y += 24
        texto(xl, y, "Pago inicial al prestador", 9)
        derecha(x_imp, y, _fmt(total - retencion), 9.5)
        y += 20
        linea(y)

        # ── Garantía / Condiciones / Observaciones ────────────────────────
        y += 26
        texto(M, y, "GARANTÍA DEL SERVICIO", 10, True)
        y += 10
        caja_texto(M, y, ANCHO - M, y + 44,
                   f"La retención forma parte del total y se libera al prestador "
                   f"cuando el cliente confirma que el servicio está conforme, o "
                   f"automáticamente a los {DIAS_RETENCION_GARANTIA} días de "
                   f"finalizar el servicio si el cliente no reporta un problema.")
        y += 58
        texto(M, y, "CONDICIONES", 10, True)
        y += 22
        texto(M, y, f"Entrega o ejecución: {d.get('entrega') or 'A convenir'}", 9.5)
        y += 20
        texto(M, y, f"Forma de pago: {d.get('forma_pago') or 'A convenir'}", 9.5)
        y += 18
        linea(y)
        y += 24
        texto(M, y, "OBSERVACIONES", 10, True)
        y += 10
        obs = (d.get("observaciones") or "").strip() or "Sin observaciones."
        caja_texto(M, y, ANCHO - M - 120, min(y + 80, ALTO - 70), obs)

        # ── Okventín al pie ───────────────────────────────────────────────
        if os.path.exists(OKVENTIN):
            try:
                page.insert_image(
                    fitz.Rect(ANCHO - M - 70, ALTO - 150, ANCHO - M, ALTO - 62),
                    stream=_okventin_chico(), keep_proportion=True)
                derecha(ANCHO - M - 76, ALTO - 104, "Pago protegido", 8.5, True, ROJO)
                derecha(ANCHO - M - 76, ALTO - 92, "con OkVenta", 8.5, False, GRIS)
            except Exception as e:
                print("WARN Okventín en el PDF:", e)

        # ── Pie de cada página ────────────────────────────────────────────
        n = len(doc)
        for i, p in enumerate(doc):
            estado["page"] = p
            linea(ALTO - 52)
            texto(M, ALTO - 36, "Valores expresados en pesos chilenos (CLP).", 7.5, False, GRIS)
            derecha(ANCHO - M, ALTO - 36, f"{i + 1} / {n}", 7.5, False, GRIS)

        os.makedirs(UPLOADS_DIR, exist_ok=True)
        nombre_archivo = f"cotizacion_{cotizacion['id']}_{secrets.token_hex(6)}.pdf"
        try:
            doc.subset_fonts()  # solo las letras usadas: PDF liviano
        except Exception:
            pass
        doc.save(os.path.join(UPLOADS_DIR, nombre_archivo), garbage=3,
                 deflate=True)
        doc.close()
        return f"/uploads/{nombre_archivo}"

    except Exception as e:
        print(f"ERROR generando el PDF de la cotización: {e!r}")
        return ""
