import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_svg/flutter_svg.dart';

import '../theme/arcanum_colors.dart';
import '../theme/arcanum_theme.dart';
import '../monetization/saldo.dart';
import '../../features/fragmentos/application/fragment_balance.dart';
import '../../shared/widgets/arcane_currency_emblem.dart';
import '../../shared/widgets/bloque_saldo.dart';
import '../../shared/widgets/arcanum_mood.dart';
import '../../shared/widgets/arcanum_resin.dart';
import '../../shared/widgets/arcanum_toggle.dart';
import '../../features/sendero/application/sendero_guide_controller.dart';
import '../state/flow_providers.dart';

/// El cajon: indice con sellos (ver [_Map]).
///
/// LA EXCEPCION DE MATERIAL, DICHA EN VOZ ALTA
///
/// Resina es OPACA, y de esa decision salio el veredicto de rendimiento: sin
/// desenfoque no hay `saveLayer` que medir. Este cajon es la unica pieza de la
/// app que se salta esa regla: lleva `BackdropFilter`, porque se pidio vidrio.
///
/// Se acepta porque el coste esta ACOTADO, y conviene saber por que:
///
///   · el `Drawer` no existe hasta que se abre -- fuera de ese momento no
///     cuesta nada, ni siquiera un widget en el arbol;
///   · lo que desenfoca es una pantalla QUIETA, no una lista con scroll, que
///     era el caso que hundia al vidrio cuando se midio;
///   · es una sola capa, no una por componente.
///
/// Si algun dia esto se nota, lo que se quita es el desenfoque y no la
/// transparencia: el alfa del degradado ya deja ver lo de detras y ese no
/// cuesta nada.
class ArcanumDrawer extends ConsumerWidget {
  const ArcanumDrawer({super.key, required this.navigationShell});

  /// Se conserva la firma mientras el shell comparte este cajon con rutas
  /// apiladas. Los mosaicos cambian de rama mediante sus rutas existentes.
  final StatefulNavigationShell navigationShell;

  /// Cuanto deja ver. Por debajo de esto el texto de dentro empieza a pelearse
  /// con lo que hay detras.
  static const _opacidad = 0.88;

  static const _blur = 14.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final base = ArcanumResin.gradient(mood: ArcanumMood.neutral);
    return Drawer(
      backgroundColor: Colors.transparent,
      elevation: 0,
      width: MediaQuery.of(context).size.width * 0.72,
      child: ClipRRect(
        borderRadius: const BorderRadius.horizontal(
          right: Radius.circular(ArcanumSelection.radius),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: _blur, sigmaY: _blur),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: base.begin,
                end: base.end,
                stops: base.stops,
                colors: [
                  for (final c in base.colors) c.withValues(alpha: _opacidad),
                ],
              ),
            ),
            child: const SafeArea(child: _Map()),
          ),
        ),
      ),
    );
  }
}

/// Glifos de cada seccion, dibujados (nada de iconos de Material ni de
/// caracteres de fuente). Trazo de 1,5 sobre 24.
abstract final class _Glyph {
  static const cielo =
      '<circle cx="12" cy="12" r="4.2"/><path d="M12 2.5v3M12 18.5v3M2.5 12h3M18.5 12h3M5.3 5.3l2.1 2.1M16.6 16.6l2.1 2.1M5.3 18.7l2.1-2.1M16.6 7.4l2.1-2.1"/>';
  static const horoscopo =
      '<path d="M15.5 4.5a8 8 0 1 0 4 12.7 6.4 6.4 0 1 1-4-12.7z"/><path d="M17.5 6.2l.6 1.4 1.4.5-1.4.6-.6 1.4-.5-1.4-1.4-.6 1.4-.5z"/>';
  static const tarot =
      '<rect x="5" y="3.5" width="11" height="16" rx="1.6"/><path d="M8 21h10.5a1.5 1.5 0 0 0 1.5-1.5V7"/><path d="M10.5 8.5l2 3.5-2 3.5-2-3.5z"/>';
  static const grimorio =
      '<path d="M4 5.5c2.6-1.2 5.3-1.2 8 .4 2.7-1.6 5.4-1.6 8-.4V19c-2.6-1.2-5.3-1.2-8 .4-2.7-1.6-5.4-1.6-8-.4z"/><path d="M12 6v13.4"/>';
  static const saber =
      '<path d="M12 21V11"/><path d="M12 13c-4.5 0-6.5-3-6.5-7 4.5 0 6.5 3 6.5 7zM12 11c0-4 2-7 6.5-7 0 4-2 7-6.5 7z"/>';
  static const cuenta =
      '<circle cx="12" cy="8.5" r="3.6"/><path d="M5 20c1.2-3.6 3.8-5.4 7-5.4s5.8 1.8 7 5.4"/>';

  static Widget draw(String paths, Color color, {double size = 18}) =>
      SvgPicture.string(
        '<svg viewBox="0 0 24 24" fill="none" stroke="#000" stroke-width="1.5" '
        'stroke-linecap="round" stroke-linejoin="round">$paths</svg>',
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
}

typedef _Open = void Function(BuildContext context, WidgetRef ref);

/// Una parte de una seccion: abre su sitio.
class _Part {
  const _Part(this.label, this.open, {this.active = false, this.key});
  final String label;
  final _Open open;
  final bool active;
  final Key? key;
}

class _Section {
  const _Section({
    required this.name,
    required this.glyph,
    required this.here,
    this.parts = const [],
    this.open,
    this.muted = false,
    this.numeral,
    this.lead,
  });
  final String name;
  final String glyph;

  /// Numero romano del sello (Samuel, 08-oct: «los numeros romanos con los
  /// circulos de los sellos»). La cuenta no lleva numero: lleva su glifo.
  final String? numeral;

  /// Lo que va encima de las partes al desplegar (el saldo, en la cuenta).
  final Widget? lead;

  /// La seccion en la que se esta: su sello brilla y su nombre va en oro.
  final bool here;
  final List<_Part> parts;

  /// Sin partes, tocar el nombre la abre.
  final _Open? open;

  /// Sello sin lacre: la cuenta no es una seccion.
  final bool muted;
}

/// El menu: indice con sellos (Samuel, 08-oct, B1 + B3). Las mismas cinco
/// secciones y en el mismo orden que la portada (Cielo, Tarot, Horoscopo,
/// Grimorio, Saber); cada una se despliega en sus
/// partes, que cuelgan de un hilo dorado. Toda la cuenta, al pie.
///
/// Sustituye al mapa por grupos del 07-oct (16 filas, nombres distintos a los
/// de la portada, el tarot en tres filas): Samuel lo encontro confuso.
class _Map extends ConsumerStatefulWidget {
  const _Map();

  @override
  ConsumerState<_Map> createState() => _MapState();
}

class _MapState extends ConsumerState<_Map> {
  /// Seccion desplegada (por nombre). Al abrir el menu, la de donde se esta.
  String? _open;
  bool _openSet = false;
  bool _forcedAccount = false;

  static void _go(BuildContext c, String route) => c.go(route);

  static void _push(BuildContext c, String route) {
    if (GoRouterState.of(c).uri.path != route) c.push(route);
  }

  static void _cielo(BuildContext c, WidgetRef r, int face) {
    r.read(cieloCaraProvider.notifier).set(face);
    c.go('/hoy');
  }

  // Sin claves del Sendero en las secciones: `section_horoscopo` ya la lleva
  // la placa de la portada, y dos widgets con la misma GlobalKey revientan al
  // abrir el menu (la portada sigue montada en el IndexedStack del shell).
  List<_Section> _sections(String path, int cara) {
    bool under(String root) => path == root || path.startsWith('$root/');
    return [
      _Section(
        name: 'Cielo',
        numeral: 'I',
        glyph: _Glyph.cielo,
        here: under('/hoy'),
        parts: [
          _Part(
            'Hoy y la hora',
            (c, r) => _cielo(c, r, 0),
            active: under('/hoy') && cara == 0,
          ),
          _Part(
            'Tu carta natal',
            (c, r) => _cielo(c, r, 1),
            active: under('/hoy') && cara == 1,
          ),
          _Part('Respirar', (c, _) => _push(c, '/respirar')),
        ],
      ),
      _Section(
        name: 'Tarot',
        numeral: 'II',
        glyph: _Glyph.tarot,
        here: under('/oraculo'),
        parts: [
          _Part('Mesa', (c, _) => _push(c, '/tarot')),
          _Part(
            'Oráculo',
            (c, _) => _go(c, '/oraculo'),
            active: under('/oraculo'),
          ),
          _Part('Tus lecturas', (c, _) => _push(c, '/lecturas')),
        ],
      ),
      _Section(
        name: 'Horóscopo',
        numeral: 'III',
        glyph: _Glyph.horoscopo,
        here: under('/horoscopo'),
        open: (c, r) {
          r.read(senderoGuideProvider.notifier).onAction('section_horoscopo');
          _go(c, '/horoscopo');
        },
      ),
      _Section(
        name: 'Grimorio',
        numeral: 'IV',
        glyph: _Glyph.grimorio,
        here: under('/grimorio'),
        parts: [
          _Part(
            'Diario',
            (c, _) => _go(c, '/grimorio'),
            active: under('/grimorio'),
          ),
          _Part('Taller de sigilos', (c, _) => _push(c, '/sigilos')),
        ],
      ),
      _Section(
        name: 'Saber',
        numeral: 'V',
        glyph: _Glyph.saber,
        here: under('/saber'),
        open: (c, _) => _go(c, '/saber'),
      ),
    ];
  }

  _Section _account(String path) {
    final targets = ref.read(senderoGuideTargetsProvider);
    return _Section(
      name: 'Tu cuenta',
      glyph: _Glyph.cuenta,
      here: false,
      muted: true,
      // el saldo completo vive aqui (Samuel, 08-oct); arriba, solo la cifra
      lead: const BloqueSaldoCajon(),
      parts: [
        _Part(
          'Perfil',
          (c, _) => _push(c, '/perfil'),
          active: path == '/perfil',
        ),
        _Part(
          'Ajustes',
          (c, r) {
            _push(c, '/settings');
            r.read(senderoGuideProvider.notifier).onAction('settings');
          },
          active: path == '/settings',
          key: targets.keyFor('settings'),
        ),
        // Privacidad sigue a mano: estaba a tres toques dentro de Ajustes
        _Part('Privacidad y datos', (c, _) => _push(c, '/privacy')),
        _Part('Fragmentos Arcanos', (c, _) => _push(c, '/fragmentos')),
        _Part('Ayuda y recorrido', (c, _) => _push(c, '/sendero')),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    final cara = ref.watch(cieloCaraProvider);
    final sections = _sections(path, cara);
    final account = _account(path);
    // el Sendero puede senalar una fila de dentro de la cuenta: se despliega
    final guide = ref.watch(senderoGuideProvider);
    final wantsAccount = guide?.current.target == 'settings';
    if (!_openSet) {
      _openSet = true;
      _open = wantsAccount
          ? account.name
          : sections
                .where((s) => s.here && s.parts.isNotEmpty)
                .firstOrNull
                ?.name;
    } else if (wantsAccount && !_forcedAccount) {
      _open = account.name;
    }
    // solo al empezar a senalar Ajustes: despues se puede plegar a mano
    _forcedAccount = wantsAccount;

    Widget block(_Section s) => _SectionBlock(
      section: s,
      expanded: _open == s.name,
      onToggle: () => setState(() => _open = _open == s.name ? null : s.name),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(top: 20, bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 10, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'ARCANUM',
                          style: ArcanumText.label().copyWith(
                            color: ArcanumColors.gold,
                            letterSpacing: 4,
                          ),
                        ),
                      ),
                      const _TinyBalance(),
                    ],
                  ),
                ),
                const _Rule(),
                for (final s in sections) block(s),
              ],
            ),
          ),
        ),
        const _Rule(),
        block(account),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// La linea dorada que se desvanece hacia la derecha.
class _Rule extends StatelessWidget {
  const _Rule();

  @override
  Widget build(BuildContext context) => Container(
    height: 1,
    margin: const EdgeInsets.fromLTRB(22, 8, 22, 6),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [ArcanumColors.goldMuted, Color(0x008A6E32)],
      ),
    ),
  );
}

class _SectionBlock extends ConsumerWidget {
  const _SectionBlock({
    required this.section,
    required this.expanded,
    required this.onToggle,
  });

  final _Section section;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = section;
    final hasParts = s.parts.isNotEmpty;
    final nameColor = s.here
        ? ArcanumColors.gold
        : s.muted
        ? ArcanumColors.ivoryMuted
        : ArcanumColors.ivory;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          selected: s.here,
          expanded: hasParts ? expanded : null,
          label: s.name,
          child: InkWell(
            onTap: hasParts
                ? onToggle
                : () {
                    // `closeDrawer` y no `Navigator.pop`: dentro del shell de
                    // go_router el pop no cerraba el cajon
                    Scaffold.of(context).closeDrawer();
                    s.open?.call(context, ref);
                  },
            child: ExcludeSemantics(
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 54),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      _Seal(
                        glyph: s.glyph,
                        numeral: s.numeral,
                        lit: s.here,
                        muted: s.muted,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          s.name,
                          style: ArcanumText.heading(
                            s.muted ? 19 : 22,
                            color: nameColor,
                          ),
                        ),
                      ),
                      if (hasParts)
                        AnimatedRotation(
                          turns: expanded ? .25 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: const Icon(
                            Icons.chevron_right,
                            color: ArcanumColors.goldMuted,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: !expanded
              ? const SizedBox(width: double.infinity)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // el saldo va a lo ancho, fuera del hilo: dentro del
                    // margen no cabia y desbordaba (08-oct)
                    ?s.lead,
                    Container(
                      // el hilo dorado del que cuelgan las partes
                      margin: const EdgeInsets.only(left: 39, bottom: 4),
                      decoration: const BoxDecoration(
                        border: Border(
                          left: BorderSide(color: Color(0x73C9A84C)),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [for (final p in s.parts) _PartRow(part: p)],
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// El sello de lacre con el glifo de la seccion.
class _Seal extends StatelessWidget {
  const _Seal({
    required this.glyph,
    required this.lit,
    this.numeral,
    this.muted = false,
  });
  final String glyph;
  final String? numeral;
  final bool lit;
  final bool muted;

  @override
  Widget build(BuildContext context) => Container(
    width: 34,
    height: 34,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(
        center: const Alignment(-.3, -.4),
        colors: muted
            ? const [Color(0xFF2B2836), Color(0xFF15131B)]
            : const [Color(0xFF7A2534), Color(0xFF3C0C15)],
      ),
      border: Border.all(
        color: lit ? ArcanumColors.goldLight : const Color(0x80E2C77A),
      ),
      boxShadow: [
        if (lit) const BoxShadow(color: Color(0x40C9A84C), spreadRadius: 3),
        const BoxShadow(
          color: Color(0x80000000),
          blurRadius: 8,
          offset: Offset(0, 3),
        ),
      ],
    ),
    child: numeral == null
        ? _Glyph.draw(glyph, ArcanumColors.goldLight)
        : Text(
            numeral!,
            style: ArcanumText.heading(
              numeral!.length > 2 ? 13 : 15,
              color: ArcanumColors.goldLight,
            ),
          ),
  );
}

class _PartRow extends ConsumerWidget {
  const _PartRow({required this.part});
  final _Part part;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = part;
    return Semantics(
      button: true,
      selected: p.active,
      label: p.label,
      child: InkWell(
        key: p.key,
        onTap: () {
          Scaffold.of(context).closeDrawer();
          p.open(context, ref);
        },
        child: ExcludeSemantics(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: ArcanumSelection.minTapHeight,
            ),
            child: Row(
              children: [
                Transform.translate(
                  offset: const Offset(-4, 0),
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: p.active
                          ? ArcanumColors.gold
                          : ArcanumColors.goldMuted,
                    ),
                  ),
                ),
                const SizedBox(width: 17),
                Expanded(
                  child: Text(
                    p.label,
                    style: ArcanumText.body(
                      17,
                      italic: true,
                      color: p.active
                          ? ArcanumColors.gold
                          : ArcanumColors.ivoryMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// El saldo en pequeno junto a ARCANUM (Samuel, 08-oct: «muy peque»):
/// creditos y Fragmentos, y abre la tienda. Se ve diminuto; se toca en 48.
class _TinyBalance extends ConsumerWidget {
  const _TinyBalance();

  static final _tiny = ArcanumText.body(11, color: ArcanumColors.goldMuted);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final credits = ref.watch(saldoProvider).value?.creditos;
    final fragments = ref.watch(fragmentBalanceProvider).value?.balance;
    if (credits == null && fragments == null) return const SizedBox(height: 48);
    return Semantics(
      button: true,
      label:
          '${credits ?? 0} créditos y ${fragments ?? 0} Fragmentos. '
          'Abrir la tienda.',
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () {
          Scaffold.of(context).closeDrawer();
          context.push('/paywall');
        },
        child: ExcludeSemantics(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: Center(
              // cada cifra con su emblema (Samuel, 08-oct), en pequeno
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (credits != null) ...[
                    const ArcaneCurrencyEmblem(
                      currency: ArcaneCurrency.credit,
                      size: 13,
                    ),
                    const SizedBox(width: 3),
                    Text('$credits', style: _tiny),
                  ],
                  if (credits != null && fragments != null)
                    const SizedBox(width: 9),
                  if (fragments != null) ...[
                    const ArcaneCurrencyEmblem(
                      currency: ArcaneCurrency.fragment,
                      size: 13,
                    ),
                    const SizedBox(width: 3),
                    Text('$fragments', style: _tiny),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
