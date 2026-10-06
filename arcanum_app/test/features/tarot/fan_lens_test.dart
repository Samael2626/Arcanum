import 'package:arcanum_app/features/tarot/table/table_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // el abanico automatico de 78: del mazo hacia la izquierda
  final base = fanPoses(
    TableGeometry.homeSpot,
    const Offset(80, TableGeometry.fanY),
    78,
  );

  test('la carta bajo el dedo se elige, sube y crece', () {
    final l = fanLens(base, base[40].offset);
    expect(l.selected, 40);
    expect(l.poses[40].y, lessThan(base[40].y - 40));
    expect(l.poses[40].scale, greaterThan(base[40].scale * 1.4));
  });

  test('las vecinas se apartan: la elegida gana sitio para el dedo', () {
    // sin lupa hay ~5 unidades entre cartas (3,27 dp en un movil de 360)
    final gap0 = (base[41].offset - base[40].offset).distance;
    final l = fanLens(base, base[40].offset);
    final gap = (l.poses[41].offset - l.poses[40].offset).distance;
    expect(gap0, lessThan(6));
    expect(gap, greaterThan(gap0 * 4));
  });

  test('lo lejano no se mueve', () {
    final l = fanLens(base, base[40].offset);
    expect(l.poses[0], base[0]);
    expect(l.poses[77], base[77]);
  });

  test('el dedo entre dos cartas elige la mas cercana', () {
    final mid = Offset.lerp(base[10].offset, base[11].offset, .3)!;
    expect(fanLens(base, mid).selected, 10);
  });

  test('sin cartas no hay eleccion', () {
    expect(fanLens(const [], Offset.zero).selected, -1);
  });
}
