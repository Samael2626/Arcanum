import 'package:flutter/material.dart';

import '../../../core/theme/arcanum_colors.dart';
import '../../../core/theme/arcanum_theme.dart';
import '../../../shared/widgets/arcanum_toggle.dart';
import 'sello_ficha.dart';
import 'sello_modelo.dart';
import 'sello_painter.dart';

/// Tercera cara de Saber: consulta de los sellos historicos de Agrippa 1651.
class SellosScreen extends StatefulWidget {
  const SellosScreen({super.key, this.catalogoOverride});

  /// Fuente inyectable para widget tests; producción lee el asset.
  final Future<CatalogoSellos>? catalogoOverride;

  @override
  State<SellosScreen> createState() => _SellosScreenState();
}

class _SellosScreenState extends State<SellosScreen> {
  late Future<CatalogoSellos> _futuro =
      widget.catalogoOverride ?? CatalogoSellos.cargar();
  String? _filtro;

  void _reintentar() => setState(
    () => _futuro = widget.catalogoOverride ?? CatalogoSellos.cargar(),
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CatalogoSellos>(
      future: _futuro,
      builder: (context, snap) {
        if (snap.hasError) return _Error(onRetry: _reintentar);
        final cat = snap.data;
        if (cat == null) {
          return const Center(
            child: CircularProgressIndicator(color: ArcanumColors.gold),
          );
        }
        return _cuerpo(cat);
      },
    );
  }

  Widget _cuerpo(CatalogoSellos cat) {
    const fuente = 'agrippa1651';
    final todas = cat.de(fuente).toList();
    final filtros = <String>{for (final p in todas) p.planetName!}.toList();
    final piezas = _filtro == null
        ? todas
        : todas
              .where(
                (p) => p.planetName == _filtro,
              )
              .toList();
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                cat.sources[fuente]!.name,
                textAlign: TextAlign.center,
                style: ArcanumText.body(14, color: ArcanumColors.ivoryMuted),
              ),
            ),
            const SizedBox(height: 6),
            _filtrosBarra(filtros),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.78,
                ),
                itemCount: piezas.length,
                itemBuilder: (context, i) => _Celda(
                  pieza: piezas[i],
                  onTap: () => _abrir(cat, piezas[i]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filtrosBarra(List<String> filtros) {
    final opciones = <String?>[null, ...filtros];
    return SizedBox(
      height: ArcanumSelection.minTapHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: opciones.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final valor = opciones[i], elegido = valor == _filtro;
          final rotulo = valor ?? 'Todos';
          return Semantics(
            button: true,
            selected: elegido,
            label: 'Filtrar por $rotulo',
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => setState(() => _filtro = valor),
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: elegido
                      ? ArcanumColors.gold.withValues(alpha: 0.16)
                      : Colors.transparent,
                ),
                child: Text(
                  rotulo,
                  style: ArcanumSelection.textStyle(elegido, size: 15),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _abrir(CatalogoSellos cat, SelloPieza pieza) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ArcanumColors.surface,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      builder: (sheet) => SelloFicha(
        catalogo: cat,
        pieza: pieza,
        onElegir: (otra) {
          Navigator.of(sheet).pop();
          _abrir(cat, otra);
        },
      ),
    );
  }
}

class _Celda extends StatelessWidget {
  const _Celda({required this.pieza, required this.onTap});

  final SelloPieza pieza;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final detalle = detalleSello(pieza);
    return Semantics(
      button: true,
      onTap: onTap,
      label: '${pieza.title}${detalle.isEmpty ? '' : ', $detalle'}',
      child: ExcludeSemantics(
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              color: ArcanumColors.surfaceHigh,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: ArcanumColors.goldMuted.withValues(alpha: 0.35),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
              child: Column(
                children: [
                  Expanded(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: SelloPainter(pieza, ArcanumColors.goldLight),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    rotuloSello(pieza),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ArcanumText.body(13),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'No se pudo abrir el catálogo de sellos.',
          style: ArcanumText.body(16),
        ),
        const SizedBox(height: 8),
        TextButton(
          style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: onRetry,
          child: Text(
            'Reintentar',
            style: ArcanumText.body(16, color: ArcanumColors.gold),
          ),
        ),
      ],
    ),
  );
}
