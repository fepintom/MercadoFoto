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

  /// true = modo oscuro, false = modo claro. Empieza en claro por defecto
  /// hasta que [init] cargue el valor guardado.
  static final ValueNotifier<bool> isDarkNotifier = ValueNotifier<bool>(false);

  static bool get isDarkMode => isDarkNotifier.value;

  /// Carga la preferencia guardada. Se llama una vez al iniciar la app.
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      isDarkNotifier.value = prefs.getBool(_prefsKey) ?? false;
    } catch (_) {
      // Si falla la carga (primer uso, error de plataforma, etc.) se
      // mantiene el modo claro por defecto.
    }
  }

  /// Alterna entre claro/oscuro y guarda la elección.
  static Future<void> toggle() async {
    isDarkNotifier.value = !isDarkNotifier.value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, isDarkNotifier.value);
    } catch (_) {
      // Best-effort: si no se puede persistir, igual queda aplicado en
      // esta sesión.
    }
  }
}
