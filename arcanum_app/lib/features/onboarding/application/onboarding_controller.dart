import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingData {
  final String? displayName;
  final DateTime? birthDate;
  final String? birthTime;
  final String? birthPlace;
  const OnboardingData({
    this.displayName,
    this.birthDate,
    this.birthTime,
    this.birthPlace,
  });
  OnboardingData copyWith({
    String? displayName,
    DateTime? birthDate,
    String? birthTime,
    String? birthPlace,
  }) =>
      OnboardingData(
        displayName: displayName ?? this.displayName,
        birthDate: birthDate ?? this.birthDate,
        birthTime: birthTime ?? this.birthTime,
        birthPlace: birthPlace ?? this.birthPlace,
      );
}

class OnboardingState {
  final int step;
  final OnboardingData data;
  const OnboardingState({required this.step, required this.data});
  bool get isFirst => step == 0;
  bool get isLast => step == 4;

  static const initial = OnboardingState(step: 0, data: OnboardingData());
}

class OnboardingNotifier extends Notifier<OnboardingState> {
  static const _kCompleted = 'onboarding_completed';
  static const _kName = 'onboarding_display_name';
  static const _kDate = 'onboarding_birth_date';
  static const _kTime = 'onboarding_birth_time';
  static const _kPlace = 'onboarding_birth_place';

  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  @override
  OnboardingState build() => OnboardingState.initial;

  Future<bool> isCompleted() async =>
      (await _prefs).getBool(_kCompleted) ?? false;

  Future<void> setDisplayName(String v) async {
    final p = await _prefs;
    await p.setString(_kName, v);
    state = OnboardingState(
        step: state.step, data: state.data.copyWith(displayName: v));
  }

  Future<void> setBirthDate(DateTime v) async {
    final p = await _prefs;
    final iso = v.toIso8601String();
    await p.setString(_kDate, iso);
    state = OnboardingState(
        step: state.step, data: state.data.copyWith(birthDate: v));
  }

  Future<void> setBirthTime(String v) async {
    final p = await _prefs;
    await p.setString(_kTime, v);
    state = OnboardingState(
        step: state.step, data: state.data.copyWith(birthTime: v));
  }

  Future<void> setBirthPlace(String v) async {
    final p = await _prefs;
    await p.setString(_kPlace, v);
    state = OnboardingState(
        step: state.step, data: state.data.copyWith(birthPlace: v));
  }

  void next() {
    if (state.step < 4) {
      state = OnboardingState(step: state.step + 1, data: state.data);
    }
  }

  void back() {
    if (state.step > 0) {
      state = OnboardingState(step: state.step - 1, data: state.data);
    }
  }

  Future<void> finish() async {
    final p = await _prefs;
    await p.setBool(_kCompleted, true);
  }

  Future<void> reset() async {
    final p = await _prefs;
    await Future.wait([
      p.remove(_kCompleted),
      p.remove(_kName),
      p.remove(_kDate),
      p.remove(_kTime),
      p.remove(_kPlace),
    ]);
    state = OnboardingState.initial;
  }
}

final onboardingProvider =
    NotifierProvider<OnboardingNotifier, OnboardingState>(OnboardingNotifier.new);

final onboardingCompletedProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('onboarding_completed') ?? false;
});
