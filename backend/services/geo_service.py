"""
geo_service.py
===============
Utilidad geográfica compartida (fórmula Haversine), consistente con el
cálculo ya usado en database/publicaciones.py (obtener_publicaciones_cercanas).
"""

import math


def distancia_km(lat1, lng1, lat2, lng2) -> float:
    """Distancia en km entre dos coordenadas usando Haversine."""
    if lat1 is None or lng1 is None or lat2 is None or lng2 is None:
        return float("inf")

    R = 6371  # Radio de la Tierra en km
    dlat = math.radians(lat2 - lat1)
    dlng = math.radians(lng2 - lng1)
    a = (math.sin(dlat / 2) ** 2
         + math.cos(math.radians(lat1))
         * math.cos(math.radians(lat2))
         * math.sin(dlng / 2) ** 2)
    return R * 2 * math.asin(math.sqrt(a))


def dentro_de_radio(lat1, lng1, lat2, lng2, radio_km) -> bool:
    return distancia_km(lat1, lng1, lat2, lng2) <= radio_km
