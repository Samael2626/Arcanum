import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/sendero_catalog.dart';
import 'sendero_controller.dart';
import '../../fragmentos/application/fragment_balance.dart';

class SenderoCompletion {
  const SenderoCompletion({required this.journey, required this.fragments});

  final SenderoJourney journey;
  final int fragments;
}

class SenderoCompletionController extends Notifier<SenderoCompletion?> {
  @override
  SenderoCompletion? build() => null;

  void show(SenderoJourney journey, int fragments) =>
      state = SenderoCompletion(journey: journey, fragments: fragments);
  void clear() => state = null;
}

final senderoCompletionProvider =
    NotifierProvider<SenderoCompletionController, SenderoCompletion?>(
      SenderoCompletionController.new,
    );

class SenderoGuideState {
  const SenderoGuideState({required this.journey, required this.step});

  final SenderoJourney journey;
  final int step;

  SenderoStep get current => journey.steps[step];

  String? get expectedRoute {
    for (var index = step; index >= 0; index--) {
      final route = journey.steps[index].route;
      if (route != null) return route;
    }
    return null;
  }
}

class SenderoGuideTargets {
  final keys = <String, GlobalKey>{};

  GlobalKey keyFor(String id) => keys.putIfAbsent(id, GlobalKey.new);
}

final senderoGuideTargetsProvider = Provider<SenderoGuideTargets>(
  (ref) => SenderoGuideTargets(),
);

class SenderoGuideController extends Notifier<SenderoGuideState?> {
  Future<void> _pending = Future<void>.value();

  Future<void> get idle => _pending;

  @override
  SenderoGuideState? build() => null;

  void start(SenderoJourney journey, {SenderoProgress? saved}) {
    if (!journey.available || journey.steps.isEmpty) return;
    final step =
        saved != null && !saved.isCompleted && saved.status == 'in_progress'
        ? saved.step.clamp(0, journey.steps.length - 1)
        : 0;
    final active = SenderoGuideState(journey: journey, step: step);
    state = active;
    if (saved == null) _enqueue(active, false);
  }

  void pause() => state = null;

  Future<void> skip() async {
    final active = state;
    if (active == null) return;
    state = null;
    await _pending;
    await ref
        .read(senderoControllerProvider.notifier)
        .advance(
          journeyId: active.journey.id,
          version: active.journey.version,
          step: active.step,
          status: 'dismissed',
        );
  }

  void onAction(String target) {
    final active = state;
    if (active == null || active.current.target != target) return;
    final isLast = active.step == active.journey.steps.length - 1;
    state = isLast
        ? null
        : SenderoGuideState(journey: active.journey, step: active.step + 1);
    _enqueue(active, isLast);
  }

  void _enqueue(SenderoGuideState active, bool isLast) {
    _pending = _pending.then((_) => _save(active, isLast));
  }

  Future<void> _save(SenderoGuideState active, bool isLast) async {
    try {
      final reward = await ref
          .read(senderoControllerProvider.notifier)
          .advance(
            journeyId: active.journey.id,
            version: active.journey.version,
            step: isLast ? active.step : active.step + 1,
            status: isLast ? 'completed' : 'in_progress',
          );
      if (reward > 0) ref.invalidate(fragmentBalanceProvider);
      if (isLast) {
        ref
            .read(senderoCompletionProvider.notifier)
            .show(active.journey, reward);
      }
    } catch (error, stack) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'sendero',
          context: ErrorDescription('guardando avance contextual'),
        ),
      );
    }
  }
}

final senderoGuideProvider =
    NotifierProvider<SenderoGuideController, SenderoGuideState?>(
      SenderoGuideController.new,
    );
