import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/theme/arcanum_colors.dart';
import '../../../core/theme/arcanum_theme.dart';
import '../../../shared/widgets/gold_button.dart';
import '../application/sendero_controller.dart';
import '../application/sendero_guide_controller.dart';
import '../domain/sendero_catalog.dart';

class SenderoInvitationGate extends ConsumerStatefulWidget {
  const SenderoInvitationGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SenderoInvitationGate> createState() =>
      _SenderoInvitationGateState();
}

class _SenderoInvitationGateState extends ConsumerState<SenderoInvitationGate> {
  bool _checked = false;
  bool _offerVisible = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_checked) return;
    _checked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _offerIfNeeded());
  }

  Future<void> _offerIfNeeded() async {
    if (!mounted) return;
    if (ref.read(senderoGuideProvider) != null) return;
    final userId = ref.read(authProvider).user?['id']?.toString();
    if (userId == null) return;
    final progress = await ref.read(senderoControllerProvider.future);
    if (progress.isNotEmpty || ref.read(senderoGuideProvider) != null) return;

    final prefs = await SharedPreferences.getInstance();
    final hiddenKey = 'sendero_offer_hidden_$userId';
    final laterKey = 'sendero_offer_after_$userId';
    if (prefs.getBool(hiddenKey) == true) return;
    final after = prefs.getInt(laterKey) ?? 0;
    if (DateTime.now().millisecondsSinceEpoch < after || !mounted) return;

    setState(() => _offerVisible = true);
  }

  Future<void> _choose(String choice) async {
    if (!_offerVisible) return;
    setState(() => _offerVisible = false);
    final userId = ref.read(authProvider).user?['id']?.toString();
    if (userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    final hiddenKey = 'sendero_offer_hidden_$userId';
    final laterKey = 'sendero_offer_after_$userId';
    if (choice == 'open') {
      await prefs.remove(laterKey);
      if (mounted) {
        ref.read(senderoGuideProvider.notifier).start(senderoJourneys.first);
        context.go('/hoy');
      }
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
  Widget build(BuildContext context) => Stack(
    children: [
      widget.child,
      if (_offerVisible)
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: SafeArea(
            top: false,
            child: Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Material(
                  key: const ValueKey('sendero_invitation_card'),
                  color: ArcanumColors.surfaceHigh,
                  elevation: 10,
                  shape: RoundedRectangleBorder(
                    side: const BorderSide(color: ArcanumColors.goldMuted),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sendero', style: ArcanumText.heading(23)),
                        const SizedBox(height: 6),
                        Text(
                          'Una guía breve para recorrer ARCANUM a tu ritmo. Puedes dejarla en cualquier momento.',
                          style: ArcanumText.body(14),
                        ),
                        const SizedBox(height: 10),
                        GoldButton(
                          label: 'Empezar guía',
                          onPressed: () => _choose('open'),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () => _choose('later'),
                                child: const Text('Ahora no'),
                              ),
                            ),
                            Expanded(
                              child: TextButton(
                                onPressed: () => _choose('hide'),
                                child: const Text('No recordarlo'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}
