/// Lecturas guardadas de la mesa. La misma lista vive en dos sitios: el panel
/// «Lecturas» del radial del paño y la ruta `/lecturas` del menu.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/arcanum_api.dart';
import '../../../core/theme/arcanum_colors.dart';
import '../../../core/theme/arcanum_theme.dart';
import '../domain/table_error.dart';
import '../domain/table_models.dart';
import '../tarot_screen.dart';

/// Nombre legible de una tirada guardada.
String tarotSpreadName(String slug, Iterable<SpreadDef> spreads) {
  if (slug == 'free') return 'Lectura libre';
  for (final s in spreads) {
    if (s.slug == slug) return s.name;
  }
  return 'Tirada';
}

/// Fecha local dd/mm/aaaa hh:mm de una lectura.
String tarotReadingDate(String? iso) {
  final d = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
  if (d == null) return '';
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
}

const _body = TextStyle(fontSize: 15, height: 1.45, color: ArcanumColors.ivory);
const _muted = TextStyle(
  fontSize: 13,
  height: 1.4,
  color: ArcanumColors.ivoryMuted,
);

/// La lista: cargando, error, vacia o una fila por lectura. Solo las lecturas
/// que guardaron la mesa ofrecen «Continuar».
class TarotReadingsList extends StatelessWidget {
  const TarotReadingsList({
    super.key,
    required this.readings,
    required this.spreadName,
    this.onContinue,
  });

  final Future<List<Map<String, dynamic>>> readings;
  final String Function(String slug) spreadName;
  final ValueChanged<Map<String, dynamic>>? onContinue;

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: readings,
    builder: (context, snap) {
      final rows = snap.data;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (snap.hasError)
            Text(tableErrorMessage(snap.error!), style: _muted),
          if (rows == null && !snap.hasError)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Center(
                child: CircularProgressIndicator(color: ArcanumColors.gold),
              ),
            ),
          if (rows != null && rows.isEmpty)
            Text('Todavía no has cerrado ningún círculo.', style: _muted),
          for (final r in rows ?? const <Map<String, dynamic>>[])
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(spreadName(r['spread_type'] as String), style: _body),
              subtitle: Text(
                [
                  tarotReadingDate(r['created_at'] as String?),
                  if (r['question'] != null) '«${r['question']}»',
                ].join(' · '),
                style: _muted,
              ),
              // solo las lecturas de la mesa guardaron la mesa: las demas no se recolocan
              trailing: r['table_snapshot'] == null || onContinue == null
                  ? null
                  : TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      onPressed: () => onContinue!(r),
                      child: const Text('Continuar'),
                    ),
            ),
        ],
      );
    },
  );
}

/// `/lecturas`: el historial fuera de la mesa. «Continuar» abre la mesa con
/// esa lectura colocada.
class TarotReadingsScreen extends ConsumerStatefulWidget {
  const TarotReadingsScreen({super.key});

  @override
  ConsumerState<TarotReadingsScreen> createState() =>
      _TarotReadingsScreenState();
}

class _TarotReadingsScreenState extends ConsumerState<TarotReadingsScreen> {
  late final Future<List<Map<String, dynamic>>> _readings = ref
      .read(arcanumApiProvider)
      .tarotReadings();

  @override
  Widget build(BuildContext context) {
    final spreads =
        ref.watch(tarotCatalogProvider).value?.spreads ?? const <SpreadDef>[];
    return Scaffold(
      backgroundColor: ArcanumColors.background,
      appBar: AppBar(
        backgroundColor: ArcanumColors.background,
        title: Text('Tus lecturas', style: ArcanumText.heading(22)),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: TarotReadingsList(
                readings: _readings,
                spreadName: (slug) => tarotSpreadName(slug, spreads),
                onContinue: (r) => context.push('/tarot', extra: r),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
