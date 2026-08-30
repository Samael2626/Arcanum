import 'package:arcanum_app/core/monetization/monetization_service.dart';
import 'package:arcanum_app/core/monetization/quota_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('un credito valido no queda bloqueado por cuota local', () async {
    final quota = QuotaService();
    expect(await quota.canPerform('oracle', SubscriptionTier.free), isTrue);
  });
}