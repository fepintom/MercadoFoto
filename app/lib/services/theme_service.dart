import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Maneja el modo claro/oscuro de la app y lo persiste en disco.
///
/// Expone un [ValueNotifier<bool>] (`isDarkNotifier`) para que cualquier
/// widget pueda escuchar el cambio (con `ValueListenableBuilder`) y
/// reconstruirse — por ejemplo el `MaterialApp` (themeMode) y el header
/// del home (ícono de ojo + logo).
class ThemeService {
  ThemeService._();

  static const String _prefsKey = 'ok_venta_dark_mode';
  static const String _tintPrefsKey = 'ok_venta_bg_tint';
  static const String _redPrefsKey = 'ok_venta_red_mode';

  /// true = modo oscuro, false = modo claro. Empieza en claro por defecto
  /// hasta que [init] cargue el valor guardado.
  static final ValueNotifier<bool> isDarkNotifier = ValueNotifier<bool>(false);

  /// true = "Modo Rojo": la app se cubre de rojo y la paleta se invierte
  /// (tarjetas en rojo más claro, texto blanco), igual que el modo oscuro
  /// la cubre de negro. Es un modo aparte y no un extremo del slider: el
  /// slider solo maneja los rosados suaves, sin saltos.
  ///
  /// Es excluyente con el modo oscuro — encender uno apaga el otro.
  static final ValueNotifier<bool> redModeNotifier = ValueNotifier<bool>(false);

  /// Intensidad (0.0 a 1.0) del tono rosado de fondo en modo claro. 0 =
  /// fondo normal de la app. Solo tiene efecto en modo claro (en modo
  /// oscuro el fondo es negro y en Modo Rojo lo cubre el rojo).
  static final ValueNotifier<double> bgTintNotifier =
      ValueNotifier<double>(0.0);

  static bool get isDarkMode => isDarkNotifier.value;

  static bool get isRedMode => redModeNotifier.value;

  static double get bgTint => bgTintNotifier.value;

  /// Carga las preferencias guardadas. Se llama una vez al iniciar la app.
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      isDarkNotifier.value = prefs.getBool(_prefsKey) ?? false;
      redModeNotifier.value = prefs.getBool(_redPrefsKey) ?? false;
      bgTintNotifier.value = prefs.getDouble(_tintPrefsKey) ?? 0.0;
      // Por si quedaran los dos guardados a la vez (versión anterior de la
      // app, escritura a medias): el oscuro manda.
      if (isDarkNotifier.value) redModeNotifier.value = false;
    } catch (_) {
      // Si falla la carga (primer uso, error de plataforma, etc.) se
      // mantiene el modo claro y sin tono por defecto.
    }
  }

  /// Alterna entre claro/oscuro y guarda la elección.
  static Future<void> toggle() async {
    await setDarkMode(!isDarkNotifier.value);
  }

  /// Fija el modo explícitamente (usado por el selector "MODO" en Mi
  /// cuenta: Modo diurno / Modo rojo / Modo nocturno) y guarda la elección.
  /// Encender el oscuro apaga el Modo Rojo: son excluyentes.
  static Future<void> setDarkMode(bool value) async {
    isDarkNotifier.value = value;
    if (value) redModeNotifier.value = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, isDarkNotifier.value);
      await prefs.setBool(_redPrefsKey, redModeNotifier.value);
    } catch (_) {
      // Best-effort: si no se puede persistir, igual queda aplicado en
      // esta sesión.
    }
  }

  /// Enciende o apaga el "Modo Rojo". Encenderlo apaga el modo oscuro.
  static Future<void> setRedMode(bool value) async {
    redModeNotifier.value = value;
    if (value) isDarkNotifier.value = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_redPrefsKey, redModeNotifier.value);
      await prefs.setBool(_prefsKey, isDarkNotifier.value);
    } catch (_) {
      // Best-effort: si no se puede persistir, igual queda aplicado en
      // esta sesión.
    }
  }

  /// Fija la intensidad del tono rojo de fondo (modo claro) y la guarda.
  /// Usado por el slider "Color de fondo" en el control de tamaño de las
  /// publicaciones.
  static Future<void> setBgTint(double value) async {
    bgTintNotifier.value = value.clamp(0.0, 1.0);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_tintPrefsKey, bgTintNotifier.value);
    } catch (_) {
      // Best-effort: si no se puede persistir, igual queda aplicado en
      // esta sesión.
    }
  }
}
