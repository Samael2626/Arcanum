import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'monetization_service.dart';

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
}

final quotaServiceProvider = Provider<QuotaService>((ref) => QuotaService());