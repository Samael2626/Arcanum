import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/arcanum_api.dart';
import '../../../core/monetization/saldo.dart';

class FragmentBalance {
  const FragmentBalance({
    required this.balance,
    required this.creditsBalance,
    required this.conversionRate,
    required this.weeklyConversionsRemaining,
    required this.weeklyConversionLimit,
    required this.tutorialReward,
  });

  final int balance;
  final int creditsBalance;
  final int conversionRate;
  final int weeklyConversionsRemaining;
  final int weeklyConversionLimit;
  final int tutorialReward;

  factory FragmentBalance.fromJson(Map<String, dynamic> json) =>
      FragmentBalance(
        balance: json['balance'] as int,
        creditsBalance: json['credits_balance'] as int,
        conversionRate: json['conversion_rate'] as int,
        weeklyConversionsRemaining: json['weekly_conversions_remaining'] as int,
        weeklyConversionLimit: json['weekly_conversion_limit'] as int,
        tutorialReward: json['tutorial_reward'] as int,
      );
}

class FragmentBalanceController extends AsyncNotifier<FragmentBalance> {
  String? _conversionKey;

  @override
  Future<FragmentBalance> build() async => FragmentBalance.fromJson(
    await ref.read(arcanumApiProvider).fragmentsBalance(),
  );

  Future<void> refresh() async {
    state = await AsyncValue.guard(build);
  }

  Future<void> convert() async {
    final key = _conversionKey ??= IdempotencyKey.create();
    final updated = await ref.read(arcanumApiProvider).convertFragments(key);
    state = AsyncData(FragmentBalance.fromJson(updated));
    _conversionKey = null;
    ref.invalidate(saldoProvider);
  }
}

final fragmentBalanceProvider =
    AsyncNotifierProvider<FragmentBalanceController, FragmentBalance>(
      FragmentBalanceController.new,
      retry: (count, error) => null,
    );
