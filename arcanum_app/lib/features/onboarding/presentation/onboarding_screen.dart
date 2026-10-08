import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/arcanum_api.dart';
import '../../../core/privacy/consent_policy.dart';
import '../../../core/theme/arcanum_colors.dart';
import '../application/onboarding_controller.dart';
import 'steps/welcome_step.dart';
import 'steps/name_step.dart';
import 'steps/birth_date_step.dart';
import 'steps/birth_time_step.dart';
import 'steps/place_step.dart';
import 'steps/sensitive_data_consent_step.dart';

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);

    Future<void> grantSensitiveData() async {
      await ref
          .read(arcanumApiProvider)
          .recordConsent(
            kind: 'datos_sensibles',
            policyVersion: sensitiveDataConsentPolicyVersion,
            granted: true,
          );
      notifier.setSensitiveDataConsent(true);
      notifier.next();
    }

    Future<void> declineSensitiveData() async {
      try {
        await ref
            .read(arcanumApiProvider)
            .recordConsent(
              kind: 'datos_sensibles',
              policyVersion: sensitiveDataConsentPolicyVersion,
              granted: false,
            );
      } catch (_) {
        // Un rechazo no puede bloquear el resto de la app.
      }
      notifier.setSensitiveDataConsent(false);
      await notifier.finishWithoutSensitiveData();
      if (context.mounted) context.go('/hoy');
    }

    Widget stepView() {
      // last step finishes + navigates, others just advance.
      final next = state.isLast
          ? () async {
              try {
                await notifier.finish();
              } catch (error, stackTrace) {
                // Defensa última: PlaceStep ya exige resolver+confirmar el
                // lugar antes de llegar aquí. Si igual falla, no navegamos
                // con datos a medias — el usuario se queda en el paso actual.
                // El fallo de red al persistir NO llega aquí: finish() lo
                // captura y deja el perfil pendiente de reintento.
                FlutterError.reportError(
                  FlutterErrorDetails(
                    exception: error,
                    stack: stackTrace,
                    library: 'arcanum onboarding',
                    context: ErrorDescription('finalizando el onboarding'),
                    silent: true,
                  ),
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Falta confirmar tu lugar de nacimiento. Inténtalo de nuevo.',
                      ),
                      backgroundColor: ArcanumColors.error,
                    ),
                  );
                }
                return;
              }
              if (context.mounted) context.go('/hoy');
            }
          : () => notifier.next();

      return switch (state.step) {
        0 => WelcomeStep(onNext: next),
        1 => SensitiveDataConsentStep(
          onGranted: grantSensitiveData,
          onDeclined: declineSensitiveData,
        ),
        2 => NameStep(onNext: next, onBack: notifier.back),
        3 => BirthDateStep(onNext: next, onBack: notifier.back),
        4 => BirthTimeStep(onNext: next, onBack: notifier.back),
        _ => PlaceStep(onNext: next, onBack: notifier.back),
      };
    }

    return Scaffold(
      backgroundColor: ArcanumColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: state.isFirst
            ? null
            : IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  color: ArcanumColors.ivoryMuted,
                ),
                onPressed: notifier.back,
              ),
      ),
      body: SafeArea(child: stepView()),
    );
  }
}
