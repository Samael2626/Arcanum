import 'package:flutter/material.dart';

import '../../core/api/arcanum_api.dart';
import '../../core/theme/arcanum_colors.dart';
import '../../core/theme/arcanum_theme.dart';
import 'gold_button.dart';

const _reportReasons = <(String, String)>[
  ('ofensiva', 'Ofensiva'),
  ('peligrosa', 'Peligrosa'),
  ('sin_sentido', 'Sin sentido'),
];

class ContentReportButton extends StatelessWidget {
  const ContentReportButton({
    required this.api,
    required this.source,
    required this.contentRef,
    super.key,
  });

  final ArcanumApi api;
  final String source;
  final String contentRef;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () => showContentReportSheet(
        context,
        api: api,
        source: source,
        contentRef: contentRef,
      ),
      icon: const Icon(Icons.flag_outlined, size: 17),
      label: const Text('Reportar esta respuesta'),
    );
  }
}

Future<void> showContentReportSheet(
  BuildContext context, {
  required ArcanumApi api,
  required String source,
  required String contentRef,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: ArcanumColors.surface,
    builder: (_) => _ContentReportSheet(
      api: api,
      source: source,
      contentRef: contentRef,
      onSubmitted: () => messenger.showSnackBar(
        const SnackBar(content: Text('Reporte enviado. Gracias.')),
      ),
    ),
  );
}

class _ContentReportSheet extends StatefulWidget {
  const _ContentReportSheet({
    required this.api,
    required this.source,
    required this.contentRef,
    required this.onSubmitted,
  });

  final ArcanumApi api;
  final String source;
  final String contentRef;
  final VoidCallback onSubmitted;

  @override
  State<_ContentReportSheet> createState() => _ContentReportSheetState();
}

class _ContentReportSheetState extends State<_ContentReportSheet> {
  final _noteController = TextEditingController();
  String? _selectedReason;
  bool _sending = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _selectedReason;
    if (reason == null || _sending) return;
    setState(() => _sending = true);
    try {
      await widget.api.createContentReport(
        source: widget.source,
        contentRef: widget.contentRef,
        reason: reason,
        note: _noteController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onSubmitted();
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo enviar el reporte. Inténtalo de nuevo.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Reportar esta respuesta', style: ArcanumText.heading(24)),
          const SizedBox(height: 12),
          RadioGroup<String>(
            groupValue: _selectedReason,
            onChanged: _sending
                ? (_) {}
                : (value) => setState(() => _selectedReason = value),
            child: Column(
              children: [
                for (final reason in _reportReasons)
                  RadioListTile<String>(
                    value: reason.$1,
                    title: Text(reason.$2),
                    activeColor: ArcanumColors.gold,
                  ),
              ],
            ),
          ),
          TextField(
            controller: _noteController,
            maxLength: 1000,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Nota opcional'),
          ),
          const SizedBox(height: 12),
          IgnorePointer(
            ignoring: _selectedReason == null || _sending,
            child: Opacity(
              opacity: _selectedReason == null ? 0.5 : 1,
              child: GoldButton(
                label: 'Enviar reporte',
                loading: _sending,
                onPressed: _submit,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
