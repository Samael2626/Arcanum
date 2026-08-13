import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/reading_identity_repository.dart';
import '../domain/hebrew_gematria.dart';
import '../domain/reading_identity.dart';

final readingIdentityRepositoryProvider = Provider<ReadingIdentityRepository>(
  (ref) => ReadingIdentityRepository(EncryptedReadingIdentityStorage()),
);

class ReadingIdentityController extends AsyncNotifier<ReadingIdentityProfile?> {
  ReadingIdentityRepository get _repository =>
      ref.read(readingIdentityRepositoryProvider);

  @override
  Future<ReadingIdentityProfile?> build() => _repository.load();

  Future<void> addPart({
    required NamePartType type,
    required String originalText,
    required ReadingDialect dialect,
  }) async {
    final clean = originalText.trim();
    if (clean.isEmpty) throw ArgumentError('Nombre vacio');
    final current = state.value;
    final sameTypeCount =
        current?.parts.where((part) => part.type == type).length ?? 0;
    if (sameTypeCount >= 3) {
      throw StateError('Maximo tres partes por tipo');
    }
    final now = DateTime.now().toUtc();
    final next = ReadingIdentityProfile(
      parts: [
        ...?current?.parts,
        ReadingNamePart(
          id: _randomId(),
          type: type,
          originalText: clean,
          dialect: dialect,
          createdAt: now,
        ),
      ],
      createdAt: current?.createdAt ?? now,
      updatedAt: now,
    );
    await _persist(next);
  }

  Future<void> confirmForm({
    required String partId,
    required String pointedHebrew,
    required String pronunciation,
    required HebrewFormOrigin origin,
    required String ruleVersion,
  }) async {
    final current = state.value;
    if (current == null) {
      throw StateError('Perfil inexistente');
    }
    final base = HebrewGematria.normalizeBase(pointedHebrew);
    if (base.isEmpty) {
      throw ArgumentError('La forma no contiene letras hebreas');
    }
    final letters = HebrewGematria.breakdown(base);
    final now = DateTime.now().toUtc();
    final form = ConfirmedHebrewForm(
      resultId: _randomId(),
      pointedHebrew: pointedHebrew.trim(),
      baseHebrew: base,
      pronunciation: pronunciation,
      origin: origin,
      ruleVersion: ruleVersion,
      gematriaVersion: HebrewGematria.methodVersion,
      letters: letters,
      value: letters.fold(0, (total, letter) => total + letter.value),
      confirmedAt: now,
    );
    var found = false;
    final parts = current.parts
        .map((part) {
          if (part.id != partId) return part;
          found = true;
          return part.addForm(form);
        })
        .toList(growable: false);
    if (!found) throw StateError('Parte inexistente');
    await _persist(
      ReadingIdentityProfile(
        parts: parts,
        createdAt: current.createdAt,
        updatedAt: now,
      ),
    );
  }

  Future<String> exportLocal() async {
    final current = state.value;
    if (current == null) throw StateError('Perfil inexistente');
    return _repository.exportLocal(current);
  }

  Future<void> deleteProfile() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repository.delete();
      return null;
    });
  }

  Future<void> _persist(ReadingIdentityProfile profile) async {
    final previous = state;
    state = const AsyncLoading();
    try {
      await _repository.save(profile);
      state = AsyncData(profile);
    } catch (_) {
      state = previous;
      rethrow;
    }
  }

  String _randomId() {
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }
}

final readingIdentityProvider =
    AsyncNotifierProvider<ReadingIdentityController, ReadingIdentityProfile?>(
      ReadingIdentityController.new,
    );
