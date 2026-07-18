#!/usr/bin/env python3
"""
run_delivery_worker.py
=======================
Worker de auto-cierre para el flujo OkDelivery: cada CHECK_INTERVAL segundos
llama a POST /admin/okdelivery/cerrar_vencidas para cerrar automáticamente
las entregas que llevan más de 1 hora esperando confirmación del comprador
(sin respuesta = se da por recibido, se liberan los fondos).

Sigue el mismo patrón que email_publisher.py: llama a la API vía HTTP en vez
de tocar la base de datos directamente, para evitar escrituras concurrentes
sobre el mismo SQLite desde dos procesos distintos.

Variables de entorno:
    API_URL        URL pública del backend (ej: https://okventa-backend.onrender.com)
    ADMIN_TOKEN    Token compartido con el endpoint /admin/... (default: okventa-admin-2026)
    CHECK_INTERVAL Segundos entre revisiones (default: 60)
    TIMEOUT_MINUTOS Minutos de espera antes de auto-cerrar (default: 60)

Uso:
    python run_delivery_worker.py           # bucle continuo
    python run_delivery_worker.py --once     # una sola pasada
"""

import argparse
import os
import sys
import time
import traceback

import requests


def revisar(api_url: str, admin_token: str, timeout_minutos: int) -> int:
    print(f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] Revisando entregas OkDelivery vencidas…")
    try:
        resp = requests.post(
            f"{api_url.rstrip('/')}/admin/okdelivery/cerrar_vencidas",
            params={"token": admin_token, "minutos": timeout_minutos},
            timeout=30,
        )
        if resp.status_code != 200:
            print(f"  ✗ Error {resp.status_code}: {resp.text[:200]}")
            return 0
        data = resp.json()
        total = data.get("total", 0)
        if total:
            print(f"  ✓ {total} entrega(s) cerrada(s) automáticamente: {data.get('cerradas')}")
        else:
            print("  Sin entregas vencidas.")
        return total
    except Exception as e:
        print(f"  ✗ Excepción: {e}")
        traceback.print_exc()
        return 0


def _llamar_admin(api_url: str, admin_token: str, path: str,
                  params: dict, etiqueta: str) -> int:
    """Llama un endpoint admin y reporta el total procesado."""
    try:
        resp = requests.post(
            f"{api_url.rstrip('/')}{path}",
            params={"token": admin_token, **params},
            timeout=30,
        )
        if resp.status_code != 200:
            print(f"  ✗ {etiqueta}: error {resp.status_code}: {resp.text[:200]}")
            return 0
        data = resp.json()
        total = data.get("total", 0)
        if total:
            print(f"  ✓ {etiqueta}: {total} orden(es): {data.get('ordenes')}")
        return total
    except Exception as e:
        print(f"  ✗ {etiqueta}: excepción: {e}")
        return 0


def revisar_confirmaciones(api_url: str, admin_token: str,
                           horas_recordatorio: int, horas_auto: int):
    """Recordatorio a las 24h y auto-confirmación a las 48h para órdenes
    en entrega_reportada (las en_disputa quedan excluidas por estado)."""
    _llamar_admin(api_url, admin_token,
                  "/admin/ordenes/recordatorios_confirmacion",
                  {"horas": horas_recordatorio}, "recordatorios")
    _llamar_admin(api_url, admin_token,
                  "/admin/ordenes/auto_confirmar",
                  {"horas": horas_auto}, "auto-confirmadas")
    _llamar_admin(api_url, admin_token,
                  "/admin/ordenes/expirar_pendientes",
                  {"horas": 24}, "pendiente_pago expiradas")


def main():
    parser = argparse.ArgumentParser(description="OkDelivery timeout worker")
    parser.add_argument("--once", action="store_true", help="Procesar una vez y salir")
    args = parser.parse_args()

    api_url = os.environ.get("API_URL")
    if not api_url:
        print("✗ Falta variable de entorno API_URL")
        sys.exit(1)

    admin_token = os.environ.get("ADMIN_TOKEN", "okventa-admin-2026")
    intervalo = int(os.environ.get("CHECK_INTERVAL", "60"))
    timeout_minutos = int(os.environ.get("TIMEOUT_MINUTOS", "60"))
    horas_recordatorio = int(os.environ.get("HORAS_RECORDATORIO", "24"))
    horas_auto = int(os.environ.get("HORAS_AUTO_CONFIRMAR", "48"))

    print("=" * 55)
    print("  OkVenta — OkDelivery Timeout Worker")
    print(f"  API           : {api_url}")
    print(f"  Timeout       : {timeout_minutos} min")
    print(f"  Intervalo     : {intervalo}s" if not args.once else "  Modo: una sola ejecución")
    print("=" * 55)

    if args.once:
        revisar(api_url, admin_token, timeout_minutos)
        revisar_confirmaciones(api_url, admin_token, horas_recordatorio, horas_auto)
        return

    while True:
        try:
            revisar(api_url, admin_token, timeout_minutos)
            revisar_confirmaciones(api_url, admin_token, horas_recordatorio, horas_auto)
        except KeyboardInterrupt:
            print("\nDetenido por el usuario.")
            break
        except Exception as e:
            print(f"Error en bucle principal: {e}")
            traceback.print_exc()

        try:
            time.sleep(intervalo)
        except KeyboardInterrupt:
            print("\nDetenido por el usuario.")
            break


if __name__ == "__main__":
    main()
