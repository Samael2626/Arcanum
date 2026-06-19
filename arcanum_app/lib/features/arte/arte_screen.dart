import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/arcanum_api.dart';
import '../../core/theme/arcanum_colors.dart';
import '../../core/theme/arcanum_theme.dart';
import '../../shared/astro_symbols.dart';
import '../../shared/widgets/arcanum_card.dart';
import '../../shared/widgets/info_dot.dart';

const _typeEs = {
  'herb': 'Hierba', 'stone': 'Piedra', 'metal': 'Metal', 'incense': 'Incienso',
  'oil': 'Aceite', 'element': 'Elemento', 'color': 'Color',
};
const _typeIcon = {
  'herb': Icons.spa_outlined, 'stone': Icons.diamond_outlined,
  'metal': Icons.brightness_1_outlined, 'incense': Icons.local_fire_department_outlined,
};

const _filters = <(String?, String)>[
  (null, 'Todos'), ('herb', 'Hierbas'), ('stone', 'Piedras'),
  ('metal', 'Metales'), ('incense', 'Inciensos'),
];

class ArteScreen extends ConsumerStatefulWidget {
  const ArteScreen({super.key});
  @override
  ConsumerState<ArteScreen> createState() => _ArteScreenState();
}

class _ArteScreenState extends ConsumerState<ArteScreen> {
  late final ArcanumApi _api = ref.read(arcanumApiProvider);
  late Future<List<Map<String, dynamic>>> _future = _api.materiaList();
  String? _type;

  void _select(String? type) {
    setState(() {
      _type = type;
      _future = _api.materiaList(itemType: type);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Column(
          children: [
            const SizedBox(height: 32),
            const ArcanumHeader(subtitle: 'Materia Arcana'),
            const SizedBox(height: 10),
            const Center(child: InfoDot('materia')),
            const SizedBox(height: 14),
            _filterBar(),
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(color: ArcanumColors.gold, strokeWidth: 2));
                  }
                  if (snap.hasError) {
                    return Center(
                        child: Text('No se pudo abrir el herbario.\n${snap.error}',
                            textAlign: TextAlign.center,
                            style: ArcanumText.body(14, color: ArcanumColors.ivoryMuted)));
                  }
                  final items = snap.data!;
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) => _itemCard(items[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterBar() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (value, label) = _filters[i];
          final selected = value == _type;
          return GestureDetector(
            onTap: () => _select(value),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: selected ? ArcanumColors.gold.withValues(alpha: 0.16) : Colors.transparent,
                border: Border.all(
                    color: selected ? ArcanumColors.gold : ArcanumColors.goldMuted.withValues(alpha: 0.4)),
              ),
              child: Text(label,
                  style: ArcanumText.body(14,
                      color: selected ? ArcanumColors.gold : ArcanumColors.ivoryMuted)),
            ),
          );
        },
      ),
    );
  }

  Widget _itemCard(Map<String, dynamic> item) {
    final planet = item['planet'] as String?;
    final type = item['item_type'] as String;
    final element = item['element'] as String?;
    return GestureDetector(
      onTap: () => _openDetail(item['slug'] as String),
      child: ArcanumCard(
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: planet != null
                  ? Text(planetGlyph[planet] ?? '•',
                      style: const TextStyle(fontSize: 26, color: ArcanumColors.gold))
                  : Icon(_typeIcon[type] ?? Icons.auto_awesome,
                      color: ArcanumColors.gold, size: 24),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item['name'] as String, style: ArcanumText.heading(20)),
                  const SizedBox(height: 2),
                  Text(
                    [
                      _typeEs[type] ?? type,
                      if (element != null) element[0].toUpperCase() + element.substring(1),
                      if (planet != null) planetEs[planet] ?? planet,
                    ].join('  ·  '),
                    style: ArcanumText.body(13, color: ArcanumColors.ivoryMuted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: ArcanumColors.goldMuted),
          ],
        ),
      ),
    );
  }

  void _openDetail(String slug) {
    showModalBottomSheet(
      context: context,
      backgroundColor: ArcanumColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => _DetailSheet(future: _api.materiaDetail(slug)),
    );
  }
}

class _DetailSheet extends StatelessWidget {
  final Future<Map<String, dynamic>> future;
  const _DetailSheet({required this.future});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 36),
      child: FutureBuilder<Map<String, dynamic>>(
        future: future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const SizedBox(
                height: 160,
                child: Center(
                    child: CircularProgressIndicator(color: ArcanumColors.gold, strokeWidth: 2)));
          }
          final d = snap.data!;
          final planet = d['planet'] as String?;
          final element = d['element'] as String?;
          final props = (d['properties'] as Map).cast<String, dynamic>();
          final intenciones = (props['intenciones'] as List?)?.cast<String>() ?? const [];
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: ArcanumColors.goldMuted, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 18),
              if (planet != null)
                Text(planetGlyph[planet] ?? '',
                    style: const TextStyle(fontSize: 44, color: ArcanumColors.gold)),
              Text(d['name'] as String, style: ArcanumText.heading(30)),
              const SizedBox(height: 6),
              Text(
                [
                  if (planet != null) planetEs[planet] ?? planet,
                  if (element != null) element[0].toUpperCase() + element.substring(1),
                ].join('  ·  '),
                style: ArcanumText.body(15, color: ArcanumColors.ivoryMuted),
              ),
              const SizedBox(height: 20),
              if (intenciones.isNotEmpty)
                Wrap(
                  spacing: 8, runSpacing: 8, alignment: WrapAlignment.center,
                  children: intenciones
                      .map((i) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: ArcanumColors.gold.withValues(alpha: 0.4))),
                            child: Text(i, style: ArcanumText.body(13, color: ArcanumColors.gold)),
                          ))
                      .toList(),
                ),
              if (props['notas'] != null) ...[
                const SizedBox(height: 20),
                Text(props['notas'] as String,
                    textAlign: TextAlign.center, style: ArcanumText.body(16)),
              ],
              if (props['parte'] != null) ...[
                const SizedBox(height: 12),
                Text('Parte: ${props['parte']}',
                    style: ArcanumText.body(13, color: ArcanumColors.ivoryMuted)),
              ],
            ],
          );
        },
      ),
    );
  }
}
