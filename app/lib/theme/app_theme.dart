import 'package:flutter/material.dart';

import '../services/theme_service.dart';

class AppColors {
  // Paleta Opción 3 — Marketplace Moderno
  static const Color primary = Color(0xFFD62B2B); // Rojo principal
  static const Color primaryDark =
      Color(0xFFB01E1E); // Rojo oscuro (hover/pressed)
  static const Color carbon =
      Color(0xFF2C2C2E); // Gris carbón (UI base, textos)
  static const Color grayMid =
      Color(0xFF6B6B6E); // Gris medio (subtítulos, hints)
  static const Color background = Color(0xFFF2F2F7); // Fondo iOS system
  static const Color surface = Color(0xFFFFFFFF); // Blanco (cards, inputs)
  static const Color divider = Color(0xFFE0E0E5); // Separadores
  static const Color textPrimary = Color(0xFF2C2C2E); // Texto principal
  static const Color textSecondary = Color(0xFF6B6B6E); // Texto secundario
  static const Color textOnPrimary = Color(0xFFFFFFFF); // Texto sobre rojo
}

// ── Paleta oscura ────────────────────────────────────────────────────────
// Misma estructura que AppColors (mismos nombres de campo) para que, a
// medida que las pantallas se vayan adaptando (fase 2/3 del modo oscuro),
// baste con leer de una u otra paleta según ThemeService.isDarkMode en vez
// de reescribir cada color a mano.
class AppColorsDark {
  static const Color primary = Color(0xFFE94B4B); // Rojo, un poco más vivo
  static const Color primaryDark = Color(0xFFB01E1E);
  // OJO: en el código "carbon" se usa sobre todo como relleno oscuro
  // (fondo de snackbars, chips seleccionados, botones, scrims) más que
  // como color de texto/ícono — por eso NO se invierte a un tono claro
  // como el resto de la paleta: se mantiene oscuro (mismo valor que en
  // claro) para que esos rellenos sigan leyéndose bien sobre fondo negro.
  // Los usos que sí son texto/ícono se migraron a colors.textPrimary.
  static const Color carbon = Color(0xFF2C2C2E);
  static const Color grayMid = Color(0xFF9A9A9E);
  static const Color background = Color(0xFF000000); // Fondo negro
  static const Color surface = Color(0xFF1C1C1E); // Tarjetas, inputs
  static const Color divider = Color(0xFF3A3A3C);
  static const Color textPrimary = Color(0xFFF2F2F2);
  static const Color textSecondary = Color(0xFF9A9A9E);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
}

// ── Paleta dinámica ──────────────────────────────────────────────────────
// AppColors/AppColorsDark siguen siendo static const (no se tocan, cero
// riesgo de regresión). AppPalette envuelve una de las dos en una instancia
// normal (no const) para poder elegirla en tiempo de ejecución según el
// modo actual.
class AppPalette {
  final Color primary;
  final Color primaryDark;
  final Color carbon;
  final Color grayMid;
  final Color background;
  final Color surface;
  final Color divider;
  final Color textPrimary;
  final Color textSecondary;
  final Color textOnPrimary;

  const AppPalette({
    required this.primary,
    required this.primaryDark,
    required this.carbon,
    required this.grayMid,
    required this.background,
    required this.surface,
    required this.divider,
    required this.textPrimary,
    required this.textSecondary,
    required this.textOnPrimary,
  });

  static const AppPalette light = AppPalette(
    primary: AppColors.primary,
    primaryDark: AppColors.primaryDark,
    carbon: AppColors.carbon,
    grayMid: AppColors.grayMid,
    background: AppColors.background,
    surface: AppColors.surface,
    divider: AppColors.divider,
    textPrimary: AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
    textOnPrimary: AppColors.textOnPrimary,
  );

  static const AppPalette dark = AppPalette(
    primary: AppColorsDark.primary,
    primaryDark: AppColorsDark.primaryDark,
    carbon: AppColorsDark.carbon,
    grayMid: AppColorsDark.grayMid,
    background: AppColorsDark.background,
    surface: AppColorsDark.surface,
    divider: AppColorsDark.divider,
    textPrimary: AppColorsDark.textPrimary,
    textSecondary: AppColorsDark.textSecondary,
    textOnPrimary: AppColorsDark.textOnPrimary,
  );

  static AppPalette of(bool isDark) => isDark ? dark : light;

  /// Devuelve esta paleta con un tono rojo (el rojo de la marca OkVenta,
  /// [AppColors.primary]) mezclado en el fondo y las superficies, según
  /// [intensity] (0.0 = sin tono, 1.0 = tono máximo). Se usa en modo claro
  /// para el slider "Color de fondo": a más intensidad, más cubre el rojo
  /// toda la app, igual que el modo oscuro cubre todo de negro.
  AppPalette withRedTint(double intensity) {
    final i = intensity.clamp(0.0, 1.0);
    if (i <= 0) return this;
    return AppPalette(
      primary: primary,
      primaryDark: primaryDark,
      carbon: carbon,
      grayMid: grayMid,
      // Fondo: se mezcla fuerte hacia el rojo de marca (cubre toda la app).
      background: Color.lerp(background, AppColors.primary, i)!,
      // Superficie (tarjetas/inputs): mezcla más suave para que sigan
      // destacando sobre el fondo, igual que blanco destaca sobre gris.
      surface: Color.lerp(surface, AppColors.primary, i * 0.35)!,
      divider: Color.lerp(divider, AppColors.primaryDark, i * 0.4)!,
      textPrimary: textPrimary,
      textSecondary: textSecondary,
      textOnPrimary: textOnPrimary,
    );
  }
}

/// Paleta activa según el modo actual. Se usa en las pantallas ya migradas
/// (home, marketplace, producto_detalle, chat) en vez de `AppColors.*` fijo,
/// para que respondan al modo claro/oscuro. Un `ValueListenableBuilder`
/// sobre `ThemeService.isDarkNotifier` en el build() de cada pantalla es lo
/// que dispara el redibujado; este getter solo entrega el valor correcto
/// en cada llamada.
AppPalette get colors {
  if (ThemeService.isDarkMode) return AppPalette.dark;
  return AppPalette.light.withRedTint(ThemeService.bgTint);
}

class AppTheme {
  static ThemeData get theme => lightTheme;

  static ThemeData get lightTheme => lightThemeWithTint(0.0);

  /// Tema claro con el fondo/superficies mezclados hacia el rojo de marca
  /// según [tint] (0.0 a 1.0) — ver [AppPalette.withRedTint]. Usado por el
  /// slider "Color de fondo".
  static ThemeData lightThemeWithTint(double tint) {
    final p = AppPalette.light.withRedTint(tint);
    return _build(
      brightness: Brightness.light,
      primary: p.primary,
      secondary: p.carbon,
      surface: p.surface,
      background: p.background,
      divider: p.divider,
      textPrimary: p.textPrimary,
      textSecondary: p.textSecondary,
      textOnPrimary: p.textOnPrimary,
      grayMid: p.grayMid,
    );
  }

  static ThemeData get darkTheme => _build(
        brightness: Brightness.dark,
        primary: AppColorsDark.primary,
        secondary: AppColorsDark.carbon,
        surface: AppColorsDark.surface,
        background: AppColorsDark.background,
        divider: AppColorsDark.divider,
        textPrimary: AppColorsDark.textPrimary,
        textSecondary: AppColorsDark.textSecondary,
        textOnPrimary: AppColorsDark.textOnPrimary,
        grayMid: AppColorsDark.grayMid,
      );

  static ThemeData _build({
    required Brightness brightness,
    required Color primary,
    required Color secondary,
    required Color surface,
    required Color background,
    required Color divider,
    required Color textPrimary,
    required Color textSecondary,
    required Color textOnPrimary,
    required Color grayMid,
  }) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: primary,
        onPrimary: textOnPrimary,
        secondary: secondary,
        onSecondary: textOnPrimary,
        surface: surface,
        onSurface: textPrimary,
        error: primary,
        onError: textOnPrimary,
      ),
      scaffoldBackgroundColor: background,
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: divider, width: 0.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: textOnPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: TextStyle(color: grayMid, fontSize: 14),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: divider, width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: divider, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: divider,
        thickness: 0.5,
      ),
      textTheme: TextTheme(
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textSecondary,
        ),
        labelSmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: grayMid,
        ),
      ),
    );
  }
}
