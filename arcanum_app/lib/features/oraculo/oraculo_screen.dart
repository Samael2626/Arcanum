import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/arcanum_api.dart';
import '../../core/api/oracle_error.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/privacy/ai_consent_service.dart';
import '../../core/state/flow_providers.dart';
import '../../core/theme/arcanum_colors.dart';
import '../../core/theme/arcanum_theme.dart';
import '../../shared/creditos.dart';
import '../../shared/titulo_book_t.dart';
import '../../shared/widgets/arcanum_card.dart';
import '../../shared/widgets/gold_button.dart';
import '../../shared/widgets/login_prompt.dart';
import '../../shared/widgets/content_report_sheet.dart';
import 'tarot_learn.dart';
import 'widgets/tarot_card.dart';
import '../../shared/widgets/ai_output.dart';

/// Quien lee las cartas. No son dos actividades: las dos TIRAN, y lo que
/// cambia es de donde sale el significado.
///
/// Por eso vive aqui dentro y no como un tercer modo junto a Consultar y
/// Aprender: ponerlo arriba sugeriria tres actividades cuando hay dos. Y
/// ademas no cabia -- medido con `TextPainter` a 360 px, tres segmentos dejan
/// 101 px cada uno y "Consultar" ya pide 135.
enum Interprete {
  /// `/oracle/tarot/draw` + `/oracle/ia`: la tirada se guarda y un modelo la
  /// interpreta.
  oraculo,

  /// `/tarot/spread` y `/tarot/draw-one`: el servidor devuelve las cartas ya
  /// resueltas con su significado del Book T. Ningun modelo toca esto.
  tradicion,
}

/// Las tiradas de cada via. La clasica anade "Una carta", que el endpoint del
/// oraculo no sirve.
const _spreadsOraculo = <(String, String)>[
  ('three_card', 'Tres cartas'),
  ('celtic_cross', 'Cruz Celta'),
];
const _spreadsTradicion = <(String, String)>[
  ('one_card', 'Una carta'),
  ('three_card', 'Tres cartas'),
  ('celtic_cross', 'Cruz Celta'),
];

class OraculoScreen extends ConsumerWidget {
  const OraculoScreen({super.key});

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
    if (!auth.isAuthenticated) {
      return const LoginPrompt(
        glyph: '⛤',
        title: 'El oráculo te aguarda',
        description:
            'Inicia sesión para tirar las cartas y guardar tus lecturas.',
      );
    }
    return const _OracleHome();
  }
}

/// El hogar del Oráculo: dos caras de la misma práctica. **Consultar** tira las
/// cartas; **Aprender** recorre el mazo carta por carta (derecho e invertida).
/// El salto de tarot desde Hoy entra directo en Aprender y abre una carta.
class _OracleHome extends ConsumerStatefulWidget {
  const _OracleHome();
  @override
  ConsumerState<_OracleHome> createState() => _OracleHomeState();
}

class _OracleHomeState extends ConsumerState<_OracleHome> {
  int _mode = 0; // 0 = consultar, 1 = aprender
  String? _focusSlug;

  @override
  void initState() {
    super.initState();
    final focus = ref.read(oraculoFocusCardProvider);
    if (focus != null) {
      _mode = 1;
      _focusSlug = focus;
      // Consumido: si vuelve al Oráculo por su cuenta, sin foco.
      Future.microtask(
        () => ref.read(oraculoFocusCardProvider.notifier).set(null),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          children: [
            const SizedBox(height: 12),
            _ModeToggle(
              mode: _mode,
              onChanged: (m) => setState(() => _mode = m),
            ),
            Expanded(
              child: IndexedStack(
                index: _mode,
                children: [
                  const _OracleView(),
                  TarotCatalog(focusSlug: _focusSlug),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Segmentado Consultar | Aprender (misma píldora dorada que el toggle de Saber).
class _ModeToggle extends StatelessWidget {
  final int mode;
  final ValueChanged<int> onChanged;
  const _ModeToggle({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: ArcanumColors.goldMuted.withValues(alpha: 0.4),
        ),
      ),
      child: Row(children: [_seg('Consultar', 0), _seg('Aprender', 1)]),
    );
  }

  Widget _seg(String label, int value) {
    final selected = value == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: selected
                ? ArcanumColors.gold.withValues(alpha: 0.16)
                : Colors.transparent,
          ),
          child: Text(
            label,
            style: ArcanumText.body(
              15,
              color: selected ? ArcanumColors.gold : ArcanumColors.ivoryMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _OracleView extends ConsumerStatefulWidget {
  const _OracleView();
  @override
  ConsumerState<_OracleView> createState() => _OracleViewState();
}

class _OracleViewState extends ConsumerState<_OracleView> {
  late final ArcanumApi _api = ref.read(arcanumApiProvider);
  final _question = TextEditingController();

  String _spread = 'three_card';
  Interprete _interprete = Interprete.oraculo;
  bool _drawing = false;
  String? _drawError;
  List<Map<String, dynamic>>? _cards;
  /// Id de la lectura clasica, para poder reportar su contenido.
  String? _readingId;
  // id de la tirada visible (DivinationSession.id). Ancla la interpretación
  // IA a estas cartas exactas (modo 2/3 del endpoint /oracle/ia).
  String? _sessionId;

  bool _iaLoading = false;
  String? _iaError;
  String? _iaReply;
  String? _iaContentRef;
  String? _drawIdempotencyKey;
  String? _oracleIdempotencyKey;

  // Presentación (no toca datos): fuerza replay de animaciones por tirada
  // y guarda cuál carta corona el viewport (solo una activa a la vez).
  int _drawNonce = 0;
  int _activeCard = 0;

  // Scroll + anclas por carta para el mini-panel sticky y el jump-to.
  final _scroll = ScrollController();
  List<GlobalKey> _cardKeys = const [];
  bool _showSticky = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _question.dispose();
    super.dispose();
  }

  /// Determina qué bloque corona el viewport (fuente única del glow activo,
  /// sincronizada entre mini-panel y bloques) y si el mini-panel debe verse.
  void _onScroll() {
    if (!mounted || _cardKeys.isEmpty) return;
    final anchor = MediaQuery.of(context).padding.top + 150.0;
    int best = _activeCard.clamp(0, _cardKeys.length - 1);
    double bestScore = -1e12;
    for (var i = 0; i < _cardKeys.length; i++) {
      final ctx = _cardKeys[i].currentContext;
      final box = ctx?.findRenderObject() as RenderBox?;
      if (box == null) continue;
      final top = box.localToGlobal(Offset.zero).dy;
      // Bloques ya alcanzados (top<=anchor): mayor top = corona el viewport.
      // Bloques aún por llegar: el más cercano gana entre ellos.
      final score = top <= anchor + 40 ? top : -1e9 - (top - anchor);
      if (score > bestScore) {
        bestScore = score;
        best = i;
      }
    }
    final show = _scroll.hasClients && _scroll.offset > 220;
    if (best != _activeCard || show != _showSticky) {
      setState(() {
        _activeCard = best;
        _showSticky = show;
      });
    }
  }

  /// Desplaza suavemente hasta el bloque de la carta i y la marca activa.
  void _jumpTo(int i) {
    final ctx = _cardKeys.length > i ? _cardKeys[i].currentContext : null;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOutCubic,
        alignment: 0.08,
      );
    }
    setState(() => _activeCard = i);
  }

  /// Las tiradas que sirve la via elegida.
  List<(String, String)> get _tiradas =>
      _interprete == Interprete.tradicion ? _spreadsTradicion : _spreadsOraculo;

  /// Cambiar de interprete tira lo que hubiera en pantalla: las cartas de una
  /// via no se pueden leer con la otra -- la clasica trae su significado
  /// dentro y la del oraculo no --, y dejarlas puestas invitaria a pedir una
  /// interpretacion de una tirada que ya no existe.
  ///
  /// Y "Una carta" solo existe en la clasica: al volver al oraculo hay que
  /// sacar de ahi al que se hubiera quedado, o el boton llamaria a una tirada
  /// que ese endpoint no sirve.
  void _cambiarInterprete(Interprete nuevo) {
    if (nuevo == _interprete) return;
    setState(() {
      _interprete = nuevo;
      if (!_tiradas.any((t) => t.$1 == _spread)) _spread = 'three_card';
      _cards = null;
      _sessionId = null;
      _readingId = null;
      _drawError = null;
      _iaError = null;
      _iaReply = null;
      _iaContentRef = null;
      _cardKeys = const [];
      _showSticky = false;
    });
  }

  Future<void> _draw() async {
    final key = _drawIdempotencyKey ??= IdempotencyKey.create();
    setState(() {
      _drawing = true;
      _drawError = null;
      _iaError = null;
      _iaReply = null;
      _iaContentRef = null;
    });
    try {
      final esClasica = _interprete == Interprete.tradicion;
      final pregunta = _question.text.trim();
      final data = esClasica
          ? (_spread == 'one_card'
                ? await _api.tarotDrawOne(
                    question: pregunta.isEmpty ? null : pregunta,
                    idempotencyKey: key,
                  )
                : await _api.tarotSpread(
                    spreadType: _spread,
                    question: pregunta.isEmpty ? null : pregunta,
                    idempotencyKey: key,
                  ))
          : await _api.tarotDraw(_spread, idempotencyKey: key);
      // Las dos vias devuelven las cartas en sitios distintos. La clasica
      // ademas dice `reversed` donde la otra dice `drawn_upright`, asi que se
      // traduce aqui y no en la vista: asi `TarotCardView` -- el naipe con su
      // arte y su volteo -- sirve para las dos y no hay dos maneras de pintar
      // una carta.
      final cards = esClasica
          ? ((data['resolved'] as List?) ?? const [])
                .cast<Map<String, dynamic>>()
                .map(
                  (c) => {...c, 'drawn_upright': c['reversed'] != true},
                )
                .toList()
          : ((data['cards_drawn'] as Map)['cards'] as List)
                .cast<Map<String, dynamic>>();
      if (!mounted) return;
      _drawIdempotencyKey = null;
      setState(() {
        _cards = cards;
        _readingId = esClasica ? data['id'] as String? : null;
        // Solo la via del oraculo deja sesion que interpretar despues.
        _sessionId = esClasica ? null : data['id'] as String?;
        _drawNonce++;
        _activeCard = 0;
        _cardKeys = List.generate(cards.length, (_) => GlobalKey());
        _showSticky = false;
      });
    } catch (error) {
      if (isCreditsRequired(error)) await _openCreditsPaywall();
      // Sesion caida: se cierra de verdad. La pantalla ya tiene su guarda
      // (`auth.isAuthenticated` -> LoginPrompt); sin esto el estado local
      // seguia diciendo que hay sesion, asi que el boton se quedaba encendido
      // bajo el aviso de «Sesion expirada» y volvia a fallar igual.
      if (esSesionExpirada(error)) {
        await ref.read(authProvider.notifier).logout();
        return;
      }
      if (mounted) {
        setState(() {
          _cards = null;
          _sessionId = null;
          _readingId = null;
          _drawError = isCreditsRequired(error)
              ? 'Saldo insuficiente. Puedes comprar créditos.'
              : oracleErrorMessage(error);
        });
      }
    } finally {
      if (mounted) setState(() => _drawing = false);
    }
  }

  Future<void> _askIa() async {
    final sessionId = _sessionId;
    if (sessionId == null) return;
    // El permiso se pide ANTES de mandar nada. Si no lo da, no se consulta:
    // pedir permiso despues de enviar es avisar, no consentir.
    final userId = ref.read(authProvider).user?['id'] as String?;
    if (userId == null ||
        !await ref
            .read(aiConsentServiceProvider)
            .ensureGranted(context, userId: userId)) {
      return;
    }
    if (!mounted) return;

    final key = _oracleIdempotencyKey ??= IdempotencyKey.create();
    final question = _question.text.trim();
    setState(() {
      _iaLoading = true;
      _iaError = null;
      _iaReply = null;
      _iaContentRef = null;
    });
    try {
      final response = await _api.oracleIa(
        question: question.isEmpty ? null : question,
        divinationSessionId: sessionId,
        idempotencyKey: key,
      );
      if (!mounted) return;
      _oracleIdempotencyKey = null;
      setState(() {
        _iaReply = assistantReply(response);
        _iaContentRef = response['id'] as String?;
      });
    } catch (error) {
      if (isCreditsRequired(error)) await _openCreditsPaywall();
      if (mounted) {
        setState(
          () => _iaError = isCreditsRequired(error)
              ? 'Saldo insuficiente. Puedes comprar créditos.'
              : oracleErrorMessage(error),
        );
      }
    } finally {
      if (mounted) setState(() => _iaLoading = false);
    }
  }

  Future<void> _openCreditsPaywall() async {
    final fallo = await abrirPaywallDeCreditos(context, _api);
    if (fallo != null && mounted) {
      setState(() => _iaError = fallo);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Stack(children: [_buildScroll(), _buildStickyPanel()]),
      ),
    );
  }

  Widget _buildScroll() {
    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      children: [
        const SizedBox(height: 8),
        _SelectorDeInterprete(
          valor: _interprete,
          onChanged: _cambiarInterprete,
        ),
        const SizedBox(height: 16),
        // El aviso de IA solo cuando la hay. Ensenarlo sobre una tirada que
        // ningun modelo toca seria avisar de algo que no pasa, y de paso
        // restarle la unica cosa que distingue a la via clasica.
        if (_interprete == Interprete.oraculo) ...[
        Semantics(
          label: 'Aviso de inteligencia artificial',
          child: ArcanumCard(
            intensity: 0.35,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.auto_awesome_outlined,
                  color: ArcanumColors.gold,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Estás hablando con un modelo de IA. Sus respuestas son simbólicas y pueden contener errores.',
                    style: ArcanumText.body(14),
                  ),
                ),
              ],
            ),
          ),
        ),
          const SizedBox(height: 18),
        ],
        // `Wrap` y no `Row`: a 360 px las dos pastillas de siempre ya
        // desbordaban 79 px, y no se veia porque los tests corrian a 800. Con
        // "Una carta" de la via clasica son tres. Que bajen de linea en vez de
        // salirse es lo que hacia la pantalla que esto sustituye.
        Wrap(
          alignment: WrapAlignment.center,
          runSpacing: 8,
          children: _tiradas.map((s) {
            final sel = s.$1 == _spread;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: GestureDetector(
                onTap: () => setState(() => _spread = s.$1),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: sel
                        ? ArcanumColors.gold.withValues(alpha: 0.16)
                        : Colors.transparent,
                    border: Border.all(
                      color: sel
                          ? ArcanumColors.gold
                          : ArcanumColors.goldMuted.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    s.$2,
                    style: ArcanumText.body(
                      14,
                      color: sel
                          ? ArcanumColors.gold
                          : ArcanumColors.ivoryMuted,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _question,
          textAlign: TextAlign.center,
          style: ArcanumText.body(16, italic: true),
          cursorColor: ArcanumColors.gold,
          decoration: InputDecoration(
            hintText: 'Formula tu pregunta… (opcional)',
            hintStyle: ArcanumText.body(
              15,
              italic: true,
              color: ArcanumColors.ivoryMuted,
            ),
            border: InputBorder.none,
          ),
        ),
        const SizedBox(height: 20),
        GoldButton(
          label: switch ((_interprete, _spread)) {
            (Interprete.oraculo, _) => 'Consultar al oráculo',
            (Interprete.tradicion, 'one_card') => 'Sacar una carta',
            (Interprete.tradicion, _) => 'Tirar las cartas',
          },
          loading: _drawing,
          onPressed: _draw,
        ),
        const SizedBox(height: 8),
        Text(
          'Los límites y créditos se actualizan desde el servidor.',
          textAlign: TextAlign.center,
          style: ArcanumText.body(
            12,
            color: ArcanumColors.ivoryMuted.withValues(alpha: 0.7),
          ),
        ),
        if (_drawError != null) ...[
          const SizedBox(height: 14),
          Text(
            _drawError!,
            textAlign: TextAlign.center,
            style: ArcanumText.body(14, color: ArcanumColors.ivoryMuted),
          ),
        ],
        const SizedBox(height: 24),
        if (_drawing) const ShuffleDeck(),
        if (!_drawing && _cards != null)
          for (var i = 0; i < _cards!.length; i++)
            KeyedSubtree(
              key: _cardKeys.length > i ? _cardKeys[i] : null,
              child: Column(
                children: [
                  TarotCardView(
                    key: ValueKey('$_drawNonce-$i'),
                    card: _cards![i],
                    index: i,
                    active: _activeCard == i,
                    onToggle: () => _jumpTo(i),
                  ),
                  // El SIGNIFICADO ya lo pinta `TarotCardView`, que lee
                  // `meaning` de la carta: por eso aqui solo va el titulo del
                  // Book T, que es lo unico que la carta no ensena. Ponerlo
                  // entero duplicaba el texto, y un test lo caza.
                  if (_interprete == Interprete.tradicion)
                    _TituloBookT(carta: _cards![i]),
                ],
              ),
            ),
        if (_interprete == Interprete.tradicion && _cards != null) ...[
          const SizedBox(height: 8),
          const SectionLabel('TIRADAS DEL SISTEMA'),
          const SizedBox(height: 10),
          Text(
            'Interpretaciones según el sistema Golden Dawn / Book T. Las cartas '
            'llegan ya resueltas con su significado y su orientación.',
            textAlign: TextAlign.center,
            style: ArcanumText.body(13, color: ArcanumColors.ivoryMuted),
          ),
          if (_readingId != null)
            Center(
              child: ContentReportButton(
                api: _api,
                source: 'tarot',
                contentRef: '$_readingId:tirada',
              ),
            ),
        ],
        if (_sessionId != null) ...[
          const SizedBox(height: 8),
          const SectionLabel('IA RITUAL'),
          const SizedBox(height: 12),
          Text(
            'Pide una interpretación de esta tirada. La pregunta es opcional.',
            textAlign: TextAlign.center,
            style: ArcanumText.body(14, color: ArcanumColors.ivoryMuted),
          ),
          const SizedBox(height: 16),
          GoldButton(
            label: 'Pedir interpretación',
            loading: _iaLoading,
            onPressed: _askIa,
          ),
          if (_iaError != null) ...[
            const SizedBox(height: 14),
            Text(
              _iaError!,
              textAlign: TextAlign.center,
              style: ArcanumText.body(14, color: ArcanumColors.ivoryMuted),
            ),
          ],
          if (_iaReply != null) ...[
            const SizedBox(height: 16),
            ArcanumCard(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 420),
                child: Scrollbar(
                  child: SingleChildScrollView(
                    child: AiOutput(
                    text: _iaReply!,
                    surface: 'oraculo',
                    child: Text(_iaReply!, style: ArcanumText.body(16)),
                  ),
                  ),
                ),
              ),
            ),
            if (_iaContentRef != null)
              Center(
                child: ContentReportButton(
                  api: _api,
                  source: 'oracle',
                  contentRef: _iaContentRef!,
                ),
              ),
          ],
        ],
      ],
    );
  }

  /// Mini-panel sticky: naipes en miniatura (misma cara vectorial) que
  /// aparecen al scrollear. Tap → salta al bloque de esa carta. La carta
  /// que corona el viewport se marca con el glow, sincronizada con el bloque.
  Widget _buildStickyPanel() {
    final cards = _cards;
    if (cards == null) return const SizedBox.shrink();

    // Cruz Celta (10): 2 filas de 5. Resto: 1 fila.
    final celtic = _spread == 'celtic_cross' && cards.length == 10;
    final miniW = celtic ? 42.0 : 58.0;

    List<Widget> mini(Iterable<int> idxs) => [
      for (final i in idxs)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: GestureDetector(
            onTap: () => _jumpTo(i),
            child: TarotNaipe(
              card: cards[i],
              width: miniW,
              reversed: cards[i]['drawn_upright'] == false,
              active: _activeCard == i,
            ),
          ),
        ),
    ];

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: IgnorePointer(
        ignoring: !_showSticky,
        child: AnimatedOpacity(
          opacity: _showSticky ? 1 : 0,
          duration: const Duration(milliseconds: 220),
          child: Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              bottom: 10,
            ),
            decoration: BoxDecoration(
              color: ArcanumColors.background.withValues(alpha: 0.94),
              border: Border(
                bottom: BorderSide(
                  color: ArcanumColors.gold.withValues(alpha: 0.3),
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: celtic
                  ? [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: mini([0, 1, 2, 3, 4]),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: mini([5, 6, 7, 8, 9]),
                      ),
                    ]
                  : [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: mini(List.generate(cards.length, (i) => i)),
                      ),
                    ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Quien lee las cartas, dentro de Consultar.
///
/// Dos pildoras y no tres segmentos arriba: la eleccion no es "que hago" sino
/// "de donde sale el significado", y las dos opciones acaban en una tirada.
class _SelectorDeInterprete extends StatelessWidget {
  const _SelectorDeInterprete({required this.valor, required this.onChanged});

  final Interprete valor;
  final ValueChanged<Interprete> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'QUIÉN LEE LAS CARTAS',
          textAlign: TextAlign.center,
          style: ArcanumText.label(),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _pildora(
              'El oráculo',
              'Un modelo interpreta tu tirada',
              Interprete.oraculo,
            ),
            const SizedBox(width: 10),
            _pildora(
              'La tradición',
              'El significado del Book T, sin IA',
              Interprete.tradicion,
            ),
          ],
        ),
      ],
    );
  }

  Widget _pildora(String titulo, String pie, Interprete cual) {
    final elegida = cual == valor;
    return Expanded(
      child: Semantics(
        button: true,
        selected: elegida,
        label: '$titulo. $pie',
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => onChanged(cual),
          // 48 de alto minimo: es lo que se puede tocar sin fallar, y el
          // conmutador de arriba se quedo en 38 desde siempre.
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: elegida
                    ? ArcanumColors.gold.withValues(alpha: 0.16)
                    : Colors.transparent,
                border: Border.all(
                  color: elegida
                      ? ArcanumColors.gold
                      : ArcanumColors.goldMuted.withValues(alpha: 0.4),
                ),
              ),
              child: ExcludeSemantics(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      titulo,
                      textAlign: TextAlign.center,
                      style: ArcanumText.body(
                        15,
                        color: elegida
                            ? ArcanumColors.gold
                            : ArcanumColors.ivoryMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      pie,
                      textAlign: TextAlign.center,
                      style: ArcanumText.body(
                        11,
                        color: ArcanumColors.ivoryMuted.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// El titulo del Book T de una carta de la via clasica.
///
/// Solo el titulo: el significado ya lo pinta `TarotCardView` desde el mismo
/// mapa. Este nombre -- "The Spirit of Aether" y sus hermanos -- es lo que
/// distingue a la lectura por la tradicion, y se traduce en `titulo_book_t`.
class _TituloBookT extends StatelessWidget {
  const _TituloBookT({required this.carta});

  final Map<String, dynamic> carta;

  @override
  Widget build(BuildContext context) {
    final titulo = tituloEnEspanol(carta['title_book_t'] as String?);
    if (titulo.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 16),
      child: Text(
        titulo,
        textAlign: TextAlign.center,
        style: ArcanumText.body(
          13,
          italic: true,
          color: ArcanumColors.goldMuted,
        ),
      ),
    );
  }
}
