import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

/// El fondo de todos los mapas de la app (Encontrar, direcciones, entregas,
/// "Estoy por aquí"...).
///
/// Con clave de CARTO (`--dart-define=CARTO_KEY=...`, la pone el workflow
/// desde el secreto CARTO_KEY) se usa Dark Matter teñido al estilo del
/// modo oscuro de Apple Maps: fondo gris azulado, calles más claras y
/// nombres en blanco. Sin clave, el mapa abierto de siempre.
class MapasConfig {
  MapasConfig._();

  static const String clave = String.fromEnvironment('CARTO_KEY');
  static bool get usaCarto => clave.isNotEmpty;

  /// Fondo del mapa (manzanas) — el gris azulado de Apple Maps oscuro.
  static const Color fondo = Color(0xFF323A48);

  /// Capas de fondo para poner al comienzo de los hijos de un FlutterMap
  /// (`...MapasConfig.capas()`): el dibujo y encima los nombres.
  static List<Widget> capas() {
    if (!usaCarto) {
      return [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.okventa.app',
        ),
      ];
    }
    return [
      _capaCarto('dark_nolabels', _tinteDibujo()),
      _capaCarto('dark_only_labels', _tinteNombres()),
    ];
  }

  /// Compatibilidad: solo la capa de dibujo.
  static TileLayer capa() => capas().first as TileLayer;

  static TileLayer _capaCarto(String estilo, ColorFilter filtro) {
    return TileLayer(
      // Siempre la versión @2x (512 px) mostrada a 256: nítida y con los
      // nombres a su tamaño real. OJO: no usar retinaMode — en
      // flutter_map 4 pide un zoom más y achica cada cuadrito a la mitad
      // (los nombres quedaban diminutos y se pedían 4 veces más cuadritos).
      urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/$estilo/'
          '{z}/{x}/{y}@2x.png?key=$clave',
      subdomains: const ['a', 'b', 'c', 'd'],
      tileSize: 256,
      userAgentPackageName: 'com.okventa.app',
      tileBuilder: (context, tileWidget, tile) =>
          ColorFiltered(colorFilter: filtro, child: tileWidget),
    );
  }

  /// Dark Matter es casi negro (manzanas #090909, calles #191919, bordes
  /// de avenidas #2a2a2a). Se estira su gris y se lleva al gris azulado:
  /// manzanas → [fondo], calles y bordes cada vez más claros.
  static ColorFilter _tinteDibujo() {
    const s = 1.7; // cuánto se separan calles y manzanas
    return _gris(s, fondo, desde: 9);
  }

  /// Nombres: texto gris (#6f6f6f / #a1a1a1) → blanco; su halo gris
  /// oscuro → el mismo [fondo], para que no se vea un "borde" negro.
  static ColorFilter _tinteNombres() => _gris(3.0, fondo, desde: 45);

  /// Pasa a gris y mapea linealmente: el gris [desde] queda del color
  /// [destino] y cada punto de gris sobre él suma [s] puntos.
  static ColorFilter _gris(double s, Color destino, {required double desde}) {
    const lr = 0.2126, lg = 0.7152, lb = 0.0722;
    double o(int c) => c - s * desde;
    return ColorFilter.matrix(<double>[
      s * lr, s * lg, s * lb, 0, o(destino.red),
      s * lr, s * lg, s * lb, 0, o(destino.green),
      s * lr, s * lg, s * lb, 0, o(destino.blue),
      0, 0, 0, 1, 0,
    ]);
  }

  /// Crédito que CARTO y OpenStreetMap piden mostrar sobre el mapa.
  static Widget atribucion() {
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(usaCarto ? '© CARTO © OpenStreetMap' : '© OpenStreetMap',
            style: const TextStyle(fontSize: 9, color: Color(0xFFCFD5DE))),
      ),
    );
  }
}
