import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'monetization_service.dart';

/// Cupo diario, ya sin contabilidad local.
///
/// Esto fue un contador en SharedPreferences que decidia por su cuenta si se
/// podia hacer una tirada. Bloqueaba a gente con creditos comprados: el cupo
/// local decia que no antes de que el servidor pudiera decir que si, y el
/// credito pagado no se gastaba nunca. Lo fija
/// `test/core/monetization/quota_service_test.dart`.
///
/// La autoridad es el servidor (`usage_operations`, 402 cuando no hay saldo).
/// Un contador en el dispositivo ademas no era exigible: se reinicia
/// desinstalando.
///
/// La clase se queda como superficie estable para quien todavia la llama; no
/// niega nada y no cuenta nada.
class DailyUsage {
  const DailyUsage();
  int get tarotDraws => 0;
  int get oracleReads => 0;
  int get materiaRecipes => 0;
  int get cielosInvestigations => 0;
}

class QuotaService {
  Future<DailyUsage> getUsage() async => const DailyUsage();
  Future<bool> canPerform(String action, SubscriptionTier tier) async => true;
  Future<void> recordUsage(String action) async {}
  Future<int> remaining(String action, SubscriptionTier tier) async => 0;

  /// Cupo extra por ver un anuncio. Sin contabilidad local no concede nada
  /// distinto: quien decide es el servidor.
  Future<void> grantBonus(String action) async {}
}

final quotaServiceProvider = Provider<QuotaService>((ref) => QuotaService());
