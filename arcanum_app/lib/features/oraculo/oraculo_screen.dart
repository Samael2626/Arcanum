import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/arcanum_api.dart';
import '../../core/api/oracle_error.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/state/flow_providers.dart';
import '../../core/theme/arcanum_colors.dart';
import '../../core/theme/arcanum_theme.dart';
import '../../shared/widgets/arcanum_card.dart';
import '../../shared/widgets/gold_button.dart';
// El "?" de Oráculo vive ahora en la barra superior del shell (InfoDot allí).
import '../../shared/widgets/login_prompt.dart';
import 'tarot_learn.dart';
import 'widgets/tarot_card.dart';

const _spreads = <(String, String)>[
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
        border: Border.all(color: ArcanumColors.goldMuted.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          _seg('Consultar', 0),
          _seg('Aprender', 1),
        ],
      ),
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
  bool _drawing = false;
  String? _drawError;
  List<Map<String, dynamic>>? _cards;
  // id de la tirada visible (DivinationSession.id). Ancla la interpretación
  // IA a estas cartas exactas (modo 2/3 del endpoint /oracle/ia).
  String? _sessionId;

  bool _iaLoading = false;
  String? _iaError;
  String? _iaReply;

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

  Future<void> _draw() async {
    setState(() {
      _drawing = true;
      _drawError = null;
      _iaError = null;
      _iaReply = null;
    });
    try {
      final data = await _api.tarotDraw(_spread);
      final cards = ((data['cards_drawn'] as Map)['cards'] as List)
          .cast<Map<String, dynamic>>();
      setState(() {
        _cards = cards;
        _sessionId = data['id'] as String?;
        _drawNonce++;
        _activeCard = 0;
        _cardKeys = List.generate(cards.length, (_) => GlobalKey());
        _showSticky = false;
      });
    } catch (e) {
      setState(() {
        _cards = null;
        _sessionId = null;
        _drawError = 'No se pudo consultar el oráculo. $e';
      });
    } finally {
      setState(() => _drawing = false);
    }
  }

  Future<void> _askIa() async {
    final sessionId = _sessionId;
    if (sessionId == null) return; // el botón no se muestra sin tirada visible.
    final q = _question.text.trim();
    setState(() {
      _iaLoading = true;
      _iaError = null;
      _iaReply = null;
    });
    try {
      // Modo 2 (con pregunta) o modo 3 (solo la tirada) — decide el servicio.
      final res = await _api.oracleIa(
        question: q.isEmpty ? null : q,
        divinationSessionId: sessionId,
      );
      setState(() => _iaReply = assistantReply(res));
    } catch (e) {
      setState(() => _iaError = oracleErrorMessage(e));
    } finally {
      setState(() => _iaLoading = false);
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
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: _spreads.map((s) {
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
          label: 'Consultar al oráculo',
          loading: _drawing,
          onPressed: _draw,
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
              child: TarotCardView(
                key: ValueKey('$_drawNonce-$i'),
                card: _cards![i],
                index: i,
                active: _activeCard == i,
                onToggle: () => _jumpTo(i),
              ),
            ),
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
                    child: Text(_iaReply!, style: ArcanumText.body(16)),
                  ),
                ),
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
