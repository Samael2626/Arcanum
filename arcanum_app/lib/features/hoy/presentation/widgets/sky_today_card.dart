import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/api/arcanum_api.dart';
import '../../../../core/content/glossary.dart';
import '../../../../core/content/transit_reading.dart';
import '../../../../core/theme/arcanum_colors.dart';
import '../../../../core/theme/arcanum_theme.dart';
import '../../../../shared/astro_symbols.dart';
import '../../../../shared/widgets/arcanum_card.dart';
import '../../../../shared/widgets/arcanum_mood.dart';
import '../../../../shared/widgets/info_dot.dart';
import '../../hoy_lore.dart';
import '../../sky_today_state.dart';
import 'today_card.dart';
import '../../../../shared/widgets/ai_output.dart';
import '../../../../core/consent/ai_consent.dart';

/// "Tu cielo de hoy": el transito dominante de esta persona, leido por la IA.
///
/// Carga aparte del resto de Hoy: `/astral/today` es el cielo comun del lugar y
/// no depende de la carta natal, asi que un fallo aqui no puede llevarse por
/// delante el regente, la hora y la luna. Son dos cielos distintos y fallan por
/// motivos distintos.
class SkyTodayCard extends ConsumerStatefulWidget {
  const SkyTodayCard({super.key});

  @override
  ConsumerState<SkyTodayCard> createState() => _SkyTodayCardState();
}

class _SkyTodayCardState extends ConsumerState<SkyTodayCard> {
  late final ArcanumApi _api = ref.read(arcanumApiProvider);
  late Future<Map<String, dynamic>> _future = _cargar();

  /// Pide permiso ANTES de llamar. El horoscopo manda fecha, hora y lugar de
  /// nacimiento a un proveedor de IA de terceros, asi que cae de lleno en
  /// Apple 5.1.2(i): divulgar y obtener permiso explicito ANTES de compartir.
  ///
  /// Antes esto llamaba a `_api.horoscope()` directamente en el inicializador
  /// del campo, o sea que los datos salian del telefono antes de que nadie
  /// preguntase nada. Se detecto revisando, no en pruebas.
  Future<Map<String, dynamic>> _cargar() async {
    if (!mounted) throw const ConsentDeclined();
    if (!await ensureAiConsent(context)) throw const ConsentDeclined();
    return _api.horoscope();
  }

  void _retry() => setState(() => _future = _cargar());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _Shell(child: _Reading.loading());
        }
        if (snap.hasError) {
          return _Shell(
            child: _Failure(error: snap.error!, onRetry: _retry),
          );
        }
        return _Shell(child: _Reading(data: snap.data!));
      },
    );
  }
}

/// El marco comun: mismo panel en los tres estados, para que la tarjeta no
/// salte de tamano ni de color mientras carga o falla.
class _Shell extends StatelessWidget {
  final Widget child;
  const _Shell({required this.child});

  @override
  Widget build(BuildContext context) => TodayCard(
    mood: ArcanumMood.neutral,
    intensity: 0.6,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Center(
          child: SectionLabel('TU CIELO DE HOY', infoKey: 'transitos'),
        ),
        const SizedBox(height: 16),
        child,
      ],
    ),
  );
}

/// El horoscopo: el titular del dia y su lectura.
class _Reading extends StatelessWidget {
  final Map<String, dynamic>? data;
  final bool isLoading;

  const _Reading({required Map<String, dynamic> this.data}) : isLoading = false;
  const _Reading.loading() : data = null, isLoading = true;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 18),
          child: SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(
              strokeWidth: 1.6,
              color: ArcanumColors.goldMuted,
            ),
          ),
        ),
      );
    }

    final primary = data!['primary'] as Map<String, dynamic>?;
    final text = (data!['text'] as String?)?.trim() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (primary != null) ...[
          _TransitHeadline(primary),
          const SizedBox(height: 14),
        ],
        AiOutput(
          text: text,
          surface: 'horoscopo',
          child: Text(text, style: ArcanumText.body(15)),
        ),
      ],
    );
  }
}

/// El titular en su forma corta y simbolica, con los terminos tocables: los
/// mismos gestos que en Cielos, para que la jerga tenga salida tambien aqui.
class _TransitHeadline extends StatelessWidget {
  final Map<String, dynamic> aspect;
  const _TransitHeadline(this.aspect);

  static const _toneColor = {
    AspectTone.fusion: ArcanumColors.aspectUnion,
    AspectTone.armonico: ArcanumColors.aspectHarmony,
    AspectTone.tenso: ArcanumColors.aspectTension,
  };

  @override
  Widget build(BuildContext context) {
    final t = aspect['transit'] as String;
    final n = aspect['natal'] as String;
    final asp = aspect['aspect'] as String;
    final accent = _toneColor[aspectToneOf(asp)] ?? ArcanumColors.goldMuted;
    final exactAt = aspect['exact_at'] as String?;
    final applying = aspect['applying'] == true;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: ArcanumColors.surfaceHigh.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: accent, width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _Term(
                '${planetGlyph[t] ?? ''} ${planetEs[t] ?? t}',
                onTap: () => showPlanetLoreSheet(context, t),
              ),
              _Term(
                aspectEs[asp] ?? asp,
                color: ArcanumColors.gold,
                onTap: () => showGlossarySheet(context, aspectGlossaryKey(asp)),
              ),
              _Term(
                '${planetGlyph[n] ?? ''} ${planetEs[n] ?? n}',
                onTap: () => showPlanetLoreSheet(context, n),
              ),
              _Term(
                'natal',
                color: ArcanumColors.ivoryMuted,
                onTap: () => showGlossarySheet(context, 'natal_vs_transito'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _tempoLine(applying, exactAt),
            style: ArcanumText.body(
              13,
              color: ArcanumColors.ivoryMuted,
              italic: true,
            ),
          ),
        ],
      ),
    );
  }

  /// Que hace el transito ahora mismo. Un aspecto que ya paso su exactitud no
  /// se anuncia como si estuviera llegando.
  static String _tempoLine(bool applying, String? exactAt) {
    if (!applying) return 'Ya pasó su punto exacto: va de salida.';
    if (exactAt == null) return 'Se está formando.';
    return 'Se está formando; su punto exacto es el ${exactAt.substring(0, 10)}.';
  }
}

class _Term extends StatelessWidget {
  final String text;
  final Color? color;
  final VoidCallback onTap;
  const _Term(this.text, {required this.onTap, this.color});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(6),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Text(text, style: ArcanumText.body(15, color: color)),
    ),
  );
}

/// El fallo, dicho por lo que es.
///
/// Cuatro causas, cuatro mensajes y cuatro salidas. Cuando los transitos siguen
/// siendo validos —no hay red, o el modelo no respondio— se muestra ademas la
/// lectura local: es determinista, offline y real, no un relleno.
class _Failure extends ConsumerStatefulWidget {
  final Object error;
  final VoidCallback onRetry;
  const _Failure({required this.error, required this.onRetry});

  @override
  ConsumerState<_Failure> createState() => _FailureState();
}

class _FailureState extends ConsumerState<_Failure> {
  late final SkyTodayFailure _failure = classifySkyFailure(widget.error);
  Future<Map<String, dynamic>>? _local;

  @override
  void initState() {
    super.initState();
    // La lectura local necesita los transitos, que es otra llamada. Solo se
    // pide cuando esos transitos siguen significando algo.
    if (allowsLocalReading(_failure)) {
      _local = ref.read(arcanumApiProvider).transits();
    }
  }

  @override
  Widget build(BuildContext context) {
    final route = skyFailureRoute(_failure);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          skyFailureMessage(_failure),
          style: ArcanumText.body(15, color: ArcanumColors.ivoryMuted),
        ),
        if (_local != null) _LocalReading(_local!),
        const SizedBox(height: 12),
        Row(
          children: [
            if (route != null)
              TextButton(
                onPressed: () => context.go(route),
                child: Text(
                  _actionLabel(_failure),
                  style: ArcanumText.body(14, color: ArcanumColors.gold),
                ),
              )
            else
              TextButton(
                onPressed: widget.onRetry,
                child: Text(
                  'Reintentar',
                  style: ArcanumText.body(14, color: ArcanumColors.gold),
                ),
              ),
          ],
        ),
      ],
    );
  }

  static String _actionLabel(SkyTodayFailure failure) {
    switch (failure) {
      case SkyTodayFailure.sinCartaNatal:
        return 'Calcular mi carta natal';
      case SkyTodayFailure.sinDatosDeNacimiento:
        return 'Completar mi perfil';
      case SkyTodayFailure.sesionExpirada:
        return 'Entrar de nuevo';
      case SkyTodayFailure.cieloNoLegible:
      case SkyTodayFailure.sinRed:
        return 'Reintentar';
      case SkyTodayFailure.sinConsentimiento:
        // No dice "reintentar": lo que hay que rehacer es la decision, y
        // llamarlo reintento la disfrazaria de fallo tecnico.
        return 'Revisar el permiso';
    }
  }
}

/// La lectura sin IA y sin red del transito mas cercano a la exactitud.
class _LocalReading extends StatelessWidget {
  final Future<Map<String, dynamic>> future;
  const _LocalReading(this.future);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final aspects = (snap.data!['aspects_to_natal'] as List?)
            ?.cast<Map<String, dynamic>>();
        if (aspects == null || aspects.isEmpty) return const SizedBox.shrink();

        // Sin el peso del servidor, el criterio local es el orbe: el aspecto
        // mas cerca de su exactitud. Es menos fino que la ponderacion completa,
        // y se dice cual se eligio en vez de aparentar que es el mismo.
        final elegido = aspects.reduce(
          (a, b) =>
              ((a['orb'] as num?) ?? 99) <= ((b['orb'] as num?) ?? 99) ? a : b,
        );
        final reading = readTransit(
          transit: elegido['transit'] as String,
          natal: elegido['natal'] as String,
          aspect: elegido['aspect'] as String,
        );
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(reading.sentence, style: ArcanumText.body(15)),
              const SizedBox(height: 8),
              Text(
                reading.guidance,
                style: ArcanumText.body(14, color: ArcanumColors.goldMuted),
              ),
            ],
          ),
        );
      },
    );
  }
}
