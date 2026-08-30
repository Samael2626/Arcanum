import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/auth/auth_controller.dart';

class OnboardingData {
  final String? displayName;
  final DateTime? birthDate;
  final String? birthTime;
  final String? birthCountry;
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
    this.birthCountry,
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
    String? birthCountry,
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
    birthCountry: birthCountry ?? this.birthCountry,
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
  static const _kPendingProfile = 'onboarding_pending_profile';
  static const _kName = 'onboarding_display_name';
  static const _kDate = 'onboarding_birth_date';
  static const _kTime = 'onboarding_birth_time';
  static const _kCountry = 'onboarding_birth_country';
  static const _kCity = 'onboarding_birth_city';

  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  @override
  OnboardingState build() => OnboardingState.initial;

  Future<bool> isCompleted() async =>
      (await _prefs).getBool(_kCompleted) ?? false;

  Future<void> setDisplayName(String v) async {
    final p = await _prefs;
    await p.setString(_kName, v);
    state = OnboardingState(
      step: state.step,
      data: state.data.copyWith(displayName: v),
    );
  }

  Future<void> setBirthDate(DateTime v) async {
    final p = await _prefs;
    final iso = v.toIso8601String();
    await p.setString(_kDate, iso);
    state = OnboardingState(
      step: state.step,
      data: state.data.copyWith(birthDate: v),
    );
  }

  Future<void> setBirthTime(String v) async {
    final p = await _prefs;
    await p.setString(_kTime, v);
    state = OnboardingState(
      step: state.step,
      data: state.data.copyWith(birthTime: v),
    );
  }

  Future<void> setBirthCountry(String v) async {
    final p = await _prefs;
    await p.setString(_kCountry, v);
    state = OnboardingState(
      step: state.step,
      data: state.data.copyWith(birthCountry: v),
    );
  }

  Future<void> setBirthCity(String v) async {
    final p = await _prefs;
    await p.setString(_kCity, v);
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
    await _complete({'onboarding_completed': true});
  }

  Future<void> _complete(Map<String, dynamic> payload) async {
    // A diferencia del resolve (que debe fallar visible), persistir el perfil
    // tolera fallo de red: el flag local permite continuar y el perfil se
    // reintenta en el próximo arranque autenticado. Los datos que se
    // reintentarán son los REALES (ya confirmados), nunca un default.
    try {
      await ref.read(authRepositoryProvider).updateProfile(payload);
      await ref.read(authProvider.notifier).refreshUser();
      await _clearPendingProfile();
    } catch (error) {
      // No bloquear el flujo, pero tampoco perder los datos: se guardan en
      // disco para reintentarlos. Estar sin red es una condición ESPERADA y
      // gestionada, no una anomalía: se registra, no se reporta como error del
      // framework (eso ensuciaría el crash reporting en cada uso offline).
      await _savePendingProfile(payload);
      debugPrint(
        'ARCANUM onboarding: perfil no persistido ($error). '
        'Queda encolado para reintento.',
      );
    }

    final p = await _prefs;
    await p.setBool(_kCompleted, true);
  }

  /// Guarda el perfil que no se pudo enviar, para reintentarlo al arrancar.
  Future<void> _savePendingProfile(Map<String, dynamic> payload) async {
    final p = await _prefs;
    await p.setString(_kPendingProfile, jsonEncode(payload));
  }

  Future<void> _clearPendingProfile() async {
    final p = await _prefs;
    await p.remove(_kPendingProfile);
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
    final p = await _prefs;
    final raw = p.getString(_kPendingProfile);
    if (raw == null) return false;

    final payload = jsonDecode(raw) as Map<String, dynamic>;
    await ref.read(authRepositoryProvider).updateProfile(payload);
    await ref.read(authProvider.notifier).refreshUser();
    await p.remove(_kPendingProfile);
    return true;
  }

  Future<void> reset() async {
    final p = await _prefs;
    await Future.wait([
      p.remove(_kCompleted),
      p.remove(_kName),
      p.remove(_kDate),
      p.remove(_kTime),
      p.remove(_kCountry),
      p.remove(_kCity),
      p.remove(_kPendingProfile),
    ]);
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

Future<void> clearOnboardingLocalData() async {
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
    'onboarding_pending_profile',
  ]) {
    await prefs.remove(key);
  }
}
