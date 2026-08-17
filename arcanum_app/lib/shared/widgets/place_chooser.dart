import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/arcanum_api.dart';
import '../../core/places/city_catalog.dart';
import '../../core/places/city_index.dart';
import '../../core/places/city_index_provider.dart';
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

/// Atribucion obligatoria del catalogo de localidades (CC BY 4.0).
///
/// Una sola fuente: la declara el dueno de los datos. Duplicar el texto legal
/// garantiza que un dia una copia mienta, y aqui mentir es incumplir la
/// licencia, no un detalle de estilo.
const String kPlacesAttribution = CityCatalog.attribution;

/// El UNICO sitio del cliente donde se elige un lugar.
///
/// Existe para que el selector se cambie en UN sitio y lo hereden a la vez el
/// onboarding y el perfil. La firma (`showPlaceChooser` -> `ChosenPlace?`) esta
/// pensada para no moverse.
///
/// Se escribe para FILTRAR, pero solo se ELIGE de la lista del catalogo. El
/// texto que se teclea NUNCA sale hacia el servidor ni se devuelve tal cual: o
/// se toca una fila del catalogo, o se entra al rescate por servidor, que
/// resuelve contra `geoResolve` y CONFIRMA antes de devolver.
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

/// Lo que la pantalla esta haciendo ahora mismo. Ninguno es mudo: cada uno
/// tiene su texto y su salida.
enum _Stage {
  /// Abriendo el catalogo empaquetado.
  loadingCatalog,

  /// El catalogo no abrio. Se ofrece el rescate por servidor.
  catalogUnavailable,

  /// Catalogo listo, aun no hay consulta util (menos de dos letras).
  prompt,

  /// Hay consulta y se esta filtrando.
  searching,

  /// Hay resultados en pantalla.
  results,

  /// La consulta no caso con nada. Se ofrece el rescate por servidor.
  empty,
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
  /// Lo justo para que no se dispare una busqueda por cada pulsacion, sin que
  /// la lista se sienta perezosa al escribir.
  static const _debounceDelay = Duration(milliseconds: 220);

  final _query = TextEditingController();
  late final TextEditingController _rescueCountry = TextEditingController(
    text: widget.initialCountry ?? '',
  );
  late final TextEditingController _rescueCity = TextEditingController(
    text: widget.initialCity ?? '',
  );

  CityIndex? _index;
  List<Country> _countries = const [];
  String? _countryCode;

  _Stage _stage = _Stage.loadingCatalog;
  List<City> _results = const [];
  City? _selected;

  /// Descarta respuestas de busquedas viejas: sin esto, una consulta lenta
  /// puede pisar los resultados de la que la persona esta viendo.
  int _searchToken = 0;
  Timer? _debounce;

  /// El flujo viejo de texto libre, que sigue existiendo como rescate.
  bool _rescue = false;
  bool _resolving = false;
  String? _rescueError;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    _rescueCountry.dispose();
    _rescueCity.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    try {
      final index = ref.read(cityIndexProvider);
      final countries = await index.countries();
      if (!mounted) return;
      setState(() {
        _index = index;
        _countries = countries;
        _stage = _Stage.prompt;
      });
    } catch (_) {
      // Sin catalogo la pantalla no se queda girando: lo dice y abre el rescate.
      if (!mounted) return;
      setState(() => _stage = _Stage.catalogUnavailable);
    }
  }

  void _onQueryChanged(String raw) {
    _debounce?.cancel();
    final texto = raw.trim();
    setState(() {
      _selected = null;
      if (texto.length < 2) {
        _results = const [];
        _stage = _Stage.prompt;
      } else {
        _stage = _Stage.searching;
      }
    });
    if (texto.length < 2) return;
    _debounce = Timer(_debounceDelay, _runSearch);
  }

  void _onCountryChanged(String? code) {
    setState(() {
      _countryCode = code;
      _selected = null;
    });
    if (_query.text.trim().length < 2) return;
    _debounce?.cancel();
    setState(() => _stage = _Stage.searching);
    _runSearch();
  }

  Future<void> _runSearch() async {
    final index = _index;
    final texto = _query.text.trim();
    if (index == null || texto.length < 2) return;
    final token = ++_searchToken;

    List<City> found;
    try {
      found = await index.search(texto, countryCode: _countryCode);
    } catch (_) {
      found = const [];
    }
    if (!mounted || token != _searchToken) return;
    setState(() {
      _results = found;
      _stage = found.isEmpty ? _Stage.empty : _Stage.results;
    });
  }

  /// Elegir una fila NO cierra la hoja: la deja marcada y pide un toque de
  /// confirmacion. Un pulgar que roza la lista no debe decidir donde naciste.
  void _select(City city) {
    FocusScope.of(context).unfocus();
    setState(() => _selected = city);
  }

  void _confirmSelected() {
    final city = _selected;
    if (city == null) return;
    Navigator.of(context).pop(
      ChosenPlace(
        displayName: city.label,
        lat: city.lat.toString(),
        lon: city.lon.toString(),
        timezone: city.timezone,
      ),
    );
  }

  void _openRescue() {
    final escrito = _query.text.trim();
    if (escrito.isNotEmpty && _rescueCity.text.trim().isEmpty) {
      // Lo tecleado se reaprovecha como borrador del rescate. Sigue sin salir
      // hacia el servidor por su cuenta: hay que pulsar "Buscar".
      _rescueCity.text = escrito;
    }
    setState(() {
      _rescue = true;
      _rescueError = null;
      _selected = null;
    });
  }

  // ── Rescate: el flujo viejo, texto libre contra el servidor ───────────────
  //
  // No se borra. Sin el, quien nacio en una aldea que no esta en el catalogo no
  // puede calcular su carta natal.

  Future<void> _resolve() async {
    final country = _rescueCountry.text.trim();
    final city = _rescueCity.text.trim();
    if (country.isEmpty || city.isEmpty) {
      setState(() => _rescueError = 'Completa país y localidad.');
      return;
    }

    setState(() {
      _resolving = true;
      _rescueError = null;
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
        _rescueError = placeChooserErrorMessage(error);
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

  /// Confirmar NO es un tramite: el servidor devuelve el primer resultado, y
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

  // ── Pintado ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // El teclado no tapa la lista: la hoja se sube por encima de el y ademas se
    // limita a lo que queda de pantalla, para que el cuerpo scrollee dentro.
    final teclado = media.viewInsets.bottom;
    final alto = (media.size.height - teclado) * 0.92;

    return Padding(
      padding: EdgeInsets.only(bottom: teclado),
      child: Container(
        constraints: BoxConstraints(maxHeight: alto),
        decoration: const BoxDecoration(
          color: ArcanumColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
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
            const SizedBox(height: 14),
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: ArcanumText.heading(20),
            ),
            const SizedBox(height: 14),
            if (_rescue) ..._rescueBody() else ..._catalogBody(),
            const SizedBox(height: 12),
            Text(
              kPlacesAttribution,
              textAlign: TextAlign.center,
              style: ArcanumText.body(
                12,
                color: ArcanumColors.ivoryMuted,
              ).copyWith(letterSpacing: 0.3),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _catalogBody() {
    final buscable =
        _stage != _Stage.loadingCatalog && _stage != _Stage.catalogUnavailable;
    return [
      _countryPicker(enabled: buscable),
      const SizedBox(height: 10),
      TextField(
        key: const Key('place-query'),
        controller: _query,
        enabled: buscable,
        autofocus: false,
        textInputAction: TextInputAction.search,
        // Enter no elige: solo baja el teclado para que se vea la lista entera.
        // Aceptar el primer resultado a ciegas es exactamente el bug de Bogota.
        onSubmitted: (_) => FocusScope.of(context).unfocus(),
        onChanged: _onQueryChanged,
        style: ArcanumText.body(17),
        cursorColor: ArcanumColors.gold,
        decoration: InputDecoration(
          labelText: 'Tu localidad',
          hintText: 'Escribe para buscar',
          hintStyle: ArcanumText.body(15, color: ArcanumColors.ivoryMuted),
          labelStyle: ArcanumText.body(14, color: ArcanumColors.ivoryMuted),
          prefixIcon: const Icon(Icons.search, color: ArcanumColors.goldMuted),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(
              color: ArcanumColors.goldMuted.withValues(alpha: 0.5),
            ),
          ),
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: ArcanumColors.gold),
          ),
        ),
      ),
      const SizedBox(height: 12),
      Flexible(child: _stageBody()),
      if (_selected != null) ...[
        const SizedBox(height: 12),
        GoldButton(label: 'Usar este lugar', onPressed: _confirmSelected),
      ],
    ];
  }

  Widget _countryPicker({required bool enabled}) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: ArcanumColors.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ArcanumColors.goldMuted.withValues(alpha: 0.4),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          key: const Key('place-country'),
          value: _countryCode,
          isExpanded: true,
          dropdownColor: ArcanumColors.surfaceHigh,
          borderRadius: BorderRadius.circular(12),
          icon: const Icon(Icons.expand_more, color: ArcanumColors.goldMuted),
          style: ArcanumText.body(16),
          onChanged: enabled ? _onCountryChanged : null,
          items: [
            // Se puede NO elegir pais: hay quien no sabe como se llama el suyo
            // en nuestra lista, y buscar en todo el mundo debe seguir valiendo.
            DropdownMenuItem<String?>(
              value: null,
              child: Text(
                'Todo el mundo',
                style: ArcanumText.body(16, color: ArcanumColors.ivoryMuted),
              ),
            ),
            for (final pais in _countries)
              DropdownMenuItem<String?>(
                value: pais.code,
                child: Text(pais.name, style: ArcanumText.body(16)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _stageBody() {
    switch (_stage) {
      case _Stage.loadingCatalog:
        return _message(
          'Preparando el catálogo de localidades…',
          spinner: true,
        );
      case _Stage.catalogUnavailable:
        return _message(
          'No pudimos abrir el catálogo de localidades.',
          rescueLabel: 'Buscar mi localidad de otra forma',
        );
      case _Stage.prompt:
        return _message(
          'Escribe al menos dos letras del nombre de tu localidad y elige una '
          'de la lista.',
        );
      case _Stage.searching:
        return _message('Buscando…', spinner: true);
      case _Stage.empty:
        return _message(
          'No encontramos ninguna localidad con ese nombre.',
          rescueLabel: '¿No encuentras tu localidad?',
        );
      case _Stage.results:
        return _resultList();
    }
  }

  Widget _message(String texto, {bool spinner = false, String? rescueLabel}) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (spinner) ...[
              const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 1.8,
                  color: ArcanumColors.goldMuted,
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              texto,
              textAlign: TextAlign.center,
              style: ArcanumText.body(15, color: ArcanumColors.ivoryMuted),
            ),
            if (rescueLabel != null) ...[
              const SizedBox(height: 8),
              // Zona de toque completa, no un enlace fino: se usa con el pulgar.
              TextButton(
                onPressed: _openRescue,
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                child: Text(
                  rescueLabel,
                  textAlign: TextAlign.center,
                  style: ArcanumText.body(15, color: ArcanumColors.gold),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _resultList() {
    // Material propio: sin el, la fila marcada y el destello del toque quedan
    // tapados por el fondo de la hoja y no se ve que se ha tocado.
    return Material(
      type: MaterialType.transparency,
      child: ListView.separated(
        key: const Key('place-results'),
        shrinkWrap: true,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.zero,
        itemCount: _results.length + 1,
        separatorBuilder: (_, _) => Divider(
          height: 1,
          color: ArcanumColors.surfaceHigh.withValues(alpha: 0.8),
        ),
        itemBuilder: (context, i) {
          // El rescate va al final de la lista, no solo cuando no hay nada: puede
          // haber resultados y ninguno ser el pueblo de la persona.
          if (i == _results.length) {
            return TextButton(
              onPressed: _openRescue,
              style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
              child: Text(
                '¿No encuentras tu localidad?',
                style: ArcanumText.body(15, color: ArcanumColors.gold),
              ),
            );
          }
          final city = _results[i];
          final elegida = identical(city, _selected);
          return ListTile(
            onTap: () => _select(city),
            // 56 de alto minimo: se toca con el pulgar, no con un raton.
            minVerticalPadding: 14,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            selected: elegida,
            selectedTileColor: ArcanumColors.gold.withValues(alpha: 0.10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            // City.label ya desambigua: "Córdoba, Andalucía, España" frente a
            // "Córdoba, Córdoba, Argentina".
            title: Text(
              city.label,
              style: ArcanumText.body(
                16,
                color: elegida ? ArcanumColors.gold : ArcanumColors.ivory,
              ),
            ),
            trailing: elegida
                ? const Icon(Icons.check, color: ArcanumColors.gold, size: 20)
                : null,
          );
        },
      ),
    );
  }

  List<Widget> _rescueBody() {
    return [
      Flexible(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Escribe el país y el nombre de tu localidad. La buscaremos y '
                'te pediremos que confirmes cuál es.',
                textAlign: TextAlign.center,
                style: ArcanumText.body(14, color: ArcanumColors.ivoryMuted),
              ),
              const SizedBox(height: 14),
              ArcanumField(controller: _rescueCountry, label: 'País'),
              const SizedBox(height: 12),
              ArcanumField(controller: _rescueCity, label: 'Localidad'),
              if (_rescueError != null) ...[
                const SizedBox(height: 12),
                Text(
                  _rescueError!,
                  textAlign: TextAlign.center,
                  style: ArcanumText.body(
                    14,
                    color: ArcanumColors.aspectTension,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              GoldButton(
                label: 'Buscar',
                loading: _resolving,
                onPressed: () {
                  if (!_resolving) _resolve();
                },
              ),
              if (_stage != _Stage.catalogUnavailable)
                TextButton(
                  onPressed: _resolving
                      ? null
                      : () => setState(() {
                          _rescue = false;
                          _rescueError = null;
                        }),
                  style: TextButton.styleFrom(minimumSize: const Size(0, 48)),
                  child: Text(
                    'Volver a la lista',
                    style: ArcanumText.body(
                      15,
                      color: ArcanumColors.ivoryMuted,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ];
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
