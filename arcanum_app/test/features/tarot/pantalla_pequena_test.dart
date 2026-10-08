// El movil mas pequeño de la prueba cerrada: 360 dp de ancho. La mesa, sus
// paneles y la «Lectura revelada» tienen que caber sin desbordar.
import 'dart:math' as math;

import 'package:arcanum_app/features/tarot/table/table_sound.dart';
import 'package:arcanum_app/features/tarot/table/table_sound_player.dart';
import 'package:arcanum_app/core/api/arcanum_api.dart';
import 'package:arcanum_app/core/auth/auth_controller.dart';
import 'package:arcanum_app/features/tarot/application/table_controller.dart';
import 'package:arcanum_app/features/tarot/domain/table_models.dart';
import 'package:arcanum_app/features/tarot/reading/lectura_revelada.dart';
import 'package:arcanum_app/features/tarot/table/table_director.dart';
import 'package:arcanum_app/features/tarot/table/table_notice.dart';
import 'package:arcanum_app/features/tarot/tarot_screen.dart';
import 'package:arcanum_app/shared/revelado/reveal_pager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

/// 360 x 640 es el peor caso: ancho minimo y alto de un movil de 16:9.
const _small = Size(360, 640);

void _phone(WidgetTester tester, Size size) {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

class _Auth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(AuthStatus.authenticated, {'id': 'u1'});
}

class _Server extends FakeServer {
  @override
  Future<List<Map<String, dynamic>>> tarotDecks() async => [
    {
      'slug': 'rws',
      'name': 'Rider–Waite–Smith',
      'description': '',
      'allow_reversed': true,
      'art': 'rws',
      'card_count': 78,
    },
  ];

  @override
  Future<List<Map<String, dynamic>>> tarotSpreads() async => [];

  @override
  Future<List<Map<String, dynamic>>> tarotReadings({int limit = 20}) async => [
    for (var i = 0; i < 12; i++)
      {
        'spread_type': 'free',
        'created_at': '2026-10-02T21:14:00Z',
        'question': '¿Qué pasará con este trabajo que me tiene tan cansado?',
        'table_snapshot': {'x': 1},
      },
  ];
}

/// Cruz Celta con textos largos: lo mas que tiene que caber.
Interpretation _celtic() {
  const long =
      'Lo que tenía que caer se resiste. El derrumbe se vive por dentro o se '
      'aplaza, y cuanto más se sostiene, más cuesta. La carta pide soltar la '
      'estructura que ya no sostiene nada antes de que caiga sola, y mirar qué '
      'queda en pie cuando el polvo se asienta. No es castigo: es despeje.';
  const slugs = [
    'la-torre',
    'cinco-de-copas',
    'la-emperatriz',
    'as-de-espadas',
    'el-sol',
    'la-luna',
    'reina-de-oros',
    'diez-de-bastos',
    'el-colgado',
    'el-mundo',
  ];
  return Interpretation.fromJson({
    'spread': 'celtic_cross',
    'spread_name': 'Cruz Celta',
    'question': '¿Qué pasará con este trabajo que me tiene tan cansado?',
    'moon_phase': 'Luna creciente',
    'moon_illumination': .63,
    'planetary_hour': 'Venus',
    'read_at': '2026-10-02T21:14:00Z',
    'cards': [
      for (var i = 0; i < 10; i++)
        {
          'slug': slugs[i],
          'name_es': 'Lo que corona (posible futuro) ${i + 1}',
          'arcana': 'major',
          'reversed': i.isOdd,
          'slot': i,
          'position': 'Lo que corona (posible futuro)',
          'position_meaning': 'Lo mejor que puede salir de todo esto.',
          'meaning': long,
        },
    ],
  });
}

final _cross = SpreadDef.fromJson({
  'slug': 'celtic_cross',
  'name': 'Cruz Celta',
  'card_scale': .56,
  'label_mode': 'number',
  'slots': [
    for (final s in [
      [.34, .5, 0],
      [.34, .5, 90],
      [.34, .8, 0],
      [.13, .5, 0],
      [.34, .2, 0],
      [.55, .5, 0],
      [.86, .87, 0],
      [.86, .62, 0],
      [.86, .38, 0],
      [.86, .13, 0],
    ])
      {'x': s[0], 'y': s[1], 'rotation': s[2], 'name': 'Hueco', 'meaning': 'x'},
  ],
});

Future<void> _frames(WidgetTester tester, [int n = 30]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  for (final size in [_small, const Size(360, 740)]) {
    testWidgets('la lectura de una Cruz Celta cabe en ${size.width.toInt()}x'
        '${size.height.toInt()}', (tester) async {
      _phone(tester, size);
      await tester.pumpWidget(
        MaterialApp(
          home: LecturaRevelada(
            reading: _celtic(),
            spread: _cross,
            onCloseCircle: () {},
            onBack: () {},
          ),
        ),
      );
      await _frames(tester);
      // con texto largo, un deslizamiento lee hasta el final y el siguiente
      // pasa de carta: nunca se queda atascada
      var flings = 0;
      while (find.text('Síntesis').evaluate().isEmpty) {
        expect(tester.takeException(), isNull, reason: 'deslizamiento $flings');
        expect(flings, lessThan(30), reason: 'no llega a la síntesis');
        await tester.fling(find.byType(PageView), const Offset(0, -500), 2000);
        await _frames(tester);
        flings++;
      }
      expect(tester.takeException(), isNull, reason: 'sintesis');
      // el boton de cerrar el circulo se puede alcanzar en la sintesis
      final hold = find.byType(HoldToConfirm);
      await tester.ensureVisible(hold);
      await _frames(tester, 5);
      final r = tester.getRect(hold);
      expect(r.bottom, lessThanOrEqualTo(size.height));
      expect(r.left, greaterThanOrEqualTo(0));
      expect(r.right, lessThanOrEqualTo(size.width));
    });
  }

  testWidgets('la mesa y sus paneles caben en 360x640', (tester) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    _phone(tester, _small);
    final c = ProviderContainer(
      overrides: [
        tableSoundPlayerProvider.overrideWithValue(const SilentPlayer()),
        arcanumApiProvider.overrideWithValue(_Server()),
        authProvider.overrideWith(_Auth.new),
      ],
    );
    addTearDown(c.dispose);
    await tester.runAsync(() => c.read(tableControllerProvider.future));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: TarotTableScreen()),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await _frames(tester, 20);
    expect(tester.takeException(), isNull, reason: 'mesa con la ayuda');
    if (find.text('Entendido').evaluate().isNotEmpty) {
      await tester.tap(find.text('Entendido'));
      await _frames(tester, 20);
    }
    expect(tester.takeException(), isNull, reason: 'mesa');

    // las lecturas guardadas, con muchas filas, desde el radial del paño
    const start = Offset(180, 260);
    final g = await tester.startGesture(start);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 480)),
    );
    await _frames(tester, 2);
    // orden fijo: Sellar pregunta, Recoger todo, Lecturas, Silenciar
    const angle = -math.pi / 2 + 2 * 2 * math.pi / 4;
    await g.moveTo(start + Offset(math.cos(angle), math.sin(angle)) * 90);
    await tester.pump();
    await g.up();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await _frames(tester, 10);
    expect(find.text('LECTURAS GUARDADAS'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'panel de lecturas');
    final panel = tester.getRect(
      find
          .ancestor(
            of: find.text('LECTURAS GUARDADAS'),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(panel.left, greaterThanOrEqualTo(0));
    expect(panel.right, lessThanOrEqualTo(_small.width));
    expect(panel.bottom, lessThanOrEqualTo(_small.height));
  });

  testWidgets('los avisos no tapan deshacer ni «Elegir carta»', (tester) async {
    // GN2200: el aviso de 2,6 s tapaba el deshacer, que solo dura 5 s
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    _phone(tester, _small);
    final c = ProviderContainer(
      overrides: [
        tableSoundPlayerProvider.overrideWithValue(const SilentPlayer()),
        arcanumApiProvider.overrideWithValue(_Server()),
        authProvider.overrideWith(_Auth.new),
      ],
    );
    addTearDown(c.dispose);
    await tester.runAsync(() => c.read(tableControllerProvider.future));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: TarotTableScreen()),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await _frames(tester, 20);
    final effects = tester.state(find.byType(TarotTableScreen)) as TableEffects;
    // los tres tipos de aviso, y la burbuja de una pieza pegada abajo, que es
    // la que mas cerca cae de los botones
    final cases = <String, void Function()>{
      'pildora': () => effects.toast('Deshecho'),
      'bordado': () =>
          effects.toast('Tirada completa', kind: NoticeKind.embroidery),
      'pieza': () => effects.toast(
        '3 · Futuro',
        kind: NoticeKind.piece,
        at: const Offset(300, 880),
      ),
    };
    for (final MapEntry(:key, :value) in cases.entries) {
      value();
      await _frames(tester, 20);
      final text = {
        'pildora': 'Deshecho',
        'bordado': 'Tirada completa',
        'pieza': '3 · Futuro',
      }[key]!;
      final r = tester.getRect(find.text(text));
      // deshacer y «Elegir carta»: 48 dp con 14 de margen, pegados abajo
      expect(
        r.bottom,
        lessThanOrEqualTo(_small.height - (14 + 48 + 14)),
        reason: key,
      );
      expect(r.left, greaterThanOrEqualTo(0), reason: key);
      expect(r.right, lessThanOrEqualTo(_small.width), reason: key);
    }
  });
}
