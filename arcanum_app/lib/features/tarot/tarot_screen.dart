import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/arcanum_api.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/monetization/monetization_service.dart';
import '../../core/monetization/quota_service.dart';
import '../../core/theme/arcanum_colors.dart';
import '../../core/theme/arcanum_theme.dart';
import '../../shared/widgets/arcanum_card.dart';
import '../../shared/widgets/gold_button.dart';
import '../../shared/widgets/info_dot.dart';
import '../../shared/widgets/login_prompt.dart';

/// Glifos de la baraja (4 palos + arcanos mayores).
const _suitGlyphs = <String, String>{
  'bastos': '✦',
  'copas': '☾',
  'espadas': '⚔',
  'oros': '☀',
};

const _spreads = <(String, String)>[
  ('one_card', 'Una carta'),
  ('three_card', 'Tres cartas'),
  ('celtic_cross', 'Cruz Celta'),
];

class TarotScreen extends ConsumerWidget {
  const TarotScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    if (auth.status == AuthStatus.unknown) {
      return const Center(
        child: CircularProgressIndicator(
          color: ArcanumColors.gold,
          strokeWidth: 2,
        ),
      );
    }
    if (!auth.isAuthenticated) {
      return const LoginPrompt(
        glyph: '♃',
        title: 'El tarot te aguarda',
        description:
            'Inicia sesión para consultar las cartas y guardar tus lecturas.',
      );
    }
    return const _TarotView();
  }
}

class _TarotView extends ConsumerStatefulWidget {
  const _TarotView();
  @override
  ConsumerState<_TarotView> createState() => _TarotViewState();
}

class _TarotViewState extends ConsumerState<_TarotView> {
  late final ArcanumApi _api = ref.read(arcanumApiProvider);
  final _question = TextEditingController();

  String _spread = 'one_card';
  bool _busy = false;
  String? _error;
  List<Map<String, dynamic>>? _resolved;

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  Future<void> _draw() async {
    final tier = ref.read(subscriptionProvider).value?.tier ?? SubscriptionTier.free;
    final quota = ref.read(quotaServiceProvider);
    final canDraw = await quota.canPerform('tarot', tier);
    if (!canDraw) {
      final remaining = await quota.remaining('tarot', tier);
      if (remaining <= 0 && mounted) {
        _showQuotaExceeded();
      }
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final q = _question.text.trim().isEmpty ? null : _question.text.trim();
      final data = _spread == 'one_card'
          ? await _api.tarotDrawOne(question: q)
          : await _api.tarotSpread(spreadType: _spread, question: q);
      await quota.recordUsage('tarot');
      final resolved = ((data['resolved'] as List?) ?? const [])
          .cast<Map<String, dynamic>>();
      setState(() => _resolved = resolved);
    } catch (e) {
      setState(() {
        _resolved = null;
        _error = 'No se pudo consultar el tarot. $e';
      });
    } finally {
      setState(() => _busy = false);
    }
  }

  void _showQuotaExceeded() {
    showModalBottomSheet(
      context: context,
      backgroundColor: ArcanumColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '✦',
              style: TextStyle(fontSize: 36, color: ArcanumColors.gold),
            ),
            const SizedBox(height: 16),
            Text(
              'Cupo diario agotado',
              style: ArcanumText.heading(22),
            ),
            const SizedBox(height: 8),
            Text(
              'Has usado todas tus tiradas de tarot de hoy.',
              textAlign: TextAlign.center,
              style: ArcanumText.body(15, color: ArcanumColors.ivoryMuted),
            ),
            const SizedBox(height: 20),
            GoldButton(
              label: 'Desbloquear con Premium',
              onPressed: () {
                Navigator.of(ctx).pop();
                context.push('/paywall');
              },
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                'Volver',
                style: ArcanumText.body(14, color: ArcanumColors.ivoryMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
          children: [
            const ArcanumHeader(subtitle: 'El tarot'),
            const SizedBox(height: 10),
            const Center(child: InfoDot('tarot_spread')),
            const SizedBox(height: 20),
            // Selector de spread.
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: _spreads.map((s) {
                final sel = s.$1 == _spread;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: GestureDetector(
                    onTap: () => setState(() => _spread = s.$1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: sel
                            ? ArcanumColors.gold.withValues(alpha: 0.16)
                            : Colors.transparent,
                        border: Border.all(
                          color: sel
                              ? ArcanumColors.gold
                              : ArcanumColors.goldMuted.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        s.$2,
                        style: ArcanumText.body(
                          13,
                          color: sel
                              ? ArcanumColors.gold
                              : ArcanumColors.ivoryMuted,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _question,
              textAlign: TextAlign.center,
              style: ArcanumText.body(16, italic: true),
              cursorColor: ArcanumColors.gold,
              decoration: InputDecoration(
                hintText: 'Formula tu pregunta… (opcional)',
                hintStyle: ArcanumText.body(
                  15,
                  italic: true,
                  color: ArcanumColors.ivoryMuted,
                ),
                border: InputBorder.none,
              ),
            ),
            const SizedBox(height: 16),
            GoldButton(
              label: _spread == 'one_card'
                  ? 'Sacar una carta'
                  : 'Tirar las cartas',
              loading: _busy,
              onPressed: _draw,
            ),
            const SizedBox(height: 8),
            _QuotaIndicator(),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: ArcanumText.body(14, color: ArcanumColors.ivoryMuted),
              ),
            ],
            const SizedBox(height: 24),
            if (_resolved != null) ..._resolved!.map(_renderCard),
            const SizedBox(height: 8),
            const SectionLabel('TIRADAS DEL SISTEMA'),
            const SizedBox(height: 10),
            Text(
              'Interpretaciones según el Sistema Golden Dawn / Book T. Las cartas ya están resueltas con su significado y orientación.',
              textAlign: TextAlign.center,
              style: ArcanumText.body(13, color: ArcanumColors.ivoryMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _renderCard(Map<String, dynamic> c) {
    final reversed = c['reversed'] == true;
    final suit = (c['suit'] as String?) ?? '';
    final glyph = _suitGlyphs[suit] ?? '✧';
    final position = (c['position'] as String?) ?? '';
    final name = (c['name'] as String?) ?? (c['slug'] as String? ?? '');
    final meaning = (c['meaning'] as String?) ?? '';
    final titleBookT = (c['title_book_t'] as String?) ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        children: [
          if (position.isNotEmpty) ...[
            Text(position.toUpperCase(), style: ArcanumText.label()),
            const SizedBox(height: 8),
          ],
          ArcanumCard(
            child: Column(
              children: [
                Transform.rotate(
                  angle: reversed ? 3.14159 : 0,
                  child: Text(
                    glyph,
                    style: const TextStyle(
                      fontSize: 38,
                      color: ArcanumColors.gold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: ArcanumText.heading(24),
                ),
                if (titleBookT.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    titleBookT,
                    textAlign: TextAlign.center,
                    style: ArcanumText.body(
                      13,
                      italic: true,
                      color: ArcanumColors.goldMuted,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: reversed
                        ? ArcanumColors.burgundy
                        : ArcanumColors.surfaceHigh,
                  ),
                  child: Text(
                    reversed ? 'Invertida' : 'Al derecho',
                    style: ArcanumText.label(),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  meaning,
                  textAlign: TextAlign.center,
                  style: ArcanumText.body(16),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuotaIndicator extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tier = ref.watch(subscriptionProvider).value?.tier ?? SubscriptionTier.free;
    final quota = ref.watch(quotaServiceProvider);

    return FutureBuilder<int>(
      future: quota.remaining('tarot', tier),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final left = snap.data!;
        return Text(
          'Tiradas restantes hoy: $left',
          textAlign: TextAlign.center,
          style: ArcanumText.body(
            12,
            color: ArcanumColors.ivoryMuted.withValues(alpha: 0.7),
          ),
        );
      },
    );
  }
}
