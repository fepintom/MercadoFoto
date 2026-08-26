import 'package:flutter/material.dart';

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
  static const Color carbon = Color(0xFFF2F2F2); // Antes texto oscuro sobre
  // claro; en oscuro se usa como "texto fuerte" sobre fondo negro.
  static const Color grayMid = Color(0xFF9A9A9E);
  static const Color background = Color(0xFF000000); // Fondo negro
  static const Color surface = Color(0xFF1C1C1E); // Tarjetas, inputs
  static const Color divider = Color(0xFF3A3A3C);
  static const Color textPrimary = Color(0xFFF2F2F2);
  static const Color textSecondary = Color(0xFF9A9A9E);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
}

class AppTheme {
  static ThemeData get theme => lightTheme;

  static ThemeData get lightTheme => _build(
        brightness: Brightness.light,
        primary: AppColors.primary,
        secondary: AppColors.carbon,
        surface: AppColors.surface,
        background: AppColors.background,
        divider: AppColors.divider,
        textPrimary: AppColors.textPrimary,
        textSecondary: AppColors.textSecondary,
        textOnPrimary: AppColors.textOnPrimary,
        grayMid: AppColors.grayMid,
      );

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
