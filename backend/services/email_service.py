"""
email_service.py
================
Envío de correos salientes (SMTP) para OkVenta.
Usa la misma config que email_publisher.py (config_email.json).
"""

import json
import os
import smtplib
from email.mime.application import MIMEApplication
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from pathlib import Path

BASE_DIR = Path(__file__).parent.parent
CONFIG_PATH = BASE_DIR / "config_email.json"
RESOURCES_DIR = BASE_DIR / "resources"


def _cargar_config() -> dict:
    if not CONFIG_PATH.exists():
        raise FileNotFoundError(f"No se encontró {CONFIG_PATH}")
    with open(CONFIG_PATH, encoding="utf-8") as f:
        return json.load(f)


def enviar_plantilla_carga_masiva(email_destino: str) -> None:
    """
    Envía la plantilla Excel de carga masiva al correo indicado.
    """
    cfg = _cargar_config()

    smtp_server = cfg.get("smtp_server") or cfg.get("imap_server", "")
    smtp_port   = int(cfg.get("smtp_port", 587))
    usuario     = cfg["email"]
    password    = cfg["password"]

    plantilla = RESOURCES_DIR / "OkVenta_Plantilla_Publicaciones.xlsx"
    if not plantilla.exists():
        raise FileNotFoundError(f"Plantilla no encontrada en {plantilla}")

    # ── Construir mensaje ────────────────────────────────────────────────
    msg = MIMEMultipart()
    msg["From"]    = f"OkVenta <{usuario}>"
    msg["To"]      = email_destino
    msg["Subject"] = "Plantilla de Carga Masiva — OkVenta"

    cuerpo = """\
Hola 👋

Adjuntamos la plantilla de carga masiva de OkVenta.

INSTRUCCIONES RÁPIDAS:
  1. Abre el archivo Excel.
  2. Completa una fila por producto (titulo, precio y user_id son obligatorios).
  3. Si tienes fotos, adjúntalas al correo con el mismo nombre indicado en la columna "imagen".
  4. Envía el correo completo a esta misma dirección.
  5. En menos de 5 minutos tus productos aparecen publicados en la app.

Consulta la hoja "Instrucciones" dentro del Excel para más detalles.

¡Éxito con tus publicaciones!
— Equipo OkVenta
"""
    msg.attach(MIMEText(cuerpo, "plain", "utf-8"))

    # ── Adjuntar Excel ───────────────────────────────────────────────────
    with open(plantilla, "rb") as f:
        adjunto = MIMEApplication(
            f.read(),
            _subtype="vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        )
    adjunto.add_header(
        "Content-Disposition",
        "attachment",
        filename="OkVenta_Plantilla_Publicaciones.xlsx",
    )
    msg.attach(adjunto)

    _enviar(smtp_server, smtp_port, usuario, password, email_destino, msg)


def enviar_confirmacion_carga_masiva(
    email_destino: str,
    username: str,
    total_publicados: int,
) -> None:
    """
    Envía confirmación al usuario tras procesar su planilla de carga masiva.
    """
    try:
        cfg = _cargar_config()
        smtp_server = cfg.get("smtp_server") or cfg.get("imap_server", "")
        smtp_port   = int(cfg.get("smtp_port", 587))
        usuario     = cfg["email"]
        password    = cfg["password"]

        msg = MIMEMultipart()
        msg["From"]    = f"OkVenta <{usuario}>"
        msg["To"]      = email_destino
        msg["Subject"] = f"✓ Tus productos fueron publicados — OkVenta"

        productos_texto = (
            f"{total_publicados} producto{'s' if total_publicados != 1 else ''}"
        )

        cuerpo = f"""\
Hola {username},

Hemos procesado y publicado {productos_texto} bajo tu usuario: {username}

Puedes verlos ahora mismo en la app OkVenta.

Si tienes alguna duda puedes escribirnos a fpinto@galmar.cl

— Equipo OkVenta
"""
        msg.attach(MIMEText(cuerpo, "plain", "utf-8"))
        _enviar(smtp_server, smtp_port, usuario, password, email_destino, msg)
        print(f"  ✓ Confirmación enviada a {email_destino}")
    except Exception as e:
        print(f"  ⚠ No se pudo enviar confirmación a {email_destino}: {e}")


def _enviar(smtp_server, smtp_port, usuario, password, destino, msg):
    if smtp_port == 465:
        with smtplib.SMTP_SSL(smtp_server, smtp_port) as server:
            server.login(usuario, password)
            server.sendmail(usuario, destino, msg.as_string())
    else:
        with smtplib.SMTP(smtp_server, smtp_port) as server:
            server.ehlo()
            server.starttls()
            server.login(usuario, password)
            server.sendmail(usuario, destino, msg.as_string())
