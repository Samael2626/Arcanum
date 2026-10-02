import 'dart:ui' as ui;

import 'package:arcanum_app/features/oraculo/widgets/tarot_card.dart';
import 'package:arcanum_app/shared/revelado/element_motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host({bool still = false, bool ticking = true}) => MediaQuery(
  data: MediaQueryData(disableAnimations: still),
  child: TickerMode(
    enabled: ticking,
    child: const Directionality(
      textDirection: TextDirection.ltr,
      child: ElementMotion(
        kind: MotionKind.fire,
        glow: Color(0xFFE0561F),
        accent: Color(0xFFF0854A),
      ),
    ),
  ),
);

bool _painting(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .any((p) => p.painter is MotionPainter);

void main() {
  test('cada elemento se dibuja en cualquier instante, tambien invertido', () {
    for (final kind in MotionKind.values) {
      for (final reversed in [false, true]) {
        for (final t in [0.0, 1.3, 7.25, 3600.0]) {
          final rec = ui.PictureRecorder();
          MotionPainter(
            kind: kind,
            glow: const Color(0xFF3A8FAC),
            accent: const Color(0xFF78C2D6),
            reversed: reversed,
            time: ValueNotifier(t),
          ).paint(Canvas(rec), const Size(390, 640));
          rec.endRecording().dispose();
        }
      }
    }
  });

  test('pocas piezas: aguanta un movil modesto', () {
    expect(MotionPainter.counts.values, everyElement(lessThanOrEqualTo(48)));
    expect(MotionPainter.counts.keys, containsAll(MotionKind.values));
  });

  testWidgets('se mueve: pide fotogramas mientras se ve', (tester) async {
    await tester.pumpWidget(_host());
    expect(_painting(tester), isTrue);
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.binding.hasScheduledFrame, isTrue);
  });

  testWidgets('con «reducir movimiento» no dibuja ni pide fotogramas', (
    tester,
  ) async {
    await tester.pumpWidget(_host(still: true));
    expect(_painting(tester), isFalse);
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets(
    'fuera de pantalla (TickerMode apagado) deja de pedir fotogramas',
    (tester) async {
      await tester.pumpWidget(_host(ticking: false));
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.binding.hasScheduledFrame, isFalse);
    },
  );

  test('cada carta se mueve como su luz', () {
    String motionOf(Map<String, dynamic> c) =>
        tarotAtmosphere(TarotFace.resolve(c)).motion;
    expect(
      motionOf({'slug': 'el-sol', 'arcana': 'major', 'number': 19}),
      'sol',
    );
    expect(
      motionOf({'slug': 'la-luna', 'arcana': 'major', 'number': 18}),
      'luna',
    );
    expect(
      motionOf({
        'slug': 'cinco-de-copas',
        'arcana': 'minor',
        'suit': 'cups',
        'number': 5,
      }),
      'agua',
    );
    expect(
      motionOf({
        'slug': 'as-de-bastos',
        'arcana': 'minor',
        'suit': 'wands',
        'number': 1,
      }),
      'fuego',
    );
    for (final m in ['fuego', 'agua', 'aire', 'tierra', 'sol', 'luna']) {
      expect(MotionKind.fromName(m), isNotNull, reason: m);
    }
  });
}
