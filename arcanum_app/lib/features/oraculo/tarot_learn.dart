/// El modo "Aprender" del Oráculo: el tarot como estudio, no como tirada.
///
/// El Oráculo tiraba cartas pero no dejaba conocerlas. Aquí se recorre el mazo
/// entero (78) carta por carta, con su cara vectorial, sus atribuciones y sus
/// dos significados — al derecho y invertida. Es el destino del salto de tarot
/// desde Hoy ("la carta de Marte es La Torre").
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/arcanum_api.dart';
import '../../core/theme/arcanum_colors.dart';
import '../../core/theme/arcanum_theme.dart';
import '../../shared/widgets/arcanum_mood.dart';
import '../../shared/widgets/arcanum_surface.dart';
import 'widgets/tarot_card.dart';

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
        child: ArcanumSurface(
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
                Center(child: TarotNaipe(card: card, width: 170)),
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
      ('TÍTULO', (card['title_book_t'] as String).trim()),
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
            SizedBox(
              width: 96,
              child: Text(label, style: ArcanumText.label()),
            ),
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
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: selected
                    ? ArcanumColors.gold.withValues(alpha: 0.16)
                    : Colors.transparent,
                border: Border.all(
                  color: selected
                      ? ArcanumColors.gold
                      : ArcanumColors.goldMuted.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                label,
                style: ArcanumText.body(
                  14,
                  color: selected
                      ? ArcanumColors.gold
                      : ArcanumColors.ivoryMuted,
                ),
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
                      return Center(child: TarotNaipe(card: card, width: w));
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
