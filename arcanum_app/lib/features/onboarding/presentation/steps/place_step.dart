import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/arcanum_colors.dart';
import '../../../../core/theme/arcanum_theme.dart';
import '../../../../shared/widgets/gold_button.dart';
import '../../../../shared/widgets/place_chooser.dart';
import '../../application/onboarding_controller.dart';

/// Lugar de nacimiento, elegido del catalogo de localidades.
///
/// POR QUE YA NO HAY DOS CAJAS DE TEXTO
/// ------------------------------------
/// Este paso tenia sus propios campos de pais y ciudad y resolvia contra el
/// servidor (Nominatim). Lo que se enseñaba en la confirmacion era el
/// `display_name` crudo, y para Medellin eso es:
///
///   "Medellín, Valle de Aburrá, Antioquia, RAP del Agua y la Montaña, 0500,
///    Colombia"
///
/// Ilegible, y es lo primero que ve alguien que acaba de instalar la app. El
/// catalogo da "Medellín, Antioquia, Colombia".
///
/// `showPlaceChooser` ya existia y hacia esto mejor, pero solo lo usaba el
/// perfil: su propio docstring dice que esta para "que el selector se cambie en
/// UN sitio y lo hereden a la vez el onboarding y el perfil". El onboarding
/// nunca se migro. Ahora si.
///
/// NO se pierde nada: el selector conserva el texto libre contra el servidor
/// como RESCATE, para quien nacio en una aldea que no esta en el catalogo. Se
/// gana que la via normal sea elegir de una lista.
///
/// LO QUE NO CAMBIA, y es lo que importa: sigue sin guardarse un lugar sin
/// CONFIRMAR, y nunca uno por omision. Ese fue el bug de Bogota hardcodeada
/// (2026-07-01). El selector no devuelve nada si la persona cancela, y esta
/// pantalla no deja avanzar sin lugar.
class PlaceStep extends ConsumerStatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;
  const PlaceStep({super.key, required this.onNext, required this.onBack});

  @override
  ConsumerState<PlaceStep> createState() => _PlaceStepState();
}

class _PlaceStepState extends ConsumerState<PlaceStep> {
  /// El lugar ya elegido y confirmado, o null mientras no lo haya.
  ///
  /// Se rehidrata de lo que el onboarding ya tuviera: quien vuelve atras desde
  /// el paso siguiente encuentra su eleccion intacta en vez de la pantalla en
  /// blanco.
  ChosenPlace? _place;

  @override
  void initState() {
    super.initState();
    final d = ref.read(onboardingProvider).data;
    if (d.hasResolvedLocation) {
      _place = ChosenPlace(
        displayName: d.resolvedDisplayName ?? d.birthCity ?? '',
        lat: d.resolvedLat!,
        lon: d.resolvedLon!,
        timezone: d.resolvedTimezone!,
      );
    }
  }

  Future<void> _elegir() async {
    final d = ref.read(onboardingProvider).data;
    final elegido = await showPlaceChooser(
      context,
      title: 'Lugar de nacimiento',
      confirmQuestion: '¿Es este tu lugar de nacimiento?',
      // Sin `initialCountry`: el pais ya no se pide por separado, y pasar algo
      // que siempre seria null solo aparentaria que se prellena.
      initialCity: _place?.displayName ?? d.birthCity,
    );
    // null = la persona cerro la hoja. No se toca lo que ya hubiera elegido.
    if (elegido == null || !mounted) return;
    setState(() => _place = elegido);
  }

  Future<void> _finalizar() async {
    final place = _place;
    if (place == null) return;
    final notifier = ref.read(onboardingProvider.notifier);
    // El nombre del catalogo ("Medellín, Antioquia, Colombia") es lo que se
    // guarda como birth_city y lo que la persona vera despues en su perfil.
    await notifier.setBirthCity(place.displayName);
    notifier.setResolvedLocation(
      displayName: place.displayName,
      lat: place.lat,
      lon: place.lon,
      timezone: place.timezone,
    );
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    final place = _place;
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          Text('Lugar de nacimiento', style: ArcanumText.heading(24)),
          const SizedBox(height: 12),
          Text(
            'Determina tu Ascendente, tus casas y tu Luna. Búscalo y elígelo '
            'de la lista.',
            style: ArcanumText.body(15, color: ArcanumColors.ivoryMuted),
          ),
          const SizedBox(height: 28),
          _Elegido(place: place, onTap: _elegir),
          const SizedBox(height: 12),
          Text(
            kPlacesAttribution,
            style: ArcanumText.body(11, color: ArcanumColors.ivoryMuted),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onBack,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: ArcanumColors.ivoryMuted),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                  child: Text(
                    'Atrás',
                    style: ArcanumText.heading(
                      18,
                      color: ArcanumColors.ivoryMuted,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: GoldButton(
                  label: 'Finalizar',
                  // Sin lugar no se avanza. `finish()` lanzaria igual en su
                  // ultima barrera, pero un boton que no hace nada es peor que
                  // uno que se ve apagado.
                  onPressed: place == null ? null : _finalizar,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// La casilla que muestra el lugar elegido, o invita a elegirlo.
///
/// Es un solo objetivo tactil grande y no un campo con un boton al lado: aqui
/// solo hay una accion posible, y partirla en dos invitaria a teclear en algo
/// que no acepta texto.
class _Elegido extends StatelessWidget {
  const _Elegido({required this.place, required this.onTap});

  final ChosenPlace? place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final elegido = place != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          // 48 dp minimos de zona tactil; en la practica es bastante mas.
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: elegido
                  ? ArcanumColors.gold.withValues(alpha: 0.55)
                  : ArcanumColors.ivoryMuted.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            children: [
              Icon(
                elegido ? Icons.place : Icons.search,
                color: elegido ? ArcanumColors.gold : ArcanumColors.ivoryMuted,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  place?.displayName ?? 'Buscar mi ciudad',
                  style: ArcanumText.body(
                    16,
                    color: elegido
                        ? ArcanumColors.gold
                        : ArcanumColors.ivoryMuted,
                  ),
                ),
              ),
              if (elegido)
                Text(
                  'Cambiar',
                  style: ArcanumText.body(14, color: ArcanumColors.ivoryMuted),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
