// Luz de la Luna sobre la mesa y su fase en la cabecera (especificacion §6).
import 'package:arcanum_app/features/tarot/table/table_sound.dart';
import 'package:arcanum_app/features/tarot/table/table_sound_player.dart';
import 'package:arcanum_app/core/api/arcanum_api.dart';
import 'package:arcanum_app/core/auth/auth_controller.dart';
import 'package:arcanum_app/features/tarot/application/table_controller.dart';
import 'package:arcanum_app/features/tarot/domain/table_models.dart';
import 'package:arcanum_app/features/tarot/table/table_moon.dart';
import 'package:arcanum_app/features/tarot/tarot_screen.dart';
import 'package:arcanum_app/shared/widgets/moon_disc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

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
}

Interpretation reading({double? f, String? phase}) => Interpretation.fromJson({
  'session_id': 's',
  'spread': 'one_card',
  'spread_name': 'Una carta',
  'cards': const [],
  'moon_illumination': f,
  'moon_phase': phase,
});

void main() {
  group('que Luna manda', () {
    final now = TableMoon.fromApi(const {
      'illumination': .2,
      'is_waxing': false,
      'phase_name': 'Menguante',
    })!;

    test('sin lectura, la de ahora', () {
      expect(tableMoonFor(null, now), same(now));
      expect(now.ofReading, isFalse);
      expect(now.info, 'Menguante · 20 %. La luz de la mesa sigue a la Luna.');
    });

    test('con lectura interpretada, la de la lectura', () {
      final m = tableMoonFor(reading(f: .97, phase: 'Luna llena'), now)!;
      expect(m.illumination, .97);
      expect(m.ofReading, isTrue);
      expect(m.info, endsWith('sigue a la Luna de esta lectura.'));
    });

    test('si la lectura no trae Luna, la de ahora', () {
      expect(tableMoonFor(reading(), now), same(now));
    });

    test('creciente o menguante se lee del nombre de la fase', () {
      expect(
        TableMoon.fromReading(
          reading(f: .4, phase: 'Cuarto menguante'),
        )!.waxing,
        isFalse,
      );
      expect(
        TableMoon.fromReading(
          reading(f: .4, phase: 'Cuarto creciente'),
        )!.waxing,
        isTrue,
      );
    });

    test('sin iluminacion no hay Luna', () {
      expect(TableMoon.fromApi(const {'phase_name': 'x'}), isNull);
    });
  });

  group('la luz', () {
    test('llena: plata desde arriba y sin velo; nueva: velo y sin plata', () {
      final full = MoonlightPainter(1), nuevo = MoonlightPainter(0);
      expect((full.silver, full.veil), (.2, 0));
      expect(nuevo.silver, 0);
      expect(nuevo.veil, closeTo(.34, 1e-9));
      final half = MoonlightPainter(.5);
      expect((half.silver, half.veil), (.1, .17));
    });

    Future<void> pumpLayer(
      WidgetTester tester,
      double f, {
      bool still = false,
    }) => tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(disableAnimations: still),
        child: MoonlightLayer(illumination: f),
      ),
    );

    double shown(WidgetTester tester) => tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<MoonlightPainter>()
        .single
        .illumination;

    testWidgets('cambia con un fundido de 2,5 s y despues no pide fotogramas', (
      tester,
    ) async {
      await pumpLayer(tester, .2);
      expect(shown(tester), .2);
      await pumpLayer(tester, 1);
      await tester.pump(const Duration(milliseconds: 1250));
      expect(shown(tester), inExclusiveRange(.2, 1));
      await tester.pump(const Duration(milliseconds: 1300));
      expect(shown(tester), 1);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('con «reducir movimiento» cambia de golpe', (tester) async {
      await pumpLayer(tester, .2, still: true);
      await pumpLayer(tester, 1, still: true);
      await tester.pump();
      expect(shown(tester), 1);
    });
  });

  testWidgets('en la pantalla: luz de la Luna de ahora y su fase junto a la '
      'ayuda; tocarla la dice', (tester) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    tester.view
      ..physicalSize = const Size(360, 760)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = ProviderContainer(
      overrides: [
        tableSoundPlayerProvider.overrideWithValue(const SilentPlayer()),
        arcanumApiProvider.overrideWithValue(_Server()),
        authProvider.overrideWith(_Auth.new),
      ],
    );
    addTearDown(c.dispose);
    await tester.runAsync(() => c.read(tableControllerProvider.future));
    tester.view
      ..physicalSize = const Size(360, 760)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: TarotTableScreen()),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    if (find.text('Entendido').evaluate().isNotEmpty) {
      await tester.tap(find.text('Entendido'));
      await tester.pump(const Duration(seconds: 1));
    }
    final disc = tester.widget<MoonDisc>(find.byType(MoonDisc));
    expect((disc.illumination, disc.waxing), (.63, true));
    expect(
      find.bySemanticsLabel(RegExp('Gibosa creciente.*63.*iluminada')),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byType(MoonBadge)).height,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester.widget<MoonlightLayer>(find.byType(MoonlightLayer)).illumination,
      .63,
    );
    await tester.tap(find.byType(MoonBadge));
    await tester.pump();
    expect(
      find.text('Gibosa creciente · 63 %. La luz de la mesa sigue a la Luna.'),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 4));
  });
}
