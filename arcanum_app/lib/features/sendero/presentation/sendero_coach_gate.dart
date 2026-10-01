import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/content/sections.dart';
import '../../../core/theme/arcanum_colors.dart';
import '../../../core/theme/arcanum_theme.dart';
import '../application/sendero_controller.dart';
import '../application/sendero_guide_controller.dart';
import '../domain/sendero_catalog.dart';
import 'sendero_spotlight.dart';

class SenderoCoachGate extends ConsumerStatefulWidget {
  const SenderoCoachGate({
    super.key,
    required this.router,
    required this.child,
  });

  final GoRouter router;
  final Widget child;

  @override
  ConsumerState<SenderoCoachGate> createState() => _SenderoCoachGateState();
}

class _CoachOffer {
  const _CoachOffer({this.journey, this.fragments});

  final SenderoJourney? journey;
  final int? fragments;
  bool get isCompletion => fragments != null;
}

class _SenderoCoachGateState extends ConsumerState<SenderoCoachGate> {
  late String _route;
  String? _suppressedRoute;
  _CoachOffer? _offer;

  @override
  void initState() {
    super.initState();
    _route = widget.router.routerDelegate.currentConfiguration.uri.path;
    widget.router.routerDelegate.addListener(_onRouteChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final completion = ref.read(senderoCompletionProvider);
      if (completion != null) _showCompletion(completion);
      _scheduleDiscovery();
    });
  }

  @override
  void didUpdateWidget(covariant SenderoCoachGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.router == widget.router) return;
    oldWidget.router.routerDelegate.removeListener(_onRouteChanged);
    widget.router.routerDelegate.addListener(_onRouteChanged);
    _onRouteChanged();
  }

  @override
  void dispose() {
    widget.router.routerDelegate.removeListener(_onRouteChanged);
    super.dispose();
  }

  void _onRouteChanged() {
    final next = widget.router.routerDelegate.currentConfiguration.uri.path;
    if (next == _route || !mounted) return;
    setState(() {
      _route = next;
      _offer = null;
    });
    _scheduleDiscovery();
  }

  void _scheduleDiscovery() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _offerDiscovery());
  }

  SenderoJourney? _journeyForRoute(String route) {
    for (final journey in senderoJourneys) {
      if (journey.id != 'orientation' &&
          journey.steps.first.route == route &&
          journey.available) {
        return journey;
      }
    }
    return null;
  }

  Future<void> _offerDiscovery() async {
    if (!mounted ||
        _offer != null ||
        _suppressedRoute == _route ||
        ref.read(senderoGuideProvider) != null) {
      return;
    }
    final progress = ref.read(senderoControllerProvider).value;
    if (progress?['orientation:2']?.isCompleted != true) return;
    final journey = _journeyForRoute(_route);
    if (journey == null) return;
    final saved = progress?['${journey.id}:${journey.version}'];
    if (saved?.isCompleted == true || saved?.status == 'dismissed') return;
    final userId = ref.read(authProvider).user?['id']?.toString();
    if (userId == null) return;
    final route = _route;
    final prefs = await SharedPreferences.getInstance();
    final key = 'sendero_context_seen_$userId';
    final seen = prefs.getStringList(key)?.toSet() ?? <String>{};
    final lessonKey = '${journey.id}:${journey.version}';
    if (seen.contains(lessonKey) ||
        !mounted ||
        _route != route ||
        _offer != null ||
        ref.read(senderoGuideProvider) != null) {
      return;
    }
    await prefs.setStringList(key, [...seen, lessonKey]);
    if (mounted && _route == route && _offer == null) {
      setState(() => _offer = _CoachOffer(journey: journey));
    }
  }

  SenderoJourney? _nextJourney(SenderoJourney completed) {
    final progress = ref.read(senderoControllerProvider).value;
    final index = senderoJourneys.indexOf(completed);
    for (final journey in senderoJourneys.skip(index + 1)) {
      if (journey.available &&
          progress?['${journey.id}:${journey.version}']?.isCompleted != true) {
        return journey;
      }
    }
    return null;
  }

  void _showCompletion(SenderoCompletion completion) {
    if (!mounted) return;
    setState(() {
      _suppressedRoute = _route;
      _offer = _CoachOffer(
        journey: _nextJourney(completion.journey),
        fragments: completion.fragments,
      );
    });
    ref.read(senderoCompletionProvider.notifier).clear();
  }

  void _start(SenderoJourney journey) {
    final saved = ref
        .read(senderoControllerProvider)
        .value?['${journey.id}:${journey.version}'];
    setState(() {
      _offer = null;
      _suppressedRoute = _route;
    });
    ref.read(senderoGuideProvider.notifier).start(journey, saved: saved);
    final route = journey.steps.first.route;
    if (route != null && route != _route) context.go(route);
  }

  void _dismiss() {
    setState(() {
      _offer = null;
      _suppressedRoute = _route;
    });
  }

  String _completionBody(_CoachOffer offer) {
    final fragments = offer.fragments!;
    if (fragments == 0) return 'Puedes seguir explorando a tu ritmo.';
    final reward = fragments == 1
        ? 'Un Fragmento Arcano despertó en tu saldo.'
        : '$fragments Fragmentos Arcanos despertaron en tu saldo.';
    return offer.journey == null ? reward : '$reward ¿Exploramos otra cámara?';
  }

  @override
  Widget build(BuildContext context) {
    final guide = ref.watch(senderoGuideProvider);
    ref.listen(senderoGuideProvider, (previous, next) {
      if (next == null && previous != null) _suppressedRoute = _route;
      if (next != null && _offer != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _offer = null);
        });
      }
      _scheduleDiscovery();
    });
    ref.listen(senderoControllerProvider, (_, _) => _scheduleDiscovery());
    ref.listen(senderoCompletionProvider, (_, completion) {
      if (completion != null) _showCompletion(completion);
    });

    final expected = guide?.expectedRoute;
    final returnTitle = expected == null
        ? null
        : arcanumSectionForRoute(expected)?.title;
    final detour = guide != null && expected != null && expected != _route;
    final localJourney = detour ? _journeyForRoute(_route) : null;
    final offer = _offer;

    return Stack(
      children: [
        widget.child,
        if (guide != null && !detour)
          Positioned.fill(child: SenderoSpotlight(guide: guide)),
        if (detour)
          _NudgeCard(
            title: localJourney == null
                ? 'Sendero te espera'
                : 'Sendero te sigue',
            body: localJourney == null
                ? 'Tu recorrido ${guide.journey.title} sigue guardado.'
                : 'Estás en ${localJourney.title}. Tu recorrido ${guide.journey.title} queda guardado.',
            primaryLabel: returnTitle == null
                ? 'Volver al recorrido'
                : 'Volver a $returnTitle',
            onPrimary: () => context.go(expected),
            secondaryLabel: localJourney == null
                ? 'Pausar'
                : 'Explorar ${localJourney.title}',
            onSecondary: localJourney == null
                ? () {
                    ref.read(senderoGuideProvider.notifier).pause();
                    _dismiss();
                  }
                : () => _start(localJourney),
            tertiaryLabel: localJourney == null ? null : 'Pausar',
            onTertiary: localJourney == null
                ? null
                : () {
                    ref.read(senderoGuideProvider.notifier).pause();
                    _dismiss();
                  },
          )
        else if (guide == null && offer != null)
          _NudgeCard(
            title: offer.isCompletion
                ? 'Lección recorrida'
                : 'Sendero en ${offer.journey!.title}',
            body: offer.isCompletion
                ? _completionBody(offer)
                : 'Hay una guía breve para descubrir esta sección mientras la usas.',
            primaryLabel: offer.journey == null
                ? null
                : offer.isCompletion
                ? 'Explorar ${offer.journey!.title}'
                : 'Mostrar guía',
            onPrimary: offer.journey == null
                ? null
                : () => _start(offer.journey!),
            secondaryLabel: 'Ahora no',
            onSecondary: _dismiss,
          ),
      ],
    );
  }
}

class _NudgeCard extends StatelessWidget {
  const _NudgeCard({
    required this.title,
    required this.body,
    required this.primaryLabel,
    required this.onPrimary,
    required this.secondaryLabel,
    required this.onSecondary,
    this.tertiaryLabel,
    this.onTertiary,
  });

  final String title;
  final String body;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String secondaryLabel;
  final VoidCallback onSecondary;
  final String? tertiaryLabel;
  final VoidCallback? onTertiary;

  @override
  Widget build(BuildContext context) => Positioned(
    left: 12,
    right: 12,
    bottom: 12,
    child: SafeArea(
      top: false,
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Material(
            key: const ValueKey('sendero_coach_card'),
            color: ArcanumColors.surfaceHigh,
            elevation: 10,
            shape: RoundedRectangleBorder(
              side: const BorderSide(color: ArcanumColors.goldMuted),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: ArcanumText.heading(21)),
                  const SizedBox(height: 5),
                  Text(body, style: ArcanumText.body(14)),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 2,
                    children: [
                      if (primaryLabel != null)
                        TextButton(
                          onPressed: onPrimary,
                          child: Text(primaryLabel!),
                        ),
                      TextButton(
                        onPressed: onSecondary,
                        child: Text(secondaryLabel),
                      ),
                      if (tertiaryLabel != null)
                        TextButton(
                          onPressed: onTertiary,
                          child: Text(tertiaryLabel!),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
