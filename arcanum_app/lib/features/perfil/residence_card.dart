import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/theme/arcanum_colors.dart';
import '../../core/theme/arcanum_theme.dart';
import '../../shared/widgets/arcanum_card.dart';
import '../../shared/widgets/place_chooser.dart';

/// Texto de la residencia actual, o null si la persona no la declaro.
String? residenceLabelOf(Map<String, dynamic>? user) {
  final ciudad = (user?['current_city'] as String?)?.trim();
  return (ciudad == null || ciudad.isEmpty) ? null : ciudad;
}

/// Ciudad de nacimiento, para explicar de donde sale el cielo cuando no hay
/// residencia declarada.
String? birthLabelOf(Map<String, dynamic>? user) {
  final ciudad = (user?['birth_city'] as String?)?.trim();
  return (ciudad == null || ciudad.isEmpty) ? null : ciudad;
}

/// "Dónde vives": el lugar desde el que se mide el cielo de hoy.
///
/// Es un campo distinto del lugar de nacimiento y NO lo sustituye. La carta
/// natal se calcula siempre donde naciste y eso no cambia nunca; la hora
/// planetaria y el regente del dia salen del amanecer y el ocaso de donde estas
/// ahora.
///
/// Vacio significa "vivo donde naci", que es cierto para la mayoria: nadie tiene
/// que rellenar esto para que la app siga funcionando igual.
class ResidenceCard extends ConsumerStatefulWidget {
  const ResidenceCard({super.key});

  @override
  ConsumerState<ResidenceCard> createState() => _ResidenceCardState();
}

class _ResidenceCardState extends ConsumerState<ResidenceCard> {
  bool _saving = false;
  String? _error;

  Future<void> _edit() async {
    final user = ref.read(authProvider).user;
    final place = await showPlaceChooser(
      context,
      title: 'Dónde vives',
      confirmQuestion: '¿Es aquí donde vives?',
      initialCity: residenceLabelOf(user),
    );
    if (place == null || !mounted) return;

    await _save({
      'current_lat': place.lat,
      'current_lon': place.lon,
      'current_city': place.displayName,
      'current_timezone': place.timezone,
    });
  }

  /// Volver a "vivo donde naci". Se manda vacio, no se borra el nacimiento.
  Future<void> _clear() async {
    await _save({
      'current_lat': null,
      'current_lon': null,
      'current_city': null,
      'current_timezone': null,
    });
  }

  Future<void> _save(Map<String, dynamic> payload) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).updateProfile(payload);
      // Refresca la sesion para que `userPlaceProvider` recalcule y Hoy vuelva
      // a pedir su cielo con el lugar nuevo, sin reiniciar la app.
      await ref.read(authProvider.notifier).refreshUser();
    } catch (_) {
      if (mounted) setState(() => _error = 'No se pudo guardar tu lugar.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final residencia = residenceLabelOf(user);
    final nacimiento = birthLabelOf(user);

    return ArcanumCard(
      intensity: 0.35,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Center(child: SectionLabel('DÓNDE VIVES')),
          const SizedBox(height: 10),
          Text(
            'Desde aquí se miden la hora planetaria y el regente del día. Tu '
            'carta natal no cambia: esa se calcula siempre donde naciste.',
            style: ArcanumText.body(14, color: ArcanumColors.ivoryMuted),
          ),
          const SizedBox(height: 16),
          Text(
            residencia ?? _sinResidencia(nacimiento),
            style: ArcanumText.body(
              17,
              color: residencia == null
                  ? ArcanumColors.ivoryMuted
                  : ArcanumColors.gold,
              italic: residencia == null,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: ArcanumText.body(14, color: ArcanumColors.aspectTension),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton(
                onPressed: _saving ? null : _edit,
                child: Text(
                  residencia == null ? 'Indicar dónde vivo' : 'Cambiar',
                  style: ArcanumText.body(15, color: ArcanumColors.gold),
                ),
              ),
              if (residencia != null)
                TextButton(
                  onPressed: _saving ? null : _clear,
                  child: Text(
                    'Vivo donde nací',
                    style: ArcanumText.body(
                      15,
                      color: ArcanumColors.ivoryMuted,
                    ),
                  ),
                ),
              if (_saving) ...[
                const SizedBox(width: 8),
                const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.6,
                    color: ArcanumColors.goldMuted,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// Sin residencia declarada el cielo sale del lugar de nacimiento. Se dice
  /// cual es, en vez de dejar el hueco mudo.
  static String _sinResidencia(String? nacimiento) => nacimiento == null
      ? 'Vives donde naciste'
      : 'Vives donde naciste · $nacimiento';
}
