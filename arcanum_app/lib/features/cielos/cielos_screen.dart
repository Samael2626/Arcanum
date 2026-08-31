import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/arcanum_api.dart';
import '../../core/astro/birth_data.dart';
import '../../core/api/oracle_error.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/privacy/ai_consent_service.dart';
import '../../core/content/glossary.dart';
import '../../core/content/transit_reading.dart';
import '../../core/state/flow_providers.dart';
import '../../core/theme/arcanum_colors.dart';
import '../../core/theme/arcanum_theme.dart';
import '../../shared/astro_symbols.dart';
import '../../shared/widgets/arcanum_card.dart';
import '../../shared/widgets/gold_button.dart';
import '../../shared/widgets/content_report_sheet.dart';
import '../../shared/widgets/info_dot.dart';
import '../hoy/hoy_guidance.dart';
import '../hoy/hoy_lore.dart';
import 'sign_lore.dart';
import 'widgets/natal_wheel.dart';
import 'widgets/sign_gallery.dart';

// ── Pantalla principal ──────────────────────────────────────────────────────

class CielosScreen extends ConsumerWidget {
  const CielosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    if (auth.status == AuthStatus.unknown) {
      return const Center(
        child: CircularProgressIndicator(
          color: ArcanumColors.gold,
          strokeWidth: 2,
        ),
      );
    }
    if (!auth.isAuthenticated) return const _LoginPrompt();
    return const _NatalView();
  }
}

class _LoginPrompt extends StatelessWidget {
  const _LoginPrompt();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '✶',
              style: TextStyle(fontSize: 60, color: ArcanumColors.goldMuted),
            ),
            const SizedBox(height: 20),
            Text(
              'Tu cielo te espera',
              textAlign: TextAlign.center,
              style: ArcanumText.heading(30),
            ),
            const SizedBox(height: 12),
            Text(
              'Inicia sesión para revelar tu carta natal y los tránsitos del cielo de hoy sobre ella.',
              textAlign: TextAlign.center,
              style: ArcanumText.body(16, color: ArcanumColors.ivoryMuted),
            ),
            const SizedBox(height: 28),
            GoldButton(
              label: 'Iniciar sesión',
              onPressed: () => context.go('/login'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.go('/register'),
              child: Text(
                'Crear cuenta',
                style: ArcanumText.body(15, color: ArcanumColors.gold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NatalView extends ConsumerStatefulWidget {
  const _NatalView();
  @override
  ConsumerState<_NatalView> createState() => _NatalViewState();
}

class _NatalViewState extends ConsumerState<_NatalView> {
  late final ArcanumApi _api = ref.read(arcanumApiProvider);
  late Future<(Map<String, dynamic>, Map<String, dynamic>)> _future = _load();

  /// Firma de nacimiento con la que se pidio `_future`. Sirve para no recargar
  /// cuando el perfil cambia por algo que no afecta a la rueda (el nombre, la
  /// residencia, la suscripcion).
  String? _firma;

  /// Planeta que Hoy pidió enfocar ("tu Marte natal"). Se lee una vez y se
  /// limpia el canal, para no re-disparar el foco en visitas siguientes.
  String? _focus;

  /// Ancla de la fila del planeta enfocado, para desplazarse hasta ella.
  final GlobalKey _focusKey = GlobalKey();

  /// El desplazamiento al foco se hace UNA vez tras dibujar; este flag lo evita
  /// repetir en cada rebuild.
  bool _focusScrolled = false;

  @override
  void initState() {
    super.initState();
    _focus = ref.read(cielosFocusPlanetProvider);
    if (_focus != null) {
      // Consumido: si el usuario vuelve a Cielos por su cuenta, sin foco.
      Future.microtask(
        () => ref.read(cielosFocusPlanetProvider.notifier).set(null),
      );
    }
  }

  /// Tras dibujar la lista, lleva la fila enfocada al centro del viewport. Una
  /// sola vez: el foco es un gesto de llegada, no un ancla permanente.
  void _scrollToFocusOnce() {
    if (_focus == null || _focusScrolled) return;
    _focusScrolled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _focusKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 520),
          curve: Curves.easeInOutCubic,
          alignment: 0.3,
        );
      }
    });
  }

  Future<(Map<String, dynamic>, Map<String, dynamic>)> _load() async {
    _firma = ref.read(birthSignatureProvider);
    try {
      final data = await _api.celestialOverview();
      return (
        data['natal_chart'] as Map<String, dynamic>,
        data['transits'] as Map<String, dynamic>,
      );
    } on DioException catch (error) {
      if (error.response?.statusCode != 404) rethrow;
      await _api.natalChart();
      final data = await _api.celestialOverview();
      return (
        data['natal_chart'] as Map<String, dynamic>,
        data['transits'] as Map<String, dynamic>,
      );
    }
  }

  bool _isMissingBirth(Object e) =>
      e is DioException && e.response?.statusCode == 422;

  @override
  Widget build(BuildContext context) {
    // El perfil puede llegar DESPUES de esta pantalla: si el PUT del onboarding
    // fallo, queda encolado y se reenvia en el arranque siguiente
    // (`tryFlushPendingProfile`), que corre contra esta carga. Sin esto, Cielos
    // se quedaba en "Aun no hay carta que trazar" con los datos ya en el
    // servidor, y su boton mandaba a rehacer un onboarding ya hecho.
    //
    // Tambien cubre el caso de corregir la hora o el lugar de nacimiento: la
    // firma cambia y la rueda se recalcula, en vez de seguir mostrando la
    // anterior.
    ref.listen<String?>(birthSignatureProvider, (previa, actual) {
      if (actual != null && actual != _firma) {
        setState(() => _future = _load());
      }
    });

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: RefreshIndicator(
          color: ArcanumColors.gold,
          backgroundColor: ArcanumColors.surface,
          onRefresh: () async => setState(() => _future = _load()),
          child: FutureBuilder<(Map<String, dynamic>, Map<String, dynamic>)>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const _WheelLoading();
              }
              if (snap.hasError) {
                return _isMissingBirth(snap.error!)
                    ? const _NoBirthData()
                    : _ErrorState(error: '${snap.error}');
              }
              final chart = snap.data!.$1['chart_data'] as Map<String, dynamic>;
              final transits = snap.data!.$2;
              return _content(chart, transits);
            },
          ),
        ),
      ),
    );
  }

  Widget _content(Map<String, dynamic> chart, Map<String, dynamic> transits) {
    // Si Hoy pidió enfocar un planeta, desplázate a su fila tras dibujar.
    _scrollToFocusOnce();
    final asc = chart['ascendant'] as Map<String, dynamic>;
    final mc = chart['midheaven'] as Map<String, dynamic>;
    final planets = (chart['planets'] as List).cast<Map<String, dynamic>>();
    final aspects = (transits['aspects_to_natal'] as List)
        .cast<Map<String, dynamic>>();

    final sunPlanet = planets.firstWhere(
      (p) => p['name'] == 'sun',
      orElse: () => <String, dynamic>{},
    );
    final sunSign = (sunPlanet['sign'] as String?) ?? '';
    final ascSign = (asc['sign'] as String?) ?? '';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
      children: [
        // ── Vistazo: Sol + Ascendente ──
        _SolarSummary(sunSign: sunSign, ascSign: ascSign),
        const SizedBox(height: 24),

        // ── La rueda: instrumento vivo e interactivo ──
        const SectionLabel('TU RUEDA NATAL', infoKey: 'carta_natal'),
        const SizedBox(height: 6),
        Text(
          'El cielo del instante en que naciste.',
          textAlign: TextAlign.center,
          style: ArcanumText.body(
            14,
            color: ArcanumColors.ivoryMuted,
            italic: true,
          ),
        ),
        const SizedBox(height: 14),
        NatalWheel(chart: chart),
        const SizedBox(height: 10),
        const _TapHint(),
        const SizedBox(height: 14),
        const _AspectLegend(),
        const SizedBox(height: 24),

        // ── Ángulos ──
        ArcanumCard(
          child: Column(
            children: [
              const SectionLabel('ÁNGULOS', infoKey: 'ascendente'),
              const SizedBox(height: 14),
              _angle('Ascendente', asc),
              const Divider(color: ArcanumColors.surfaceHigh, height: 28),
              _angle('Medio Cielo', mc),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // ── Planetas ──
        ArcanumCard(
          child: Column(
            children: [
              const SectionLabel('PLANETAS', infoKey: 'carta_natal'),
              const SizedBox(height: 4),
              const _TermHint(),
              const SizedBox(height: 6),
              ...planets.map(_planetRow),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // ── Tránsitos ──
        ArcanumCard(
          child: Column(
            children: [
              const SectionLabel('TRÁNSITOS DE HOY', infoKey: 'transitos'),
              const SizedBox(height: 4),
              if (aspects.isNotEmpty) const _TermHint(),
              const SizedBox(height: 6),
              if (aspects.isEmpty)
                Text(
                  'Cielo en calma: sin aspectos exactos a tu carta ahora.',
                  textAlign: TextAlign.center,
                  style: ArcanumText.body(15, color: ArcanumColors.ivoryMuted),
                )
              else
                ...aspects.map((a) => _AspectRow(a)),
            ],
          ),
        ),
        const SizedBox(height: 30),

        // ── Los doce signos ──
        const SectionLabel('LOS DOCE SIGNOS'),
        const SizedBox(height: 6),
        Text(
          'Cada signo, su elemento y su regente. Toca uno para su lore.',
          textAlign: TextAlign.center,
          style: ArcanumText.body(
            14,
            color: ArcanumColors.ivoryMuted,
            italic: true,
          ),
        ),
        const SizedBox(height: 16),
        SignGallery(sunSign: sunSign, ascSign: ascSign),
        const SizedBox(height: 24),

        Center(
          child: TextButton(
            onPressed: () => ref.read(authProvider.notifier).logout(),
            child: Text(
              'Cerrar sesión',
              style: ArcanumText.body(14, color: ArcanumColors.ivoryMuted),
            ),
          ),
        ),
      ],
    );
  }

  Widget _angle(String label, Map<String, dynamic> a) {
    final sign = a['sign'] as String;
    return InkWell(
      onTap: () => showSignLoreSheet(context, sign),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: ArcanumText.body(16, color: ArcanumColors.ivoryMuted),
            ),
            const SizedBox(width: 12),
            Text(
              '${signGlyph[sign] ?? ''} ${signEs[sign] ?? sign}',
              style: ArcanumText.heading(22, color: ArcanumColors.gold),
            ),
          ],
        ),
      ),
    );
  }

  /// Fila de planeta: cada parte abre SU propia explicación.
  ///
  /// Antes la fila entera abría el lore del signo — tocabas "Sol" y salía
  /// "Capricornio". Ahora planeta, signo, retrogradación y casa son cuatro
  /// zonas independientes.
  Widget _planetRow(Map<String, dynamic> p) {
    final name = p['name'] as String;
    final sign = p['sign'] as String;
    final retro = p['retrograde'] == true;
    final house = (p['house'] as num?)?.toInt();
    final focused = name == _focus;

    return Container(
      key: focused ? _focusKey : null,
      decoration: focused
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: ArcanumColors.gold.withValues(alpha: 0.10),
              border: Border(
                left: BorderSide(
                  color: ArcanumColors.gold.withValues(alpha: 0.7),
                  width: 2,
                ),
              ),
            )
          : null,
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
      child: Row(
        children: [
          // Planeta → su propio lore
          Expanded(
            child: _Tappable(
              onTap: () => showPlanetLoreSheet(context, name),
              child: Row(
                children: [
                  SizedBox(
                    width: 34,
                    child: Text(
                      planetGlyph[name] ?? '✶',
                      style: const TextStyle(
                        fontSize: 22,
                        color: ArcanumColors.gold,
                      ),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      planetEs[name] ?? name,
                      style: ArcanumText.body(16),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Signo → lore del signo
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Tappable(
                    onTap: () => showSignLoreSheet(context, sign),
                    child: Text(
                      '${signGlyph[sign] ?? ''} ${signEs[sign] ?? sign}',
                      style: ArcanumText.body(
                        15,
                        color: ArcanumColors.ivoryMuted,
                      ),
                    ),
                  ),
                  // Retrogradación → qué significa ℞
                  if (retro)
                    _Tappable(
                      onTap: () => showGlossarySheet(context, 'retrogrado'),
                      child: const Text(
                        '℞',
                        style: TextStyle(
                          color: ArcanumColors.burgundyLight,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  // Casa → qué terreno de la vida es (era el ilegible "C2")
                  if (house != null)
                    _Tappable(
                      onTap: () =>
                          showGlossarySheet(context, houseGlossaryKey(house)),
                      child: Text(
                        'Casa $house',
                        style: ArcanumText.body(
                          13,
                          color: ArcanumColors.goldMuted,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fila de tránsito: cada término es tocable por separado (capa 1) y la fila
/// entera se despliega con la lectura en español llano (capa 2).
///
/// Era una línea de texto muerta — "♀ Venus trígono ☽ Luna natal" — donde
/// ninguna de las cuatro piezas de jerga tenía salida.
class _AspectRow extends ConsumerStatefulWidget {
  final Map<String, dynamic> aspect;
  const _AspectRow(this.aspect);

  @override
  ConsumerState<_AspectRow> createState() => _AspectRowState();
}

class _AspectRowState extends ConsumerState<_AspectRow> {
  bool _open = false;
  bool _asking = false;
  String? _oracleReply;
  String? _oracleContentRef;
  String? _oracleError;
  String? _idempotencyKey;

  /// Abre en Oráculo → Aprender la carta del planeta que transita. El planeta
  /// activo del tránsito tiene su Arcano Mayor (Golden Dawn): otro hilo entre
  /// secciones, del cielo al mazo.
  void _openTarot(String slug) {
    ref.read(oraculoFocusCardProvider.notifier).set(slug);
    context.go('/oraculo');
  }

  /// Pide al oráculo la lectura personalizada de ESTE tránsito.
  /// El servidor ya inyecta la carta natal: solo hay que nombrar el tránsito.
  Future<void> _askOracle() async {
    final userId = ref.read(authProvider).user?['id'] as String?;
    if (userId == null ||
        !await ref
            .read(aiConsentServiceProvider)
            .ensureGranted(context, userId: userId)) {
      return;
    }
    final key = _idempotencyKey ??= IdempotencyKey.create();
    final aspect = widget.aspect;
    setState(() {
      _asking = true;
      _oracleError = null;
      _oracleReply = null;
      _oracleContentRef = null;
    });
    try {
      final response = await ref.read(arcanumApiProvider).oracleIa(
        question: transitOracleQuestion(
          transit: aspect['transit'] as String,
          natal: aspect['natal'] as String,
          aspect: aspect['aspect'] as String,
        ),
        idempotencyKey: key,
      );
      if (!mounted) return;
      _idempotencyKey = null;
      setState(() {
        _oracleReply = assistantReply(response);
        _oracleContentRef = response['id'] as String?;
      });
    } catch (error) {
      if (isCreditsRequired(error)) await _openCreditsPaywall();
      if (!mounted) return;
      setState(() => _oracleError = isCreditsRequired(error) ? 'Saldo insuficiente. Puedes comprar créditos.' : oracleErrorMessage(error));
    } finally {
      if (mounted) setState(() => _asking = false);
    }
  }

  Future<void> _openCreditsPaywall() async {
    try {
      final balance = await ref.read(arcanumApiProvider).creditsBalance();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saldo actual: ${balance['balance'] ?? 0} créditos.')));
      context.push('/paywall');
    } catch (error) {
      if (mounted) setState(() => _oracleError = 'No se pudo actualizar tu saldo. Inténtalo de nuevo.');
    }
  }
  static const _toneColor = {
    AspectTone.fusion: ArcanumColors.aspectUnion,
    AspectTone.armonico: ArcanumColors.aspectHarmony,
    AspectTone.tenso: ArcanumColors.aspectTension,
  };

  @override
  Widget build(BuildContext context) {
    final a = widget.aspect;
    final t = a['transit'] as String;
    final n = a['natal'] as String;
    final asp = a['aspect'] as String;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _Tappable(
                onTap: () => showPlanetLoreSheet(context, t),
                child: Text(
                  '${planetGlyph[t] ?? ''} ${planetEs[t] ?? t}',
                  style: ArcanumText.body(15),
                ),
              ),
              _Tappable(
                onTap: () => showGlossarySheet(context, aspectGlossaryKey(asp)),
                child: Text(
                  aspectEs[asp] ?? asp,
                  style: ArcanumText.body(15, color: ArcanumColors.gold),
                ),
              ),
              _Tappable(
                onTap: () => showPlanetLoreSheet(context, n),
                child: Text(
                  '${planetGlyph[n] ?? ''} ${planetEs[n] ?? n}',
                  style: ArcanumText.body(15),
                ),
              ),
              // "natal" es la palabra que hace ilegible la línea entera.
              _Tappable(
                onTap: () => showGlossarySheet(context, 'natal_vs_transito'),
                child: Text(
                  'natal',
                  style: ArcanumText.body(15, color: ArcanumColors.ivoryMuted),
                ),
              ),
              _Tappable(
                onTap: () => setState(() => _open = !_open),
                child: Icon(
                  _open ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: ArcanumColors.goldMuted,
                ),
              ),
            ],
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState: _open
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: _Reading(
              reading: readTransit(transit: t, natal: n, aspect: asp),
              accent: _toneColor[aspectToneOf(asp)] ?? ArcanumColors.goldMuted,
              asking: _asking,
              oracleReply: _oracleReply,
              oracleContentRef: _oracleContentRef,
              api: ref.read(arcanumApiProvider),
              oracleError: _oracleError,
              onAskOracle: _askOracle,
              tarotPlanet: planetTarot.containsKey(t) ? t : null,
              onOpenTarot: planetTarot.containsKey(t)
                  ? () => _openTarot(planetTarot[t]!)
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// El tránsito traducido: qué pasa, qué hace ese aspecto y qué hacer con ello.
/// Al final, la puerta a la lectura personalizada del oráculo (capa 3).
class _Reading extends StatelessWidget {
  final TransitReading reading;
  final Color accent;
  final bool asking;
  final String? oracleReply;
  final String? oracleContentRef;
  final ArcanumApi api;
  final String? oracleError;
  final VoidCallback onAskOracle;

  /// Planeta que transita, si tiene Arcano Mayor (uno de los siete clásicos):
  /// habilita el salto a su carta en el Oráculo. Null para los modernos.
  final String? tarotPlanet;
  final VoidCallback? onOpenTarot;

  const _Reading({
    required this.reading,
    required this.accent,
    required this.asking,
    required this.oracleReply,
    required this.oracleContentRef,
    required this.api,
    required this.oracleError,
    required this.onAskOracle,
    this.tarotPlanet,
    this.onOpenTarot,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(4, 2, 4, 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: ArcanumColors.surfaceHigh.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: accent, width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(reading.sentence, style: ArcanumText.body(15)),
          const SizedBox(height: 10),
          Text(
            reading.nature,
            style: ArcanumText.body(
              14,
              color: ArcanumColors.ivoryMuted,
              italic: true,
            ),
          ),
          const SizedBox(height: 10),
          Text(reading.guidance, style: ArcanumText.body(14, color: accent)),

          // ── Hilo al mazo: la carta del planeta que transita ──
          if (onOpenTarot != null) ...[
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: onOpenTarot,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Text(
                '✦',
                style: TextStyle(fontSize: 13, color: ArcanumColors.goldMuted),
              ),
              label: Text(
                'Ver la carta de ${planetEs[tarotPlanet] ?? tarotPlanet}',
                style: ArcanumText.body(14, color: ArcanumColors.goldMuted),
              ),
            ),
          ],

          // ── El oráculo: lectura personalizada de este tránsito ──
          const SizedBox(height: 14),
          Divider(
            height: 1,
            color: ArcanumColors.goldMuted.withValues(alpha: 0.25),
          ),
          const SizedBox(height: 10),
          if (oracleReply == null)
            _OracleButton(asking: asking, onPressed: onAskOracle),
          if (oracleError != null) ...[
            const SizedBox(height: 8),
            Text(
              oracleError!,
              style: ArcanumText.body(13, color: ArcanumColors.burgundyLight),
            ),
          ],
          if (oracleReply != null) ...[
            Row(
              children: [
                const Text(
                  '✦',
                  style: TextStyle(
                    fontSize: 13,
                    color: ArcanumColors.goldMuted,
                  ),
                ),
                const SizedBox(width: 8),
                Text('EL ORÁCULO', style: ArcanumText.label()),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              oracleReply!.isEmpty
                  ? 'El oráculo guardó silencio. Inténtalo de nuevo.'
                  : oracleReply!,
              style: ArcanumText.body(15),
            ),
            // Play exige poder denunciar contenido de IA donde se muestre.
            if (oracleContentRef != null)
              Center(
                child: ContentReportButton(
                  api: api,
                  source: 'oracle',
                  contentRef: oracleContentRef!,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Botón discreto que abre la lectura personalizada. Consume cupo diario del
/// oráculo, así que se pide explícitamente: nunca se dispara solo al desplegar.
class _OracleButton extends StatelessWidget {
  final bool asking;
  final VoidCallback onPressed;
  const _OracleButton({required this.asking, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: asking ? null : onPressed,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: asking
          ? const SizedBox(
              width: 13,
              height: 13,
              child: CircularProgressIndicator(
                color: ArcanumColors.gold,
                strokeWidth: 1.6,
              ),
            )
          : const Text(
              '✦',
              style: TextStyle(fontSize: 13, color: ArcanumColors.gold),
            ),
      label: Text(
        asking ? 'Consultando al oráculo…' : 'Explícame esto',
        style: ArcanumText.body(14, color: ArcanumColors.gold),
      ),
    );
  }
}

/// Envoltorio táctil uniforme para los términos explicables de la carta.
/// Da área de toque cómoda (≥40px de alto) sin romper el ritmo visual.
class _Tappable extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;
  const _Tappable({required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 5),
      child: child,
    ),
  );
}

// ── Resumen solar / ascendente ────────────────────────────────────────────────

class _SolarSummary extends StatelessWidget {
  final String sunSign;
  final String ascSign;
  const _SolarSummary({required this.sunSign, required this.ascSign});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _pill(context, '☉', 'Tu Sol', sunSign)),
        const SizedBox(width: 12),
        Expanded(child: _pill(context, 'AC', 'Ascendente', ascSign)),
      ],
    );
  }

  Widget _pill(BuildContext context, String glyph, String label, String sign) {
    final name = signEs[sign] ?? '—';
    return GestureDetector(
      onTap: sign.isEmpty ? null : () => showSignLoreSheet(context, sign),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: ArcanumColors.surface,
          border: Border.all(color: ArcanumColors.gold.withValues(alpha: 0.28)),
        ),
        child: Row(
          children: [
            Text(
              glyph,
              style: const TextStyle(
                fontSize: 22,
                color: ArcanumColors.goldMuted,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label.toUpperCase(), style: ArcanumText.label()),
                  const SizedBox(height: 2),
                  Text(
                    '${signGlyph[sign] ?? ''} $name',
                    style: ArcanumText.heading(20, color: ArcanumColors.gold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Ayudas visuales de la rueda ───────────────────────────────────────────────

class _TapHint extends StatelessWidget {
  const _TapHint();
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(
        Icons.touch_app_outlined,
        size: 15,
        color: ArcanumColors.goldMuted.withValues(alpha: 0.9),
      ),
      const SizedBox(width: 6),
      Text(
        'Toca planeta, signo o casa · arrastra para girar',
        style: ArcanumText.body(13, color: ArcanumColors.ivoryMuted),
      ),
    ],
  );
}

/// Avisa de que cada término técnico de la lista se puede tocar.
/// Sin esto la capa explicativa existe pero nadie la descubre.
class _TermHint extends StatelessWidget {
  const _TermHint();
  @override
  Widget build(BuildContext context) => Text(
    'Toca cualquier término para saber qué significa.',
    textAlign: TextAlign.center,
    style: ArcanumText.body(12, color: ArcanumColors.ivoryMuted, italic: true),
  );
}

class _AspectLegend extends StatelessWidget {
  const _AspectLegend();
  @override
  Widget build(BuildContext context) => const Wrap(
    alignment: WrapAlignment.center,
    spacing: 16,
    runSpacing: 8,
    children: [
      _LegendDot(ArcanumColors.aspectUnion, 'Unión'),
      _LegendDot(ArcanumColors.aspectHarmony, 'Armonía'),
      _LegendDot(ArcanumColors.aspectTension, 'Tensión'),
    ],
  );
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot(this.color, this.label);
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 14, height: 2, color: color),
      const SizedBox(width: 6),
      Text(label, style: ArcanumText.body(13, color: ArcanumColors.ivoryMuted)),
    ],
  );
}

// ── Estados premium ───────────────────────────────────────────────────────────

class _WheelLoading extends StatelessWidget {
  const _WheelLoading();
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 160),
        const Center(
          child: Text(
            '✵',
            style: TextStyle(fontSize: 54, color: ArcanumColors.goldMuted),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Trazando tu cielo…',
          textAlign: TextAlign.center,
          style: ArcanumText.body(16, color: ArcanumColors.ivoryMuted),
        ),
        const SizedBox(height: 18),
        const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              color: ArcanumColors.gold,
              strokeWidth: 2,
            ),
          ),
        ),
      ],
    );
  }
}

class _NoBirthData extends StatelessWidget {
  const _NoBirthData();
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      children: [
        const SizedBox(height: 120),
        const Center(
          child: Text(
            '☽',
            style: TextStyle(fontSize: 60, color: ArcanumColors.goldMuted),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'Aún no hay carta que trazar',
          textAlign: TextAlign.center,
          style: ArcanumText.heading(28),
        ),
        const SizedBox(height: 12),
        Text(
          'Para dibujar tu rueda natal necesito el instante y el lugar exactos '
          'de tu nacimiento: fecha, hora y coordenadas.',
          textAlign: TextAlign.center,
          style: ArcanumText.body(16, color: ArcanumColors.ivoryMuted),
        ),
        const SizedBox(height: 28),
        GoldButton(
          label: 'Completar mi nacimiento',
          onPressed: () => context.go('/onboarding'),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  const _ErrorState({required this.error});
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      children: [
        const SizedBox(height: 140),
        const Center(
          child: Text(
            '✶',
            style: TextStyle(fontSize: 54, color: ArcanumColors.goldMuted),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'No se pudo trazar tu carta',
          textAlign: TextAlign.center,
          style: ArcanumText.heading(24),
        ),
        const SizedBox(height: 10),
        Text(
          'Desliza hacia abajo para reintentar.',
          textAlign: TextAlign.center,
          style: ArcanumText.body(15, color: ArcanumColors.ivoryMuted),
        ),
        const SizedBox(height: 8),
        Text(
          error,
          textAlign: TextAlign.center,
          style: ArcanumText.body(
            12,
            color: ArcanumColors.ivoryMuted.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}
