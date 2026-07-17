import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/arcanum_colors.dart';
import '../../shared/widgets/arcanum_mood.dart';
import 'engraving_manifest_loader.dart';
import 'materia_engravings.dart';

/// Capa visual unificada de Materia Arcana.
///
/// Las hierbas con lámina histórica usan el SVG del manifiesto. El resto cae
/// en el grabado procedural semántico, de modo que un asset ausente o inválido
/// nunca deja una tarjeta vacía.
class MateriaSpecimen extends StatefulWidget {
  const MateriaSpecimen({
    super.key,
    required this.slug,
    required this.type,
    required this.mood,
    required this.size,
    this.progress = 1,
    this.strokeWidth = 1.5,
    this.compact = false,
    this.semanticLabel,
  });

  final String slug;
  final String type;
  final ArcanumMood mood;
  final double size;
  final double progress;
  final double strokeWidth;

  /// Usa la silueta procedural, legible en tarjetas pequeñas.
  /// La lámina histórica se reserva para la vista de detalle.
  final bool compact;
  final String? semanticLabel;

  @override
  State<MateriaSpecimen> createState() => _MateriaSpecimenState();
}

class _MateriaSpecimenState extends State<MateriaSpecimen> {
  Future<EngravingEntry?>? _entry;

  @override
  void initState() {
    super.initState();
    _entry = widget.compact ? null : _resolve();
  }

  @override
  void didUpdateWidget(covariant MateriaSpecimen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slug != widget.slug ||
        oldWidget.type != widget.type ||
        oldWidget.compact != widget.compact) {
      _entry = widget.compact ? null : _resolve();
    }
  }

  Future<EngravingEntry?>? _resolve() {
    return () async {
      final manifest = EngravingManifest.instance;
      await manifest.ensureLoaded();
      final entry = manifest.resolve(widget.slug);
      return entry?.isFinal == true ? entry : null;
    }();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return MateriaGlyph(
        type: widget.type,
        size: widget.size,
        variant: materiaVariant(widget.slug, widget.type),
        progress: widget.progress,
      );
    }
    final future = _entry;
    if (future == null) return _fallback();
    return FutureBuilder<EngravingEntry?>(
      future: future,
      builder: (context, snapshot) {
        final path = snapshot.data?.assetPath;
        if (path == null) return _fallback();
        return _HistoricalPlate(
          assetPath: path,
          mood: widget.mood,
          size: widget.size,
          progress: widget.progress,
          semanticLabel: widget.semanticLabel,
          fallback: _fallback(),
        );
      },
    );
  }

  Widget _fallback() => MateriaArt(
    type: widget.type,
    variant: materiaVariant(widget.slug, widget.type),
    mood: widget.mood,
    size: widget.size,
    progress: widget.progress,
    strokeWidth: widget.strokeWidth,
  );
}

class _HistoricalPlate extends StatelessWidget {
  const _HistoricalPlate({
    required this.assetPath,
    required this.mood,
    required this.size,
    required this.progress,
    required this.fallback,
    this.semanticLabel,
  });

  final String assetPath;
  final ArcanumMood mood;
  final double size;
  final double progress;
  final Widget fallback;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = progress.clamp(0.0, 1.0);
    final ink = Color.lerp(
      mood.accent,
      ArcanumColors.ivory,
      0.54,
    )!.withValues(alpha: 0.96);
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: size,
        child: ClipRect(
          clipper: _PlateRevealClipper(t),
          child: Opacity(
            opacity: Curves.easeOut.transform(t),
            child: SvgPicture.asset(
              assetPath,
              width: size,
              height: size,
              fit: BoxFit.contain,
              alignment: Alignment.center,
              colorFilter: ColorFilter.mode(ink, BlendMode.srcIn),
              semanticsLabel: semanticLabel,
              errorBuilder: (_, _, _) => fallback,
            ),
          ),
        ),
      ),
    );
  }
}

class _PlateRevealClipper extends CustomClipper<Rect> {
  const _PlateRevealClipper(this.progress);
  final double progress;

  @override
  Rect getClip(Size size) => Rect.fromLTWH(
    0,
    size.height * (1 - progress),
    size.width,
    size.height * progress,
  );

  @override
  bool shouldReclip(covariant _PlateRevealClipper oldClipper) =>
      oldClipper.progress != progress;
}
