import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ajuste de color de un mapa: se aplica como un filtro sobre los
/// cuadritos de OpenStreetMap.
class AjusteMapa {
  /// Mapa base de CARTO (clave de [MapasCarto.disponibles]).
  final String mapa;
  final double brillo; // -100 … 100
  final double contraste; // 0.5 … 2.5 (1 = igual)
  final double saturacion; // 0 … 2 (0 = gris, 1 = igual)
  final double tono; // -180 … 180 grados
  final bool invertir; // claro ↔ oscuro

  const AjusteMapa({
    this.mapa = 'voyager',
    this.brillo = 0,
    this.contraste = 1,
    this.saturacion = 1,
    this.tono = 0,
    this.invertir = false,
  });

  AjusteMapa copyWith({
    String? mapa,
    double? brillo,
    double? contraste,
    double? saturacion,
    double? tono,
    bool? invertir,
  }) =>
      AjusteMapa(
        mapa: mapa ?? this.mapa,
        brillo: brillo ?? this.brillo,
        contraste: contraste ?? this.contraste,
        saturacion: saturacion ?? this.saturacion,
        tono: tono ?? this.tono,
        invertir: invertir ?? this.invertir,
      );

  Map<String, dynamic> toJson() => {
        'mapa': mapa,
        'brillo': double.parse(brillo.toStringAsFixed(0)),
        'contraste': double.parse(contraste.toStringAsFixed(2)),
        'saturacion': double.parse(saturacion.toStringAsFixed(2)),
        'tono': double.parse(tono.toStringAsFixed(0)),
        'invertir': invertir,
      };

  factory AjusteMapa.fromJson(Map<String, dynamic> j) => AjusteMapa(
        mapa: MapasCarto.disponibles.containsKey(j['mapa'])
            ? j['mapa'] as String
            : 'voyager',
        brillo: (j['brillo'] as num?)?.toDouble() ?? 0,
        contraste: (j['contraste'] as num?)?.toDouble() ?? 1,
        saturacion: (j['saturacion'] as num?)?.toDouble() ?? 1,
        tono: (j['tono'] as num?)?.toDouble() ?? 0,
        invertir: j['invertir'] == true,
      );

  /// Filtro de color: invertir → tono → saturación → contraste → brillo.
  ColorFilter filtro() {
    var m = _identidad();
    if (invertir) {
      m = _mult(<double>[
        -1, 0, 0, 0, 255, //
        0, -1, 0, 0, 255, //
        0, 0, -1, 0, 255, //
        0, 0, 0, 1, 0, //
      ], m);
    }
    if (tono != 0) {
      final r = tono * math.pi / 180;
      final c = math.cos(r), s = math.sin(r);
      m = _mult(<double>[
        0.213 + c * 0.787 - s * 0.213, 0.715 - c * 0.715 - s * 0.715,
        0.072 - c * 0.072 + s * 0.928, 0, 0, //
        0.213 - c * 0.213 + s * 0.143, 0.715 + c * 0.285 + s * 0.140,
        0.072 - c * 0.072 - s * 0.283, 0, 0, //
        0.213 - c * 0.213 - s * 0.787, 0.715 - c * 0.715 + s * 0.715,
        0.072 + c * 0.928 + s * 0.072, 0, 0, //
        0, 0, 0, 1, 0, //
      ], m);
    }
    if (saturacion != 1) {
      final s = saturacion;
      m = _mult(<double>[
        0.213 + 0.787 * s, 0.715 - 0.715 * s, 0.072 - 0.072 * s, 0, 0, //
        0.213 - 0.213 * s, 0.715 + 0.285 * s, 0.072 - 0.072 * s, 0, 0, //
        0.213 - 0.213 * s, 0.715 - 0.715 * s, 0.072 + 0.928 * s, 0, 0, //
        0, 0, 0, 1, 0, //
      ], m);
    }
    if (contraste != 1 || brillo != 0) {
      final c = contraste;
      final t = 128 * (1 - c) + brillo * 2.55;
      m = _mult(<double>[
        c, 0, 0, 0, t, //
        0, c, 0, 0, t, //
        0, 0, c, 0, t, //
        0, 0, 0, 1, 0, //
      ], m);
    }
    return ColorFilter.matrix(m);
  }

  static List<double> _identidad() => <double>[
        1, 0, 0, 0, 0, //
        0, 1, 0, 0, 0, //
        0, 0, 1, 0, 0, //
        0, 0, 0, 1, 0, //
      ];

  /// a · b (matrices de color 4×5, con la fila implícita 0 0 0 0 1).
  static List<double> _mult(List<double> a, List<double> b) {
    final r = List<double>.filled(20, 0);
    for (var i = 0; i < 4; i++) {
      for (var j = 0; j < 5; j++) {
        var v = j == 4 ? a[i * 5 + 4] : 0.0;
        for (var k = 0; k < 4; k++) {
          v += a[i * 5 + k] * b[k * 5 + j];
        }
        r[i * 5 + j] = v;
      }
    }
    return r;
  }
}

/// Ajustes de color de los mapas, uno para modo claro y otro para modo
/// oscuro. Los valores DEFINITIVOS van en [claroFijo] / [oscuroFijo]; el
/// panel "Ajustes del mapa" permite probar otros en este teléfono.
class AjustesMapa {
  AjustesMapa._();

  // ── Valores definitivos (los que ven todos) ─────────────────────────────
  static const AjusteMapa claroFijo = AjusteMapa(mapa: 'voyager');
  static const AjusteMapa oscuroFijo = AjusteMapa(mapa: 'dark_all');

  static const _clave = 'ajustes_mapa_v2';

  static AjusteMapa claro = claroFijo;
  static AjusteMapa oscuro = oscuroFijo;

  /// Avisa a los mapas abiertos que cambió un ajuste.
  static final ValueNotifier<int> cambios = ValueNotifier<int>(0);

  static AjusteMapa para(bool modoOscuro) => modoOscuro ? oscuro : claro;

  /// Lee los ajustes de prueba guardados en este teléfono (si hay).
  static Future<void> cargar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final txt = prefs.getString(_clave);
      if (txt == null) return;
      final j = jsonDecode(txt) as Map<String, dynamic>;
      claro = AjusteMapa.fromJson(Map<String, dynamic>.from(j['claro'] as Map));
      oscuro =
          AjusteMapa.fromJson(Map<String, dynamic>.from(j['oscuro'] as Map));
      cambios.value++;
    } catch (_) {}
  }

  static void cambiar({required bool modoOscuro, required AjusteMapa ajuste}) {
    if (modoOscuro) {
      oscuro = ajuste;
    } else {
      claro = ajuste;
    }
    cambios.value++;
  }

  static Future<void> guardar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_clave, valoresTexto());
  }

  /// Vuelve a los valores definitivos (borra la prueba de este teléfono).
  static Future<void> restablecer() async {
    claro = claroFijo;
    oscuro = oscuroFijo;
    cambios.value++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_clave);
  }

  /// Texto para copiar y pegar en el chat: así se dejan fijos en la app.
  static String valoresTexto() =>
      jsonEncode({'claro': claro.toJson(), 'oscuro': oscuro.toJson()});
}

/// Mapas de CARTO que se pueden elegir (todos gratis hasta 1 millón de
/// cuadritos al mes con la clave CARTO_KEY).
class MapasCarto {
  MapasCarto._();

  static const String clave = String.fromEnvironment('CARTO_KEY');

  /// id → (nombre, ruta en basemaps.cartocdn.com)
  static const Map<String, (String, String)> disponibles = {
    'voyager': ('Voyager', 'rastertiles/voyager'),
    'voyager_labels_under':
        ('Voyager · nombres bajo calles', 'rastertiles/voyager_labels_under'),
    'voyager_nolabels': ('Voyager · sin nombres', 'rastertiles/voyager_nolabels'),
    'light_all': ('Positron (claro)', 'light_all'),
    'light_nolabels': ('Positron · sin nombres', 'light_nolabels'),
    'dark_all': ('Dark Matter (oscuro)', 'dark_all'),
    'dark_nolabels': ('Dark Matter · sin nombres', 'dark_nolabels'),
  };

  static String nombre(String id) => (disponibles[id] ?? disponibles['voyager']!).$1;

  /// Siempre la versión @2x (512 px) mostrada a 256: nítida y con los
  /// nombres a su tamaño real (sin retinaMode, que en flutter_map 4 los
  /// achica a la mitad).
  static String url(String id) {
    final ruta = (disponibles[id] ?? disponibles['voyager']!).$2;
    final k = clave.isEmpty ? '' : '?key=$clave';
    return 'https://{s}.basemaps.cartocdn.com/$ruta/{z}/{x}/{y}@2x.png$k';
  }
}
