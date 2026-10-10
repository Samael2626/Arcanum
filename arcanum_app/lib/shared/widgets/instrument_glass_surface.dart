import 'package:flutter/material.dart';

/// Vidrio ahumado con esmalte profundo para el instrumento de Hoy.
class InstrumentGlassSurface extends StatelessWidget {
  const InstrumentGlassSurface({super.key, this.radius = 18});

  final double radius;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0x80BFC9D8), width: 0.8),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xC948515E),
            Color(0xE8252A35),
            Color(0xF0191923),
            Color(0xF221181E),
          ],
          stops: [0, 0.3, 0.68, 1],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26FFFFFF),
            blurRadius: 1,
            offset: Offset(0, 1),
            spreadRadius: -0.5,
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: const Alignment(0.5, 0.2),
                  colors: [
                    const Color(0x33FFFFFF),
                    Colors.transparent,
                    Colors.transparent,
                    const Color(0x0FC9A84C),
                  ],
                  stops: const [0, 0.24, 0.72, 1],
                ),
              ),
            ),
          ),
          IgnorePointer(
            child: Padding(
              padding: const EdgeInsets.all(5),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(
                    (radius - 5).clamp(0.0, radius).toDouble(),
                  ),
                  border: Border.all(
                    color: const Color(0x24E4D4A6),
                    width: 0.7,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
