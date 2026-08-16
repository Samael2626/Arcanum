import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/arcanum_api.dart';
import '../data/umbral_cache.dart';
import '../domain/umbral_reading.dart';

/// Lectura del Umbral del día.
///
/// Sin red devuelve la última lectura cacheada marcada como `stale`, con su
/// fecha y su zona originales. NO la regenera: recalcular en el teléfono daría
/// un texto distinto bajo el mismo nombre, y la persona no tendría forma de
/// saber cuál de los dos leyó.
class UmbralController extends AsyncNotifier<UmbralReading?> {
  @override
  Future<UmbralReading?> build() => _load();

  Future<UmbralReading?> _load() async {
    final cache = ref.read(umbralCacheProvider);
    try {
      final contract = await ref.read(arcanumApiProvider).umbral();
      await cache.save(contract);
      return UmbralReading.fromJson(contract);
    } on Object catch (error) {
      final cached = await cache.load();
      if (cached == null) rethrow;
      debugPrint(
        'ARCANUM umbral: sin red ($error). Se muestra la lectura cacheada.',
      );
      return UmbralReading.fromJson(cached, stale: true);
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_load);
  }
}

final umbralProvider =
    AsyncNotifierProvider<UmbralController, UmbralReading?>(
      UmbralController.new,
    );
