import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/arcanum_colors.dart';
import '../../../core/theme/arcanum_theme.dart';
import '../../../shared/widgets/arcanum_card.dart';
import '../../../shared/widgets/gold_button.dart';
import '../application/reading_identity_controller.dart';
import '../domain/reading_identity.dart';

class NameThresholdScreen extends ConsumerWidget {
  const NameThresholdScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(readingIdentityProvider);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: ArcanumColors.background,
        title: Text('Nombre y Umbral', style: ArcanumText.heading(24)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: profile.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => _ErrorState(
              onRetry: () => ref.invalidate(readingIdentityProvider),
            ),
            data: (data) => ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
              children: [
                const _PrivacyIntro(),
                const SizedBox(height: 20),
                if (data == null || data.parts.isEmpty)
                  const _EmptyState()
                else
                  ...data.parts.map(
                    (part) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _PartCard(part: part),
                    ),
                  ),
                const SizedBox(height: 8),
                GoldButton(
                  label: 'Añadir parte del nombre',
                  onPressed: () => _showAddPart(context, ref, data),
                ),
                if (data != null) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () => _export(context, ref),
                          icon: const Icon(Icons.content_copy_outlined),
                          label: const Text('Exportar local'),
                        ),
                      ),
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () => _delete(context, ref),
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Borrar perfil'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showAddPart(
    BuildContext context,
    WidgetRef ref,
    ReadingIdentityProfile? profile,
  ) async {
    final availableTypes = NamePartType.values
        .where(
          (candidate) =>
              (profile?.parts.where((part) => part.type == candidate).length ??
                  0) <
              3,
        )
        .toList(growable: false);
    if (availableTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ya guardaste tres nombres y tres apellidos.'),
        ),
      );
      return;
    }
    final draft = await showDialog<_NamePartDraft>(
      context: context,
      builder: (_) => _AddPartDialog(availableTypes: availableTypes),
    );
    if (draft == null) return;
    try {
      await ref
          .read(readingIdentityProvider.notifier)
          .addPart(
            type: draft.type,
            originalText: draft.originalText,
            dialect: draft.dialect,
          );
    } on Object {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo guardar la parte cifrada.')),
        );
      }
      return;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Parte guardada solo en este dispositivo.'),
        ),
      );
    }
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final exported = await ref
        .read(readingIdentityProvider.notifier)
        .exportLocal();
    await Clipboard.setData(ClipboardData(text: exported));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Copia local preparada en el portapapeles.'),
        ),
      );
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: ArcanumColors.surfaceHigh,
        title: Text('Borrar perfil privado', style: ArcanumText.heading(23)),
        content: const Text(
          'Se eliminarán todas las partes y versiones confirmadas de este dispositivo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(readingIdentityProvider.notifier).deleteProfile();
    }
  }
}

class _PrivacyIntro extends StatelessWidget {
  const _PrivacyIntro();

  @override
  Widget build(BuildContext context) => ArcanumCard(
    intensity: 0.35,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('PERFIL PRIVADO'),
        const SizedBox(height: 10),
        Text('Cada nombre guarda una historia', style: ArcanumText.heading(22)),
        const SizedBox(height: 8),
        Text(
          'Aquí reúnes las formas, historias y cálculos que eliges explorar. Este archivo vive cifrado en tu dispositivo.',
          style: ArcanumText.body(16),
        ),
      ],
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 28),
    child: Text(
      'Una sola parte basta. Puedes añadir hasta tres nombres y tres apellidos.',
      textAlign: TextAlign.center,
      style: ArcanumText.body(16, color: ArcanumColors.ivoryMuted),
    ),
  );
}

class _PartCard extends StatelessWidget {
  final ReadingNamePart part;
  const _PartCard({required this.part});

  @override
  Widget build(BuildContext context) => ArcanumCard(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
    child: ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(part.originalText, style: ArcanumText.heading(24)),
      subtitle: Text(
        '${part.type.label} · ${part.dialect.label}${part.currentForm == null ? '' : ' · ${part.currentForm!.value}'}',
        style: ArcanumText.body(13, color: ArcanumColors.ivoryMuted),
      ),
      trailing: const Icon(Icons.chevron_right, color: ArcanumColors.gold),
      onTap: () => context.push('/perfil/identidad/nombre-y-umbral/${part.id}'),
    ),
  );
}

class _NamePartDraft {
  final NamePartType type;
  final String originalText;
  final ReadingDialect dialect;

  const _NamePartDraft({
    required this.type,
    required this.originalText,
    required this.dialect,
  });
}

class _AddPartDialog extends StatefulWidget {
  final List<NamePartType> availableTypes;

  const _AddPartDialog({required this.availableTypes});

  @override
  State<_AddPartDialog> createState() => _AddPartDialogState();
}

class _AddPartDialogState extends State<_AddPartDialog> {
  final _controller = TextEditingController();
  late NamePartType _type = widget.availableTypes.first;
  ReadingDialect _dialect = ReadingDialect.latinAmerica;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: ArcanumColors.surfaceHigh,
    title: Text('Añadir parte', style: ArcanumText.heading(24)),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SegmentedButton<NamePartType>(
            segments: widget.availableTypes
                .map(
                  (value) =>
                      ButtonSegment(value: value, label: Text(value.label)),
                )
                .toList(),
            selected: {_type},
            onSelectionChanged: (value) => setState(() => _type = value.single),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: _type.label,
              hintText: _type == NamePartType.givenName
                  ? 'Ej. María'
                  : 'Ej. Rodríguez',
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<ReadingDialect>(
            isExpanded: true,
            initialValue: _dialect,
            decoration: const InputDecoration(labelText: 'Pronunciación'),
            items: ReadingDialect.values
                .map(
                  (value) =>
                      DropdownMenuItem(value: value, child: Text(value.label)),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => _dialect = value);
            },
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () {
          if (_controller.text.trim().isEmpty) return;
          Navigator.pop(
            context,
            _NamePartDraft(
              type: _type,
              originalText: _controller.text,
              dialect: _dialect,
            ),
          );
        },
        child: const Text('Guardar cifrado'),
      ),
    ],
  );
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('No se pudo abrir el perfil cifrado.'),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    ),
  );
}
