import 'package:flutter/material.dart';

import 'arcanum_colors.dart';

/// Estilos tipográficos del sistema: Cormorant Garamond (títulos) + Crimson Pro.
class ArcanumText {
  static TextStyle wordmark({double size = 44}) => TextStyle(
    fontFamily: 'Cormorant Garamond',
    fontSize: size,
    fontWeight: FontWeight.w600,
    letterSpacing: 10,
    color: ArcanumColors.gold,
  );

  static TextStyle heading(double size, {Color? color}) => TextStyle(
    fontFamily: 'Cormorant Garamond',
    fontSize: size,
    fontWeight: FontWeight.w600,
    color: color ?? ArcanumColors.ivory,
  );

  static TextStyle body(double size, {Color? color, bool italic = false}) =>
      TextStyle(
        fontFamily: 'Crimson Pro',
        fontSize: size,
        color: color ?? ArcanumColors.ivory,
        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
      );

  static TextStyle label() => const TextStyle(
    fontFamily: 'Crimson Pro',
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
