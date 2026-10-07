/// Reproductor de la mesa con SoLoud: motor de juegos, baja latencia y varias
/// voces a la vez (un acorde son hasta siete).
///
/// Si el motor no arranca, la mesa sigue sin sonido y el fallo se reporta
/// (Crashlytics lo recoge de `FlutterError`): el sonido no es imprescindible,
/// pero callarlo sin decir nada esconderia un aparato roto.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import 'table_sound.dart';

/// El reproductor de la mesa. Los tests de pantalla lo cambian por
/// [SilentPlayer]: alli no hay motor nativo.
final tableSoundPlayerProvider = Provider<SoundPlayer>((ref) => SoLoudPlayer());

class SoLoudPlayer implements SoundPlayer {
  SoLoudPlayer({SoLoud? engine}) : _injected = engine;

  static const _dir = 'assets/sounds/mesa';

  final SoLoud? _injected;

  /// Pedir el motor carga la libreria nativa: solo dentro de [prepare], que
  /// captura el fallo. En el constructor tumbaba la pantalla entera.
  SoLoud get _engine => _injected ?? SoLoud.instance;
  final Map<String, AudioSource> _sources = {};
  final Set<Timer> _pending = {};
  bool _disposed = false;

  @override
  Future<void> prepare(Iterable<String> files) async {
    try {
      if (!_engine.isInitialized) await _engine.init();
      for (final f in files) {
        if (_disposed) return;
        _sources[f] = await _engine.loadAsset('$_dir/$f.ogg');
      }
    } catch (e, st) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: e,
          stack: st,
          library: 'mesa de tarot',
          context: ErrorDescription('al preparar el sonido de la mesa'),
        ),
      );
    }
  }

  @override
  void play(SoundHit hit) {
    if (_disposed) return;
    if (hit.delay <= Duration.zero) return _start(hit);
    late final Timer t;
    t = Timer(hit.delay, () {
      _pending.remove(t);
      _start(hit);
    });
    _pending.add(t);
  }

  void _start(SoundHit hit) {
    final src = _sources[hit.file];
    if (src == null || _disposed || !_engine.isInitialized) return;
    try {
      // en pausa para fijar el tono antes de que suene la primera muestra
      final h = _engine.play(src, volume: hit.volume, paused: true);
      _engine.setRelativePlaySpeed(h, hit.speed);
      _engine.setPause(h, false);
    } on SoLoudException catch (e, st) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: e, stack: st, library: 'mesa de tarot'),
      );
    }
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    for (final t in _pending) {
      t.cancel();
    }
    _pending.clear();
    final sources = _sources.values.toList();
    _sources.clear();
    // sin nada cargado no se toca el motor: puede que no llegara a arrancar
    if (sources.isEmpty || !_engine.isInitialized) return;
    for (final s in sources) {
      await _engine.disposeSource(s);
    }
  }
}
