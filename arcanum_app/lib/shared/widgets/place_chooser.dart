import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/arcanum_api.dart';
import '../../core/theme/arcanum_colors.dart';
import '../../core/theme/arcanum_theme.dart';
import 'arcanum_field.dart';
import 'gold_button.dart';

/// Un lugar ya resuelto y confirmado por la persona.
class ChosenPlace {
  const ChosenPlace({
    required this.displayName,
    required this.lat,
    required this.lon,
    required this.timezone,
  });

  final String displayName;
  final String lat;
  final String lon;
  final String timezone;
}

/// El UNICO sitio del cliente donde se elige un lugar.
///
/// Existe para que el selector de ciudades, cuando llegue, se cambie en UN sitio
/// y lo hereden a la vez el onboarding y el perfil. Hoy son dos campos de texto
/// resueltos por el servidor (Nominatim) y CONFIRMADOS antes de devolverse: es
/// el flujo que ya estaba probado en el onboarding, movido aqui sin tocarlo.
///
/// Cuando entre el dataset empaquetado de ciudades, lo que cambia es el interior
/// de este widget: la firma (`showPlaceChooser` -> `ChosenPlace?`) esta pensada
/// para no moverse.
///
/// Nunca devuelve un lugar sin confirmar, y nunca uno por omision: si la persona
/// cancela, devuelve null. Ese fue el bug de Bogota.
Future<ChosenPlace?> showPlaceChooser(
  BuildContext context, {
  required String title,
  required String confirmQuestion,
  String? initialCountry,
  String? initialCity,
}) {
  return showModalBottomSheet<ChosenPlace>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PlaceChooserSheet(
      title: title,
      confirmQuestion: confirmQuestion,
      initialCountry: initialCountry,
      initialCity: initialCity,
    ),
  );
}

class _PlaceChooserSheet extends ConsumerStatefulWidget {
  const _PlaceChooserSheet({
    required this.title,
    required this.confirmQuestion,
    this.initialCountry,
    this.initialCity,
  });

  final String title;
  final String confirmQuestion;
  final String? initialCountry;
  final String? initialCity;

  @override
  ConsumerState<_PlaceChooserSheet> createState() => _PlaceChooserSheetState();
}

class _PlaceChooserSheetState extends ConsumerState<_PlaceChooserSheet> {
  late final TextEditingController _country = TextEditingController(
    text: widget.initialCountry ?? '',
  );
  late final TextEditingController _city = TextEditingController(
    text: widget.initialCity ?? '',
  );
  bool _resolving = false;
  String? _error;

  @override
  void dispose() {
    _country.dispose();
    _city.dispose();
    super.dispose();
  }

  Future<void> _resolve() async {
    final country = _country.text.trim();
    final city = _city.text.trim();
    if (country.isEmpty || city.isEmpty) {
      setState(() => _error = 'Completa país y ciudad.');
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
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _resolving = false;
        _error = placeChooserErrorMessage(error);
      });
      return;
    }

    if (!mounted) return;
    setState(() => _resolving = false);

    final place = ChosenPlace(
      displayName: resolved['display_name'] as String,
      lat: resolved['lat'] as String,
      lon: resolved['lon'] as String,
      timezone: resolved['timezone'] as String,
    );

    final ok = await _confirm(place.displayName);
    if (ok != true || !mounted) return;
    Navigator.of(context).pop(place);
  }

  /// Confirmar NO es un tramite: Nominatim devuelve el primer resultado, y
  /// "Cordoba" es una ciudad distinta en Espana y en Argentina.
  Future<bool?> _confirm(String displayName) {
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
              Text(
                widget.confirmQuestion,
                textAlign: TextAlign.center,
                style: ArcanumText.heading(20),
              ),
              const SizedBox(height: 16),
              Text(
                displayName,
                textAlign: TextAlign.center,
                style: ArcanumText.body(17, color: ArcanumColors.gold),
              ),
              const SizedBox(height: 22),
              GoldButton(
                label: 'Sí, es este',
                onPressed: () => Navigator.of(ctx).pop(true),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(
                  'Corregir',
                  style: ArcanumText.body(15, color: ArcanumColors.ivoryMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: ArcanumColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: ArcanumColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: ArcanumText.heading(20),
            ),
            const SizedBox(height: 18),
            ArcanumField(controller: _country, label: 'País'),
            const SizedBox(height: 12),
            ArcanumField(controller: _city, label: 'Ciudad'),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: ArcanumText.body(14, color: ArcanumColors.aspectTension),
              ),
            ],
            const SizedBox(height: 20),
            GoldButton(
              label: 'Buscar',
              loading: _resolving,
              onPressed: () {
                if (!_resolving) _resolve();
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Mensaje para un fallo al resolver el lugar.
///
/// Nunca interpola el error: filtraria la URL, el estado HTTP y la traza. El
/// texto del servidor tampoco se muestra crudo por el mismo motivo.
String placeChooserErrorMessage(Object error) {
  final texto = error.toString().toLowerCase();
  if (texto.contains('no se pudo contactar') || texto.contains('socket')) {
    return 'No hay conexión para buscar el lugar. Inténtalo más tarde.';
  }
  return 'No encontramos ese lugar. Revisa el país y la ciudad.';
}
