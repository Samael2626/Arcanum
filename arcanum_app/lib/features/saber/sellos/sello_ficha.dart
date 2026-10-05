import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/arcanum_colors.dart';
import '../../../core/theme/arcanum_theme.dart';
import 'sello_modelo.dart';
import 'sello_painter.dart';

const _tipos = {
  'sello': 'Sello',
  'inteligencia': 'Inteligencia',
  'inteligencias': 'Inteligencias',
  'espiritu': 'Espíritu',
  'espiritu-de-los-espiritus': 'Espíritu de los espíritus',
  'inteligencia-de-las-inteligencias': 'Inteligencia de las inteligencias',
};

/// Rótulo corto de una pieza, el mismo en la cuadrícula y en la ficha.
String rotuloSello(SelloPieza p) => p.esGoetia
    ? '${p.spirit} · ${p.name}${p.second ? ' (2.º)' : ''}'
    : (_tipos[p.kind] ?? p.title);

/// Segunda línea: rango de la Goetia o planeta de Agrippa.
String detalleSello(SelloPieza p) =>
    p.esGoetia ? p.ranks.join(' y ') : (p.planetName ?? '');

/// Ficha de una pieza. La procedencia no es opcional: es obra ajena
/// reproducida, y la licencia exige citarla donde se muestra.
class SelloFicha extends StatelessWidget {
  const SelloFicha({
    super.key,
    required this.catalogo,
    required this.pieza,
    required this.onElegir,
  });

  final CatalogoSellos catalogo;
  final SelloPieza pieza;

  /// Abre otra pieza (la pareja de un espíritu con dos sellos).
  final ValueChanged<SelloPieza> onElegir;

  @override
  Widget build(BuildContext context) {
    final f = catalogo.fuenteDe(pieza);
    final pareja = catalogo.pareja(pieza);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              image: true,
              label: pieza.title,
              child: ExcludeSemantics(
                child: Center(
                  child: SizedBox(
                    width: 260,
                    height: 260,
                    child: CustomPaint(
                      painter: SelloPainter(
                        pieza,
                        ArcanumColors.goldLight,
                        margen: 8,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(pieza.title, style: ArcanumText.heading(26)),
            const SizedBox(height: 4),
            Text(
              f.short,
              style: ArcanumText.body(14, color: ArcanumColors.ivoryMuted),
            ),
            const SizedBox(height: 16),
            if (pieza.esGoetia) ..._goetia() else ..._agrippa(),
            if (pareja != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: TextButton(
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  onPressed: () => onElegir(pareja),
                  child: Text(
                    'Ver su otro sello (figura ${pareja.fig})',
                    style: ArcanumText.body(16, color: ArcanumColors.gold),
                  ),
                ),
              ),
            if (pieza.note != null) ...[
              const SizedBox(height: 12),
              _linea('Nota', pieza.note!),
            ],
            const SizedBox(height: 18),
            Text(
              'PROCEDENCIA',
              style: ArcanumText.label().copyWith(
                color: ArcanumColors.goldLabel,
              ),
            ),
            const SizedBox(height: 8),
            _linea('Obra', f.work),
            _linea('Edición', f.edition),
            _linea('Escaneo', f.scan),
            _linea('Licencia', f.license),
            _linea(
              'Hoja',
              pieza.esGoetia
                  ? 'Hoja ${pieza.leaf} del escaneo (láminas sin paginar).'
                  : 'Página ${pieza.page}, hoja ${pieza.leaf} del escaneo.',
            ),
            const SizedBox(height: 6),
            Text(
              'Calco del escaneo: el trazo no se redibuja ni se corrige.',
              style: ArcanumText.body(
                14,
                color: ArcanumColors.ivoryMuted,
                italic: true,
              ),
            ),
            const SizedBox(height: 8),
            Semantics(
              button: true,
              label: 'Copiar el enlace al escaneo',
              child: TextButton.icon(
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                icon: const Icon(Icons.copy, size: 18),
                label: Text(
                  'Copiar enlace al escaneo',
                  style: ArcanumText.body(16, color: ArcanumColors.gold),
                ),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: pieza.scanUrl));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Enlace copiado')),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _goetia() => [
    _linea(
      'Espíritu',
      'N.º ${pieza.spirit}, ${pieza.name}'
          '${pieza.alt.isEmpty ? '' : ' (también ${pieza.alt.join(', ')})'}.',
    ),
    _linea(
      'Rango',
      [
        for (var i = 0; i < pieza.ranks.length; i++)
          '${pieza.ranks[i]}: su sello va en ${pieza.metals[i]}',
      ].join('; '),
    ),
    _linea('Lámina', 'Figura ${pieza.fig}.'),
  ];

  List<Widget> _agrippa() => [
    if (pieza.planetName != null) _linea('Planeta', pieza.planetName!),
    _linea('Pieza', _tipos[pieza.kind] ?? pieza.title),
  ];

  Widget _linea(String k, String v) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 78,
          child: Text(
            k,
            style: ArcanumText.body(15, color: ArcanumColors.ivoryMuted),
          ),
        ),
        Expanded(child: Text(v, style: ArcanumText.body(16))),
      ],
    ),
  );
}
