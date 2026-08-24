import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/theme/arcanum_colors.dart';
import '../../core/theme/arcanum_theme.dart';
import '../../shared/widgets/arcanum_card.dart';
import '../../shared/widgets/gold_button.dart';
import 'account_deletion_service.dart';
import 'ai_consent_settings_card.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _deleting = false;
  final _deleteInput = TextEditingController();

  @override
  void dispose() {
    _deleteInput.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete() async {
    _deleteInput.clear();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: ArcanumColors.surfaceHigh,
          title: Text(
            'Eliminar cuenta',
            style: ArcanumText.heading(25, color: ArcanumColors.burgundyLight),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Se borrarán para siempre tu carta natal, grimorio, tiradas y conversaciones.',
                style: ArcanumText.body(16),
              ),
              const SizedBox(height: 18),
              Text(
                'Escribe ELIMINAR para confirmar.',
                style: ArcanumText.body(14, color: ArcanumColors.ivoryMuted),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _deleteInput,
                autofocus: true,
                onChanged: (_) => setDialogState(() {}),
                decoration: const InputDecoration(hintText: 'ELIMINAR'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: _deleteInput.text == 'ELIMINAR'
                  ? () => Navigator.pop(dialogContext, true)
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: ArcanumColors.error,
              ),
              child: const Text('Borrar todo'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await ref.read(accountDeletionServiceProvider).deleteAccount();
      if (mounted) context.go('/hoy');
    } catch (error) {
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo eliminar la cuenta. $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final user = auth.user;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: ArcanumColors.background,
        title: Text('Ajustes', style: ArcanumText.heading(24)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: [
              const ArcanumHeader(subtitle: 'Cuenta y custodia'),
              const SizedBox(height: 24),
              ArcanumCard(
                child: auth.isAuthenticated
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionLabel('TU CUENTA'),
                          const SizedBox(height: 14),
                          Text(
                            (user?['display_name'] as String?) ?? 'Practicante',
                            style: ArcanumText.heading(24),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            (user?['email'] as String?) ?? '',
                            style: ArcanumText.body(
                              15,
                              color: ArcanumColors.ivoryMuted,
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextButton.icon(
                            onPressed: () =>
                                ref.read(authProvider.notifier).logout(),
                            icon: const Icon(Icons.logout),
                            label: const Text('Cerrar sesión'),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          Text(
                            'Inicia sesión para administrar tu cuenta.',
                            style: ArcanumText.body(16),
                          ),
                          const SizedBox(height: 18),
                          GoldButton(
                            label: 'Iniciar sesión',
                            onPressed: () => context.go('/login'),
                          ),
                        ],
                      ),
              ),
              if (auth.isAuthenticated) ...[
                const SizedBox(height: 20),
                const AiConsentSettingsCard(),
                const SizedBox(height: 20),
                ArcanumCard(
                  intensity: 0.35,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ZONA IRREVERSIBLE',
                        style: ArcanumText.label().copyWith(
                          color: ArcanumColors.burgundyLight,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Elimina tu cuenta y todos los datos asociados.',
                        style: ArcanumText.body(16),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _deleting ? null : _confirmDelete,
                        icon: _deleting
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.delete_forever_outlined),
                        label: Text(
                          _deleting ? 'Eliminando…' : 'Eliminar cuenta y datos',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: ArcanumColors.burgundyLight,
                          side: const BorderSide(color: ArcanumColors.error),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
