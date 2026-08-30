import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferencias de cómo se ven los listados de servicios, compartidas por
/// todas las vistas (pestañas "Ofrezco" y "Busco") y persistidas en disco.
///
/// Son [ValueNotifier] a propósito: antes la preferencia de columnas era una
/// variable estática, así que al cambiarla en una pestaña la otra no se
/// enteraba hasta reconstruirse. Con notificadores las dos vistas se
/// redibujan al instante.
class VistaServicios {
  VistaServicios._();

  static const String _kPrefColumnas = 'srv_columnas';
  static const String _kPrefComoLista = 'srv_como_lista';

  /// true = "Como lista" (una tarjeta ancha por fila).
  /// false = "Como miniaturas" (grilla de tarjetas compactas).
  static final ValueNotifier<bool> comoListaNotifier =
      ValueNotifier<bool>(true);

  /// Columnas de la grilla cuando se ve "Como miniaturas" (2 o 3).
  /// No aplica en modo lista.
  static final ValueNotifier<int> columnasNotifier = ValueNotifier<int>(2);

  static bool get comoLista => comoListaNotifier.value;
  static int get columnas => columnasNotifier.value;

  /// Carga las preferencias guardadas. Se llama una vez al iniciar la app.
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Compatibilidad con la versión anterior: el tamaño se guardaba como
      // un número de columnas donde "1" significaba, de hecho, la vista de
      // lista. Ahora la vista es una preferencia aparte, así que un 1
      // guardado se traduce a "como lista" con la grilla en su valor por
      // defecto.
      final colGuardadas = prefs.getInt(_kPrefColumnas) ?? 1;
      final listaGuardada = prefs.getBool(_kPrefComoLista);

      comoListaNotifier.value = listaGuardada ?? (colGuardadas == 1);
      columnasNotifier.value = colGuardadas <= 1 ? 2 : colGuardadas.clamp(2, 3);
    } catch (_) {
      // Primer uso o error de plataforma: quedan los valores por defecto.
    }
  }

  static Future<void> setComoLista(bool value) async {
    comoListaNotifier.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kPrefComoLista, value);
    } catch (_) {
      // Best-effort: aunque no se persista, queda aplicado en esta sesión.
    }
  }

  static Future<void> setColumnas(int value) async {
    final v = value.clamp(2, 3);
    columnasNotifier.value = v;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kPrefColumnas, v);
    } catch (_) {
      // Best-effort.
    }
  }
}
