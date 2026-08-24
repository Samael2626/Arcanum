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
/// El respaldo son cuatro familias, y **el orden es el diseño**: Libertinus
/// Serif pone los 24 glifos que tiene —es la única serif del grupo, la que
/// acompaña a Cormorant— y las Noto solo rellenan los 15 que a ella le faltan.
/// Entre las cuatro cubren los 39, medidos sobre `lib/`.
///
/// Van como FALLBACK, no como familia principal: solo entran cuando el glifo no
/// existe en la fuente elegida, así que no tocan ni una letra del texto. Y van
/// recortadas a esos 39 glifos: completas pesarían 2,2 MB, aquí pesan 11 KB.
/// Las genera `tool/generar_fuente_glifos.py`.
const List<String> kGlyphFallback = [
  'ArcanumGlifos',
  'ArcanumGlifosB',
  'ArcanumGlifosC',
  'ArcanumGlifosD',
];

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
  );
}
