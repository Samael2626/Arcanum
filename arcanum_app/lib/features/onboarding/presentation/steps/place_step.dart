import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/arcanum_api.dart';
import '../../../../core/theme/arcanum_colors.dart';
import '../../../../core/theme/arcanum_theme.dart';
import '../../../../shared/widgets/arcanum_field.dart';
import '../../../../shared/widgets/gold_button.dart';
import '../../application/onboarding_controller.dart';

/// Lugar de nacimiento: país + ciudad separados (desambigua p. ej. Córdoba-ES
/// vs Córdoba-AR), resueltos por el backend (Nominatim + timezonefinder) y
/// CONFIRMADOS por el usuario antes de avanzar. Nunca se guarda un lugar sin
/// confirmar — ver bug de Bogotá hardcodeada documentado 2026-07-01.
class PlaceStep extends ConsumerStatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;
  const PlaceStep({super.key, required this.onNext, required this.onBack});

  @override
  ConsumerState<PlaceStep> createState() => _PlaceStepState();
}

class _PlaceStepState extends ConsumerState<PlaceStep> {
  late final TextEditingController _countryCtrl;
  late final TextEditingController _cityCtrl;
  bool _resolving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final data = ref.read(onboardingProvider).data;
    _countryCtrl = TextEditingController(text: data.birthCountry ?? '');
    _cityCtrl = TextEditingController(text: data.birthCity ?? '');
  }

  @override
  void dispose() {
    _countryCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  Future<void> _resolveAndConfirm() async {
    final country = _countryCtrl.text.trim();
    final city = _cityCtrl.text.trim();
    if (country.isEmpty || city.isEmpty) {
      setState(() => _error = 'Completá país y ciudad.');
      return;
    }

    setState(() {
      _resolving = true;
      _error = null;
    });

    Map<String, dynamic> resolved;
    try {
      resolved = await ref
          .read(arcanumApiProvider)
          .geoResolve(country: country, city: city);
    } catch (e) {
      setState(() {
        _resolving = false;
        _error = _geoErrorMessage(e);
      });
      return;
    }

    setState(() => _resolving = false);
    if (!mounted) return;

    final confirmed = await _showConfirmDialog(
      displayName: resolved['display_name'] as String,
    );
    if (confirmed != true) return; // "Corregir": el usuario ajusta los campos.

    final notifier = ref.read(onboardingProvider.notifier);
    await notifier.setBirthCountry(country);
    await notifier.setBirthCity(city);
    notifier.setResolvedLocation(
      displayName: resolved['display_name'] as String,
      lat: resolved['lat'] as String,
      lon: resolved['lon'] as String,
      timezone: resolved['timezone'] as String,
    );

    widget.onNext();
  }

  Future<bool?> _showConfirmDialog({required String displayName}) {
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (ctx) => Dialog(
        backgroundColor: ArcanumColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: ArcanumColors.gold.withValues(alpha: 0.4)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('¿Es este tu lugar de nacimiento?',
                  textAlign: TextAlign.center, style: ArcanumText.heading(20)),
              const SizedBox(height: 16),
              Text(displayName,
                  textAlign: TextAlign.center,
                  style: ArcanumText.body(17, color: ArcanumColors.gold)),
              const SizedBox(height: 12),
              Text(
                'Tu Ascendente, casas y Luna se calculan a partir de estas '
                'coordenadas exactas. Confirmalo con cuidado.',
                textAlign: TextAlign.center,
                style: ArcanumText.body(13, color: ArcanumColors.ivoryMuted),
              ),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: ArcanumColors.ivoryMuted),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text('Corregir',
                        style:
                            ArcanumText.body(15, color: ArcanumColors.ivoryMuted)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GoldButton(
                    label: 'Confirmar',
                    onPressed: () => Navigator.of(ctx).pop(true),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  /// Prefiere el `detail` legible que devuelve el backend (422: ambigüedad o
  /// lugar no encontrado); nunca oculta el fallo tras un mensaje genérico
  /// que invite a "seguir igual".
  String _geoErrorMessage(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      final detail =
          (data is Map && data['detail'] is String) ? data['detail'] as String : null;
      if (e.response?.statusCode == 429) {
        return detail ?? 'Demasiados intentos. Probá de nuevo en un momento.';
      }
      return detail ?? 'No se pudo verificar el lugar. Revisá tu conexión.';
    }
    return 'No se pudo verificar el lugar. Intentá de nuevo.';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          Text('Lugar de nacimiento', style: ArcanumText.heading(24)),
          const SizedBox(height: 12),
          Text(
            'País y ciudad exactos. Determinan tu Ascendente, tus casas y tu '
            'Luna — te mostraremos el lugar resuelto para que lo confirmes.',
            style: ArcanumText.body(15, color: ArcanumColors.ivoryMuted),
          ),
          const SizedBox(height: 28),
          ArcanumField(controller: _countryCtrl, label: 'País'),
          const SizedBox(height: 16),
          ArcanumField(controller: _cityCtrl, label: 'Ciudad'),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: ArcanumText.body(14, color: ArcanumColors.error)),
          ],
          const SizedBox(height: 28),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _resolving ? null : widget.onBack,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: ArcanumColors.ivoryMuted),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                ),
                child: Text('Atrás',
                    style: ArcanumText.heading(18, color: ArcanumColors.ivoryMuted)),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: GoldButton(
                label: 'Finalizar',
                loading: _resolving,
                onPressed: _resolveAndConfirm,
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
