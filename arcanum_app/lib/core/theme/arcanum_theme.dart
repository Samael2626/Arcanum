import 'package:flutter/material.dart';

import 'arcanum_colors.dart';

/// Estilos tipográficos del sistema: Cormorant Garamond (títulos) + Crimson Pro.
///
/// Y un respaldo que no es cosmético. Ninguna de las dos familias trae los
/// signos del zodíaco (U+2648–U+2653) ni los glifos planetarios: comprobado
/// leyendo su tabla `cmap`, **0 de 12 en ambas**. Sin declarar un respaldo, cada
/// dispositivo elige por su cuenta qué fuente los pinta, y en algunos Android
/// eso significa emoji de colores dentro de la rueda natal.
///
/// El respaldo es **una sola familia**, `ArcanumGlifos`. Ninguna fuente libre
/// trae los 39 glifos que usa la app, así que se construye: la base es
/// Libertinus Serif —la única serif del grupo, la que acompaña a Cormorant, y
/// de ella salen la rueda del zodíaco y los planetas— y los 15 que le faltan
/// van injertados dentro desde las Noto, escalados a su tamaño. Medido: los
/// cuatro orígenes acaban con el mismo alto medio, 689.
///
/// Va como FALLBACK, no como familia principal: solo entra cuando el glifo no
/// existe en la fuente elegida, así que no toca ni una letra del texto. Y va
/// recortada a esos 39: la fuente entera pesaría 560 KB, aquí pesa 8,7 KB.
/// La genera `tool/generar_fuente_glifos.py`.
const List<String> kGlyphFallback = ['ArcanumGlifos'];

class ArcanumText {
  static TextStyle wordmark({double size = 44}) => TextStyle(
    fontFamily: 'Cormorant Garamond',
    fontFamilyFallback: kGlyphFallback,
    fontSize: size,
    fontWeight: FontWeight.w600,
    letterSpacing: 10,
    color: ArcanumColors.gold,
  );

  static TextStyle heading(double size, {Color? color}) => TextStyle(
    fontFamily: 'Cormorant Garamond',
    fontFamilyFallback: kGlyphFallback,
    fontSize: size,
    fontWeight: FontWeight.w600,
    color: color ?? ArcanumColors.ivory,
  );

  static TextStyle body(double size, {Color? color, bool italic = false}) =>
      TextStyle(
        fontFamily: 'Crimson Pro',
        fontFamilyFallback: kGlyphFallback,
        fontSize: size,
        color: color ?? ArcanumColors.ivory,
        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
      );

  static TextStyle label() => const TextStyle(
    fontFamily: 'Crimson Pro',
    fontFamilyFallback: kGlyphFallback,
    fontSize: 12,
    letterSpacing: 3,
    color: ArcanumColors.goldMuted,
    fontWeight: FontWeight.w600,
  );
}

ThemeData buildArcanumTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: ArcanumColors.background,
    colorScheme: base.colorScheme.copyWith(
      primary: ArcanumColors.gold,
      surface: ArcanumColors.surface,
    ),
    textTheme: base.textTheme.apply(
      fontFamily: 'Crimson Pro',
      fontFamilyFallback: kGlyphFallback,
      bodyColor: ArcanumColors.ivory,
      displayColor: ArcanumColors.ivory,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: ArcanumColors.surface,
      indicatorColor: ArcanumColors.gold.withValues(alpha: 0.16),
      elevation: 0,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: 'Crimson Pro',
          fontFamilyFallback: kGlyphFallback,
          fontSize: 12,
          letterSpacing: 0.5,
          color: states.contains(WidgetState.selected)
              ? ArcanumColors.gold
              : ArcanumColors.ivoryMuted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? ArcanumColors.gold
              : ArcanumColors.ivoryMuted,
          size: 24,
        ),
      ),
    ),

    // ── Los dos selectores del onboarding ────────────────────────────────
    //
    // Salían con el morado y el vino POR DEFECTO de Material 3, que es el
    // primer contacto de cada persona nueva con la app: dos pantallas donde
    // ARCANUM dejaba de parecer ARCANUM. `colorScheme.primary` no basta —
    // ambos widgets tienen su propio tema y toman de él el relleno del día
    // elegido, el fondo del reloj y el bloque de la hora.
    datePickerTheme: DatePickerThemeData(
      backgroundColor: ArcanumColors.surface,
      surfaceTintColor: Colors.transparent,
      headerBackgroundColor: ArcanumColors.surfaceHigh,
      headerForegroundColor: ArcanumColors.goldLight,
      dividerColor: ArcanumColors.goldMuted.withValues(alpha: 0.35),
      // El día elegido en oro con texto oscuro: el contraste va al revés que
      // en el resto de la app porque aquí el oro es el fondo, no la tinta.
      todayForegroundColor: WidgetStatePropertyAll(ArcanumColors.gold),
      todayBorder: BorderSide(color: ArcanumColors.gold),
      dayForegroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? ArcanumColors.background
            : ArcanumColors.ivory,
      ),
      dayBackgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? ArcanumColors.gold
            : Colors.transparent,
      ),
      yearForegroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? ArcanumColors.background
            : ArcanumColors.ivory,
      ),
      yearBackgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? ArcanumColors.gold
            : Colors.transparent,
      ),
      confirmButtonStyle: TextButton.styleFrom(
        foregroundColor: ArcanumColors.gold,
      ),
      cancelButtonStyle: TextButton.styleFrom(
        foregroundColor: ArcanumColors.ivoryMuted,
      ),
    ),
    timePickerTheme: TimePickerThemeData(
      backgroundColor: ArcanumColors.surface,
      dialBackgroundColor: ArcanumColors.surfaceHigh,
      dialHandColor: ArcanumColors.gold,
      dialTextColor: WidgetStateColor.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? ArcanumColors.background
            : ArcanumColors.ivory,
      ),
      hourMinuteColor: WidgetStateColor.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? ArcanumColors.gold.withValues(alpha: 0.22)
            : ArcanumColors.surfaceHigh,
      ),
      hourMinuteTextColor: WidgetStateColor.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? ArcanumColors.goldLight
            : ArcanumColors.ivoryMuted,
      ),
      // El AM/PM era el bloque VINO de Material. El borgoña de la casa está
      // reservado a la carta invertida del Tarot, así que aquí va oro tenue.
      dayPeriodColor: WidgetStateColor.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? ArcanumColors.gold.withValues(alpha: 0.22)
            : Colors.transparent,
      ),
      dayPeriodTextColor: WidgetStateColor.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? ArcanumColors.goldLight
            : ArcanumColors.ivoryMuted,
      ),
      dayPeriodBorderSide: BorderSide(
        color: ArcanumColors.goldMuted.withValues(alpha: 0.6),
      ),
      entryModeIconColor: ArcanumColors.goldMuted,
      confirmButtonStyle: TextButton.styleFrom(
        foregroundColor: ArcanumColors.gold,
      ),
      cancelButtonStyle: TextButton.styleFrom(
        foregroundColor: ArcanumColors.ivoryMuted,
      ),
    ),
  );
}
