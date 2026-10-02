import 'dart:ui' as ui;

import 'package:arcanum_app/features/oraculo/widgets/tarot_card.dart';
import 'package:arcanum_app/features/tarot/table/table_fx.dart';
import 'package:arcanum_app/features/tarot/table/table_geometry.dart';
import 'package:arcanum_app/features/tarot/table/table_painters.dart';
import 'package:arcanum_app/shared/revelado/element_motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

TarotFace _face(Map<String, dynamic> c) => TarotFace.resolve(c);

void _paint(CustomPainter p, Size size) {
  final rec = ui.PictureRecorder();
  p.paint(Canvas(rec), size);
  rec.endRecording().dispose();
}

void main() {
  const pose = TablePose(300, 400);

  test('un Mayor llega con destello y su glifo planetario', () {
    final sun = Imprint.of(
      _face({'slug': 'el-sol', 'arcana': 'major', 'number': 19}),
      pose,
    );
    expect(sun.major, isTrue);
    expect(sun.glyph, '☉');
    expect(sun.kind, MotionKind.sun);
    final tower = Imprint.of(
      _face({'slug': 'la-torre', 'arcana': 'major', 'number': 16}),
      pose,
    );
    expect(tower.glyph, '♂');
    expect(tower.kind, MotionKind.fire);
  });

  test('un Menor deja la huella de su palo y no lleva glifo', () {
    final cups = Imprint.of(
      _face({'slug': 'cinco-de-copas', 'arcana': 'minor', 'number': 5}),
      pose,
    );
    expect(cups.major, isFalse);
    expect(cups.glyph, isNull);
    expect(cups.kind, MotionKind.water);
  });

  test('el Loco no tiene glifo planetario: solo destello', () {
    final fool = Imprint.of(
      _face({'slug': 'el-loco', 'arcana': 'major', 'number': 0}),
      pose,
    );
    expect(fool.major, isTrue);
    expect(fool.glyph, isNull);
  });

  test('cada huella se dibuja en cualquier momento', () {
    for (final kind in MotionKind.values) {
      for (final major in [false, true]) {
        for (final t in [0.0, .01, .2, .5, .99, 1.0]) {
          _paint(
            ImprintPainter(
              Imprint(
                pose: pose,
                kind: kind,
                glow: const Color(0xFFE0561F),
                accent: const Color(0xFFF0854A),
                major: major,
                glyph: major ? '☉' : null,
              ),
              t: t,
              scale: .56,
            ),
            ImprintPiece.area,
          );
        }
      }
    }
  });

  test('el bordado se dibuja apagado, a medias y encendido', () {
    for (final t in [0.0, .3, .6, 1.0]) {
      _paint(
        EmbroideryPainter(t),
        const Size(TableGeometry.width, TableGeometry.height),
      );
    }
    expect(EmbroideryPainter(.5).shouldRepaint(EmbroideryPainter(.4)), isTrue);
  });
}
