import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/arcanum_api.dart';
import '../../core/crypto/grimoire_crypto.dart';
import '../../core/theme/arcanum_colors.dart';
import '../../core/theme/arcanum_theme.dart';
import '../../shared/widgets/arcanum_field.dart';
import '../../shared/widgets/gold_button.dart';

const entryTypeEs = {'ritual': 'Ritual', 'reading': 'Lectura', 'note': 'Nota', 'sigil': 'Sigilo'};

class GrimorioEditor extends ConsumerStatefulWidget {
  const GrimorioEditor({super.key});
  @override
  ConsumerState<GrimorioEditor> createState() => _GrimorioEditorState();
}

class _GrimorioEditorState extends ConsumerState<GrimorioEditor> {
  final _title = TextEditingController();
  final _content = TextEditingController();
  String _type = 'note';
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty || _content.text.trim().isEmpty) {
      setState(() => _error = 'Título y contenido son necesarios');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final api = ref.read(arcanumApiProvider);
    try {
      final enc = await ref.read(grimoireCryptoProvider).encryptText(_content.text);

      // Captura el contexto astral del momento (best-effort).
      String? moonPhase, planetaryHour, dayPlanet;
      try {
        final today = await api.today();
        moonPhase = today['moon']?['phase_name'] as String?;
        planetaryHour = today['planetary_hour']?['planet'] as String?;
        dayPlanet = today['day_ruler'] as String?;
      } catch (_) {}

      await api.grimoireCreate({
        'entry_type': _type,
        'title': _title.text.trim(),
        'encrypted_content': enc.ciphertext,
        'content_iv': enc.iv,
        'moon_phase': moonPhase,
        'planetary_hour': planetaryHour,
        'day_planet': dayPlanet,
        'entry_date': DateTime.now().toUtc().toIso8601String(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Nueva entrada', style: ArcanumText.heading(22)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: ArcanumColors.ivoryMuted),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  children: entryTypeEs.entries.map((e) {
                    final sel = e.key == _type;
                    return GestureDetector(
                      onTap: () => setState(() => _type = e.key),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          color: sel ? ArcanumColors.gold.withValues(alpha: 0.16) : Colors.transparent,
                          border: Border.all(
                              color: sel ? ArcanumColors.gold : ArcanumColors.goldMuted.withValues(alpha: 0.4)),
                        ),
                        child: Text(e.value,
                            style: ArcanumText.body(13,
                                color: sel ? ArcanumColors.gold : ArcanumColors.ivoryMuted)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                ArcanumField(controller: _title, label: 'Título'),
                const SizedBox(height: 12),
                Expanded(
                  child: TextField(
                    controller: _content,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    style: ArcanumText.body(16),
                    cursorColor: ArcanumColors.gold,
                    decoration: InputDecoration(
                      hintText: 'Escribe tu rito, lectura o nota… (se cifra en tu dispositivo)',
                      hintStyle: ArcanumText.body(15, color: ArcanumColors.ivoryMuted),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_error!, style: ArcanumText.body(14, color: ArcanumColors.error)),
                  ),
                GoldButton(label: 'Sellar entrada', loading: _saving, onPressed: _save),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
