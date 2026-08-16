import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/arcanum_api.dart';
import '../../../core/crypto/grimoire_crypto.dart';
import '../../../core/theme/arcanum_colors.dart';
import '../../../core/theme/arcanum_theme.dart';
import '../../../shared/widgets/arcanum_card.dart';
import '../application/umbral_controller.dart';
import '../domain/umbral_reading.dart';

/// Lectura completa del Umbral, dentro del Oráculo.
///
/// Orden fijo y no negociable: primero el hecho calculado, después la lectura
/// simbólica etiquetada, después la práctica opcional y al final el criterio
/// con sus fuentes y sus límites. Invertirlo convierte una observación en una
/// sentencia con datos de adorno.
class UmbralReadingView extends ConsumerWidget {
  const UmbralReadingView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(umbralProvider);

    return state.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (reading) {
        if (reading == null || !reading.hasReading) {
          return const SizedBox.shrink();
        }
        return _Reading(reading: reading);
      },
    );
  }
}

class _Reading extends StatelessWidget {
  final UmbralReading reading;
  const _Reading({required this.reading});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ORÁCULO · ${reading.situation}',
          style: ArcanumText.body(12, color: ArcanumColors.goldMuted),
        ),
        const SizedBox(height: 14),

        _Block(
          label: 'LECTURA DEL UMBRAL',
          lines: reading.headlines,
          emphasis: true,
        ),
        if (reading.tension && reading.tensionNote != null)
          _Note(reading.tensionNote!),

        _Block(label: 'CIELO OBSERVADO', lines: reading.observedSky),
        _Block(label: 'LECTURA SIMBÓLICA', lines: reading.symbolicReading),

        if (reading.practice != null)
          _Block(
            label: 'PRÁCTICA OPCIONAL',
            lines: [reading.practice!],
            footnote: 'Opcional de verdad: no hacerla no deja nada a medias.',
          ),

        _Block(
          label: 'POR QUÉ APARECE HOY',
          lines: [...reading.whyToday, ...reading.limits],
          footnote: reading.sources.map((s) => s.text).join('\n\n'),
        ),

        const SizedBox(height: 18),
        _ReflectionCard(reading: reading),
        const SizedBox(height: 14),
        const _DeepenCta(),
        const SizedBox(height: 12),
        _Provenance(reading: reading),
      ],
    );
  }
}

class _Block extends StatelessWidget {
  final String label;
  final List<String> lines;
  final String? footnote;
  final bool emphasis;

  const _Block({
    required this.label,
    required this.lines,
    this.footnote,
    this.emphasis = false,
  });

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ArcanumCard(
        intensity: emphasis ? 0.36 : 0.26,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionLabel(label),
            const SizedBox(height: 12),
            for (final line in lines) ...[
              Text(
                line,
                style: emphasis
                    ? ArcanumText.body(17)
                    : ArcanumText.body(15, color: ArcanumColors.ivory),
              ),
              if (line != lines.last) const SizedBox(height: 10),
            ],
            if (footnote != null) ...[
              const SizedBox(height: 14),
              Text(
                footnote!,
                style: ArcanumText.body(
                  12.5,
                  italic: true,
                  color: ArcanumColors.ivoryMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  final String text;
  const _Note(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Text(
      text,
      style: ArcanumText.body(
        14,
        italic: true,
        color: ArcanumColors.ivoryMuted,
      ),
    ),
  );
}

/// Trazabilidad. Va al final y en pequeño porque no es el contenido, pero va:
/// una lectura sin versión ni motor no se puede auditar cuando algo suena mal.
class _Provenance extends StatelessWidget {
  final UmbralReading reading;
  const _Provenance({required this.reading});

  @override
  Widget build(BuildContext context) => Text(
    'Cálculo: ${reading.ephemeris} · Contrato: ${reading.contractVersion} · '
    'Selector: ${reading.selectorVersion} · '
    'Edición: ${reading.editorialVersion} · '
    'Generada: ${reading.computedAt.toIso8601String()}',
    style: ArcanumText.body(11, color: ArcanumColors.ivoryMuted),
  );
}

/// "Profundizar con el Oráculo": construida y visible, pero inerte.
///
/// El botón queda apagado a propósito. Cobra créditos, y los créditos dependen
/// de un gate de pagos que todavía no está verde. Encenderlo aquí sería atar
/// una decisión editorial ya tomada a una de cobro que no lo está.
class _DeepenCta extends StatelessWidget {
  const _DeepenCta();

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: 0.45,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ArcanumColors.gold.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            'Profundizar con el Oráculo',
            style: ArcanumText.body(15, color: ArcanumColors.gold),
          ),
          const SizedBox(height: 6),
          Text(
            'Todavía no disponible.',
            style: ArcanumText.body(12.5, color: ArcanumColors.ivoryMuted),
          ),
        ],
      ),
    ),
  );
}

/// Reflexión opt-in y cifrada.
///
/// Cerrada por defecto: una caja de texto siempre abierta bajo una lectura
/// diaria es una invitación permanente a dejar rastro, y el rastro es
/// justamente lo que hay que pedir, no dar por hecho. El texto se cifra en el
/// dispositivo antes de salir; el servidor recibe ciphertext y nonce.
class _ReflectionCard extends ConsumerStatefulWidget {
  final UmbralReading reading;
  const _ReflectionCard({required this.reading});

  @override
  ConsumerState<_ReflectionCard> createState() => _ReflectionCardState();
}

class _ReflectionCardState extends ConsumerState<_ReflectionCard> {
  final _controller = TextEditingController();
  bool _open = false;
  bool _saving = false;
  String? _message;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      final sealed = await ref
          .read(grimoireCryptoProvider)
          .encryptText(text);
      await ref.read(arcanumApiProvider).grimoireCreate({
        'entry_type': 'reflection',
        'title': 'Umbral · ${widget.reading.localDate ?? 'sin fecha'}',
        'encrypted_content': sealed.ciphertext,
        'content_iv': sealed.iv,
        'entry_date': DateTime.now().toUtc().toIso8601String(),
      });
      if (!mounted) return;
      _controller.clear();
      setState(() {
        _open = false;
        _message = 'Guardada cifrada en tu Grimorio.';
      });
    } on Object {
      if (!mounted) return;
      setState(() => _message = 'No se pudo guardar. Revisa tu conexión.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ArcanumCard(
      intensity: 0.24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('REFLEXIÓN'),
          const SizedBox(height: 10),
          if (!_open)
            TextButton(
              onPressed: () => setState(() => _open = true),
              child: Text(
                'Guardar una reflexión cifrada',
                style: ArcanumText.body(15, color: ArcanumColors.gold),
              ),
            )
          else ...[
            TextField(
              controller: _controller,
              maxLines: 4,
              style: ArcanumText.body(15),
              decoration: const InputDecoration(
                hintText: 'Lo que quieras dejar escrito de hoy.',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Se cifra en este teléfono antes de salir. El servidor guarda el '
              'texto cifrado; no puede leerlo.',
              style: ArcanumText.body(12.5, color: ArcanumColors.ivoryMuted),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                TextButton(
                  onPressed: _saving ? null : () => setState(() => _open = false),
                  child: Text(
                    'Cancelar',
                    style: ArcanumText.body(
                      14,
                      color: ArcanumColors.ivoryMuted,
                    ),
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _saving ? null : _save,
                  child: Text(
                    _saving ? 'Sellando…' : 'Sellar',
                    style: ArcanumText.body(15, color: ArcanumColors.gold),
                  ),
                ),
              ],
            ),
          ],
          if (_message != null) ...[
            const SizedBox(height: 8),
            Text(
              _message!,
              style: ArcanumText.body(13, color: ArcanumColors.ivoryMuted),
            ),
          ],
        ],
      ),
    );
  }
}
