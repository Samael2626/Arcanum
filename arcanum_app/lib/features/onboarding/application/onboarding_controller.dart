import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/auth_repository.dart';
import 'pending_profile_store.dart';

class OnboardingData {
  final String? displayName;
  final DateTime? birthDate;
  final String? birthTime;
  final String? birthCity;
  // Lugar RESUELTO por el backend (Nominatim + timezonefinder) y CONFIRMADO
  // por el usuario. Solo estos valores (nunca un default) se persisten como
  // birth_lat/birth_lon/birth_timezone. Ver bug documentado 2026-07-01.
  final String? resolvedDisplayName;
  final String? resolvedLat;
  final String? resolvedLon;
  final String? resolvedTimezone;
  final bool? sensitiveDataConsent;
  const OnboardingData({
    this.displayName,
    this.birthDate,
    this.birthTime,
    this.birthCity,
    this.resolvedDisplayName,
    this.resolvedLat,
    this.resolvedLon,
    this.resolvedTimezone,
    this.sensitiveDataConsent,
  });

  bool get hasResolvedLocation =>
      resolvedLat != null && resolvedLon != null && resolvedTimezone != null;

  OnboardingData copyWith({
    String? displayName,
    DateTime? birthDate,
    String? birthTime,
    String? birthCity,
    String? resolvedDisplayName,
    String? resolvedLat,
    String? resolvedLon,
    String? resolvedTimezone,
    bool? sensitiveDataConsent,
  }) => OnboardingData(
    displayName: displayName ?? this.displayName,
    birthDate: birthDate ?? this.birthDate,
    birthTime: birthTime ?? this.birthTime,
    birthCity: birthCity ?? this.birthCity,
    resolvedDisplayName: resolvedDisplayName ?? this.resolvedDisplayName,
    resolvedLat: resolvedLat ?? this.resolvedLat,
    resolvedLon: resolvedLon ?? this.resolvedLon,
    resolvedTimezone: resolvedTimezone ?? this.resolvedTimezone,
    sensitiveDataConsent: sensitiveDataConsent ?? this.sensitiveDataConsent,
  );
}

class OnboardingState {
  final int step;
  final OnboardingData data;
  const OnboardingState({required this.step, required this.data});
  bool get isFirst => step == 0;
  bool get isLast => step == 5;

  static const initial = OnboardingState(step: 0, data: OnboardingData());
}

class OnboardingNotifier extends Notifier<OnboardingState> {
  static const _kCompleted = 'onboarding_completed';
  static const _kName = 'onboarding_display_name';
  static const _kDate = 'onboarding_birth_date';
  static const _kTime = 'onboarding_birth_time';
  static const _kCity = 'onboarding_birth_city';
  // Heredada. Ya no se escribe: el pais dejo de pedirse por separado
  // cuando el paso del lugar paso al selector de catalogo. Se sigue
  // BORRANDO porque las instalaciones anteriores la tienen en disco.
  static const _kCountryHeredada = 'onboarding_birth_country';

  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  @override
  OnboardingState build() => OnboardingState.initial;

  Future<bool> isCompleted() async =>
      (await _prefs).getBool(_kCompleted) ?? false;

  Future<void> setDisplayName(String v) async {
    state = OnboardingState(
      step: state.step,
      data: state.data.copyWith(displayName: v),
    );
  }

  Future<void> setBirthDate(DateTime v) async {
    state = OnboardingState(
      step: state.step,
      data: state.data.copyWith(birthDate: v),
    );
  }

  Future<void> setBirthTime(String v) async {
    state = OnboardingState(
      step: state.step,
      data: state.data.copyWith(birthTime: v),
    );
  }

  Future<void> setBirthCity(String v) async {
    state = OnboardingState(
      step: state.step,
      data: state.data.copyWith(birthCity: v),
    );
  }

  /// Guarda el lugar resuelto por el backend y CONFIRMADO por el usuario.
  /// No se persiste en SharedPreferences a propósito: si el onboarding se
  /// interrumpe, se re-resuelve en lugar de arrastrar coordenadas viejas.
  void setResolvedLocation({
    required String displayName,
    required String lat,
    required String lon,
    required String timezone,
  }) {
    state = OnboardingState(
      step: state.step,
      data: state.data.copyWith(
        resolvedDisplayName: displayName,
        resolvedLat: lat,
        resolvedLon: lon,
        resolvedTimezone: timezone,
      ),
    );
  }

  void setSensitiveDataConsent(bool granted) {
    state = OnboardingState(
      step: state.step,
      data: state.data.copyWith(sensitiveDataConsent: granted),
    );
  }

  void next() {
    if (state.step < 5) {
      state = OnboardingState(step: state.step + 1, data: state.data);
    }
  }

  void back() {
    if (state.step > 0) {
      state = OnboardingState(step: state.step - 1, data: state.data);
    }
  }

  Future<void> finish() async {
    final d = state.data;

    if (d.sensitiveDataConsent != true) {
      throw StateError(
        'No se pueden persistir datos sensibles sin autorizacion explicita.',
      );
    }

    // FAIL LOUD: sin lugar resuelto y confirmado, NO se persiste nada de
    // ubicación. Nunca un default silencioso (ese fue el bug de Bogotá
    // hardcodeada, documentado 2026-07-01). PlaceStep garantiza que esto solo
    // se llame tras un resolve+confirmación exitosos; esta es la última
    // barrera defensiva.
    if (!d.hasResolvedLocation) {
      throw StateError(
        'No se puede finalizar el onboarding sin un lugar de nacimiento confirmado.',
      );
    }

    // Persistir el perfil en el backend (datos capturados en el onboarding).
    final payload = <String, dynamic>{
      'onboarding_completed': true,
      if (d.displayName != null && d.displayName!.isNotEmpty)
        'display_name': d.displayName,
      if (d.birthDate != null) 'birth_date': d.birthDate!.toIso8601String(),
      if (d.birthTime != null && d.birthTime!.isNotEmpty)
        'birth_time': '2000-01-01T${d.birthTime}:00',
      if (d.birthCity != null && d.birthCity!.isNotEmpty)
        'birth_city': d.birthCity,
      'birth_lat': d.resolvedLat,
      'birth_lon': d.resolvedLon,
      'birth_timezone': d.resolvedTimezone,
    };

    await _complete(payload);
  }

  Future<void> finishWithoutSensitiveData() async {
    await ref.read(pendingProfileStoreProvider).clear();
    await _complete({'onboarding_completed': true});
  }

  Future<void> _complete(Map<String, dynamic> payload) async {
    final userId = ref.read(authProvider).user?['id'] as String?;
    if (userId == null) {
      throw StateError(
        'No se puede guardar un perfil sin usuario autenticado.',
      );
    }
    // A diferencia del resolve (que debe fallar visible), persistir el perfil
    // tolera fallo de red: el flag local permite continuar y el perfil se
    // reintenta en el próximo arranque autenticado. Los datos que se
    // reintentarán son los REALES (ya confirmados), nunca un default.
    try {
      await ref.read(authRepositoryProvider).updateProfile(payload);
      await ref.read(authProvider.notifier).refreshUser();
      await ref.read(pendingProfileStoreProvider).clear();
    } catch (error) {
      if (error is AuthException &&
          error.statusCode != null &&
          error.statusCode! < 500 &&
          error.statusCode != 429) {
        await ref.read(pendingProfileStoreProvider).clear();
        rethrow;
      }
      if (ref.read(authProvider).user?['id'] != userId) {
        throw StateError('La sesión cambió mientras se guardaba el perfil.');
      }
      // No bloquear el flujo, pero tampoco perder los datos: se guardan en
      // disco para reintentarlos. Estar sin red es una condición ESPERADA y
      // gestionada, no una anomalía: se registra, no se reporta como error del
      // framework (eso ensuciaría el crash reporting en cada uso offline).
      await ref.read(pendingProfileStoreProvider).save(userId, payload);
      debugPrint(
        'ARCANUM onboarding: perfil no persistido ($error). '
        'Queda encolado para reintento.',
      );
    }

    final p = await _prefs;
    await p.setBool(_kCompleted, true);
  }

  /// Reintenta el perfil que quedó pendiente por un fallo de red al terminar
  /// el onboarding.
  ///
  /// Sin esto, un corte de red en ese instante exacto dejaba la fecha, hora y
  /// lugar de nacimiento SOLO en el dispositivo: el onboarding se marcaba
  /// completo, no volvía a mostrarse, y el servidor nunca recibía los datos
  /// → carta natal imposible (422) para siempre y sin explicación.
  ///
  /// Devuelve true si había algo pendiente y se envió.
  Future<bool> flushPendingProfile() async {
    final userId = ref.read(authProvider).user?['id'] as String?;
    if (userId == null) return false;
    final store = ref.read(pendingProfileStoreProvider);
    final payload = await store.readFor(userId);
    if (payload == null) return false;
    try {
      await ref.read(authRepositoryProvider).updateProfile(payload);
    } on AuthException catch (error) {
      if (error.statusCode != 403) rethrow;
      await store.clear();
      return false;
    }
    await ref.read(authProvider.notifier).refreshUser();
    await store.clear();
    return true;
  }

  Future<void> reset() async {
    final p = await _prefs;
    await Future.wait([
      p.remove(_kCompleted),
      p.remove(_kName),
      p.remove(_kDate),
      p.remove(_kTime),
      p.remove(_kCountryHeredada),
      p.remove(_kCity),
    ]);
    await ref.read(pendingProfileStoreProvider).clear();
    state = OnboardingState.initial;
  }
}

final onboardingProvider =
    NotifierProvider<OnboardingNotifier, OnboardingState>(
      OnboardingNotifier.new,
    );

/// Reintenta el perfil pendiente sin romper el arranque si sigue sin red.
///
/// Se llama al pasar a autenticado (ver `ArcanumApp`). Si vuelve a fallar, el
/// perfil sigue en disco y se reintentará el próximo arranque: no se pierde.
/// Recibe el notifier en vez de un `Ref` para servir igual a `Ref` y a
/// `WidgetRef`, que en Riverpod 3 no comparten tipo.
Future<void> tryFlushPendingProfile(OnboardingNotifier notifier) async {
  try {
    await notifier.flushPendingProfile();
  } catch (error) {
    debugPrint(
      'ARCANUM onboarding: el reintento del perfil falló ($error). '
      'Sigue guardado en disco para el próximo arranque.',
    );
  }
}

final onboardingCompletedProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('onboarding_completed') ?? false;
});

Future<void> clearOnboardingLocalData({
  PendingProfileStore? pendingStore,
}) async {
  final prefs = await SharedPreferences.getInstance();
  for (final key in const [
    'onboarding_completed',
    'onboarding_display_name',
    'onboarding_birth_date',
    'onboarding_birth_time',
    'onboarding_birth_country',
    'onboarding_birth_city',
    // Crítico al borrar la cuenta: si el perfil pendiente sobreviviera, los
    // datos de nacimiento de un usuario se enviarían a la cuenta siguiente.
  ]) {
    await prefs.remove(key);
  }
  await (pendingStore ?? SecurePendingProfileStore()).clear();
}
