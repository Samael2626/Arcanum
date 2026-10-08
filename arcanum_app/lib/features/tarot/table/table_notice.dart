/// Avisos de la mesa: donde salen depende de lo que dicen (Samuel, 07-oct).
///
/// Sustituyen al SnackBar blanco de abajo, que no era de la mesa. La regla,
/// para que un aviso nuevo caiga solo en su sitio:
///
/// | Tipo | Que dice | Donde |
/// |---|---|---|
/// | [NoticeKind.embroidery] | Un hito del ritual: barajar, cortar, tirada completa, circulo cerrado | Bordado en el paño, bajo «Interpretar» |
/// | [NoticeKind.piece] | Algo de una carta o un monton concretos | Burbuja junto a esa pieza |
/// | [NoticeKind.pill] | El estado de la mesa o del sistema: silencio, deshacer, errores | Pildora arriba |
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/arcanum_colors.dart';
import 'table_camera.dart';

enum NoticeKind { pill, embroidery, piece }

class TableNotice {
  TableNotice(this.text, {this.kind = NoticeKind.pill, this.at})
    : assert(
        kind != NoticeKind.piece || at != null,
        'la burbuja necesita pieza',
      );

  final String text;
  final NoticeKind kind;

  /// Punto de la mesa de la pieza, para [NoticeKind.piece].
  final Offset? at;
}

/// El aviso de ahora; uno nuevo sustituye al anterior.
class NoticeBoard extends ValueNotifier<TableNotice?> {
  NoticeBoard() : super(null);

  static const shown = Duration(milliseconds: 2600);
  Timer? _timer;

  void show(TableNotice notice) {
    _timer?.cancel();
    value = notice;
    _timer = Timer(shown, () => value = null);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// Dibuja el aviso. La burbuja y el bordado se proyectan con la camara de
/// ahora: siguen a la mesa aunque este girada o con zoom.
class NoticeLayer extends StatelessWidget {
  const NoticeLayer({
    super.key,
    required this.board,
    required this.camera,
    required this.embroideryAt,
    this.top = 72,
  });

  final NoticeBoard board;
  final TableCamera camera;
  final Offset embroideryAt;

  /// Donde va la pildora: bajo la fila de botones de la pantalla.
  final double top;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ValueListenableBuilder<TableNotice?>(
      valueListenable: board,
      builder: (context, n, _) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: n == null
            ? const SizedBox.expand(key: ValueKey('nada'))
            : LayoutBuilder(
                key: ObjectKey(n),
                builder: (context, box) =>
                    Stack(children: [_place(n, box.biggest)]),
              ),
      ),
    ),
  );

  Widget _place(TableNotice n, Size screen) {
    final text = Semantics(liveRegion: true, child: _body(n));
    switch (n.kind) {
      case NoticeKind.pill:
        return Positioned(
          left: 16,
          right: 16,
          top: top,
          child: Center(child: text),
        );
      case NoticeKind.embroidery:
        final at = camera.toScreen(embroideryAt + const Offset(0, 52));
        return Positioned(
          left: 16,
          right: 16,
          top: (at.dy - 8).clamp(top, screen.height - 120),
          child: Center(child: text),
        );
      case NoticeKind.piece:
        // encima de la pieza; si no cabe arriba, debajo. El piquito apunta a
        // ella: con dos cartas juntas, la burbuja sola no decia de cual hablaba
        final at = camera.toScreen(n.at!);
        const width = 240.0, lift = 64.0;
        final above = at.dy - lift > top + 40;
        final left = (at.dx - width / 2).clamp(16.0, screen.width - 16 - width);
        final tailX = (at.dx - left).clamp(18.0, width - 18);
        final tail = Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.only(left: tailX - _Tail.size.width / 2),
            child: _Tail(down: above),
          ),
        );
        return Positioned(
          left: left,
          width: width,
          top: above ? null : at.dy + lift / 2 - _Tail.size.height,
          bottom: above
              ? screen.height - (at.dy - lift) - _Tail.size.height
              : null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: above
                ? [Center(child: text), tail]
                : [tail, Center(child: text)],
          ),
        );
    }
  }

  Widget _body(TableNotice n) => switch (n.kind) {
    NoticeKind.embroidery => ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _Stitch(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              n.text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Cormorant Garamond',
                fontSize: 19,
                height: 1.25,
                fontWeight: FontWeight.w600,
                color: ArcanumColors.gold,
                shadows: [Shadow(color: Color(0xCC000000), blurRadius: 6)],
              ),
            ),
          ),
          const _Stitch(),
        ],
      ),
    ),
    _ => Container(
      constraints: BoxConstraints(
        maxWidth: n.kind == NoticeKind.pill ? 360 : 240,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xF014131B),
        borderRadius: BorderRadius.circular(
          n.kind == NoticeKind.pill ? 22 : 12,
        ),
        border: Border.all(color: ArcanumColors.gold),
        boxShadow: const [
          BoxShadow(
            color: Color(0x80000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Text(
        n.text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: 'Crimson Pro',
          fontSize: 15,
          height: 1.3,
          color: Color(0xFFF5F0E8),
        ),
      ),
    ),
  };
}

/// La puntada dorada que enmarca el bordado.
class _Stitch extends StatelessWidget {
  const _Stitch();

  @override
  Widget build(BuildContext context) => Container(
    width: 120,
    height: 1,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0x00C9A84C), ArcanumColors.gold, Color(0x00C9A84C)],
      ),
    ),
  );
}

/// El piquito de la burbuja: del mismo fondo y con el borde dorado.
class _Tail extends StatelessWidget {
  const _Tail({required this.down});

  static const size = Size(16, 9);
  final bool down;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: size, painter: _TailPainter(down));
}

class _TailPainter extends CustomPainter {
  _TailPainter(this.down);
  final bool down;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // se solapa 1 px con la burbuja para tapar su borde
    final path = down
        ? (Path()
            ..moveTo(0, -1)
            ..lineTo(w / 2, h)
            ..lineTo(w, -1))
        : (Path()
            ..moveTo(0, h + 1)
            ..lineTo(w / 2, 0)
            ..lineTo(w, h + 1));
    canvas.drawPath(path, Paint()..color = const Color(0xF014131B));
    canvas.drawPath(
      path,
      Paint()
        ..color = ArcanumColors.gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_TailPainter old) => old.down != down;
}
