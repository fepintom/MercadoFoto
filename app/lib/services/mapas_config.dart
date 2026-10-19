import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';
import 'package:vector_tile_renderer/vector_tile_renderer.dart' as vtr;

import 'estilo_mapa_okventa.dart';

/// El fondo de todos los mapas de la app (Encontrar, direcciones, entregas,
/// "Estoy por aquí"...).
///
/// Mapa VECTORIAL de OpenFreeMap (gratis, sin clave ni límite de vistas,
/// datos de OpenStreetMap) dibujado en el teléfono con nuestro propio
/// estilo: azul marino, calles celestes y nombres en blanco
/// (ver estilo_mapa_okventa.dart).
class MapasConfig {
  MapasConfig._();

  /// Para volver al mapa de OpenStreetMap de siempre, poner en false.
  static const bool vectorial = true;

  static const String _teselas =
      'https://tiles.openfreemap.org/planet/latest/{z}/{x}/{y}.pbf';

  /// Color de fondo (mientras carga y en las manzanas).
  static const Color fondo = Color(0xFF13213A);

  static vtr.Theme? _tema;
  static vtr.Theme get _temaNoche => _tema ??= vtr.ThemeReader()
      .read(jsonDecode(estiloMapaOkventaNoche) as Map<String, dynamic>);

  static TileProviders? _proveedores;
  static TileProviders get _proveedoresOfm => _proveedores ??= TileProviders({
        'openmaptiles': NetworkVectorTileProvider(
          urlTemplate: _teselas,
          maximumZoom: 14,
          httpHeaders: const {'User-Agent': 'OkVenta/1.0 (com.okventa.app)'},
        ),
      });

  /// Capas de fondo para poner al comienzo de los hijos de un FlutterMap
  /// (`...MapasConfig.capas()`).
  static List<Widget> capas() {
    if (!vectorial) {
      return [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.okventa.app',
        ),
      ];
    }
    return [
      // Fondo azul mientras llegan los cuadritos (sin parpadeo gris).
      const ColoredBox(color: fondo, child: SizedBox.expand()),
      VectorTileLayer(
        theme: _temaNoche,
        tileProviders: _proveedoresOfm,
        // Dibujado como vectores en el teléfono: nombres nítidos y sin
        // cortarse en el borde de cada cuadrito. OpenFreeMap llega hasta
        // zoom 14; más cerca se agranda el mismo dibujo (sigue nítido).
        layerMode: VectorTileLayerMode.vector,
        maximumZoom: 22,
      ),
    ];
  }

  /// Crédito que OpenFreeMap, OpenMapTiles y OpenStreetMap piden mostrar sobre el mapa.
  static Widget atribucion() {
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(vectorial ? 'OpenFreeMap © OpenMapTiles © OpenStreetMap' : '© OpenStreetMap',
            style: const TextStyle(fontSize: 9, color: Color(0xFFCFD5DE))),
      ),
    );
  }
}
