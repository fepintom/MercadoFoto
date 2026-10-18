import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import 'theme_service.dart';

/// El fondo de todos los mapas de la app (Encontrar, direcciones, entregas,
/// "Estoy por aquí"...).
///
/// Con clave de CARTO (`--dart-define=CARTO_KEY=...`, la pone el workflow
/// desde el secreto CARTO_KEY) se usan sus mapas:
///   ☀️ día   → Voyager (claro) con nombres en negro
///   🌙 noche → Dark Matter (casi negro) con nombres en blanco
/// Gratis para uso comercial hasta 1 millón de cuadritos al mes.
/// Sin clave, el mapa abierto de siempre: nada se rompe.
class MapasConfig {
  MapasConfig._();

  static const String clave = String.fromEnvironment('CARTO_KEY');
  static bool get usaCarto => clave.isNotEmpty;

  static const String estiloDia = 'voyager';
  static const String estiloNoche = 'dark_all';

  /// Capas de fondo para poner al comienzo de los hijos de un FlutterMap
  /// (`...MapasConfig.capas()`).
  ///
  /// Con CARTO van separadas: el dibujo del mapa (sin nombres) y encima
  /// solo los nombres de calles y lugares. Así a cada una se le sube el
  /// contraste por su lado: los nombres quedan NEGROS de día y BLANCOS de
  /// noche, y los bordes de las calles se marcan más.
  static List<Widget> capas() {
    if (!usaCarto) {
      return [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.okventa.app',
        ),
      ];
    }
    final oscuro = ThemeService.isDarkMode;
    final base = oscuro ? 'dark_nolabels' : 'voyager_nolabels';
    final nombres = oscuro ? 'dark_only_labels' : 'voyager_only_labels';
    // Dibujo: un poco más de contraste y color (calles y manzanas más
    // notorias). Nombres: en escala de grises y contraste fuerte (texto
    // negro puro de día, blanco puro de noche; el halo queda al revés).
    final filtroBase = oscuro
        ? _contraste(1.45, 0.10, saturacion: 1.1, brillo: 8)
        : _contraste(1.30, 0.92, saturacion: 1.2);
    final filtroNombres = oscuro
        ? _contraste(2.4, 0.18, saturacion: 0)
        : _contraste(2.6, 0.78, saturacion: 0);
    return [
      _capaCarto(base, filtroBase),
      _capaCarto(nombres, filtroNombres),
    ];
  }

  /// Compatibilidad: solo la capa de dibujo.
  static TileLayer capa() => capas().first as TileLayer;

  static TileLayer _capaCarto(String estilo, ColorFilter filtro) {
    return TileLayer(
      urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/$estilo/'
          '{z}/{x}/{y}{r}.png?key=$clave',
      subdomains: const ['a', 'b', 'c', 'd'],
      // {r} = "@2x" en pantallas retina: mismo número de cuadritos, más
      // nítidos.
      retinaMode: true,
      userAgentPackageName: 'com.okventa.app',
      tileBuilder: (context, tileWidget, tile) =>
          ColorFiltered(colorFilter: filtro, child: tileWidget),
    );
  }

  /// Contraste alrededor de un punto medio [pivote] (0 = negro, 1 =
  /// blanco): lo más oscuro que el pivote se oscurece y lo más claro se
  /// aclara. [saturacion] 0 = gris, 1 = igual, >1 = más color.
  static ColorFilter _contraste(double c, double pivote,
      {double saturacion = 1, double brillo = 0}) {
    const lr = 0.2126, lg = 0.7152, lb = 0.0722;
    final s = saturacion;
    final sr = (1 - s) * lr, sg = (1 - s) * lg, sb = (1 - s) * lb;
    final t = (1 - c) * pivote * 255 + brillo;
    return ColorFilter.matrix(<double>[
      c * (sr + s), c * sg, c * sb, 0, t,
      c * sr, c * (sg + s), c * sb, 0, t,
      c * sr, c * sg, c * (sb + s), 0, t,
      0, 0, 0, 1, 0,
    ]);
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
