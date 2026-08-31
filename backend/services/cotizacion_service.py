"""Genera el PDF de una cotización de servicio.

Formato único para toda la app: mismo encabezado, mismos campos y las dos
firmas al pie, con los datos del proveedor ya importados. Así el cliente
recibe siempre el mismo documento, venga de quien venga.

Se dibuja con PyMuPDF, que ya está en el proyecto para leer los catálogos en
PDF — no hace falta ninguna dependencia nueva. Es una API de bajo nivel
(coordenadas en puntos, origen arriba a la izquierda), por eso el layout va
con constantes nombradas en vez de números sueltos.
"""
import os
import secrets
from datetime import datetime

from config import UPLOADS_DIR

# A4 en puntos
ANCHO, ALTO = 595.0, 842.0
MARGEN = 48.0

# Paleta de marca, en 0-1 como pide PyMuPDF
ROJO = (214 / 255, 43 / 255, 43 / 255)
CARBON = (44 / 255, 44 / 255, 46 / 255)
GRIS = (107 / 255, 107 / 255, 110 / 255)
GRIS_CLARO = (224 / 255, 224 / 255, 229 / 255)
BLANCO = (1, 1, 1)

LOGO = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                    "assets", "okventin_servicios.png")


def _fmt_monto(monto) -> str:
    try:
        return "$" + f"{float(monto):,.0f}".replace(",", ".")
    except Exception:
        return str(monto)


def generar_pdf_cotizacion(cotizacion: dict, nombre_proveedor: str = "",
                           nombre_cliente: str = "") -> str:
    """Crea el PDF y devuelve su ruta pública '/uploads/...'.

    Nunca levanta excepción hacia afuera: si algo falla devuelve "" y el
    llamador manda la cotización sin adjunto en vez de romper el chat.
    """
    try:
        import fitz  # PyMuPDF
    except ImportError:
        print("ERROR: falta PyMuPDF, no se puede generar el PDF de cotización")
        return ""

    try:
        doc = fitz.open()
        page = doc.new_page(width=ANCHO, height=ALTO)

        # ── Encabezado ──────────────────────────────────────────────────
        page.draw_rect(fitz.Rect(0, 0, ANCHO, 104), color=None, fill=CARBON)
        page.draw_rect(fitz.Rect(0, 104, ANCHO, 108), color=None, fill=ROJO)

        if os.path.exists(LOGO):
            try:
                page.insert_image(fitz.Rect(MARGEN, 20, MARGEN + 64, 84),
                                  filename=LOGO, keep_proportion=True)
            except Exception as e:
                print("WARN logo en el PDF:", e)

        page.insert_text(fitz.Point(MARGEN + 78, 48), "OKVENTA",
                         fontsize=22, fontname="hebo", color=BLANCO)
        page.insert_text(fitz.Point(MARGEN + 78, 68), "Servicios",
                         fontsize=12, fontname="helv", color=(1, 0.8, 0.8))
        page.insert_textbox(
            fitz.Rect(ANCHO - MARGEN - 200, 34, ANCHO - MARGEN, 80),
            f"COTIZACIÓN N° {cotizacion['id']:05d}\n"
            f"{datetime.now().strftime('%d/%m/%Y')}",
            fontsize=11, fontname="hebo", color=BLANCO, align=2)

        y = 148

        # ── Campos ──────────────────────────────────────────────────────
        def campo(etiqueta: str, valor: str, y: float, alto: float = 34) -> float:
            page.insert_text(fitz.Point(MARGEN, y), etiqueta.upper(),
                             fontsize=8, fontname="hebo", color=GRIS)
            caja = fitz.Rect(MARGEN, y + 6, ANCHO - MARGEN, y + alto)
            page.insert_textbox(caja, valor or "—", fontsize=12,
                                fontname="helv", color=CARBON)
            page.draw_line(fitz.Point(MARGEN, y + alto + 2),
                           fitz.Point(ANCHO - MARGEN, y + alto + 2),
                           color=GRIS_CLARO, width=0.8)
            return y + alto + 22

        y = campo("Nombre de empresa",
                  cotizacion.get("empresa") or nombre_proveedor or "—", y)
        y = campo("Servicio cotizado", cotizacion.get("servicio_cotizado"), y)

        # El monto va destacado: es el dato que se firma.
        page.insert_text(fitz.Point(MARGEN, y), "MONTO DEL SERVICIO",
                         fontsize=8, fontname="hebo", color=GRIS)
        page.draw_rect(fitz.Rect(MARGEN, y + 8, ANCHO - MARGEN, y + 54),
                       color=GRIS_CLARO, fill=(0.97, 0.97, 0.98), width=0.8)
        page.insert_text(fitz.Point(MARGEN + 14, y + 40),
                         _fmt_monto(cotizacion.get("monto")),
                         fontsize=24, fontname="hebo", color=ROJO)
        y += 76

        # Detalle: bloque alto, es texto libre del proveedor.
        y = campo("Detalle", cotizacion.get("detalle"), y, alto=150)

        # ── Firmas ──────────────────────────────────────────────────────
        y_firmas = max(y + 40, ALTO - 190)
        ancho_firma = (ANCHO - MARGEN * 2 - 40) / 2
        for i, (rotulo, nombre) in enumerate((
                ("Firma cliente", nombre_cliente),
                ("Firma proveedor", nombre_proveedor))):
            x0 = MARGEN + i * (ancho_firma + 40)
            page.draw_line(fitz.Point(x0, y_firmas),
                           fitz.Point(x0 + ancho_firma, y_firmas),
                           color=CARBON, width=1)
            page.insert_text(fitz.Point(x0, y_firmas + 16), rotulo,
                             fontsize=10, fontname="hebo", color=CARBON)
            if nombre:
                page.insert_text(fitz.Point(x0, y_firmas + 30), nombre,
                                 fontsize=9, fontname="helv", color=GRIS)

        # ── Pie: la garantía, que es parte del trato ────────────────────
        page.draw_line(fitz.Point(MARGEN, ALTO - 92),
                       fitz.Point(ANCHO - MARGEN, ALTO - 92),
                       color=GRIS_CLARO, width=0.8)
        page.insert_textbox(
            fitz.Rect(MARGEN, ALTO - 84, ANCHO - MARGEN, ALTO - 30),
            "Seguro Garantía OkVenta: al aceptar esta cotización el pago queda "
            "protegido. Se abona el 80% al proveedor al confirmarse el pago y "
            "el 20% restante a los 30 días, si el cliente no presenta un "
            "reclamo de garantía dentro de ese plazo.",
            fontsize=8, fontname="helv", color=GRIS)

        os.makedirs(UPLOADS_DIR, exist_ok=True)
        nombre_archivo = f"cotizacion_{cotizacion['id']}_{secrets.token_hex(6)}.pdf"
        doc.save(os.path.join(UPLOADS_DIR, nombre_archivo))
        doc.close()
        return f"/uploads/{nombre_archivo}"

    except Exception as e:
        print(f"ERROR generando el PDF de la cotización: {e!r}")
        return ""
