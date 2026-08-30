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

  /// true = modo oscuro, false = modo claro. Empieza en claro por defecto
  /// hasta que [init] cargue el valor guardado.
  static final ValueNotifier<bool> isDarkNotifier = ValueNotifier<bool>(false);


  /// Intensidad (0.0 a 1.0) con la que se oscurece el gris del fondo en
  /// modo diurno. 0 = fondo normal de la app. Solo tiene efecto en modo
  /// diurno: en nocturno el fondo es negro.
  static final ValueNotifier<double> bgTintNotifier =
      ValueNotifier<double>(0.0);

  static bool get isDarkMode => isDarkNotifier.value;

  static double get bgTint => bgTintNotifier.value;

  /// Carga las preferencias guardadas. Se llama una vez al iniciar la app.
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      isDarkNotifier.value = prefs.getBool(_prefsKey) ?? false;
      bgTintNotifier.value = prefs.getDouble(_tintPrefsKey) ?? 0.0;
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
  /// cuenta: Modo diurno / Modo nocturno) y guarda la elección.
  static Future<void> setDarkMode(bool value) async {
    isDarkNotifier.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
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
