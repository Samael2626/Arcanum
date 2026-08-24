import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/arcanum_colors.dart';
import '../../../../core/theme/arcanum_theme.dart';
import '../../../../shared/astro_symbols.dart';
import '../../domain/figura_aspecto.dart';

const double aspectBodyHaloScale = 1.5;

class LevelThreeAspects extends StatelessWidget {
  const LevelThreeAspects({super.key, required this.overview});

  final Future<Map<String, dynamic>> overview;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: overview,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.only(top: 18),
            child: SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: ArcanumColors.goldMuted,
              ),
            ),
          );
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.only(top: 18),
            child: Text(
              'Las otras ruedas no están disponibles.',
              textAlign: TextAlign.center,
              style: ArcanumText.body(13, color: ArcanumColors.ivoryMuted),
            ),
          );
        }

        final data = snapshot.data!;
        final transits = _map(data['transits']);
        final chart = _map(_map(data['natal_chart'])['chart_data']);
        final aspects = _maps(transits['aspects_to_natal']);
        final transitLongitudes = _longitudes(_maps(transits['transiting']));
        final natalBodies = <Map<String, dynamic>>[
          ..._maps(chart['planets']),
          if (_mapOrNull(chart['ascendant']) case final asc?)
            {...asc, 'name': 'ascendant'},
          if (_mapOrNull(chart['midheaven']) case final mc?)
            {...mc, 'name': 'midheaven'},
        ];
        final natalLongitudes = _longitudes(natalBodies);

        if (aspects.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(top: 18),
            child: Text(
              'No hay otros aspectos exactos.',
              textAlign: TextAlign.center,
              style: ArcanumText.body(13, color: ArcanumColors.ivoryMuted),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Column(
            children: [
              Text('TODOS LOS ASPECTOS', style: ArcanumText.label()),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisExtent: 176,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: aspects.length,
                itemBuilder: (context, index) {
                  final aspect = aspects[index];
                  final transit = aspect['transit'] as String?;
                  final natal = aspect['natal'] as String?;
                  return _AspectTarget(
                    index: index,
                    aspect: aspect,
                    transitLongitude: transitLongitudes[transit],
                    natalLongitude: natalLongitudes[natal],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AspectTarget extends StatelessWidget {
  const _AspectTarget({
    required this.index,
    required this.aspect,
    required this.transitLongitude,
    required this.natalLongitude,
  });

  final int index;
  final Map<String, dynamic> aspect;
  final double? transitLongitude;
  final double? natalLongitude;

  @override
  Widget build(BuildContext context) {
    final transit = aspect['transit'] as String?;
    final natal = aspect['natal'] as String?;
    final aspectKey = aspect['aspect'] as String?;
    final title =
        '${_bodyName(transit)} ${aspectEs[aspectKey] ?? aspectKey ?? ''} '
        '${_bodyName(natal)}';

    return Semantics(
      button: true,
      label: 'Abrir rueda real de $title',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: Key('hoy-aspect-target-$index'),
          onTap: () => _showWheel(
            context,
            title: title,
            aspect: aspectKey,
            transit: transit,
            natal: natal,
            transitLongitude: transitLongitude,
            natalLongitude: natalLongitude,
          ),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: ArcanumColors.gold.withValues(alpha: 0.18),
              ),
            ),
            child: Column(
              children: [
                AspectWheel(
                  index: index,
                  aspect: aspectKey,
                  transit: transit,
                  natal: natal,
                  transitLongitude: transitLongitude,
                  natalLongitude: natalLongitude,
                  size: 110,
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: ArcanumText.body(11, color: ArcanumColors.ivoryMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AspectWheel extends StatelessWidget {
  const AspectWheel({
    super.key,
    required this.index,
    required this.aspect,
    required this.transit,
    required this.natal,
    required this.transitLongitude,
    required this.natalLongitude,
    required this.size,
  });

  final int index;
  final String? aspect;
  final String? transit;
  final String? natal;
  final double? transitLongitude;
  final double? natalLongitude;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      key: Key('hoy-aspect-wheel-$index'),
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _AspectWheelPainter(
                transit: transit,
                natal: natal,
                transitLongitude: transitLongitude,
                natalLongitude: natalLongitude,
              ),
            ),
          ),
          Text(
            _aspectGlyph[aspect] ?? '·',
            key: Key('hoy-aspect-glyph-$index'),
            style: ArcanumText.heading(20, color: ArcanumColors.gold),
          ),
          if (transitLongitude == null || natalLongitude == null)
            Positioned(
              bottom: 3,
              child: Text(
                'sin longitud',
                style: ArcanumText.body(9, color: ArcanumColors.ivoryMuted),
              ),
            ),
        ],
      ),
    );
  }
}

class _AspectWheelPainter extends CustomPainter {
  const _AspectWheelPainter({
    required this.transit,
    required this.natal,
    required this.transitLongitude,
    required this.natalLongitude,
  });

  final String? transit;
  final String? natal;
  final double? transitLongitude;
  final double? natalLongitude;

  @override
  void paint(Canvas canvas, Size size) {
    final center = PuntoRueda(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 13;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = ArcanumColors.gold.withValues(alpha: 0.18);
    final offsetCenter = Offset(center.x, center.y);
    canvas.drawCircle(offsetCenter, radius, ring);
    _paintText(canvas, '♈', Offset(center.x, 6), 9, ArcanumColors.goldMuted);

    for (var sign = 0; sign < 12; sign++) {
      final outer = puntoZodiacal(sign * 30, radio: radius, centro: center);
      final inner = puntoZodiacal(
        sign * 30,
        radio: radius - (sign == 0 ? 8 : 5),
        centro: center,
      );
      canvas.drawLine(Offset(outer.x, outer.y), Offset(inner.x, inner.y), ring);
    }

    if (transitLongitude == null || natalLongitude == null) return;
    final transitPoint = puntoZodiacal(
      transitLongitude!,
      radio: radius,
      centro: center,
    );
    final natalPoint = puntoZodiacal(
      natalLongitude!,
      radio: radius,
      centro: center,
    );
    final transitOffset = Offset(transitPoint.x, transitPoint.y);
    final natalOffset = Offset(natalPoint.x, natalPoint.y);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = ArcanumColors.gold.withValues(alpha: 0.8);
    canvas.drawLine(transitOffset, offsetCenter, line);
    canvas.drawLine(offsetCenter, natalOffset, line);

    const bodyRadius = 4.5;
    final halo = Paint()..color = ArcanumColors.gold.withValues(alpha: 0.18);
    final body = Paint()..color = ArcanumColors.gold;
    for (final point in [transitOffset, natalOffset]) {
      canvas.drawCircle(point, bodyRadius * aspectBodyHaloScale, halo);
      canvas.drawCircle(point, bodyRadius, body);
    }
    _paintText(
      canvas,
      planetGlyph[transit] ?? '•',
      transitOffset,
      12,
      ArcanumColors.gold,
    );
    _paintText(
      canvas,
      planetGlyph[natal] ?? '•',
      natalOffset,
      12,
      ArcanumColors.ivory,
    );
  }

  @override
  bool shouldRepaint(covariant _AspectWheelPainter oldDelegate) {
    return transit != oldDelegate.transit ||
        natal != oldDelegate.natal ||
        transitLongitude != oldDelegate.transitLongitude ||
        natalLongitude != oldDelegate.natalLongitude;
  }
}

void _paintText(
  Canvas canvas,
  String text,
  Offset center,
  double size,
  Color color,
) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: size,
        // ArcanumGlifos como familia PRINCIPAL, no como respaldo. Un
        // `TextPainter` no hereda el tema, y sin `fontFamily` la familia
        // principal es la que traiga el sistema: en un Android que resuelva
        // los signos a Noto Color Emoji, ese emoji gana antes de que el
        // respaldo llegue a entrar -- que es justo el fallo que esta fuente
        // vino a arreglar en el resto de la app.
        fontFamily: 'ArcanumGlifos',
        fontFamilyFallback: const ['Crimson Pro'],
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  painter.paint(canvas, center - Offset(painter.width / 2, painter.height / 2));
}

Future<void> _showWheel(
  BuildContext context, {
  required String title,
  required String? aspect,
  required String? transit,
  required String? natal,
  required double? transitLongitude,
  required double? natalLongitude,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: ArcanumColors.surface,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: ArcanumText.heading(21),
            ),
            const SizedBox(height: 14),
            AspectWheel(
              index: 999,
              aspect: aspect,
              transit: transit,
              natal: natal,
              transitLongitude: transitLongitude,
              natalLongitude: natalLongitude,
              size: 220,
            ),
            const SizedBox(height: 10),
            Text(
              _longitudeLabel(transitLongitude, natalLongitude),
              style: ArcanumText.body(13, color: ArcanumColors.ivoryMuted),
            ),
          ],
        ),
      ),
    ),
  );
}

String _longitudeLabel(double? transit, double? natal) {
  if (transit == null || natal == null) {
    return 'Longitudes no disponibles en la respuesta.';
  }
  final t = transit.toStringAsFixed(1).replaceAll('.', ',');
  final n = natal.toStringAsFixed(1).replaceAll('.', ',');
  return 'Tránsito $t° · natal $n°';
}

String _bodyName(String? key) {
  if (key == 'ascendant') return 'Ascendente';
  if (key == 'midheaven') return 'Medio Cielo';
  return planetEs[key] ?? key ?? '';
}

Map<String, dynamic> _map(Object? value) {
  return value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
}

Map<String, dynamic>? _mapOrNull(Object? value) {
  return value is Map ? Map<String, dynamic>.from(value) : null;
}

List<Map<String, dynamic>> _maps(Object? value) {
  if (value is! List) return const [];
  return value.whereType<Map>().map(Map<String, dynamic>.from).toList();
}

Map<String, double> _longitudes(List<Map<String, dynamic>> bodies) {
  return {
    for (final body in bodies)
      if (body['name'] is String && body['longitude'] is num)
        body['name'] as String: (body['longitude'] as num).toDouble(),
  };
}

const _aspectGlyph = {
  'conjunction': '☌',
  'sextile': '⚹',
  'square': '□',
  'trine': '△',
  'opposition': '☍',
};
