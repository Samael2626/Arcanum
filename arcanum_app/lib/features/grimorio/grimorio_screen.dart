import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/arcanum_api.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/theme/arcanum_colors.dart';
import '../../core/theme/arcanum_theme.dart';
import '../../shared/astro_symbols.dart';
import '../../shared/widgets/arcanum_card.dart';
import '../../shared/widgets/info_dot.dart';
import '../../shared/widgets/login_prompt.dart';
import 'grimorio_detail.dart';
import 'grimorio_editor.dart';

class GrimorioScreen extends ConsumerStatefulWidget {
  const GrimorioScreen({super.key});
  @override
  ConsumerState<GrimorioScreen> createState() => _GrimorioScreenState();
}

class _GrimorioScreenState extends ConsumerState<GrimorioScreen> {
  late final ArcanumApi _api = ref.read(arcanumApiProvider);
  Future<List<Map<String, dynamic>>>? _future;

  void _refresh() => setState(() => _future = _api.grimoireList());

  Future<void> _newEntry() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const GrimorioEditor()),
    );
    if (saved == true) _refresh();
  }

  Future<void> _open(String id) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => GrimorioDetail(id: id)),
    );
    if (changed == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    if (auth.status == AuthStatus.unknown) {
      return const Center(child: CircularProgressIndicator(color: ArcanumColors.gold, strokeWidth: 2));
    }
    if (!auth.isAuthenticated) {
      return const LoginPrompt(
        glyph: '❦',
        title: 'Tu grimorio te aguarda',
        description: 'Inicia sesión para abrir tu libro personal, cifrado de extremo a extremo.',
      );
    }
    _future ??= _api.grimoireList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: _newEntry,
        backgroundColor: ArcanumColors.gold,
        foregroundColor: ArcanumColors.background,
        child: const Icon(Icons.add),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: ArcanumColors.gold, strokeWidth: 2));
              }
              final entries = snap.data ?? const [];
              return ListView(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 90),
                children: [
                  Text('Grimorio', textAlign: TextAlign.center, style: ArcanumText.heading(34)),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Tu libro cifrado',
                          style: ArcanumText.body(15, italic: true, color: ArcanumColors.ivoryMuted)),
                      const SizedBox(width: 8),
                      const InfoDot('grimorio'),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (entries.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 60),
                      child: Text('Aún no has sellado ninguna entrada.\nToca + para empezar.',
                          textAlign: TextAlign.center,
                          style: ArcanumText.body(16, color: ArcanumColors.ivoryMuted)),
                    )
                  else
                    ...entries.map(_entryCard),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _entryCard(Map<String, dynamic> e) {
    final ph = e['planetary_hour'] as String?;
    final moon = e['moon_phase'] as String?;
    final date = (e['entry_date'] as String).split('T').first;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => _open(e['id'] as String),
        child: ArcanumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Text(e['title'] as String, style: ArcanumText.heading(20))),
                Text(entryTypeEs[e['entry_type']] ?? '', style: ArcanumText.label()),
              ]),
              const SizedBox(height: 6),
              Text(
                [
                  date,
                  if (moon != null) '☽ $moon',
                  if (ph != null) '${planetGlyph[ph] ?? ''} ${planetEs[ph] ?? ph}',
                ].join('   ·   '),
                style: ArcanumText.body(13, color: ArcanumColors.goldMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
