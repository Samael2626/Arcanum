import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/theme/arcanum_colors.dart';
import '../../../core/theme/arcanum_theme.dart';
import '../../../shared/widgets/gold_button.dart';
import '../application/sendero_controller.dart';

class SenderoInvitationGate extends ConsumerStatefulWidget {
  const SenderoInvitationGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SenderoInvitationGate> createState() =>
      _SenderoInvitationGateState();
}

class _SenderoInvitationGateState extends ConsumerState<SenderoInvitationGate> {
  bool _checked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_checked) return;
    _checked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _offerIfNeeded());
  }

  Future<void> _offerIfNeeded() async {
    if (!mounted) return;
    final userId = ref.read(authProvider).user?['id']?.toString();
    if (userId == null) return;
    final progress = await ref.read(senderoControllerProvider.future);
    if (progress.isNotEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final hiddenKey = 'sendero_offer_hidden_$userId';
    final laterKey = 'sendero_offer_after_$userId';
    if (prefs.getBool(hiddenKey) == true) return;
    final after = prefs.getInt(laterKey) ?? 0;
    if (DateTime.now().millisecondsSinceEpoch < after || !mounted) return;

    final choice = await showModalBottomSheet<String>(
      context: context,
      isDismissible: true,
      backgroundColor: ArcanumColors.surfaceHigh,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sendero', style: ArcanumText.heading(32)),
              const SizedBox(height: 10),
              Text(
                'Una guía breve para recorrer ARCANUM a tu ritmo. Puedes dejarla en cualquier momento.',
                style: ArcanumText.body(17),
              ),
              const SizedBox(height: 22),
              GoldButton(
                label: 'Abrir Sendero',
                onPressed: () => Navigator.pop(sheetContext, 'open'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(sheetContext, 'later'),
                      child: const Text('Ahora no'),
                    ),
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(sheetContext, 'hide'),
                      child: const Text('No recordarlo'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted) return;
    if (choice == 'open') {
      await prefs.remove(laterKey);
      if (mounted) context.push('/sendero');
    } else if (choice == 'hide') {
      await prefs.setBool(hiddenKey, true);
      await ref
          .read(senderoControllerProvider.notifier)
          .advance(
            journeyId: 'orientation',
            version: 1,
            step: 0,
            status: 'dismissed',
          );
    } else {
      final retry = DateTime.now().add(const Duration(days: 3));
      await prefs.setInt(laterKey, retry.millisecondsSinceEpoch);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
