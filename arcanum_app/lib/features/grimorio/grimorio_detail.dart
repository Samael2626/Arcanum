import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/arcanum_api.dart';
import '../../core/crypto/grimoire_crypto.dart';
import '../../core/theme/arcanum_colors.dart';
import '../../core/theme/arcanum_theme.dart';
import '../../shared/astro_symbols.dart';
import 'grimorio_editor.dart' show entryTypeEs;

class GrimorioDetail extends ConsumerStatefulWidget {
  final String id;
  const GrimorioDetail({super.key, required this.id});
  @override
  ConsumerState<GrimorioDetail> createState() => _GrimorioDetailState();
}

class _GrimorioDetailState extends ConsumerState<GrimorioDetail> {
  late final ArcanumApi _api = ref.read(arcanumApiProvider);
  late Future<(Map<String, dynamic>, String)> _future = _load();

  Future<(Map<String, dynamic>, String)> _load() async {
    final entry = await _api.grimoireGet(widget.id);
    final content = await ref
        .read(grimoireCryptoProvider)
        .decryptText(entry['encrypted_content'] as String, entry['content_iv'] as String);
    return (entry, content);
  }

  Future<void> _delete() async {
    await _api.grimoireDelete(widget.id);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: ArcanumColors.ivoryMuted),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: ArcanumColors.burgundy),
            onPressed: _delete,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: FutureBuilder<(Map<String, dynamic>, String)>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: ArcanumColors.gold, strokeWidth: 2));
              }
              if (snap.hasError) {
                return Center(
                    child: Text('No se pudo descifrar.\n${snap.error}',
                        textAlign: TextAlign.center,
                        style: ArcanumText.body(14, color: ArcanumColors.ivoryMuted)));
              }
              final entry = snap.data!.$1;
              final content = snap.data!.$2;
              final ph = entry['planetary_hour'] as String?;
              final dp = entry['day_planet'] as String?;
              final moon = entry['moon_phase'] as String?;
              final ctx = [
                if (moon != null) '☽ $moon',
                if (ph != null) '${planetGlyph[ph] ?? ''} hora de ${planetEs[ph] ?? ph}',
                if (dp != null) 'día de ${planetEs[dp] ?? dp}',
              ].join('   ·   ');
              return ListView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                children: [
                  Text(entryTypeEs[entry['entry_type']] ?? entry['entry_type'] as String,
                      style: ArcanumText.label()),
                  const SizedBox(height: 6),
                  Text(entry['title'] as String, style: ArcanumText.heading(30)),
                  if (ctx.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(ctx, style: ArcanumText.body(13, color: ArcanumColors.goldMuted)),
                  ],
                  const Divider(color: ArcanumColors.surfaceHigh, height: 32),
                  Text(content, style: ArcanumText.body(17)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
