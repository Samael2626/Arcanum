import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/breath_pattern.dart';
import '../domain/breath_phase.dart';

/// Ajustes de una practica. Viven lo que vive la sesion de la app: en v1 no
/// se guardan en disco.
class BreathSettings {
  const BreathSettings({
    this.patternId = 'regardie',
    this.retention = false,
    this.amount = 12,
    this.tempo = 1.0,
    this.showCount = true,
    this.vibration = false,
    this.reducedMotion = false,
  });

  final String patternId;

  /// Apagada por defecto: la via sin retencion siempre es la de partida.
  final bool retention;

  /// Ciclos, o minutos en los patrones libres.
  final int amount;

  /// Segundos por cuenta.
  final double tempo;
  final bool showCount;
  final bool vibration;
  final bool reducedMotion;

  static const double minTempo = 0.6;
  static const double maxTempo = 1.6;

  BreathPattern get pattern => breathPatternById(patternId);

  /// Solo cuenta si el patron tiene algo que retener.
  bool get retentionActive => retention && pattern.hasRetention;

  List<BreathPhase> get phases =>
      buildPhases(pattern, retention: retention, tempo: tempo);

  /// Duracion total en segundos.
  double get totalSeconds =>
      pattern.free ? amount * 60.0 : cycleSeconds(phases) * amount;

  BreathSettings copyWith({
    String? patternId,
    bool? retention,
    int? amount,
    double? tempo,
    bool? showCount,
    bool? vibration,
    bool? reducedMotion,
  }) => BreathSettings(
    patternId: patternId ?? this.patternId,
    retention: retention ?? this.retention,
    amount: amount ?? this.amount,
    tempo: tempo ?? this.tempo,
    showCount: showCount ?? this.showCount,
    vibration: vibration ?? this.vibration,
    reducedMotion: reducedMotion ?? this.reducedMotion,
  );
}

class BreathSettingsNotifier extends Notifier<BreathSettings> {
  @override
  BreathSettings build() => const BreathSettings();

  /// Cambiar de patron vuelve a su cantidad por defecto, como el prototipo.
  void selectPattern(String id) {
    final p = breathPatternById(id);
    state = state.copyWith(patternId: id, amount: p.defaultAmount);
  }

  void setRetention(bool on) => state = state.copyWith(retention: on);

  void changeAmount(int delta) => state = state.copyWith(
    amount: (state.amount + delta).clamp(1, state.pattern.maxAmount),
  );

  void setTempo(double v) => state = state.copyWith(
    tempo:
        (v.clamp(BreathSettings.minTempo, BreathSettings.maxTempo) * 10)
            .roundToDouble() /
        10,
  );

  void setShowCount(bool on) => state = state.copyWith(showCount: on);

  void setVibration(bool on) => state = state.copyWith(vibration: on);

  void setReducedMotion(bool on) => state = state.copyWith(reducedMotion: on);
}

final breathSettingsProvider =
    NotifierProvider<BreathSettingsNotifier, BreathSettings>(
      BreathSettingsNotifier.new,
    );
