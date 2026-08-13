import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/arcanum_colors.dart';
import '../../../core/theme/arcanum_theme.dart';
import '../../../shared/widgets/arcanum_card.dart';
import '../../../shared/widgets/gold_button.dart';
import '../application/reading_identity_controller.dart';
import '../data/name_catalog.dart';
import '../domain/phonetic_converter.dart';
import '../domain/reading_identity.dart';

class NamePartScreen extends ConsumerStatefulWidget {
  final String partId;
  const NamePartScreen({super.key, required this.partId});

  @override
  ConsumerState<NamePartScreen> createState() => _NamePartScreenState();
}

class _NamePartScreenState extends ConsumerState<NamePartScreen> {
  final _hebrewController = TextEditingController();
  final _converter = SpanishHebrewConverter();
  ConversionProposal? _proposal;
  HebrewFormOrigin _origin = HebrewFormOrigin.arcanumContemplative;

  @override
  void dispose() {
    _hebrewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(readingIdentityProvider).value;
    final part = profile?.parts.cast<ReadingNamePart?>().firstWhere(
      (item) => item?.id == widget.partId,
      orElse: () => null,
    );
    if (part == null) {
      return const Scaffold(body: Center(child: Text('Parte no encontrada.')));
    }
    final catalog = part.type == NamePartType.givenName
        ? NameCatalog.find(part.originalText)
        : null;
    final current = part.currentForm;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: ArcanumColors.background,
        title: Text(part.originalText, style: ArcanumText.heading(24)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: [
              _ArchiveCard(part: part, catalog: catalog),
              const SizedBox(height: 18),
              _lettersCard(part, catalog),
              if (_proposal != null) ...[
                const SizedBox(height: 18),
                _proposalCard(part),
              ],
              if (current != null) ...[
                const SizedBox(height: 18),
                _GematriaCard(form: current),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _lettersCard(ReadingNamePart part, NameCatalogEntry? catalog) {
    return ArcanumCard(
      padding: const EdgeInsets.all(20),
      intensity: 0.4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('LETRAS'),
          const SizedBox(height: 10),
          Text('Elige el origen de la forma', style: ArcanumText.heading(21)),
          const SizedBox(height: 12),
          DropdownButtonFormField<HebrewFormOrigin>(
            isExpanded: true,
            initialValue: _origin,
            items: HebrewFormOrigin.values
                .where(
                  (origin) =>
                      origin != HebrewFormOrigin.historicalDocumented ||
                      (catalog?.hasHistoricalHebrew == true &&
                          part.type == NamePartType.givenName),
                )
                .map(
                  (value) =>
                      DropdownMenuItem(value: value, child: Text(value.label)),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _origin = value;
                _proposal = null;
                if (value == HebrewFormOrigin.historicalDocumented &&
                    catalog != null) {
                  _hebrewController.text = catalog.hebrew!;
                } else {
                  _hebrewController.clear();
                }
              });
            },
          ),
          const SizedBox(height: 12),
          Text(_originLimit(_origin), style: ArcanumText.body(14)),
          const SizedBox(height: 18),
          if (_origin == HebrewFormOrigin.arcanumContemplative)
            GoldButton(
              label: 'Detectar pronunciación',
              onPressed: () => setState(() {
                _proposal = _converter.propose(part.originalText, part.dialect);
                final hebrew = _proposal?.proposedHebrew;
                if (hebrew != null) _hebrewController.text = hebrew;
              }),
            )
          else ...[
            TextField(
              controller: _hebrewController,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 28),
              decoration: const InputDecoration(labelText: 'Forma hebrea'),
            ),
            const SizedBox(height: 14),
            GoldButton(
              label: 'Revisar y confirmar',
              onPressed: () => setState(() {
                _proposal = ConversionProposal(
                  ruleVersion: _origin == HebrewFormOrigin.historicalDocumented
                      ? 'catalog-hebrew-1.0.0'
                      : 'user-provided-1.0.0',
                  pronunciation: part.originalText,
                  proposedHebrew: _hebrewController.text,
                );
              }),
            ),
          ],
        ],
      ),
    );
  }

  Widget _proposalCard(ReadingNamePart part) {
    final proposal = _proposal!;
    if (proposal.unavailableReason != null) {
      return ArcanumCard(
        intensity: 0.3,
        child: Text(proposal.unavailableReason!, style: ArcanumText.body(16)),
      );
    }
    if (proposal.ambiguities.isNotEmpty) {
      final ambiguity = proposal.ambiguities.first;
      return ArcanumCard(
        padding: const EdgeInsets.all(20),
        intensity: 0.4,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionLabel('PRONUNCIACIÓN'),
            const SizedBox(height: 12),
            Text(ambiguity.question, style: ArcanumText.heading(22)),
            const SizedBox(height: 14),
            ...ambiguity.options.map(
              (option) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: OutlinedButton(
                  onPressed: () => setState(() {
                    _proposal = _converter.resolve(
                      part.originalText,
                      part.dialect,
                      option,
                    );
                    _hebrewController.text = option.hebrew;
                  }),
                  child: Text('${option.label} · ${option.hebrew}'),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ArcanumCard(
      padding: const EdgeInsets.all(20),
      intensity: 0.4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('CONFIRMAR FORMA'),
          const SizedBox(height: 10),
          Text(proposal.pronunciation, style: ArcanumText.body(14)),
          const SizedBox(height: 12),
          TextField(
            controller: _hebrewController,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 30),
            decoration: const InputDecoration(
              labelText: 'Puedes editar esta forma',
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Calcularemos exactamente las letras confirmadas. El resultado no determina tu vida ni personalidad.',
            style: ArcanumText.body(14, color: ArcanumColors.ivoryMuted),
          ),
          const SizedBox(height: 16),
          GoldButton(
            label: 'Confirmar forma y calcular',
            onPressed: () => _confirm(part, proposal),
          ),
        ],
      ),
    );
  }

  Future<void> _confirm(
    ReadingNamePart part,
    ConversionProposal proposal,
  ) async {
    await ref
        .read(readingIdentityProvider.notifier)
        .confirmForm(
          partId: part.id,
          pointedHebrew: _hebrewController.text,
          pronunciation: proposal.pronunciation,
          origin: _origin,
          ruleVersion: proposal.ruleVersion,
        );
    if (mounted) {
      setState(() => _proposal = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Forma confirmada. La versión anterior se conserva.'),
        ),
      );
    }
  }

  String _originLimit(HebrewFormOrigin origin) => switch (origin) {
    HebrewFormOrigin.historicalDocumented =>
      'La grafía aparece en la fuente citada. No prueba religión, etnia ni destino.',
    HebrewFormOrigin.userProvided =>
      'Usaremos la forma que escribas. ARCANUM no afirma que sea histórica.',
    HebrewFormOrigin.arcanumContemplative =>
      'Conversión por sonido, editable. No es traducción histórica ni nombre hebreo verdadero.',
  };
}

class _ArchiveCard extends StatelessWidget {
  final ReadingNamePart part;
  final NameCatalogEntry? catalog;
  const _ArchiveCard({required this.part, required this.catalog});

  @override
  Widget build(BuildContext context) {
    if (part.type == NamePartType.surname) {
      return ArcanumCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionLabel('ARCHIVO'),
            const SizedBox(height: 10),
            Text(
              'Archivo histórico en revisión',
              style: ArcanumText.heading(22),
            ),
            const SizedBox(height: 8),
            Text(
              'Puedes convertir y calcular este apellido. V1 no publica etimología ni interpretación simbólica. Un apellido no prueba linaje, etnia o nobleza.',
              style: ArcanumText.body(15),
            ),
          ],
        ),
      );
    }
    if (catalog == null) {
      return ArcanumCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionLabel('ARCHIVO'),
            const SizedBox(height: 10),
            Text('Archivo en crecimiento', style: ArcanumText.heading(22)),
            const SizedBox(height: 8),
            Text(
              'Aún no existe una ficha verificada para esta forma. No inventaremos origen ni significado.',
              style: ArcanumText.body(15),
            ),
          ],
        ),
      );
    }
    final entry = catalog!;
    return ArcanumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('ARCHIVO DEL NOMBRE'),
          const SizedBox(height: 10),
          Text(
            entry.meaning,
            style: ArcanumText.heading(26, color: ArcanumColors.gold),
          ),
          const SizedBox(height: 8),
          Text(
            '${entry.displayName} · ${entry.origin}',
            style: ArcanumText.body(14),
          ),
          const SizedBox(height: 6),
          Text(entry.story ?? entry.etymology, style: ArcanumText.body(16)),
          if (entry.archiveForm != null) ...[
            const SizedBox(height: 18),
            Text(entry.archiveFormLabel!, style: ArcanumText.label()),
            const SizedBox(height: 6),
            Text(
              entry.archiveForm!,
              style: ArcanumText.heading(28, color: ArcanumColors.gold),
            ),
          ],
          if (entry.traditionalRoots.isNotEmpty) ...[
            const SizedBox(height: 18),
            const SectionLabel('LECTURA TRADICIONAL DE LAS LETRAS'),
            const SizedBox(height: 10),
            ...entry.traditionalRoots.map(
              (root) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 70,
                      child: Text(
                        root.hebrew,
                        textDirection: TextDirection.rtl,
                        style: ArcanumText.heading(
                          26,
                          color: ArcanumColors.gold,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '${root.transliteration} · ${root.meaning}',
                        style: ArcanumText.body(16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Text(
              entry.traditionalRootsLimit!,
              style: ArcanumText.body(
                13,
                italic: true,
                color: ArcanumColors.ivoryMuted,
              ),
            ),
          ],
          const Divider(height: 24),
          TextButton.icon(
            onPressed: () => _showArchiveNote(context, entry),
            icon: const Icon(Icons.menu_book_outlined),
            label: const Text('Nota de archivo'),
          ),
        ],
      ),
    );
  }

  void _showArchiveNote(BuildContext context, NameCatalogEntry entry) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: ArcanumColors.surfaceHigh,
        title: Text('Nota de archivo', style: ArcanumText.heading(23)),
        content: Text(
          'Certeza: ${entry.certainty}\n\nFuente: ${entry.citation}\n\n${entry.editorialLimit}\n\n${entry.attribution}',
          style: ArcanumText.body(14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}

class _GematriaCard extends StatelessWidget {
  final ConfirmedHebrewForm form;
  const _GematriaCard({required this.form});

  @override
  Widget build(BuildContext context) => ArcanumCard(
    padding: const EdgeInsets.all(20),
    intensity: 0.4,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(form.origin.label.toUpperCase()),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            form.pointedHebrew,
            textDirection: TextDirection.rtl,
            style: const TextStyle(fontSize: 34, color: ArcanumColors.ivory),
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: form.letters
              .map(
                (letter) => Chip(
                  label: Text(
                    '${letter.glyph} · ${letter.value}',
                    textDirection: TextDirection.rtl,
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 16),
        Text(
          'Total: ${form.value}',
          style: ArcanumText.heading(26, color: ArcanumColors.gold),
        ),
        const SizedBox(height: 6),
        Text(
          '${form.gematriaVersion} · ${form.ruleVersion}',
          style: ArcanumText.body(12, color: ArcanumColors.ivoryMuted),
        ),
        const SizedBox(height: 10),
        Text(
          'Es la suma de esta escritura confirmada. No demuestra personalidad, destino ni causalidad.',
          style: ArcanumText.body(14),
        ),
      ],
    ),
  );
}
