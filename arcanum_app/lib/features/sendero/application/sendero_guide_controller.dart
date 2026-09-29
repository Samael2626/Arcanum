import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/sendero_catalog.dart';
import 'sendero_controller.dart';

class SenderoGuideState {
  const SenderoGuideState({required this.journey, required this.step});

  final SenderoJourney journey;
  final int step;

  SenderoStep get current => journey.steps[step];
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
    var step =
        saved != null && !saved.isCompleted && saved.status == 'in_progress'
        ? saved.step.clamp(0, journey.steps.length - 1)
        : 0;
    if (journey.steps[step].target.startsWith('section_') ||
        journey.steps[step].target == 'settings') {
      step = 0;
    }
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
      await ref
          .read(senderoControllerProvider.notifier)
          .advance(
            journeyId: active.journey.id,
            version: active.journey.version,
            step: isLast ? active.step : active.step + 1,
            status: isLast ? 'completed' : 'in_progress',
          );
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
