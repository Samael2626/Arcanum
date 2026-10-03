/// Gramatica de gestos de la mesa, sin widgets: entran toques con su hora y
/// salen intenciones. La regla unica del prototipo:
///
///   tocar = accion directa; mantener = radial, que se elige deslizando y
///   soltando (o tocando despues).
///
/// Quien la usa le dice que hay bajo el dedo (`Hit`) y ejecuta lo que salga.
/// Asi los umbrales y las decisiones se prueban sin pantalla.
library;

import 'dart:ui';

/// Que hay bajo el dedo al empezar.
sealed class Hit {
  const Hit();
}

/// Nada tocable (fuera de la mesa, un hueco de la interfaz...).
class HitNothing extends Hit {
  const HitNothing();
}

/// El paño o el marco: se orbita, se mantiene para su radial, doble toque recentra.
class HitSurface extends Hit {
  const HitSurface();
}

/// El «Interpretar» bordado: tocar abre, mantener 1,3 s cierra el circulo.
class HitEmbroidery extends Hit {
  const HitEmbroidery();
}

/// El sello de la pregunta: solo se toca (dice si esta sellada o la enseña).
class HitSeal extends Hit {
  const HitSeal();
}

class HitDeck extends Hit {
  const HitDeck({
    required this.pid,
    required this.local,
    required this.count,
    this.inPlay = true,
  });

  final String pid;

  /// Punto agarrado en coordenadas locales normalizadas a [-1, 1].
  final Offset local;
  final int count;

  /// false: mazo del estante, todavia sin abrir.
  final bool inPlay;
}

class HitCard extends Hit {
  const HitCard({
    required this.slug,
    required this.local,
    required this.faceUp,
    this.inFan = false,
  });

  final String slug;
  final Offset local;
  final bool faceUp;

  /// Carta del abanico abierto (todavia del mazo, no sacada).
  final bool inFan;
}

/// Lo que la mesa tiene que hacer.
sealed class Intent {
  const Intent();
}

class TapIntent extends Intent {
  const TapIntent(this.hit, this.position);
  final Hit hit;
  final Offset position;
}

/// Doble toque en el paño: recentrar la camara.
class ResetCameraIntent extends Intent {
  const ResetCameraIntent();
}

/// Mantener: abrir el radial de lo que hay debajo.
class OpenRadialIntent extends Intent {
  const OpenRadialIntent(this.hit, this.position);
  final Hit hit;
  final Offset position;
}

/// El dedo se movio con el radial abierto.
class RadialMoveIntent extends Intent {
  const RadialMoveIntent(this.position);
  final Offset position;
}

/// Soltar con el radial abierto: elegir lo que este marcado (si hay algo).
class RadialReleaseIntent extends Intent {
  const RadialReleaseIntent(this.position);
  final Offset position;
}

/// Mantener el bordado 1,3 s.
class CloseCircleIntent extends Intent {
  const CloseCircleIntent();
}

enum DragKind {
  /// Mover una carta o un monton.
  move,

  /// Tirar del borde de arriba de un monton: corta.
  cut,

  /// Tirar del borde lateral de un monton: extiende el abanico.
  fan,

  /// Tirar de la esquina de una carta boca abajo: la voltea.
  peel,

  /// Arrastrar el paño: gira la camara.
  orbit,
}

class DragStartIntent extends Intent {
  const DragStartIntent(this.kind, this.hit, this.start, this.position);
  final DragKind kind;
  final Hit hit;
  final Offset start;
  final Offset position;
}

class DragUpdateIntent extends Intent {
  const DragUpdateIntent(this.kind, this.position, this.delta);
  final DragKind kind;
  final Offset position;
  final Offset delta;
}

class DragEndIntent extends Intent {
  const DragEndIntent(this.kind, this.position, {this.cancelled = false});
  final DragKind kind;
  final Offset position;
  final bool cancelled;
}

class PinchStartIntent extends Intent {
  const PinchStartIntent(this.a, this.b);
  final Offset a;
  final Offset b;
}

class PinchUpdateIntent extends Intent {
  const PinchUpdateIntent(this.a, this.b);
  final Offset a;
  final Offset b;
}

class PinchEndIntent extends Intent {
  const PinchEndIntent();
}

enum _Mode { pending, radial, drag, sealed, idle }

class GestureGrammar {
  /// Mantener para abrir el radial.
  static const hold = Duration(milliseconds: 430);

  /// Mantener el bordado para cerrar el circulo.
  static const sealHold = Duration(milliseconds: 1300);

  /// Lo que se mueve el dedo antes de dejar de ser un toque (px de pantalla).
  static const slop = 6.0;

  /// Doble toque en el paño.
  static const doubleTapWindow = Duration(milliseconds: 320);
  static const doubleTapSlop = 40.0;

  final Map<int, Offset> _pointers = {};
  bool _pinching = false;

  int? _id;
  Hit _hit = const HitNothing();
  Offset _start = Offset.zero;
  Offset _last = Offset.zero;
  Duration _downAt = Duration.zero;
  _Mode _mode = _Mode.idle;
  DragKind? _drag;

  Duration? _lastSurfaceTap;
  Offset _lastSurfaceTapAt = Offset.zero;

  /// Hay un gesto de un dedo en curso.
  bool get active => _mode != _Mode.idle;

  /// Cuando vence el temporizador de mantener, o null. Quien use la gramatica
  /// llama a `tick` en ese momento (o en cada frame, que tambien vale).
  Duration? get deadline =>
      _mode == _Mode.pending && _hit is! HitSeal && _hit is! HitNothing
      ? _downAt + (_hit is HitEmbroidery ? sealHold : hold)
      : null;

  List<Intent> down(int pointer, Offset position, Duration time, Hit hit) {
    _pointers[pointer] = position;
    if (_pointers.length == 2) {
      // el segundo dedo convierte lo que hubiera en pellizco
      final out = <Intent>[
        if (_mode == _Mode.drag) DragEndIntent(_drag!, _last, cancelled: true),
      ];
      _reset();
      _pinching = true;
      final [a, b] = _pointers.values.toList();
      return [...out, PinchStartIntent(a, b)];
    }
    if (_pointers.length > 2 || _pinching) return const [];
    _id = pointer;
    _hit = hit;
    _start = _last = position;
    _downAt = time;
    // fuera de la mesa no hay nada que agarrar, pero el doble toque recentra:
    // si la camara dejo el paño lejos, ahi es donde cae el dedo
    _mode = _Mode.pending;
    _drag = null;
    return const [];
  }

  List<Intent> tick(Duration time) {
    final due = deadline;
    if (due == null || time < due) return const [];
    if (_hit is HitEmbroidery) {
      _mode = _Mode.sealed;
      return const [CloseCircleIntent()];
    }
    _mode = _Mode.radial;
    return [OpenRadialIntent(_hit, _start)];
  }

  List<Intent> move(int pointer, Offset position, Duration time) {
    if (!_pointers.containsKey(pointer)) return const [];
    _pointers[pointer] = position;
    if (_pinching) {
      if (_pointers.length < 2) return const [];
      final [a, b] = _pointers.values.take(2).toList();
      return [PinchUpdateIntent(a, b)];
    }
    if (pointer != _id) return const [];
    final pre = tick(time);
    if (pre.isNotEmpty && _mode == _Mode.sealed) return pre;
    switch (_mode) {
      case _Mode.radial:
        _last = position;
        return [...pre, RadialMoveIntent(position)];
      case _Mode.pending:
        if ((position - _start).distance < slop) return pre;
        final kind = _dragKind();
        if (kind == null) {
          _mode = _Mode.idle;
          return const [];
        }
        _mode = _Mode.drag;
        _drag = kind;
        final delta = position - _last;
        _last = position;
        return [
          DragStartIntent(kind, _hit, _start, position),
          DragUpdateIntent(kind, position, delta),
        ];
      case _Mode.drag:
        final delta = position - _last;
        _last = position;
        return [DragUpdateIntent(_drag!, position, delta)];
      case _Mode.sealed:
      case _Mode.idle:
        return const [];
    }
  }

  List<Intent> up(int pointer, Offset position, Duration time) =>
      _finish(pointer, position, time, cancelled: false);

  List<Intent> cancel(int pointer) => _finish(
    pointer,
    _pointers[pointer] ?? _last,
    Duration.zero,
    cancelled: true,
  );

  List<Intent> _finish(
    int pointer,
    Offset position,
    Duration time, {
    required bool cancelled,
  }) {
    if (_pointers.remove(pointer) == null) return const [];
    if (_pinching) {
      if (_pointers.length < 2) {
        _pinching = false;
        _pointers.clear();
        return const [PinchEndIntent()];
      }
      return const [];
    }
    if (pointer != _id) return const [];
    final mode = _mode;
    final hit = _hit;
    final drag = _drag;
    // soltar justo al vencer el temporizador cuenta como mantener
    final pre = cancelled ? const <Intent>[] : tick(time);
    final after = _mode;
    _reset();
    if (pre.isNotEmpty) {
      return after == _Mode.radial
          ? [...pre, RadialReleaseIntent(position)]
          : pre;
    }
    switch (mode) {
      case _Mode.radial:
        return cancelled ? const [] : [RadialReleaseIntent(position)];
      case _Mode.drag:
        return [DragEndIntent(drag!, position, cancelled: cancelled)];
      case _Mode.pending:
        if (cancelled) return const [];
        if (hit is HitSurface || hit is HitNothing) {
          final last = _lastSurfaceTap;
          if (last != null &&
              time - last < doubleTapWindow &&
              (position - _lastSurfaceTapAt).distance < doubleTapSlop) {
            _lastSurfaceTap = null;
            return const [ResetCameraIntent()];
          }
          _lastSurfaceTap = time;
          _lastSurfaceTapAt = position;
        }
        return hit is HitNothing ? const [] : [TapIntent(hit, position)];
      case _Mode.sealed:
      case _Mode.idle:
        return const [];
    }
  }

  void _reset() {
    _id = null;
    _mode = _Mode.idle;
    _drag = null;
  }

  /// Que arrastre empieza segun lo que se agarro y por donde (reglas del prototipo).
  DragKind? _dragKind() => switch (_hit) {
    HitSurface() => DragKind.orbit,
    HitEmbroidery() || HitSeal() || HitNothing() => null,
    HitDeck(:final local, :final count, :final inPlay) =>
      !inPlay
          ? DragKind.move
          : local.dx.abs() <= .5 && local.dy < -.45 && count >= 4
          ? DragKind.cut
          : local.dx.abs() > .5 && count > 0
          ? DragKind.fan
          : DragKind.move,
    // esquina generosa: basta con caer cerca de cualquier esquina
    HitCard(:final local, :final faceUp, :final inFan) =>
      !inFan && !faceUp && local.dx.abs() > .3 && local.dy.abs() > .38
          ? DragKind.peel
          : DragKind.move,
  };
}
