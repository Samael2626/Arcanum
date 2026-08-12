import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/arcanum_api.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/state/flow_providers.dart';
import '../../core/theme/arcanum_colors.dart';
import '../../core/theme/arcanum_theme.dart';
import '../../shared/astro_symbols.dart';
import '../../shared/widgets/arcanum_mood.dart';
import '../../shared/widgets/arcanum_surface.dart';
import '../../shared/widgets/info_dot.dart';
import '../../shared/widgets/login_prompt.dart';
import 'grimorio_atmosphere.dart';
import 'grimorio_detail.dart';
import 'grimorio_editor.dart';

class GrimorioScreen extends ConsumerStatefulWidget {
  const GrimorioScreen({super.key});
  @override
  ConsumerState<GrimorioScreen> createState() => _GrimorioScreenState();
}

class _GrimorioScreenState extends ConsumerState<GrimorioScreen> {
  late final ArcanumApi _api = ref.read(arcanumApiProvider);
  Future<List<Map<String, dynamic>>>? _future;
  Object? _authSession;

  void _refresh() {
    final next = _api.grimoireList();
    setState(() {
      _future = next;
    });
  }

  Future<void> _newEntry() async {
    final saved = await Navigator.push<bool>(
      context,
      bookPageRoute(const GrimorioEditor()),
    );
    if (mounted && saved == true) _refresh();
  }

  Future<void> _open(String id, ArcanumMood mood) async {
    final changed = await Navigator.push<bool>(
      context,
      bookPageRoute(GrimorioDetail(id: id, mood: mood)),
    );
    if (mounted && changed == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    if (auth.status == AuthStatus.unknown) {
      return const Center(
        child: CircularProgressIndicator(
          color: ArcanumColors.gold,
          strokeWidth: 2,
        ),
      );
    }
    if (!auth.isAuthenticated) {
      _authSession = null;
      _future = null;
      return const LoginPrompt(
        glyph: '❦',
        title: 'Tu grimorio te aguarda',
        description:
            'Inicia sesión para abrir tu libro personal, cifrado de extremo a extremo.',
      );
    }
    final session = auth.user?['id'] ?? auth.user?['email'] ?? 'authenticated';
    if (_authSession != session) {
      _authSession = session;
      _future = _api.grimoireList();
    }

    // Si llegamos desde "Anotar", abrimos el editor automáticamente.
    if (ref.watch(grimoireComposeProvider)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ref.read(grimoireComposeProvider)) {
          ref.read(grimoireComposeProvider.notifier).set(false);
          _newEntry();
        }
      });
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: _QuillFab(onPressed: _newEntry),
      body: Stack(
        children: [
          const Positioned.fill(child: GrimoireSky()),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const _GrimoireLoading();
                  }
                  if (snap.hasError) {
                    return _GrimoireError(onRetry: _refresh);
                  }
                  final entries = snap.data ?? const [];
                  if (entries.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(22, 40, 22, 100),
                      children: [
                        // El enlace a los pasajes va tambien en el vacio: se
                        // puede haber guardado un pasaje leyendo sin haber
                        // escrito nunca una entrada.
                        const _SavedPassagesLink(),
                        const SizedBox(height: 18),
                        _GrimoireEmpty(onWrite: _newEntry),
                      ],
                    );
                  }
                  return RefreshIndicator(
                    color: ArcanumColors.gold,
                    backgroundColor: ArcanumColors.surface,
                    onRefresh: () async => _refresh(),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(22, 40, 22, 100),
                      children: [
                        const _GrimoireHeader(),
                        const SizedBox(height: 18),
                        const _SavedPassagesLink(),
                        const SizedBox(height: 18),
                        for (var i = 0; i < entries.length; i++)
                          Cascade(
                            delayMs: (i * 90).clamp(0, 600),
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: _CodexLeaf(
                                entry: entries[i],
                                onTap: _open,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Cabecera del libro ──────────────────────────────────────────────────────

class _GrimoireHeader extends StatelessWidget {
  const _GrimoireHeader();
  @override
  Widget build(BuildContext context) {
    Widget rule() => Expanded(
      child: Container(
        height: 1,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.transparent,
              ArcanumColors.goldMuted.withValues(alpha: 0.55),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
    return Column(
      children: [
        Text(
          'Grimorio',
          textAlign: TextAlign.center,
          style: ArcanumText.heading(38).copyWith(letterSpacing: 2),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Tu libro cifrado',
              style: ArcanumText.body(
                15,
                italic: true,
                color: ArcanumColors.ivoryMuted,
              ),
            ),
            const SizedBox(width: 8),
            const InfoDot('grimorio'),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            rule(),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                '✦',
                style: TextStyle(color: ArcanumColors.gold, fontSize: 15),
              ),
            ),
            rule(),
          ],
        ),
      ],
    );
  }
}

// ── Hoja del códice ─────────────────────────────────────────────────────────

/// Una entrada como hoja de un libro de trabajo: capitular iluminada del
/// regente del día, título capitular, y una línea de contexto con el planeta
/// regente + fase lunar. El color del día SUSURRA (bloom bajo + filete), nunca
/// grita — códice unificado, no bloques de color.
class _CodexLeaf extends StatelessWidget {
  final Map<String, dynamic> entry;
  final void Function(String id, ArcanumMood mood) onTap;
  const _CodexLeaf({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final type = entry['entry_type'] as String?;
    final title = (entry['title'] as String?)?.trim();
    final titleText = (title == null || title.isEmpty) ? 'Sin título' : title;
    final moon = entry['moon_phase'] as String?;
    final planetaryHour = entry['planetary_hour'] as String?;
    final day = GrimoireDay.from(
      entry['entry_date'] as String?,
      entry['day_planet'] as String?,
    );
    final mood = day.mood;
    final accent = mood.accent;
    final r = BorderRadius.circular(15);

    Widget hair() => Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            ArcanumColors.goldMuted.withValues(alpha: 0.38),
            Colors.transparent,
          ],
        ),
      ),
    );

    return PressFade(
      onTap: () => onTap(entry['id'] as String, mood),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: r,
          border: Border.all(color: accent.withValues(alpha: 0.28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.38),
              blurRadius: 16,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: r,
          child: Stack(
            children: [
              // Base parchment neutral + susurro del regente por encima.
              const Positioned.fill(
                child: ArcanumSurface(
                  mood: ArcanumMood.neutral,
                  intensity: 0.5,
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(-0.7, -0.6),
                        radius: 1.3,
                        colors: [
                          mood.glow.withValues(alpha: 0.14),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.7],
                      ),
                    ),
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        IlluminatedDropCap(letter: titleText[0], mood: mood),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    entryTypeGlyph[type] ?? '❦',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: accent,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    (entryTypeEs[type] ?? 'Nota').toUpperCase(),
                                    style: ArcanumText.label().copyWith(
                                      color: accent.withValues(alpha: 0.9),
                                      letterSpacing: 2.5,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                titleText,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: ArcanumText.heading(
                                  21,
                                ).copyWith(height: 1.12),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                [
                                  '${planetGlyph[day.planet] ?? ''} ${day.weekdayEs} · ${planetEs[day.planet] ?? day.planet}',
                                  if (moon != null && moon.isNotEmpty)
                                    '☽ $moon',
                                ].join('    ·    '),
                                style: ArcanumText.body(
                                  13,
                                  color: ArcanumColors.ivoryMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  hair(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 9, 16, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          day.longDate,
                          style: ArcanumText.body(
                            12.5,
                            italic: true,
                            color: ArcanumColors.goldMuted,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              planetaryHour == null || planetaryHour.isEmpty
                                  ? 'día de ${planetEs[day.planet] ?? day.planet}'
                                  : 'hora de ${planetEs[planetaryHour] ?? planetaryHour}',
                              style: ArcanumText.body(12.5, color: accent),
                            ),
                            const SizedBox(width: 5),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 16,
                              color: accent.withValues(alpha: 0.8),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GrimoireError extends StatelessWidget {
  final VoidCallback onRetry;
  const _GrimoireError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 34),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              color: ArcanumColors.goldMuted,
              size: 38,
            ),
            const SizedBox(height: 14),
            Text(
              'El grimorio no pudo abrirse',
              textAlign: TextAlign.center,
              style: ArcanumText.heading(23),
            ),
            const SizedBox(height: 8),
            Text(
              'Tus entradas siguen selladas. Revisa tu conexión e inténtalo de nuevo.',
              textAlign: TextAlign.center,
              style: ArcanumText.body(
                14.5,
                color: ArcanumColors.ivoryMuted,
                italic: true,
              ),
            ),
            const SizedBox(height: 22),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Estado vacío: invitación ────────────────────────────────────────────────

class _GrimoireEmpty extends StatelessWidget {
  final VoidCallback onWrite;
  const _GrimoireEmpty({required this.onWrite});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 34),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 150,
              height: 150,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const BreathingHeptagram(size: 150),
                  _BreathingSeal(),
                ],
              ),
            ),
            const SizedBox(height: 30),
            Text(
              'Tu grimorio\naguarda su primera palabra',
              textAlign: TextAlign.center,
              style: ArcanumText.heading(28).copyWith(height: 1.2),
            ),
            const SizedBox(height: 14),
            Text(
              'Cada rito, cada lectura, cada sueño —\nsellado y cifrado, solo para tus ojos.',
              textAlign: TextAlign.center,
              style: ArcanumText.body(
                15.5,
                italic: true,
                color: ArcanumColors.ivoryMuted,
              ),
            ),
            const SizedBox(height: 30),
            OutlinedButton(
              onPressed: onWrite,
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: ArcanumColors.gold.withValues(alpha: 0.7),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 26,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Escribir la primera entrada',
                style: ArcanumText.heading(19, color: ArcanumColors.gold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BreathingSeal extends StatefulWidget {
  @override
  State<_BreathingSeal> createState() => _BreathingSealState();
}

class _BreathingSealState extends State<_BreathingSeal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_c.value);
        return Container(
          width: 104,
          height: 104,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: ArcanumColors.gold.withValues(alpha: 0.4),
            ),
            gradient: RadialGradient(
              colors: [
                ArcanumColors.gold.withValues(alpha: 0.06 + 0.05 * t),
                Colors.transparent,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: ArcanumColors.gold.withValues(alpha: 0.10 + 0.10 * t),
                blurRadius: 24 + 12 * t,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Text(
            '❦',
            style: TextStyle(
              fontSize: 52,
              color: ArcanumColors.gold,
              height: 1,
              shadows: [
                Shadow(
                  color: ArcanumColors.gold.withValues(alpha: 0.4 + 0.2 * t),
                  blurRadius: 18,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Carga premium ───────────────────────────────────────────────────────────

class _GrimoireLoading extends StatefulWidget {
  const _GrimoireLoading();
  @override
  State<_GrimoireLoading> createState() => _GrimoireLoadingState();
}

class _GrimoireLoadingState extends State<_GrimoireLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final t = Curves.easeInOut.transform(_c.value);
              return Opacity(
                opacity: 0.55 + 0.4 * t,
                child: Text(
                  '❦',
                  style: TextStyle(
                    fontSize: 46,
                    color: ArcanumColors.gold,
                    shadows: [
                      Shadow(
                        color: ArcanumColors.gold.withValues(alpha: 0.35 * t),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 18),
          Text(
            'Descifrando tu libro…',
            style: ArcanumText.body(
              15.5,
              italic: true,
              color: ArcanumColors.ivoryMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// ── FAB pluma ───────────────────────────────────────────────────────────────

class _QuillFab extends StatelessWidget {
  final VoidCallback onPressed;
  const _QuillFab({required this.onPressed});
  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: onPressed,
      backgroundColor: ArcanumColors.gold,
      foregroundColor: ArcanumColors.background,
      elevation: 6,
      child: const Icon(Icons.edit_outlined, size: 24),
    );
  }
}


/// Puerta a "Pasajes guardados": lo que el usuario subrayo leyendo.
///
/// Vive en el Grimorio y no en la Biblioteca porque no es contenido de la obra:
/// es lo que esta persona hizo con ella.
class _SavedPassagesLink extends StatelessWidget {
  const _SavedPassagesLink();

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Pasajes guardados',
    child: InkWell(
      onTap: () => context.push('/grimorio/pasajes'),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: ArcanumColors.goldMuted.withValues(alpha: 0.45),
          ),
        ),
        child: Row(
          children: [
            const Text(
              '❧',
              style: TextStyle(fontSize: 15, color: ArcanumColors.gold),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PASAJES GUARDADOS', style: ArcanumText.label()),
                  const SizedBox(height: 2),
                  Text(
                    'Lo que subrayaste en la Biblioteca',
                    style: ArcanumText.body(14, color: ArcanumColors.ivory),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: ArcanumColors.goldMuted,
            ),
          ],
        ),
      ),
    ),
  );
}
