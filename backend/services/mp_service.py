"""
Wrapper de la API REST de MercadoPago.
Usamos requests directamente para evitar incompatibilidades de versiones del SDK.
Las credenciales vienen de variables de entorno:
  MP_ACCESS_TOKEN  — token de acceso (producción o sandbox)
  MP_COMISION_PCT  — porcentaje de comisión OkVenta (default 5)
  MP_WEBHOOK_URL   — URL pública del webhook (ej: https://okventa-backend.onrender.com/pagos/webhook)
"""

import os
import requests

_BASE = "https://api.mercadopago.com"


def _token():
    t = os.environ.get("MP_ACCESS_TOKEN", "")
    if not t:
        raise RuntimeError("MP_ACCESS_TOKEN no está configurado")
    return t


def _headers():
    return {
        "Authorization": f"Bearer {_token()}",
        "Content-Type": "application/json",
        "X-Idempotency-Key": os.urandom(16).hex(),
    }


def _comision_pct() -> float:
    try:
        return float(os.environ.get("MP_COMISION_PCT", "5"))
    except ValueError:
        return 5.0


def _webhook_url() -> str:
    return os.environ.get(
        "MP_WEBHOOK_URL",
        "https://okventa-backend.onrender.com/pagos/webhook",
    )


# ── Crear preferencia de pago ─────────────────────────────────────────────────

def crear_preferencia(
    orden_id: int,
    titulo: str,
    monto: float,
    comprador_email: str,
    imagen_url: str = "",
) -> dict:
    """
    Crea una preferencia de pago en MP y devuelve:
      {preference_id, init_point, sandbox_init_point}
    """
    comision = round(monto * _comision_pct() / 100, 2)

    body = {
        "items": [
            {
                "id":          str(orden_id),
                "title":       titulo[:255],
                "quantity":    1,
                "unit_price":  monto,
                "currency_id": "CLP",
                **({"picture_url": imagen_url} if imagen_url else {}),
            }
        ],
        "payer": {
            "email": comprador_email or "comprador@okventa.cl",
        },
        "external_reference": f"orden_{orden_id}",
        "notification_url":   _webhook_url(),
        "application_fee":    comision,
        "back_urls": {
            "success": f"https://okventa-backend.onrender.com/pagos/resultado?estado=aprobado&orden={orden_id}",
            "failure": f"https://okventa-backend.onrender.com/pagos/resultado?estado=fallido&orden={orden_id}",
            "pending": f"https://okventa-backend.onrender.com/pagos/resultado?estado=pendiente&orden={orden_id}",
        },
        "auto_return": "approved",
    }

    r = requests.post(
        f"{_BASE}/checkout/preferences",
        headers=_headers(),
        json=body,
        timeout=15,
    )
    r.raise_for_status()
    data = r.json()
    return {
        "preference_id":      data["id"],
        "init_point":         data["init_point"],
        "sandbox_init_point": data.get("sandbox_init_point", data["init_point"]),
    }


# ── Obtener pago ──────────────────────────────────────────────────────────────

def obtener_pago(payment_id: str) -> dict:
    r = requests.get(
        f"{_BASE}/v1/payments/{payment_id}",
        headers=_headers(),
        timeout=15,
    )
    r.raise_for_status()
    return r.json()


# ── Reembolsar pago ───────────────────────────────────────────────────────────

def reembolsar_pago(payment_id: str) -> dict:
    r = requests.post(
        f"{_BASE}/v1/payments/{payment_id}/refunds",
        headers=_headers(),
        json={},
        timeout=15,
    )
    r.raise_for_status()
    return r.json()
