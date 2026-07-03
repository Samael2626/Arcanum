import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/arcanum_colors.dart';
import '../application/onboarding_controller.dart';
import 'steps/welcome_step.dart';
import 'steps/name_step.dart';
import 'steps/birth_date_step.dart';
import 'steps/birth_time_step.dart';
import 'steps/place_step.dart';

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);

    Widget stepView() {
      // last step finishes + navigates, others just advance.
      final next = state.isLast
          ? () async {
              try {
                await notifier.finish();
              } catch (_) {
                // Defensa última: PlaceStep ya exige resolver+confirmar el
                // lugar antes de llegar aquí. Si igual falla, no navegamos
                // con datos a medias — el usuario se queda en el paso actual.
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text(
                        'Falta confirmar tu lugar de nacimiento. Volvé a intentarlo.'),
                    backgroundColor: ArcanumColors.error,
                  ));
                }
                return;
              }
              if (context.mounted) context.go('/hoy');
            }
          : () => notifier.next();

      return switch (state.step) {
        0 => WelcomeStep(onNext: next),
        1 => NameStep(onNext: next, onBack: notifier.back),
        2 => BirthDateStep(onNext: next, onBack: notifier.back),
        3 => BirthTimeStep(onNext: next, onBack: notifier.back),
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
                icon: const Icon(Icons.arrow_back,
                    color: ArcanumColors.ivoryMuted),
                onPressed: notifier.back,
              ),
      ),
      body: SafeArea(child: stepView()),
    );
  }
}
