/// El modo "Aprender" del Oráculo: el tarot como estudio, no como tirada.
///
/// El Oráculo tiraba cartas pero no dejaba conocerlas. Aquí se recorre el mazo
/// entero (78) carta por carta, con su cara vectorial, sus atribuciones y sus
/// dos significados — al derecho y invertida. Es el destino del salto de tarot
/// desde Hoy ("la carta de Marte es La Torre").
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../shared/widgets/arcanum_toggle.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/arcanum_api.dart';
import '../../core/theme/arcanum_colors.dart';
import '../../core/theme/arcanum_theme.dart';
import '../../shared/widgets/arcanum_mood.dart';
import '../../shared/widgets/arcanum_resin.dart';
import 'widgets/tarot_card.dart';
import '../../shared/titulo_book_t.dart';

/// Conectores que van en minúscula dentro del nombre (salvo si abren).
const _connectors = {'de', 'del', 'la', 'el', 'los', 'las', 'y', 'e'};

/// Nombre legible desde el slug: el catálogo no trae `name`. 'el-sol' → 'El
/// Sol'; 'dos-de-copas' → 'Dos de Copas'.
String tarotCardName(String slug) {
  final words = slug.split('-');
  return words
      .asMap()
      .entries
      .map((e) {
        final w = e.value;
        if (w.isEmpty) return w;
        if (e.key != 0 && _connectors.contains(w)) return w;
        return w[0].toUpperCase() + w.substring(1);
      })
      .join(' ');
}

const _suitEs = {
  'bastos': 'Bastos',
  'copas': 'Copas',
  'espadas': 'Espadas',
  'oros': 'Oros',
};

const _elementEs = {
  'fire': 'Fuego',
  'fuego': 'Fuego',
  'water': 'Agua',
  'agua': 'Agua',
  'air': 'Aire',
  'aire': 'Aire',
  'earth': 'Tierra',
  'tierra': 'Tierra',
};

ArcanumMood _cardMood(Map<String, dynamic> card) {
  final element = (card['element'] as String?)?.toLowerCase();
  final normalized = _elementEs[element ?? '']?.toLowerCase();
  if (normalized != null) return ArcanumMood.forElement(normalized);
  return ArcanumMood.neutral;
}

/// Ficha de estudio de una carta: la cara grande + atribuciones + los dos
/// significados. Misma andamiaje que las hojas de Materia/Hoy.
void showTarotCardSheet(BuildContext context, Map<String, dynamic> card) {
  final mood = _cardMood(card);
  final name = tarotCardName(card['slug'] as String);

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scroll) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: ArcanumResin(
          mood: mood,
          intensity: 0.42,
          child: SingleChildScrollView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(28, 18, 28, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: ArcanumColors.goldMuted,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Center(child: _NaipeDeLaFicha(card: card)),
                const SizedBox(height: 18),
                Center(
                  child: Text(
                    name,
                    textAlign: TextAlign.center,
                    style: ArcanumText.heading(28, color: ArcanumColors.gold),
                  ),
                ),
                const SizedBox(height: 4),
                Center(child: _lineage(card)),
                const SizedBox(height: 22),
                _MeaningBlock(
                  label: 'AL DERECHO',
                  text: (card['meaning_upright'] as String?) ?? '',
                  accent: mood.accent,
                ),
                const SizedBox(height: 18),
                _MeaningBlock(
                  label: 'INVERTIDA',
                  text: (card['meaning_reversed'] as String?) ?? '',
                  accent: ArcanumColors.burgundyLight,
                ),
                const SizedBox(height: 22),
                _attributions(card),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

Widget _lineage(Map<String, dynamic> card) {
  final arcana = (card['arcana'] as String?) == 'major';
  final suit = (card['suit'] as String?)?.toLowerCase();
  final parts = <String>[
    arcana ? 'Arcano Mayor' : 'Arcano Menor',
    if (suit != null && _suitEs.containsKey(suit)) _suitEs[suit]!,
  ];
  return Text(
    parts.join('  ·  '),
    textAlign: TextAlign.center,
    style: ArcanumText.body(15, color: ArcanumColors.ivoryMuted, italic: true),
  );
}

Widget _attributions(Map<String, dynamic> card) {
  final element = (card['element'] as String?)?.toLowerCase();
  final rows = <(String, String)>[
    if (element != null && _elementEs.containsKey(element))
      ('ELEMENTO', _elementEs[element]!),
    if ((card['zodiac'] as String?)?.trim().isNotEmpty ?? false)
      ('ASTRO', (card['zodiac'] as String).trim()),
    if ((card['decan'] as String?)?.trim().isNotEmpty ?? false)
      ('DECANATO', (card['decan'] as String).trim()),
    if ((card['sephirah'] as String?)?.trim().isNotEmpty ?? false)
      ('SÉFIRA', (card['sephirah'] as String).trim()),
    if ((card['title_book_t'] as String?)?.trim().isNotEmpty ?? false)
      ('TÍTULO', tituloEnEspanol(card['title_book_t'] as String?)),
  ];
  if (rows.isEmpty) return const SizedBox.shrink();
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('EN LA TRADICIÓN', style: ArcanumText.label()),
      const SizedBox(height: 12),
      for (final (label, value) in rows) ...[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 96, child: Text(label, style: ArcanumText.label())),
            Expanded(
              child: Text(
                value,
                style: ArcanumText.body(15, color: ArcanumColors.ivory),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
      ],
    ],
  );
}

class _MeaningBlock extends StatelessWidget {
  final String label;
  final String text;
  final Color accent;
  const _MeaningBlock({
    required this.label,
    required this.text,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: accent.withValues(alpha: 0.07),
        border: Border(left: BorderSide(color: accent, width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: ArcanumText.label()),
          const SizedBox(height: 8),
          Text(
            text.isEmpty ? '—' : text,
            style: ArcanumText.body(16, color: ArcanumColors.ivory),
          ),
        ],
      ),
    );
  }
}

// ── Catálogo: el mazo completo, recorrible ────────────────────────────────

const _filters = <(String?, String)>[
  (null, 'Todos'),
  ('major', 'Mayores'),
  ('bastos', 'Bastos'),
  ('copas', 'Copas'),
  ('espadas', 'Espadas'),
  ('oros', 'Oros'),
];

/// El modo Aprender: rejilla del mazo entero con filtro por arcano/palo. Tap en
/// una carta abre su ficha. [focusSlug] (del salto desde Hoy) abre esa carta en
/// cuanto carga el mazo.
class TarotCatalog extends ConsumerStatefulWidget {
  final String? focusSlug;
  const TarotCatalog({super.key, this.focusSlug});

  @override
  ConsumerState<TarotCatalog> createState() => _TarotCatalogState();
}

class _TarotCatalogState extends ConsumerState<TarotCatalog> {
  late final Future<List<Map<String, dynamic>>> _future = ref
      .read(arcanumApiProvider)
      .tarotList();
  String? _filter;
  bool _focusOpened = false;

  bool _matches(Map<String, dynamic> card) {
    if (_filter == null) return true;
    if (_filter == 'major') return card['arcana'] == 'major';
    return (card['suit'] as String?)?.toLowerCase() == _filter;
  }

  /// Abre la ficha de la carta enfocada una sola vez, tras cargar el mazo.
  void _openFocusOnce(List<Map<String, dynamic>> cards) {
    if (widget.focusSlug == null || _focusOpened) return;
    _focusOpened = true;
    final match = cards.where((c) => c['slug'] == widget.focusSlug);
    if (match.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showTarotCardSheet(context, match.first);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: ArcanumColors.gold,
              strokeWidth: 2,
            ),
          );
        }
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'No se pudo abrir el mazo. Desliza para reintentar.',
                textAlign: TextAlign.center,
                style: ArcanumText.body(15, color: ArcanumColors.ivoryMuted),
              ),
            ),
          );
        }
        final all = snap.data ?? const [];
        _openFocusOnce(all);
        final cards = all.where(_matches).toList(growable: false);
        return Column(
          children: [
            const SizedBox(height: 8),
            _filterBar(),
            const SizedBox(height: 6),
            Expanded(child: _grid(cards)),
          ],
        );
      },
    );
  }

  Widget _filterBar() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (value, label) = _filters[i];
          final selected = value == _filter;
          return InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => setState(() => _filter = value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: ArcanumSelection.surface(selected, radio: 20),
              child: Text(
                label,
                style: ArcanumSelection.textStyle(selected, size: 14),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _grid(List<Map<String, dynamic>> cards) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 16,
        crossAxisSpacing: 14,
        childAspectRatio: 0.54,
      ),
      itemCount: cards.length,
      itemBuilder: (context, i) {
        final card = cards[i];
        final name = tarotCardName(card['slug'] as String);
        return Semantics(
          button: true,
          label: 'Abrir $name',
          excludeSemantics: true,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => showTarotCardSheet(context, card),
            child: Column(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    // Encaja el naipe (relación 1:1.6) sin desbordar la celda:
                    // limita por el MENOR de ancho o alto disponibles.
                    builder: (context, c) {
                      final w = math.min(c.maxWidth, c.maxHeight / 1.6);
                      return Center(
                        child: TarotNaipe(card: card, width: w),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: ArcanumText.body(12, color: ArcanumColors.ivory),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// El naipe de la ficha de estudio, con el grabado de 1909 a un toque.
///
/// POR QUE AQUI Y NO EN LA REJILLA
///
/// La rejilla de Aprender es un `GridView.builder`: perezoso, monta doce o
/// quince celdas y destruye las que salen de pantalla. Darle el gesto ahi
/// obligaria a guardar la cara de las 78 FUERA de la celda, porque si vive
/// dentro el scroll la borra -- que es exactamente el fallo que se cazo en la
/// tirada, multiplicado por 78 y en la pantalla donde mas se hace scroll. Y
/// aun resuelto, un catalogo con cartas a medio voltear segun lo que tocaste
/// antes no es un catalogo, es ruido.
///
/// En la ficha no hay nada de eso: una sola carta, un solo controlador, y el
/// estado muere con la hoja. No hay nada que persistir ni que perder.
class _NaipeDeLaFicha extends StatefulWidget {
  const _NaipeDeLaFicha({required this.card});

  final Map<String, dynamic> card;

  @override
  State<_NaipeDeLaFicha> createState() => _NaipeDeLaFichaState();
}

class _NaipeDeLaFichaState extends State<_NaipeDeLaFicha>
    with SingleTickerProviderStateMixin {
  static const double _ancho = 170;
  static const Duration _giro = Duration(milliseconds: 620);

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: _giro,
  );
  late final Animation<double> _t = CurvedAnimation(
    parent: _c,
    curve: Curves.easeInOutCubic,
  );

  bool _grabado = false;

  bool get _reducido => MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  /// Si ya se paso el canto del giro. Hasta los 90 grados la carta sigue
  /// ensenando la cara de antes, y el rotulo de debajo tiene que creerselo.
  bool get _cruzado => _t.value >= 0.5;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _voltear(String? lamina) {
    if (lamina == null || _c.isAnimating) return;
    setState(() => _grabado = !_grabado);
    if (_reducido) {
      // Sin movimiento la carta CAMBIA de cara, no gira.
      _c.value = _grabado ? 1 : 0;
      return;
    }
    _grabado ? _c.forward(from: 0) : _c.reverse(from: 1);
  }

  @override
  Widget build(BuildContext context) {
    final face = TarotFace.resolve(widget.card);
    final lamina = face.rwsAsset;
    final alto = _ancho * 1.6;

    return Column(
      children: [
        Semantics(
          button: lamina != null,
          label: lamina == null
              ? null
              : (_grabado
                    ? 'Volver al trazo de ARCANUM'
                    : 'Ver el grabado de 1909'),
          excludeSemantics: lamina != null,
          child: GestureDetector(
            // Con llave propia: dentro de la hoja hay mas de un gesto y el
            // de la carta tiene que poder senalarse sin contar por orden.
            key: const ValueKey('ficha-naipe'),
            onTap: () => _voltear(lamina),
            child: AnimatedBuilder(
              animation: _t,
              builder: (context, _) {
                final angulo = _t.value * math.pi;
                final cara = _cruzado && lamina != null
                    ? _lamina(lamina, alto)
                    : TarotNaipe(card: widget.card, width: _ancho);
                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0019)
                    ..rotateY(angulo),
                  child: _cruzado
                      // Pasado el canto la cara viaja girada mas de 90 grados
                      // y saldria en espejo: se le deshace aqui.
                      ? Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()..rotateY(math.pi),
                          child: cara,
                        )
                      : cara,
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 10),
        // La invitacion, que es lo que hace el gesto descubrible. Sin ella el
        // toque existe y nadie lo encuentra.
        if (lamina != null)
          AnimatedBuilder(
            animation: _t,
            builder: (context, _) => Text(
              _cruzado
                  ? 'Grabado de 1909 · toca para volver'
                  : 'Toca la carta para ver el grabado de 1909',
              textAlign: TextAlign.center,
              style: ArcanumText.body(
                12.5,
                color: ArcanumColors.ivoryMuted,
                italic: true,
              ),
            ),
          ),
      ],
    );
  }

  Widget _lamina(String asset, double alto) => ClipRRect(
    borderRadius: BorderRadius.circular(_ancho * 0.10),
    child: Image.asset(
      asset,
      width: _ancho,
      height: alto,
      fit: BoxFit.cover,
      cacheWidth: (_ancho * MediaQuery.devicePixelRatioOf(context)).round(),
      filterQuality: FilterQuality.medium,
      // Un slug sin lamina no es un error: la carta se queda en su trazo.
      errorBuilder: (_, _, _) => TarotNaipe(card: widget.card, width: _ancho),
    ),
  );
}
