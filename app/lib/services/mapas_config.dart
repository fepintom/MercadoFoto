import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import 'theme_service.dart';

/// El fondo de todos los mapas de la app (Encontrar, direcciones, entregas,
/// "Estoy por aquí"...).
///
/// Con token de Mapbox (`--dart-define=MAPBOX_TOKEN=pk...`, lo pone el
/// workflow desde el secreto MAPBOX_TOKEN) se usan los estilos de Mapbox:
///   ☀️ día   → Streets
///   🌙 noche → Navigation Night (azul oscuro, como el modo nocturno de
///              los navegadores)
/// Sin token, el mapa abierto de siempre: nada se rompe.
class MapasConfig {
  MapasConfig._();

  static const String token = String.fromEnvironment('MAPBOX_TOKEN');
  static bool get usaMapbox => token.isNotEmpty;

  static const String estiloDia = 'mapbox/streets-v12';
  static const String estiloNoche = 'mapbox/navigation-night-v1';

  /// Capa de fondo lista para poner como primer hijo de un FlutterMap.
  static TileLayer capa() {
    if (!usaMapbox) {
      return TileLayer(
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        userAgentPackageName: 'com.okventa.app',
      );
    }
    final estilo = ThemeService.isDarkMode ? estiloNoche : estiloDia;
    // Teselas de 512 px (zoomOffset -1): se ven nítidas y se piden menos.
    return TileLayer(
      urlTemplate: 'https://api.mapbox.com/styles/v1/$estilo/tiles/512/'
          '{z}/{x}/{y}{r}?access_token=$token',
      tileSize: 512,
      zoomOffset: -1,
      retinaMode: true,
      userAgentPackageName: 'com.okventa.app',
    );
  }

  /// Crédito que Mapbox y OpenStreetMap piden mostrar sobre el mapa.
  static Widget atribucion() {
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
            usaMapbox ? '© Mapbox © OpenStreetMap' : '© OpenStreetMap',
            style: const TextStyle(fontSize: 9, color: Color(0xFF333333))),
      ),
    );
  }
}
