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
  // Estados. Antes estaban hardcodeados dentro de cada pantalla (#34C759,
  // #FF9500), lo que impedía que la regla de contraste los alcanzara: en
  // fondo rojo el verde de "Nuevo" o "Puedes recibirlo hoy" quedaba ilegible
  // y ningún cambio de paleta podía corregirlo. Ahora son tokens y se
  // ajustan solos junto al resto.
  static const Color success = Color(0xFF34C759); // "Nuevo", "Recíbelo hoy"
  static const Color warning = Color(0xFFFF9500); // "Usado", avisos
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
  // Un poco más vivos que en claro, para que resalten sobre el negro.
  static const Color success = Color(0xFF32D74B);
  static const Color warning = Color(0xFFFFA00A);
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
  final Color success;
  final Color warning;

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
    required this.success,
    required this.warning,
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
    success: AppColors.success,
    warning: AppColors.warning,
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
    success: AppColorsDark.success,
    warning: AppColorsDark.warning,
  );

  static AppPalette of(bool isDark) => isDark ? dark : light;

  // ── Regla de contraste ──────────────────────────────────────────────────
  //
  // Tanto el modo claro como el oscuro cumplen sin querer una invariante:
  // el fondo y las tarjetas están del MISMO lado de la escala de luz, y el
  // texto está del lado opuesto. Por eso un único `textPrimary` alcanza
  // para toda la app (se lee igual de bien sobre el fondo que sobre una
  // tarjeta). El tinte rojo rompía esa invariante — dejaba el fondo oscuro
  // pero las tarjetas blancas y el texto oscuro — y por eso se perdía la
  // información en ~43 pantallas.
  //
  // Estas constantes y helpers convierten esa invariante en una regla
  // explícita: dado cualquier fondo, la paleta ajusta sola sus colores de
  // texto hasta alcanzar contraste AA, y si el fondo se vuelve oscuro
  // invierte la familia completa (tarjetas y texto) en vez de dejar una
  // mezcla ilegible.

  /// Contraste mínimo WCAG AA para texto normal.
  static const double kContrasteAA = 4.5;

  /// Tope del slider: rosa de marca.
  ///
  /// El slider NO llega al rojo pleno a propósito. Con el texto oscuro de
  /// la app (#2C2C2E) existe una banda de luminancia entre 0.183 y 0.289 en
  /// la que NINGÚN color de texto —ni negro ni blanco— alcanza 4.5:1. El
  /// slider anterior barría esa banda entre 0.7 y 0.9, que es justo donde
  /// se perdía la información. Ahora el recorrido termina en este rosa
  /// (L≈0.47 ⇒ 6.9:1 con el texto principal), muy por encima de la zona
  /// muerta, y el rojo pleno vive en un modo aparte ([rojo]) en vez de al
  /// final del mismo control. Así el slider nunca da un salto.
  static const Color _rosaMax = Color(0xFFE8A6A8);

  /// Familia oscura ("Modo Rojo"). El fondo es el rojo profundo y las
  /// tarjetas un rojo más claro, igual que en modo oscuro el fondo es negro
  /// y las tarjetas gris carbón.
  static const Color _rojoFondo = Color(0xFFA81C1C);
  static const Color _rojoCard = Color(0xFFC62B2B);

  static double _contraste(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final hi = la > lb ? la : lb;
    final lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }

  /// Acerca [fg] hacia [hacia] (negro o blanco) lo mínimo necesario para
  /// que alcance [objetivo] de contraste contra [fondo]. Si ya lo cumple lo
  /// devuelve intacto, así en el modo normal (sin tinte) ningún color se
  /// mueve ni un ápice.
  static Color _asegurar(
    Color fg,
    Color fondo, {
    required Color hacia,
    double objetivo = kContrasteAA,
  }) {
    if (_contraste(fg, fondo) >= objetivo) return fg;
    for (int paso = 1; paso <= 20; paso++) {
      final c = Color.lerp(fg, hacia, paso / 20)!;
      if (_contraste(c, fondo) >= objetivo) return c;
    }
    return hacia;
  }

  /// ¿Esta paleta quedó con fondo oscuro? Sirve para elegir el
  /// [Brightness] correcto del ThemeData y para que las pantallas que lo
  /// necesiten puedan preguntar sin tener que conocer el valor del slider.
  bool get esFondoOscuro => background.computeLuminance() < 0.25;

  /// Devuelve esta paleta con el rosa de marca mezclado en el fondo según
  /// [intensity] (0.0 = sin tono, 1.0 = [_rosaMax]), manteniendo SIEMPRE la
  /// legibilidad.
  ///
  /// El fondo va del gris de sistema al rosa; las tarjetas siguen blancas y
  /// el texto oscuro. A medida que el rosa se satura, los textos y el rojo
  /// de acento se OSCURECEN lo justo para conservar 4.5:1 contra el fondo.
  /// Oscurecerlos nunca perjudica: sobre una tarjeta blanca contrastan
  /// todavía más, así que un mismo color de texto sigue sirviendo en las dos
  /// superficies.
  ///
  /// La comprobación se hace contra el fondo real, no contra valores fijos:
  /// si mañana se cambia el color del tinte, la regla sigue valiendo sin
  /// tocar ninguna pantalla.
  AppPalette withRedTint(double intensity) {
    final i = intensity.clamp(0.0, 1.0);
    if (i <= 0) return this;

    final bg = Color.lerp(background, _rosaMax, i)!;
    Color ajustar(Color c, [double objetivo = kContrasteAA]) =>
        _asegurar(c, bg, hacia: Colors.black, objetivo: objetivo);

    return AppPalette(
      primary: ajustar(primary),
      primaryDark: ajustar(primaryDark),
      carbon: carbon,
      grayMid: ajustar(grayMid),
      background: bg,
      // Las tarjetas se quedan blancas: siguen contrastando contra el rosa
      // igual que hoy contrastan contra el gris.
      surface: surface,
      divider: Color.lerp(divider, _rosaMax, i)!,
      textPrimary: ajustar(textPrimary),
      textSecondary: ajustar(textSecondary),
      textOnPrimary: textOnPrimary,
      success: ajustar(success),
      warning: ajustar(warning),
    );
  }

  /// Paleta del "Modo Rojo": la app cubierta de rojo, con la paleta
  /// invertida igual que hace el modo oscuro con el negro — fondo rojo
  /// profundo, tarjetas en un rojo más claro, texto blanco.
  ///
  /// El acento pasa de rojo a blanco a propósito: sobre un fondo rojo el
  /// rojo ya no distingue nada (el precio se camuflaría contra su propia
  /// tarjeta). Los textos se ACLARAN hasta cumplir 4.5:1 contra la
  /// superficie más clara de las dos, que es el peor caso — así el mismo
  /// color sirve sobre el fondo y sobre las tarjetas.
  static final AppPalette rojo = _construirRojo();

  static AppPalette _construirRojo() {
    const bg = _rojoFondo;
    const card = _rojoCard;
    final peorCaso =
        card.computeLuminance() > bg.computeLuminance() ? card : bg;
    Color ajustar(Color c, [double objetivo = kContrasteAA]) =>
        _asegurar(c, peorCaso, hacia: Colors.white, objetivo: objetivo);

    return AppPalette(
      primary: Colors.white,
      primaryDark: const Color(0xFFFFD9D9),
      // `carbon` se usa como relleno oscuro (snackbars, scrims, chips) con
      // texto blanco encima, así que se mantiene oscuro, en rojo profundo.
      carbon: const Color(0xFF7A1414),
      grayMid: ajustar(const Color(0xFFF3C2C2), 4.0),
      background: bg,
      surface: card,
      divider: Colors.white.withOpacity(0.28),
      textPrimary: ajustar(const Color(0xFFF2F2F2)),
      textSecondary: ajustar(const Color(0xFFFFE1E1)),
      // Texto sobre botones de acento (que ahora son blancos) = rojo profundo.
      textOnPrimary: bg,
      success: ajustar(const Color(0xFF7BE89C)),
      warning: ajustar(const Color(0xFFFFC46B)),
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
  // El Modo Rojo cubre toda la app, igual que el oscuro: manda por sobre el
  // slider de fondo (que solo maneja los rosados del modo diurno).
  if (ThemeService.isRedMode) return AppPalette.rojo;
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
      // En "Modo Rojo" el fondo es oscuro, así que el ThemeData tiene que
      // declararse oscuro para que los widgets de Material que se pintan
      // solos (ripples, íconos por defecto, la barra de estado) elijan sus
      // variantes claras en vez de las oscuras.
      brightness: p.esFondoOscuro ? Brightness.dark : Brightness.light,
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

  /// Tema del "Modo Rojo" — ver [AppPalette.rojo].
  static ThemeData get redTheme {
    final p = AppPalette.rojo;
    return _build(
      // Fondo oscuro ⇒ brightness oscuro, para que los widgets de Material
      // que se pintan solos (ripples, íconos por defecto, barra de estado)
      // elijan sus variantes claras.
      brightness: Brightness.dark,
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
