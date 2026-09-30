import 'package:flutter/material.dart';

import '../../core/theme/arcanum_colors.dart';

enum ArcaneCurrency { fragment, credit }

class ArcaneCurrencyEmblem extends StatelessWidget {
  const ArcaneCurrencyEmblem({
    super.key,
    required this.currency,
    this.size = 24,
  });

  final ArcaneCurrency currency;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _CurrencyPainter(currency)),
  );
}

class _CurrencyPainter extends CustomPainter {
  const _CurrencyPainter(this.currency);

  final ArcaneCurrency currency;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    switch (currency) {
      case ArcaneCurrency.fragment:
        _paintFragment(canvas);
        break;
      case ArcaneCurrency.credit:
        _paintCredit(canvas);
        break;
    }
    canvas.restore();
  }

  void _paintFragment(Canvas canvas) {
    final body = _polygon([
      const Offset(53, 6),
      const Offset(74, 34),
      const Offset(67, 73),
      const Offset(44, 95),
      const Offset(20, 54),
      const Offset(31, 20),
    ]);
    canvas.drawPath(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ArcanumColors.fragmentBlueLight,
            ArcanumColors.fragmentBlue,
            ArcanumColors.fragmentBlueDeep,
          ],
          stops: [0, 0.38, 1],
        ).createShader(const Rect.fromLTWH(20, 6, 54, 89)),
    );
    canvas.drawPath(
      body,
      Paint()
        ..color = ArcanumColors.fragmentBlueLight
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.7,
    );
    canvas.drawPath(
      _polygon([
        const Offset(53, 6),
        const Offset(49, 47),
        const Offset(31, 20),
      ]),
      Paint()..color = const Color(0x4DE2F6FD),
    );
    canvas.drawPath(
      _polygon([
        const Offset(49, 47),
        const Offset(67, 73),
        const Offset(44, 95),
      ]),
      Paint()..color = const Color(0x4DE2F6FD),
    );
    final facet = Paint()
      ..color = ArcanumColors.fragmentBlueDeep
      ..strokeWidth = 2;
    for (final (start, end) in [
      (const Offset(53, 6), const Offset(49, 47)),
      (const Offset(49, 47), const Offset(44, 95)),
      (const Offset(31, 20), const Offset(49, 47)),
      (const Offset(49, 47), const Offset(74, 34)),
      (const Offset(49, 47), const Offset(67, 73)),
      (const Offset(20, 54), const Offset(49, 47)),
    ]) {
      canvas.drawLine(start, end, facet);
    }
    final spark = Paint()
      ..color = const Color(0xFF8ED3ED)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (final (x, y, radius) in [(80.0, 16.0, 6.5), (15.0, 82.0, 4.0)]) {
      canvas.drawLine(Offset(x, y - radius), Offset(x, y + radius), spark);
      canvas.drawLine(Offset(x - radius, y), Offset(x + radius, y), spark);
    }
  }

  void _paintCredit(Canvas canvas) {
    final center = const Offset(50, 50);
    canvas.drawCircle(center, 43, Paint()..color = const Color(0xFF15121B));
    canvas.drawCircle(
      center,
      43,
      Paint()
        ..color = ArcanumColors.creditGoldAged
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.drawCircle(
      center,
      36,
      Paint()
        ..color = ArcanumColors.goldMuted
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.drawPath(
      _polygon([
        const Offset(50, 18),
        const Offset(77, 50),
        const Offset(50, 82),
        const Offset(23, 50),
      ]),
      Paint()
        ..color = ArcanumColors.creditGoldAged
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.drawPath(
      _polygon([
        const Offset(50, 27),
        const Offset(64, 50),
        const Offset(50, 73),
        const Offset(36, 50),
      ]),
      Paint()..color = const Color(0xFF886A37),
    );
    canvas.drawPath(
      _polygon([
        const Offset(50, 36),
        const Offset(54, 46),
        const Offset(64, 50),
        const Offset(54, 54),
        const Offset(50, 64),
        const Offset(46, 54),
        const Offset(36, 50),
        const Offset(46, 46),
      ]),
      Paint()..color = const Color(0xB8D7C38E),
    );
    final engraving = Paint()
      ..color = const Color(0xFFB89A58)
      ..strokeWidth = 1.5;
    for (final (start, end) in [
      (const Offset(50, 8), const Offset(50, 15)),
      (const Offset(50, 85), const Offset(50, 92)),
      (const Offset(8, 50), const Offset(15, 50)),
      (const Offset(85, 50), const Offset(92, 50)),
    ]) {
      canvas.drawLine(start, end, engraving);
    }
  }

  Path _polygon(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    return path..close();
  }

  @override
  bool shouldRepaint(_CurrencyPainter oldDelegate) =>
      oldDelegate.currency != currency;
}
