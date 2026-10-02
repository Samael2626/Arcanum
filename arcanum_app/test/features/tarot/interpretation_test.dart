import 'package:arcanum_app/features/tarot/domain/table_models.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _json({
  Object? illumination = .634,
  String? hour = 'Venus',
  String? readAt = '2026-10-02T21:14:00Z',
}) => {
  'spread': 'three_card',
  'spread_name': 'Tres cartas',
  'moon_phase': 'Luna creciente',
  'moon_illumination': illumination,
  'planetary_hour': hour,
  'read_at': readAt,
  'cards': <Map<String, dynamic>>[],
};

void main() {
  group('cielo de la interpretacion', () {
    test('fase, luz, hora planetaria y momento en una linea', () {
      final r = Interpretation.fromJson(_json());
      final at = DateTime.utc(2026, 10, 2, 21, 14).toLocal();
      final hh = at.hour.toString().padLeft(2, '0');
      final mm = at.minute.toString().padLeft(2, '0');
      expect(r.moonIllumination, .634);
      expect(
        r.skyLine,
        'Luna creciente · 63 % iluminada · hora de Venus · '
        '${at.day} de octubre de 2026, $hh:$mm',
      );
    });

    test('sin lugar confirmado no hay hora planetaria, y no se inventa', () {
      final r = Interpretation.fromJson(_json(hour: null));
      expect(r.skyLine, isNot(contains('hora de')));
      expect(r.skyLine, startsWith('Luna creciente · 63 % iluminada · '));
    });

    test('una respuesta vieja, sin luz ni momento, se sigue leyendo', () {
      final r = Interpretation.fromJson(
        _json(illumination: null, readAt: null),
      );
      expect(r.moonIllumination, isNull);
      expect(r.readAt, isNull);
      expect(r.skyLine, 'Luna creciente · hora de Venus');
    });

    test('la luz llena llega entera aunque venga como entero', () {
      expect(
        Interpretation.fromJson(_json(illumination: 1)).moonIllumination,
        1,
      );
    });

    test('el autoguardado conserva la luz y el momento', () {
      final r = Interpretation.fromJson(_json());
      final back = Interpretation.fromJson(r.toJson());
      expect(back.moonIllumination, r.moonIllumination);
      expect(back.readAt, r.readAt);
      expect(back.skyLine, r.skyLine);
    });
  });
}
