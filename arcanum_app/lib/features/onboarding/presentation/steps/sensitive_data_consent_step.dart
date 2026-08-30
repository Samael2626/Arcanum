import 'package:flutter/material.dart';

import '../../../../core/theme/arcanum_colors.dart';
import '../../../../core/theme/arcanum_theme.dart';
import '../../../../shared/widgets/gold_button.dart';

class SensitiveDataConsentStep extends StatefulWidget {
  const SensitiveDataConsentStep({
    required this.onGranted,
    required this.onDeclined,
    super.key,
  });

  final Future<void> Function() onGranted;
  final Future<void> Function() onDeclined;

  @override
  State<SensitiveDataConsentStep> createState() =>
      _SensitiveDataConsentStepState();
}

class _SensitiveDataConsentStepState extends State<SensitiveDataConsentStep> {
  bool _busy = false;
  String? _error;

  Future<void> _submit(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'No pudimos guardar tu decisión. Inténtalo de nuevo.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          Text('Tus datos sensibles', style: ArcanumText.heading(24)),
          const SizedBox(height: 16),
          Text(
            'Tu fecha, hora y lugar de nacimiento y lo que escribas sobre tu práctica pueden revelar convicciones personales. Entregarlos es voluntario.',
            style: ArcanumText.body(17),
          ),
          const SizedBox(height: 12),
          Text(
            'Puedes retirar tu autorización desde Ajustes y borrar estos datos cuando quieras.',
            style: ArcanumText.body(15, color: ArcanumColors.ivoryMuted),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              style: ArcanumText.body(14, color: ArcanumColors.error),
            ),
          ],
          const Spacer(),
          GoldButton(
            label: 'Acepto compartirlos',
            loading: _busy,
            onPressed: () => _submit(widget.onGranted),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _busy ? null : () => _submit(widget.onDeclined),
            child: const Text('Continuar sin datos sensibles'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
