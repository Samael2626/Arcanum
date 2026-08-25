import 'package:arcanum_app/core/monetization/monetization_service.dart';
import 'package:arcanum_app/core/monetization/quota_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// El cupo que se gana viendo un anuncio.
///
/// Suma al LÍMITE del día en vez de restar al contador. Parece lo mismo y no lo
/// es: restando se perdería cuántas veces se usó de verdad, que es el único dato
/// que dice si esto le sirve a alguien.
///
/// Y caduca con el día, como el propio límite. Un bonus que sobreviviera a la
/// noche convertiría el límite diario en un límite a secas.
void main() {
  late QuotaService cupo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    cupo = QuotaService();
  });

  String hoy() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-'
        '${n.day.toString().padLeft(2, '0')}';
  }

  group('cupo ganado por anuncio', () {
    test('sin bonus, el gratuito se queda sin materia tras una', () async {
      expect(await cupo.canPerform('materia', SubscriptionTier.free), isTrue);
      await cupo.recordUsage('materia');
      expect(await cupo.canPerform('materia', SubscriptionTier.free), isFalse);
    });

    test('el bonus devuelve exactamente una, no barra libre', () async {
      await cupo.recordUsage('materia');
      await cupo.grantBonus('materia');

      expect(await cupo.canPerform('materia', SubscriptionTier.free), isTrue);
      await cupo.recordUsage('materia');
      // La segunda se gastó: sin otro anuncio, se acabó otra vez.
      expect(await cupo.canPerform('materia', SubscriptionTier.free), isFalse);
    });

    test('dos anuncios dan dos', () async {
      await cupo.recordUsage('materia');
      await cupo.grantBonus('materia');
      await cupo.grantBonus('materia');
      await cupo.recordUsage('materia');
      expect(await cupo.canPerform('materia', SubscriptionTier.free), isTrue);
    });

    test('el bonus se cuenta en lo que queda', () async {
      await cupo.recordUsage('materia');
      expect(await cupo.remaining('materia', SubscriptionTier.free), 0);
      await cupo.grantBonus('materia');
      expect(await cupo.remaining('materia', SubscriptionTier.free), 1);
    });

    test('el bonus de una acción no abre otra', () async {
      // Ver un anuncio en Materia no puede regalar una tirada de tarot, que sí
      // cuesta dinero: cada llamada al modelo se paga.
      await cupo.grantBonus('materia');
      await cupo.recordUsage('tarot');
      expect(await cupo.canPerform('tarot', SubscriptionTier.free), isFalse);
    });

    test('el bonus de ayer no vale hoy', () async {
      // Se escribe a mano un bonus con fecha vieja, que es lo que quedaría en
      // el teléfono de quien vio un anuncio anoche.
      SharedPreferences.setMockInitialValues({
        'quota_materia_bonus_2020-01-01': 5,
        'quota_materia_${hoy()}': 1,
      });
      cupo = QuotaService();
      expect(await cupo.canPerform('materia', SubscriptionTier.free), isFalse);
    });

    test('premium no depende de esto', () async {
      for (var i = 0; i < 10; i++) {
        await cupo.recordUsage('materia');
      }
      expect(
        await cupo.canPerform('materia', SubscriptionTier.premium),
        isTrue,
      );
    });
  });
}
