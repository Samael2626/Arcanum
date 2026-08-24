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
  );
}
