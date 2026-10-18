import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import 'theme_service.dart';

/// El fondo de todos los mapas de la app (Encontrar, direcciones, entregas,
/// "Estoy por aquí"...).
///
/// Con clave de CARTO (`--dart-define=CARTO_KEY=...`, la pone el workflow
/// desde el secreto CARTO_KEY) se usan sus mapas:
///   ☀️ día   → Voyager (claro, colores suaves)
///   🌙 noche → Dark Matter (casi negro, calles grises)
/// Gratis para uso comercial hasta 1 millón de cuadritos al mes.
/// Sin clave, el mapa abierto de siempre: nada se rompe.
class MapasConfig {
  MapasConfig._();

  static const String clave = String.fromEnvironment('CARTO_KEY');
  static bool get usaCarto => clave.isNotEmpty;

  static const String estiloDia = 'voyager';
  static const String estiloNoche = 'dark_all';

  /// Capa de fondo lista para poner como primer hijo de un FlutterMap.
  static TileLayer capa() {
    if (!usaCarto) {
      return TileLayer(
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        userAgentPackageName: 'com.okventa.app',
      );
    }
    final estilo = ThemeService.isDarkMode ? estiloNoche : estiloDia;
    return TileLayer(
      urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/$estilo/'
          '{z}/{x}/{y}{r}.png?key=$clave',
      subdomains: const ['a', 'b', 'c', 'd'],
      // {r} = "@2x" en pantallas retina: mismo número de cuadritos, más
      // nítidos.
      retinaMode: true,
      userAgentPackageName: 'com.okventa.app',
    );
  }

  /// Crédito que CARTO y OpenStreetMap piden mostrar sobre el mapa.
  static Widget atribucion() {
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(usaCarto ? '© CARTO © OpenStreetMap' : '© OpenStreetMap',
            style: const TextStyle(fontSize: 9, color: Color(0xFF333333))),
      ),
    );
  }
}
