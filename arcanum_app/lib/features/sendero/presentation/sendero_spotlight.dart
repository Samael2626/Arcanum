import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/astro/birth_data.dart';
import '../../../core/theme/arcanum_colors.dart';
import '../../../core/theme/arcanum_theme.dart';
import '../application/sendero_guide_controller.dart';

class SenderoSpotlight extends ConsumerStatefulWidget {
  const SenderoSpotlight({super.key, required this.guide});

  final SenderoGuideState guide;

  @override
  ConsumerState<SenderoSpotlight> createState() => _SenderoSpotlightState();
}

class _SenderoSpotlightState extends ConsumerState<SenderoSpotlight>
    with WidgetsBindingObserver {
  final _rootKey = GlobalKey();
  final _cardKey = GlobalKey();
  Rect? _targetRect;
  double? _cardHeight;
  String? _scrolledTarget;
  Timer? _measureTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleMeasure();
  }

  @override
  void didUpdateWidget(covariant SenderoSpotlight oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.guide.current.target != widget.guide.current.target) {
      _targetRect = null;
      _scrolledTarget = null;
    }
    _scheduleMeasure();
  }

  @override
  void didChangeMetrics() => _scheduleMeasure();

  /// La pantalla que se desplaza bajo el objetivo: al moverse, el hueco del
  /// velo se recoloca (07-oct: se quedaba donde estaba y tapaba la placa).
  ScrollPosition? _watched;

  void _watch(BuildContext target) {
    final position = Scrollable.maybeOf(target)?.position;
    if (identical(position, _watched)) return;
    _watched?.removeListener(_measure);
    _watched = position?..addListener(_measure);
  }

  @override
  void dispose() {
    _watched?.removeListener(_measure);
    _measureTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _scheduleMeasure() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    _measureTimer?.cancel();
    _measureTimer = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => _measure(),
    );
  }

  void _measure() {
    if (!mounted) return;
    final card = _cardKey.currentContext?.findRenderObject();
    if (card is RenderBox && card.hasSize) {
      final height = card.size.height;
      if (_cardHeight == null || (height - _cardHeight!).abs() > 1) {
        setState(() => _cardHeight = height);
      }
    }
    final targetKey = ref
        .read(senderoGuideTargetsProvider)
        .keyFor(widget.guide.current.target);
    final targetContext = targetKey.currentContext;
    final target = targetContext?.findRenderObject();
    final root = _rootKey.currentContext?.findRenderObject();
    if (target is! RenderBox || root is! RenderBox || !target.hasSize) {
      if (_targetRect != null) setState(() => _targetRect = null);
      return;
    }
    _watch(targetContext!);
    final origin = root.globalToLocal(target.localToGlobal(Offset.zero));
    final whole = origin & target.size;
    final rect = whole.intersect(Offset.zero & root.size);
    // a medias tambien se trae a la vista: asomaba un borde, el velo iluminaba
    // media placa y el toque caia fuera de la pantalla
    final cut = rect.isEmpty || rect.height < whole.height - 1;
    if (cut && _scrolledTarget != widget.guide.current.target) {
      _scrolledTarget = widget.guide.current.target;
      unawaited(
        Scrollable.ensureVisible(
          targetContext,
          duration: MediaQuery.of(context).disableAnimations
              ? Duration.zero
              : const Duration(milliseconds: 300),
        ).then((_) => _scheduleMeasure()),
      );
    }
    final next = rect.isEmpty ? null : rect.inflate(5);
    if (next != _targetRect) setState(() => _targetRect = next);
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.guide.current;
    final hasNatalData = ref.watch(birthSignatureProvider) != null;
    final body = step.target == 'horoscope_card' && !hasNatalData
        ? 'Necesitas completar tu carta natal para abrir una lectura. Puedes terminar esta guía sin gastar nada.'
        : step.body;
    final rect = _targetRect;
    final targets = ref.watch(senderoGuideTargetsProvider);
    final root = _rootKey.currentContext?.findRenderObject();
    final firstDrawerRow = step.target.startsWith('section_')
        ? targets.keyFor('section_hoy').currentContext?.findRenderObject()
        : null;
    final firstDrawerRowTop = root is RenderBox && firstDrawerRow is RenderBox
        ? root.globalToLocal(firstDrawerRow.localToGlobal(Offset.zero)).dy
        : null;
    if (targets.keyFor(step.target).currentContext == null && rect != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    }

    return LayoutBuilder(
      builder: (context, bounds) {
        final cardWidth = math.min(360.0, bounds.maxWidth - 24);
        final cardHeight = _cardHeight ?? 200;
        final safeTop = MediaQuery.paddingOf(context).top + 12;
        final safeBottom =
            bounds.maxHeight - MediaQuery.paddingOf(context).bottom - 12;
        final maxTop = math.max(safeTop, safeBottom - cardHeight);
        final drawerCardTop = firstDrawerRowTop == null
            ? null
            : firstDrawerRowTop - cardHeight - 12;
        final top = switch (rect) {
          null => maxTop,
          _ => () {
            if (drawerCardTop != null && drawerCardTop >= safeTop) {
              return drawerCardTop.clamp(safeTop, maxTop);
            }
            final below = rect.bottom + 12;
            final above = rect.top - cardHeight - 12;
            final spaceBelow = safeBottom - below;
            final spaceAbove = rect.top - safeTop - 12;
            final preferred = spaceBelow >= cardHeight
                ? below
                : spaceAbove >= cardHeight
                ? above
                : spaceBelow >= spaceAbove
                ? below
                : above;
            return preferred.clamp(safeTop, maxTop);
          }(),
        };
        final left = rect == null
            ? (bounds.maxWidth - cardWidth) / 2
            : (rect.center.dx - cardWidth / 2).clamp(
                12.0,
                bounds.maxWidth - cardWidth - 12,
              );

        return Stack(
          key: _rootKey,
          children: [
            if (rect != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: _VeilPainter(rect)),
                ),
              ),
            AnimatedPositioned(
              duration: MediaQuery.of(context).disableAnimations
                  ? Duration.zero
                  : const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              top: top,
              left: left,
              width: cardWidth,
              child: KeyedSubtree(
                key: _cardKey,
                child: Material(
                  key: const ValueKey('sendero_guide_card'),
                  color: ArcanumColors.surfaceHigh,
                  elevation: 14,
                  shape: RoundedRectangleBorder(
                    side: const BorderSide(color: ArcanumColors.goldMuted),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${widget.guide.journey.title.toUpperCase()} · ${widget.guide.step + 1} DE ${widget.guide.journey.steps.length}',
                          style: ArcanumText.label(),
                        ),
                        const SizedBox(height: 6),
                        Text(step.title, style: ArcanumText.heading(23)),
                        const SizedBox(height: 4),
                        Text(body, style: ArcanumText.body(14)),
                        const SizedBox(height: 6),
                        if (rect == null &&
                            (step.target.startsWith('section_') ||
                                step.target == 'settings'))
                          Text(
                            'Abre el menú para continuar',
                            style: ArcanumText.body(
                              13,
                              color: ArcanumColors.gold,
                            ),
                          )
                        else if (rect == null)
                          TextButton(
                            onPressed: widget.guide.expectedRoute == null
                                ? null
                                : () => context.go(widget.guide.expectedRoute!),
                            child: const Text('Ir a esta parte'),
                          )
                        else if (step.buttonLabel != null)
                          TextButton(
                            onPressed: () => ref
                                .read(senderoGuideProvider.notifier)
                                .onAction(step.target),
                            child: Text(step.buttonLabel!),
                          )
                        else
                          Text(
                            'Toca el control iluminado',
                            style: ArcanumText.body(
                              13,
                              color: ArcanumColors.gold,
                            ),
                          ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              key: const ValueKey('sendero_guide_pause'),
                              onPressed: () => ref
                                  .read(senderoGuideProvider.notifier)
                                  .pause(),
                              child: const Text('Pausar'),
                            ),
                            TextButton(
                              key: const ValueKey('sendero_guide_skip'),
                              onPressed: () => unawaited(
                                ref.read(senderoGuideProvider.notifier).skip(),
                              ),
                              child: const Text('Omitir'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _VeilPainter extends CustomPainter {
  const _VeilPainter(this.target);

  final Rect target;

  @override
  void paint(Canvas canvas, Size size) {
    final cutout = RRect.fromRectAndRadius(target, const Radius.circular(12));
    final veil = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(cutout);
    canvas.drawPath(veil, Paint()..color = const Color(0x7607060A));
    canvas.drawRRect(
      cutout,
      Paint()
        ..color = ArcanumColors.gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _VeilPainter oldDelegate) =>
      oldDelegate.target != target;
}
