import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/arcanum_api.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/theme/arcanum_colors.dart';
import '../../core/theme/arcanum_theme.dart';
import '../../shared/astro_symbols.dart';
import '../../shared/widgets/arcanum_card.dart';
import '../../shared/widgets/gold_button.dart';
import '../../shared/widgets/info_dot.dart';
import '../../shared/widgets/login_prompt.dart';

const _spreads = <(String, String)>[
  ('three_card', 'Tres cartas'),
  ('celtic_cross', 'Cruz Celta'),
];

const _roman = ['0', 'I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X',
  'XI', 'XII', 'XIII', 'XIV', 'XV', 'XVI', 'XVII', 'XVIII', 'XIX', 'XX', 'XXI'];

class OraculoScreen extends ConsumerWidget {
  const OraculoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    if (auth.status == AuthStatus.unknown) {
      return const Center(
          child: CircularProgressIndicator(color: ArcanumColors.gold, strokeWidth: 2));
    }
    if (!auth.isAuthenticated) {
      return const LoginPrompt(
        glyph: '⛤',
        title: 'El oráculo te aguarda',
        description: 'Inicia sesión para tirar las cartas y guardar tus lecturas.',
      );
    }
    return const _OracleView();
  }
}

class _OracleView extends ConsumerStatefulWidget {
  const _OracleView();
  @override
  ConsumerState<_OracleView> createState() => _OracleViewState();
}

class _OracleViewState extends ConsumerState<_OracleView> {
  late final ArcanumApi _api = ref.read(arcanumApiProvider);
  final _question = TextEditingController();

  String _spread = 'three_card';
  bool _drawing = false;
  String? _drawError;
  List<Map<String, dynamic>>? _cards;

  bool _iaLoading = false;
  String? _iaError;
  String? _iaReply;

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  Future<void> _draw() async {
    setState(() {
      _drawing = true;
      _drawError = null;
    });
    try {
      final data = await _api.tarotDraw(_spread);
      final cards = ((data['cards_drawn'] as Map)['cards'] as List)
          .cast<Map<String, dynamic>>();
      setState(() => _cards = cards);
    } catch (e) {
      setState(() {
        _cards = null;
        _drawError = 'No se pudo consultar el oráculo. $e';
      });
    } finally {
      setState(() => _drawing = false);
    }
  }

  Future<void> _askIa() async {
    final q = _question.text.trim();
    if (q.isEmpty) {
      setState(() => _iaError = 'Formula una pregunta para la IA ritual.');
      return;
    }
    setState(() {
      _iaLoading = true;
      _iaError = null;
      _iaReply = null;
    });
    var context = '';
    try {
      final today = await _api.today();
      final moon = today['moon'] as Map<String, dynamic>;
      final hour = today['planetary_hour'] as Map<String, dynamic>;
      final dayRuler = today['day_ruler'] as String;
      context =
          'Luna: ${moon['phase_name']}. Hora planetaria: ${planetEs[hour['planet']] ?? hour['planet']}. '
          'Día regente: ${planetEs[dayRuler] ?? dayRuler}.';
    } catch (_) {
      context = '';
    }
    try {
      final res = await _api.oracleIa(context: context, question: q);
      final messages = (res['messages'] as List).cast<Map<String, dynamic>>();
      final assistant = messages.lastWhere(
        (m) => m['role'] == 'assistant',
        orElse: () => const {'content': ''},
      );
      setState(() => _iaReply = (assistant['content'] as String?) ?? '');
    } catch (e) {
      setState(() => _iaError = 'La IA ritual no respondió. $e');
    } finally {
      setState(() => _iaLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
          children: [
            const ArcanumHeader(subtitle: 'El oráculo'),
            const SizedBox(height: 10),
            const Center(child: InfoDot('tarot')),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: _spreads.map((s) {
                final sel = s.$1 == _spread;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: GestureDetector(
                    onTap: () => setState(() => _spread = s.$1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: sel ? ArcanumColors.gold.withValues(alpha: 0.16) : Colors.transparent,
                        border: Border.all(
                            color: sel ? ArcanumColors.gold : ArcanumColors.goldMuted.withValues(alpha: 0.4)),
                      ),
                      child: Text(s.$2,
                          style: ArcanumText.body(14, color: sel ? ArcanumColors.gold : ArcanumColors.ivoryMuted)),
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
                hintStyle: ArcanumText.body(15, italic: true, color: ArcanumColors.ivoryMuted),
                border: InputBorder.none,
              ),
            ),
            const SizedBox(height: 20),
            GoldButton(label: 'Consultar al oráculo', loading: _drawing, onPressed: _draw),
            if (_drawError != null) ...[
              const SizedBox(height: 14),
              Text(_drawError!,
                  textAlign: TextAlign.center,
                  style: ArcanumText.body(14, color: ArcanumColors.ivoryMuted)),
            ],
            const SizedBox(height: 24),
            if (_cards != null) ..._cards!.map(_tarotCard),
            const SizedBox(height: 8),
            const SectionLabel('IA RITUAL'),
            const SizedBox(height: 12),
            Text(
              'Interpreta tu pregunta a la luz del cielo de hoy.',
              textAlign: TextAlign.center,
              style: ArcanumText.body(14, color: ArcanumColors.ivoryMuted),
            ),
            const SizedBox(height: 16),
            GoldButton(label: 'Pedir interpretación', loading: _iaLoading, onPressed: _askIa),
            if (_iaError != null) ...[
              const SizedBox(height: 14),
              Text(_iaError!,
                  textAlign: TextAlign.center,
                  style: ArcanumText.body(14, color: ArcanumColors.ivoryMuted)),
            ],
            if (_iaReply != null) ...[
              const SizedBox(height: 16),
              ArcanumCard(
                child: Text(_iaReply!,
                    style: ArcanumText.body(16)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tarotCard(Map<String, dynamic> c) {
    final reversed = c['drawn_upright'] == false;
    final id = (c['id'] as num?)?.toInt() ?? 0;
    final position = (c['position'] as String?) ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Text(position.toUpperCase(), style: ArcanumText.label()),
          const SizedBox(height: 8),
          ArcanumCard(
            child: Column(
              children: [
                Text(id < _roman.length ? _roman[id] : '$id',
                    style: ArcanumText.heading(20, color: ArcanumColors.goldMuted)),
                const SizedBox(height: 4),
                Transform.rotate(
                  angle: reversed ? 3.14159 : 0,
                  child: const Text('✦', style: TextStyle(fontSize: 30, color: ArcanumColors.gold)),
                ),
                const SizedBox(height: 8),
                Text((c['name'] as String?) ?? '', textAlign: TextAlign.center, style: ArcanumText.heading(26)),
                const SizedBox(height: 6),
                Text(reversed ? 'Invertida' : 'Al derecho',
                    style: ArcanumText.body(13,
                        color: reversed ? ArcanumColors.burgundy : ArcanumColors.goldMuted)),
                const SizedBox(height: 12),
                Text((c['meaning'] as String?) ?? '',
                    textAlign: TextAlign.center, style: ArcanumText.body(16)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
