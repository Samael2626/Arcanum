import 'package:arcanum_app/core/monetization/monetization_service.dart';
import 'package:arcanum_app/core/monetization/quota_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// El cupo local ya no niega nada, y eso es el arreglo, no una regresion.
///
/// Habia un contador en SharedPreferences que decidia por su cuenta si se podia
/// hacer una tirada. Bloqueaba a gente CON CREDITOS COMPRADOS: el contador
/// local decia que no antes de que el servidor pudiera decir que si, y el
/// credito pagado no llegaba a gastarse nunca. Un bug de dinero.
///
/// La autoridad es el servidor (`usage_operations`, 402 cuando no hay saldo).
/// Un contador en el dispositivo tampoco era exigible: se reinicia
/// desinstalando la app.
///
/// Con esto se retiro `cupo_por_anuncio_test.dart`, que fijaba el
/// comportamiento contrario — que el cupo local SI negara — y que ademas cubria
/// el bonus por anuncio, funcion inerte mientras `ADS_ENABLED` sea false. Si
/// vuelven los anuncios, el bonus se implementa contra el servidor y se prueba
/// alli, no contra una preferencia del telefono.
void main() {
  group('el cupo local no bloquea', () {
    final quota = QuotaService();

    test('un credito valido no queda bloqueado por cuota local', () async {
      expect(await quota.canPerform('oracle', SubscriptionTier.free), isTrue);
    });

    test('ninguna accion se niega, en ningun tier', () async {
      for (final accion in ['oracle', 'tarot', 'materia', 'cielos']) {
        for (final tier in SubscriptionTier.values) {
          expect(
            await quota.canPerform(accion, tier),
            isTrue,
            reason: '$accion en $tier no debe negarse en el dispositivo',
          );
        }
      }
    });

    test('registrar uso o bonus no cambia nada: no hay contabilidad local',
        () async {
      await quota.recordUsage('oracle');
      await quota.grantBonus('oracle');
      expect(await quota.canPerform('oracle', SubscriptionTier.free), isTrue);
    });
  });
}
