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

  /// Nombres de calles y lugares (capa aparte): color (null = el
  /// original del mapa), intensidad (0.5 suave … 2 fuerte) y tamaño.
  final int? nombresColor;
  final double nombresIntensidad;
  final bool nombresGrandes;

  const AjusteMapa({
    this.mapa = 'voyager',
    this.brillo = 0,
    this.contraste = 1,
    this.saturacion = 1,
    this.tono = 0,
    this.invertir = false,
    this.nombresColor,
    this.nombresIntensidad = 1,
    this.nombresGrandes = false,
  });

  AjusteMapa copyWith({
    String? mapa,
    double? brillo,
    double? contraste,
    double? saturacion,
    double? tono,
    bool? invertir,
    int? nombresColor,
    bool sinColorNombres = false,
    double? nombresIntensidad,
    bool? nombresGrandes,
  }) =>
      AjusteMapa(
        mapa: mapa ?? this.mapa,
        brillo: brillo ?? this.brillo,
        contraste: contraste ?? this.contraste,
        saturacion: saturacion ?? this.saturacion,
        tono: tono ?? this.tono,
        invertir: invertir ?? this.invertir,
        nombresColor:
            sinColorNombres ? null : (nombresColor ?? this.nombresColor),
        nombresIntensidad: nombresIntensidad ?? this.nombresIntensidad,
        nombresGrandes: nombresGrandes ?? this.nombresGrandes,
      );

  Map<String, dynamic> toJson() => {
        'mapa': mapa,
        'brillo': double.parse(brillo.toStringAsFixed(0)),
        'contraste': double.parse(contraste.toStringAsFixed(2)),
        'saturacion': double.parse(saturacion.toStringAsFixed(2)),
        'tono': double.parse(tono.toStringAsFixed(0)),
        'invertir': invertir,
        'nombres_color': nombresColor == null
            ? null
            : '#${(nombresColor! & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}',
        'nombres_intensidad': double.parse(nombresIntensidad.toStringAsFixed(2)),
        'nombres_grandes': nombresGrandes,
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
        nombresColor: _leerColor(j['nombres_color']),
        nombresIntensidad:
            (j['nombres_intensidad'] as num?)?.toDouble() ?? 1,
        nombresGrandes: j['nombres_grandes'] == true,
      );

  static int? _leerColor(dynamic v) {
    if (v is! String || !v.startsWith('#') || v.length != 7) return null;
    final n = int.tryParse(v.substring(1), radix: 16);
    return n == null ? null : 0xFF000000 | n;
  }

  /// Filtro SOLO para la capa de nombres: el texto queda del color
  /// elegido y su borde (halo) del contrario, para que siempre se lea.
  /// Usa los grises del texto y del halo de cada familia de CARTO.
  ColorFilter? filtroNombres() {
    final c = nombresColor;
    if (c == null) return null;
    final (double lHalo, double lTexto) = mapa.startsWith('dark')
        ? (45.0, 111.0) // Dark Matter: texto #6f6f6f, halo #2d2d2d
        : mapa.startsWith('light')
            ? (247.0, 119.0) // Positron: texto #697b89, halo #f7f7f7
            : (248.0, 115.0); // Voyager: texto #6a7584, halo #fbf8f3
    final tr = ((c >> 16) & 0xFF).toDouble();
    final tg = ((c >> 8) & 0xFF).toDouble();
    final tb = (c & 0xFF).toDouble();
    final claro = (0.2126 * tr + 0.7152 * tg + 0.0722 * tb) > 140;
    final h = claro ? 28.0 : 250.0; // halo opuesto al texto
    const lr = 0.2126, lg = 0.7152, lb = 0.0722;
    List<double> fila(double t) {
      final g = (t - h) * nombresIntensidad / (lTexto - lHalo);
      return [g * lr, g * lg, g * lb, 0, h - g * lHalo];
    }

    return ColorFilter.matrix(<double>[
      ...fila(tr),
      ...fila(tg),
      ...fila(tb),
      0, 0, 0, 1, 0,
    ]);
  }

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

  /// id → (nombre, dibujo sin nombres, capa de solo nombres o null).
  /// Los nombres van en una capa aparte para poder cambiarles el color.
  static const Map<String, (String, String, String?)> disponibles = {
    'voyager': ('Voyager', 'rastertiles/voyager_nolabels',
        'rastertiles/voyager_only_labels'),
    'voyager_nolabels':
        ('Voyager · sin nombres', 'rastertiles/voyager_nolabels', null),
    'light_all': ('Positron (claro)', 'light_nolabels', 'light_only_labels'),
    'light_nolabels': ('Positron · sin nombres', 'light_nolabels', null),
    'dark_all': ('Dark Matter (oscuro)', 'dark_nolabels', 'dark_only_labels'),
    'dark_nolabels': ('Dark Matter · sin nombres', 'dark_nolabels', null),
  };

  static (String, String, String?) _de(String id) =>
      disponibles[id] ?? disponibles['voyager']!;

  static String nombre(String id) => _de(id).$1;

  static bool tieneNombres(String id) => _de(id).$3 != null;

  static String urlDibujo(String id) => _url(_de(id).$2);

  static String? urlNombres(String id) {
    final r = _de(id).$3;
    return r == null ? null : _url(r);
  }

  /// Siempre la versión @2x (512 px) mostrada a 256: nítida y con los
  /// nombres a su tamaño real (sin retinaMode, que en flutter_map 4 los
  /// achica a la mitad).
  static String _url(String ruta) {
    final k = clave.isEmpty ? '' : '?key=$clave';
    return 'https://{s}.basemaps.cartocdn.com/$ruta/{z}/{x}/{y}@2x.png$k';
  }
}
