import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/arcanum_api.dart';
import '../../../core/auth/auth_controller.dart';

class SenderoProgress {
  const SenderoProgress({
    required this.journeyId,
    required this.version,
    required this.step,
    required this.status,
    required this.updatedAt,
  });

  final String journeyId;
  final int version;
  final int step;
  final String status;
  final DateTime updatedAt;

  String get key => '$journeyId:$version';
  bool get isCompleted => status == 'completed';

  Map<String, dynamic> toJson() => {
    'journey_id': journeyId,
    'version': version,
    'step': step,
    'status': status,
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };

  factory SenderoProgress.fromJson(Map<String, dynamic> json) =>
      SenderoProgress(
        journeyId: json['journey_id'] as String,
        version: json['version'] as int,
        step: json['step'] as int,
        status: json['status'] as String,
        updatedAt:
            DateTime.tryParse(json['updated_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
}

class SenderoController extends AsyncNotifier<Map<String, SenderoProgress>> {
  static const _storagePrefix = 'sendero_progress_v1_';

  @override
  Future<Map<String, SenderoProgress>> build() async {
    final userId = ref.watch(
      authProvider.select((state) => state.user?['id']?.toString()),
    );
    if (userId == null) return {};
    final storageKey = '$_storagePrefix$userId';
    final local = await _readLocal(storageKey);
    late final List<Map<String, dynamic>> remoteRows;
    try {
      remoteRows = await ref.read(arcanumApiProvider).senderoProgress();
    } catch (_) {
      return local;
    }

    final merged = {...local};
    for (final row in remoteRows) {
      final remote = SenderoProgress.fromJson(row);
      final current = merged[remote.key];
      merged[remote.key] = _merge(current, remote);
    }
    await _writeLocal(storageKey, merged);
    for (final entry in merged.values) {
      try {
        await _sync(entry);
      } catch (_) {
        // El estado fusionado ya quedo local; la subida espera otro arranque.
      }
    }
    return merged;
  }

  SenderoProgress? progress(String journeyId, int version) =>
      state.value?["$journeyId:$version"];

  Future<int> advance({
    required String journeyId,
    required int version,
    required int step,
    String status = 'in_progress',
  }) async {
    final current = state.value ?? await future;
    final userId = ref.read(authProvider).user?['id']?.toString();
    if (userId == null) return 0;
    final key = '$journeyId:$version';
    final next = _merge(
      current[key],
      SenderoProgress(
        journeyId: journeyId,
        version: version,
        step: step,
        status: status,
        updatedAt: DateTime.now().toUtc(),
      ),
    );
    final updated = {...current, key: next};
    state = AsyncData(updated);
    await _writeLocal('$_storagePrefix$userId', updated);
    try {
      final response = await _sync(next);
      return response['reward_fragments'] as int? ?? 0;
    } catch (_) {
      // La copia local manda offline y se reintenta al abrir Sendero.
      return 0;
    }
  }

  SenderoProgress _merge(SenderoProgress? a, SenderoProgress b) {
    if (a == null) return b;
    final completed = a.isCompleted || b.isCompleted;
    final newest = a.updatedAt.isAfter(b.updatedAt) ? a : b;
    return SenderoProgress(
      journeyId: b.journeyId,
      version: b.version,
      step: a.step > b.step ? a.step : b.step,
      status: completed ? 'completed' : newest.status,
      updatedAt: newest.updatedAt,
    );
  }

  Future<Map<String, SenderoProgress>> _readLocal(String storageKey) async {
    final raw = (await SharedPreferences.getInstance()).getString(storageKey);
    if (raw == null) return {};
    try {
      final rows = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      return {
        for (final row in rows)
          SenderoProgress.fromJson(row).key: SenderoProgress.fromJson(row),
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeLocal(
    String storageKey,
    Map<String, SenderoProgress> values,
  ) async {
    await (await SharedPreferences.getInstance()).setString(
      storageKey,
      jsonEncode(values.values.map((value) => value.toJson()).toList()),
    );
  }

  Future<Map<String, dynamic>> _sync(SenderoProgress value) async {
    return await ref
        .read(arcanumApiProvider)
        .updateSenderoProgress(
          journeyId: value.journeyId,
          version: value.version,
          step: value.step,
          status: value.status,
        );
  }
}

final senderoControllerProvider =
    AsyncNotifierProvider<SenderoController, Map<String, SenderoProgress>>(
      SenderoController.new,
    );

Future<void> clearSenderoLocalData() async {
  final prefs = await SharedPreferences.getInstance();
  for (final key in prefs.getKeys().where(
    (key) =>
        key.startsWith(SenderoController._storagePrefix) ||
        key.startsWith('sendero_offer_'),
  )) {
    await prefs.remove(key);
  }
}
