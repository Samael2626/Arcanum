import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/arcanum_api.dart';
import '../../core/theme/arcanum_colors.dart';
import '../../core/theme/arcanum_theme.dart';
import '../../shared/widgets/arcanum_card.dart';
import '../../shared/widgets/gold_button.dart';

const _spreads = <(String, String)>[('single', 'Una carta'), ('three', 'Tres cartas')];

const _roman = ['0', 'I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X',
  'XI', 'XII', 'XIII', 'XIV', 'XV', 'XVI', 'XVII', 'XVIII', 'XIX', 'XX', 'XXI'];

class OraculoScreen extends ConsumerStatefulWidget {
  const OraculoScreen({super.key});
  @override
  ConsumerState<OraculoScreen> createState() => _OraculoScreenState();
}

class _OraculoScreenState extends ConsumerState<OraculoScreen> {
  final _question = TextEditingController();
  String _spread = 'three';
  bool _loading = false;
  List<Map<String, dynamic>>? _cards;

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  Future<void> _draw() async {
    setState(() => _loading = true);
    try {
      final res = await ref.read(arcanumApiProvider).tarotDraw(_spread);
      setState(() => _cards = (res['cards'] as List).cast<Map<String, dynamic>>());
    } catch (_) {
      setState(() => _cards = null);
    } finally {
      setState(() => _loading = false);
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
            const SizedBox(height: 24),
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
            GoldButton(label: 'Consultar al oráculo', loading: _loading, onPressed: _draw),
            const SizedBox(height: 24),
            if (_cards != null) ..._cards!.map(_tarotCard),
          ],
        ),
      ),
    );
  }

  Widget _tarotCard(Map<String, dynamic> c) {
    final reversed = c['orientation'] == 'reversed';
    final number = c['number'] as int;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Text((c['position'] as String).toUpperCase(), style: ArcanumText.label()),
          const SizedBox(height: 8),
          ArcanumCard(
            child: Column(
              children: [
                Text(number < _roman.length ? _roman[number] : '$number',
                    style: ArcanumText.heading(20, color: ArcanumColors.goldMuted)),
                const SizedBox(height: 4),
                Transform.rotate(
                  angle: reversed ? 3.14159 : 0,
                  child: const Text('✦', style: TextStyle(fontSize: 30, color: ArcanumColors.gold)),
                ),
                const SizedBox(height: 8),
                Text(c['name'] as String, textAlign: TextAlign.center, style: ArcanumText.heading(26)),
                const SizedBox(height: 6),
                Text(reversed ? 'Invertida' : 'Al derecho',
                    style: ArcanumText.body(13,
                        color: reversed ? ArcanumColors.burgundy : ArcanumColors.goldMuted)),
                const SizedBox(height: 12),
                Text(c['meaning'] as String,
                    textAlign: TextAlign.center, style: ArcanumText.body(16)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
