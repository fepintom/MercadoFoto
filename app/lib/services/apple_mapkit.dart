import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme_service.dart';

/// Un lugar o dirección encontrado con el buscador de Apple.
class LugarApple {
  final String nombre;
  final String direccion;
  final double lat;
  final double lng;
  final String categoria;

  const LugarApple(this.nombre, this.direccion, this.lat, this.lng,
      this.categoria);
}

/// Ruta calculada por Apple (auto o a pie).
class RutaApple {
  final double metros;
  final double segundos;
  final List<(double, double)> puntos;
  final bool aPie;

  const RutaApple(this.metros, this.segundos, this.puntos, this.aPie);

  String get distancia => metros >= 1000
      ? '${(metros / 1000).toStringAsFixed(metros >= 10000 ? 0 : 1).replaceAll('.', ',')} km'
      : '${metros.round()} m';

  String get tiempo {
    final min = (segundos / 60).round();
    if (min < 60) return '${min < 1 ? 1 : min} min';
    final h = min ~/ 60, m = min % 60;
    return m == 0 ? '$h h' : '$h h $m min';
  }
}

/// Funciones nativas de Apple Maps (solo iPhone): buscar lugares,
/// calcular rutas, vista de calle y estilo de los mapas.
class AppleMapKit {
  AppleMapKit._();

  static const _canal = MethodChannel('okventa/mapkit');
  static bool get disponible => Platform.isIOS;

  // ── Opciones del mapa (guardadas en el teléfono) ─────────────────────────

  /// 'todos' | 'utiles' | 'ninguno'
  static String lugares = 'todos';

  /// 0 normal · 1 satélite · 2 híbrido
  static int tipo = 0;
  static bool trafico = false;

  static Future<void> cargarOpciones() async {
    try {
      final p = await SharedPreferences.getInstance();
      lugares = p.getString('apple_lugares') ?? 'todos';
      tipo = p.getInt('apple_tipo') ?? 0;
      trafico = p.getBool('apple_trafico') ?? false;
    } catch (_) {}
  }

  static Future<void> guardarOpciones() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('apple_lugares', lugares);
      await p.setInt('apple_tipo', tipo);
      await p.setBool('apple_trafico', trafico);
    } catch (_) {}
  }

  /// Aplica a los mapas abiertos el modo claro/oscuro de OkVenta y el
  /// filtro de lugares. Llamar al crear un mapa y al cambiar el modo.
  static Future<void> aplicarEstilo() async {
    if (!disponible) return;
    try {
      await _canal.invokeMethod('estilo', {
        'oscuro': ThemeService.isDarkMode,
        'lugares': lugares,
      });
    } catch (_) {}
  }

  // ── Buscar ───────────────────────────────────────────────────────────────

  static Future<List<LugarApple>> buscar(String texto,
      {double? lat, double? lng}) async {
    if (!disponible || texto.trim().length < 2) return [];
    try {
      final r = await _canal.invokeMethod<List>('buscar', {
        'texto': texto,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
      });
      return [
        for (final m in (r ?? []).cast<Map>())
          LugarApple(
            (m['nombre'] ?? '').toString(),
            (m['direccion'] ?? '').toString(),
            (m['lat'] as num).toDouble(),
            (m['lng'] as num).toDouble(),
            (m['categoria'] ?? '').toString(),
          ),
      ];
    } catch (_) {
      return [];
    }
  }

  // ── Rutas ────────────────────────────────────────────────────────────────

  static Future<RutaApple?> ruta({
    required double desdeLat,
    required double desdeLng,
    required double hastaLat,
    required double hastaLng,
    bool aPie = false,
  }) async {
    if (!disponible) return null;
    try {
      final r = await _canal.invokeMethod<Map>('ruta', {
        'olat': desdeLat,
        'olng': desdeLng,
        'dlat': hastaLat,
        'dlng': hastaLng,
        'modo': aPie ? 'pie' : 'auto',
      });
      if (r == null) return null;
      return RutaApple(
        (r['metros'] as num).toDouble(),
        (r['segundos'] as num).toDouble(),
        [
          for (final p in (r['puntos'] as List).cast<List>())
            ((p[0] as num).toDouble(), (p[1] as num).toDouble()),
        ],
        aPie,
      );
    } catch (_) {
      return null;
    }
  }

  // ── Foto fija del mapa ───────────────────────────────────────────────────

  static final Map<String, Future<Uint8List?>> _fotos = {};

  /// Imagen PNG del mapa de Apple centrada en un punto (para mapas chicos
  /// que no se mueven, p. ej. una ubicación compartida en un chat).
  static Future<Uint8List?> foto(double lat, double lng,
      {required double ancho, required double alto, double zoom = 15}) {
    if (!disponible) return Future.value(null);
    final oscuro = ThemeService.isDarkMode;
    final k = '${lat.toStringAsFixed(5)},${lng.toStringAsFixed(5)},'
        '${ancho.round()}x${alto.round()},$zoom,$oscuro,$lugares';
    return _fotos[k] ??= () async {
      try {
        final r = await _canal.invokeMethod<Uint8List>('foto', {
          'lat': lat,
          'lng': lng,
          'ancho': ancho,
          'alto': alto,
          'zoom': zoom,
          'oscuro': oscuro,
        });
        if (r == null) _fotos.remove(k); // reintentar la próxima vez
        return r;
      } catch (_) {
        _fotos.remove(k);
        return null;
      }
    }();
  }

  // ── Vista de calle ───────────────────────────────────────────────────────

  /// Abre Look Around. Devuelve false si Apple no tiene vista de calle ahí.
  static Future<bool> verCalle(double lat, double lng) async {
    if (!disponible) return false;
    try {
      return await _canal
              .invokeMethod<bool>('lookAround', {'lat': lat, 'lng': lng}) ??
          false;
    } catch (_) {
      return false;
    }
  }
}
