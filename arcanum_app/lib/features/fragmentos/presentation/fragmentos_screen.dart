import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/arcanum_colors.dart';
import '../../../core/theme/arcanum_theme.dart';
import '../../../shared/widgets/arcane_currency_emblem.dart';
import '../../sendero/application/sendero_guide_controller.dart';
import '../../sendero/presentation/sendero_spotlight.dart';
import '../application/fragment_balance.dart';

class FragmentosScreen extends ConsumerStatefulWidget {
  const FragmentosScreen({super.key});

  @override
  ConsumerState<FragmentosScreen> createState() => _FragmentosScreenState();
}

class _FragmentosScreenState extends ConsumerState<FragmentosScreen> {
  bool _converting = false;

  Future<void> _convert(FragmentBalance balance) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Convertir Fragmentos'),
        content: Text(
          'Cambiarás ${balance.conversionRate} Fragmentos Arcanos por 1 crédito. '
          'Te quedarán ${balance.balance - balance.conversionRate} Fragmentos. '
          '¿Quieres continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Convertir'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    setState(() => _converting = true);
    try {
      await ref.read(fragmentBalanceProvider.notifier).convert();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Un crédito llegó a tu saldo.')),
        );
      }
    } on DioException catch (error) {
      if (mounted) {
        final detail = error.response?.data is Map
            ? error.response?.data['detail']?.toString()
            : null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              detail ?? 'No pudimos convertir ahora. Inténtalo de nuevo.',
            ),
          ),
        );
      }
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'fragmentos',
          context: ErrorDescription('convirtiendo fragmentos'),
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No pudimos convertir ahora. Inténtalo de nuevo.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _converting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fragments = ref.watch(fragmentBalanceProvider);
    final guide = ref.watch(senderoGuideProvider);
    final target = ref
        .read(senderoGuideTargetsProvider)
        .keyFor('fragments_balance');
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: Text('Fragmentos Arcanos', style: ArcanumText.heading(24)),
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: fragments.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, _) => Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('No pudimos consultar tus Fragmentos.'),
                        TextButton(
                          onPressed: () => ref
                              .read(fragmentBalanceProvider.notifier)
                              .refresh(),
                          child: const Text('Reintentar'),
                        ),
                      ],
                    ),
                    data: (balance) => SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            key: target,
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: ArcanumColors.surfaceHigh,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: ArcanumColors.goldMuted,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('TU PRÁCTICA', style: ArcanumText.label()),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    const ArcaneCurrencyEmblem(
                                      currency: ArcaneCurrency.fragment,
                                      size: 36,
                                    ),
                                    const SizedBox(width: 12),
                                    Flexible(
                                      child: Text(
                                        '${balance.balance} Fragmentos',
                                        style: ArcanumText.heading(32),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Sendero te da ${balance.tutorialReward} una sola vez al completar el primer recorrido. '
                                  'Estudia una carta del mazo en Oráculo y marca su ficha: '
                                  'la primera vez recibes 1 Fragmento más. No se compran.',
                                  style: ArcanumText.body(15),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              const ArcaneCurrencyEmblem(
                                currency: ArcaneCurrency.fragment,
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Text(
                                  '${balance.conversionRate} Fragmentos = 1 crédito',
                                  style: ArcanumText.heading(22),
                                ),
                              ),
                              const SizedBox(width: 9),
                              const ArcaneCurrencyEmblem(
                                currency: ArcaneCurrency.credit,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Puedes convertir hasta ${balance.weeklyConversionLimit} créditos por semana. '
                            'Te quedan ${balance.weeklyConversionsRemaining} conversiones esta semana.',
                            style: ArcanumText.body(15),
                          ),
                          const SizedBox(height: 20),
                          FilledButton(
                            onPressed:
                                _converting ||
                                    balance.balance < balance.conversionRate ||
                                    balance.weeklyConversionsRemaining == 0
                                ? null
                                : () => _convert(balance),
                            child: const Text('Convertir en crédito'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (guide?.journey.id == 'fragmentos')
          Positioned.fill(child: SenderoSpotlight(guide: guide!)),
      ],
    );
  }
}
