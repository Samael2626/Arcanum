import 'package:flutter/material.dart';

import '../../core/theme/arcanum_colors.dart';
import '../../core/theme/arcanum_theme.dart';
import 'arcanum_frame.dart';
import 'arcanum_mood.dart';
import 'arcanum_surface.dart';
import 'info_dot.dart';

/// Tarjeta base de ARCANUM, ahora apoyada en el sistema de atmósferas.
///
/// Por defecto viste una atmósfera neutra sutil (pergamino vivo) con el mismo
/// borde dorado de siempre → las pantallas que ya la usan mejoran solas sin
/// recargarse. Opta a [mood] (elemento/planeta) y [frame] para el tratamiento
/// premium completo (marco biselado + florituras), como en Hoy.
class ArcanumCard extends StatelessWidget {
  final Widget child;

  /// Atmósfera del panel. Si es null → neutra (pergamino tibio).
  final ArcanumMood? mood;

  /// Dibuja el marco dorado biselado con florituras (tratamiento premium).
  final bool frame;

  final EdgeInsets padding;
  final double radius;

  /// Intensidad de la atmósfera. Si es null conserva el comportamiento clásico
  /// (0.55 sin humor, 1.0 con humor). Bájala para un panel más profundo y
  /// misterioso (menos bloom) sin tocar el resto de la app.
  final double? intensity;

  const ArcanumCard({
    super.key,
    required this.child,
    this.mood,
    this.frame = false,
    this.padding = const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
    this.radius = 16,
    this.intensity,
  });

  @override
  Widget build(BuildContext context) {
    final m = mood ?? ArcanumMood.neutral;
    final br = BorderRadius.circular(radius);

    Widget content = ArcanumSurface(
      mood: m,
      borderRadius: br,
      intensity: intensity ?? (mood == null ? 0.55 : 1.0),
      child: Padding(padding: padding, child: child),
    );
    if (frame) {
      content = ArcanumFrame(mood: mood, radius: radius, child: content);
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: br,
        border: Border.all(
            color: (mood?.accent ?? ArcanumColors.gold).withValues(alpha: 0.30)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(borderRadius: br, child: content),
    );
  }
}

/// Etiqueta dorada en versalitas (ej. "HORA PLANETARIA").
/// Con `infoKey` añade un "?" que abre la explicación del concepto.
class SectionLabel extends StatelessWidget {
  final String text;
  final String? infoKey;
  const SectionLabel(this.text, {super.key, this.infoKey});
  @override
  Widget build(BuildContext context) {
    final label = Text(text, style: ArcanumText.label());
    if (infoKey == null) return label;
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [label, const SizedBox(width: 8), InfoDot(infoKey!)],
    );
  }
}

/// Divisor ornamental con estrella central.
class Ornament extends StatelessWidget {
  const Ornament({super.key});
  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
              child: Container(
                  height: 1,
                  color: ArcanumColors.goldMuted.withValues(alpha: 0.5))),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child:
                Text('✧', style: TextStyle(color: ArcanumColors.gold, fontSize: 16)),
          ),
          Expanded(
              child: Container(
                  height: 1,
                  color: ArcanumColors.goldMuted.withValues(alpha: 0.5))),
        ],
      );
}

/// Cabecera de pantalla: wordmark ARCANUM + subtítulo + ornamento.
class ArcanumHeader extends StatelessWidget {
  final String subtitle;
  const ArcanumHeader({super.key, required this.subtitle});
  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text('ARCANUM',
              textAlign: TextAlign.center, style: ArcanumText.wordmark()),
          const SizedBox(height: 6),
          Text(subtitle,
              style: ArcanumText.body(17,
                  italic: true, color: ArcanumColors.ivoryMuted)),
          const SizedBox(height: 16),
          const Ornament(),
        ],
      );
}
