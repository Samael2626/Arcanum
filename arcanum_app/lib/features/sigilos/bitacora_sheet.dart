// Anotacion voluntaria tras olvidar un sigilo de letras.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/arcanum_api.dart';
import '../../core/astro/user_place.dart';
import '../../core/crypto/grimoire_crypto.dart';
import '../../core/theme/arcanum_colors.dart';
import '../../core/theme/arcanum_theme.dart';
import '../../shared/widgets/gold_button.dart';
import 'sigil_store.dart';

class BitacoraSheet extends ConsumerStatefulWidget {
  final bool savedCopy;
  const BitacoraSheet({super.key, this.savedCopy = false});
  @override
  ConsumerState<BitacoraSheet> createState() => _BitacoraSheetState();
}

class _BitacoraSheetState extends ConsumerState<BitacoraSheet> {
  final _note = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() { _note.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (_note.text.trim().isEmpty) {
      setState(() => _error = 'Escribe una observación antes de guardar.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      final store = SigilStore(ref.read(arcanumApiProvider), ref.read(grimoireCryptoProvider), ref.read(userPlaceProvider));
      await store.savePracticeNote(_note.text);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      debugPrint('ARCANUM bitacora: fallo al guardar ($error).');
      if (mounted) setState(() { _saving = false; _error = 'No se pudo guardar. Inténtalo de nuevo.'; });
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(child: Padding(
    padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
    child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Bitácora de práctica', style: ArcanumText.heading(24)),
      const SizedBox(height: 8),
      Text('El sigilo se soltó. Anota qué observaste, sin volver a dibujarlo. La nota se cifra en tu Grimorio.',
        style: ArcanumText.body(15, color: ArcanumColors.ivoryMuted)),
      if (widget.savedCopy) Text('La copia que ya guardaste en el Grimorio permanece allí.',
        style: ArcanumText.body(14, color: ArcanumColors.ivoryMuted)),
      const SizedBox(height: 18),
      TextField(controller: _note, minLines: 3, maxLines: 6, maxLength: 2000,
        decoration: const InputDecoration(hintText: 'Qué sentiste o notaste durante la práctica'),
        style: ArcanumText.body(16)),
      if (_error != null) Text(_error!, style: ArcanumText.body(14, color: ArcanumColors.burgundyLight)),
      GoldButton(label: 'Guardar en la Bitácora', loading: _saving, onPressed: _saving ? null : _save),
      TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('Cerrar sin anotar')),
    ])),
  ));
}
