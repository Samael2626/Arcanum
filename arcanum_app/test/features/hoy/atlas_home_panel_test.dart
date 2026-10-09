import 'package:arcanum_app/core/content/sections.dart';
import 'package:arcanum_app/core/theme/arcanum_theme.dart';
import 'package:arcanum_app/features/hoy/presentation/widgets/atlas_home_panel.dart';
import 'package:arcanum_app/features/hoy/presentation/widgets/reliquary_fx.dart';
import 'package:arcanum_app/features/hoy/presentation/widgets/zodiaco_laminas.g.dart';
import 'package:arcanum_app/shared/widgets/moon_disc.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Los mosaicos de la portada, desde el 07-oct-2026 la entrada a las
/// secciones, y desde el 08-oct con la forma del «Atlas de reliquias» (E).
/// Heredan lo que vigilaba el cajon cuando las listaba: que esten todas, que
/// cada una abra la suya y que ninguna baje de 48 de alto. Y lo que Samuel
/// odiaba de la version anterior: texto montado sobre la carta y la misma
/// carta en dos placas.
///
/// Se monta el panel suelto porque aqui se puede elegir `showTable`. El viaje
/// real por el router lo prueba `navegacion/cajon_navegacion_test.dart`.
/// Ruta del arte de una imagen; `cacheWidth` la envuelve en un ResizeImage.
String? _asset(Image i) {
  final p = i.image;
  final inner = p is ResizeImage ? p.imageProvider : p;
  return inner is AssetImage ? inner.assetName : null;
}

void main() {
  // Con la letra real y no con Ahem (cuadros de un cuerpo de ancho): lo que se
  // mide aqui es si un titulo cabe o pisa una carta, y eso depende de la letra.
  setUpAll(() async {
    for (final (familia, ruta) in [
      ('Cormorant Garamond', 'assets/fonts/CormorantGaramond-600.ttf'),
      ('Crimson Pro', 'assets/fonts/CrimsonPro-400.ttf'),
    ]) {
      final cargador = FontLoader(
        familia,
      )..addFont(File(ruta).readAsBytes().then((b) => ByteData.view(b.buffer)));
      await cargador.load();
    }
  });

  const moon = {
    'phase_name': 'Gibosa creciente',
    'illumination': 0.62,
    'is_waxing': true,
  };

  Future<List<String>> montar(
    WidgetTester t, {
    required bool showTable,
    double width = 411,
    String? tableCard,
    bool reposo = false,
    double letra = 1,
  }) async {
    t.view
      ..physicalSize = Size(width * 3, 2745)
      ..devicePixelRatio = 3.0;
    addTearDown(t.view.reset);
    t.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: reposo);
    addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
    t.platformDispatcher.textScaleFactorTestValue = letra;
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    final abiertos = <String>[];
    await t.pumpWidget(
      MaterialApp(
        theme: buildArcanumTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: AtlasHomePanel(
              moon: moon,
              observedAt: DateTime(2026, 10, 6, 21, 30),
              dayRuler: 'mars',
              hour: const {'planet': 'mars', 'is_daytime': false},
              tableCard: tableCard,
              showTable: showTable,
              onMoonTap: () => abiertos.add('luna'),
              onHoroscope: () => abiertos.add('/horoscopo'),
              onGrimoire: () => abiertos.add('/grimorio'),
              onSaber: () => abiertos.add('/saber'),
              onTable: () => abiertos.add('/tarot'),
              onOracle: () => abiertos.add('/oraculo'),
              onSigil: () => abiertos.add('taller'),
              onBreathe: () => abiertos.add('/respirar'),
              onChart: () => abiertos.add('carta'),
              onToday: () => abiertos.add('hoy'),
            ),
          ),
        ),
      ),
    );
    await t.pump();
    return abiertos;
  }

  Future<void> tocar(WidgetTester t, Key key) async {
    await t.ensureVisible(find.byKey(key));
    await t.pump();
    await t.tap(find.byKey(key));
    await t.pump();
  }

  // Lo que era "cada fila del cajon lleva a una rama que existe": cada placa
  // abre la ruta de SU seccion, y esas rutas son las de `arcanumSections`.
  testWidgets('cada mosaico abre la ruta de su sección', (t) async {
    final abiertos = await montar(t, showTable: false);
    final rutas = {for (final s in arcanumSections) s.route};

    for (final (key, ruta) in [
      (const Key('atlas-horoscopo'), '/horoscopo'),
      (const Key('atlas-grimorio'), '/grimorio'),
      (const Key('atlas-saber'), '/saber'),
      (const Key('atlas-oraculo'), '/oraculo'),
    ]) {
      await tocar(t, key);
      expect(abiertos.last, ruta, reason: '$key abrio otra cosa');
      expect(rutas, contains(ruta), reason: '$ruta no es una seccion');
    }
    await tocar(t, const Key('atlas-cielo'));
    expect(abiertos.last, 'luna');
  });

  testWidgets('la portada nombra las cinco secciones', (t) async {
    await montar(t, showTable: false);
    // Cielo es la portada misma: su placa es el cielo vivo.
    expect(find.byKey(const Key('atlas-cielo')), findsOneWidget);
    for (final s in arcanumSections.skip(1)) {
      expect(find.text(s.title), findsOneWidget, reason: s.title);
    }
  });

  testWidgets('con la mesa, su placa se suma y el Oráculo sigue', (t) async {
    // 07-oct: la mesa sustituia al Oraculo y este se quedaba sin entrada
    final abiertos = await montar(t, showTable: true);
    await tocar(t, const Key('atlas-mesa'));
    expect(abiertos.last, '/tarot');
    await tocar(t, const Key('atlas-oraculo'));
    expect(abiertos.last, '/oraculo');
  });

  testWidgets('el cielo vivo dice el día y la hora reales', (t) async {
    await montar(t, showTable: true);
    // 06-oct-2026 fue martes; hora de Marte del dato, no inventada
    expect(find.text('MARTES · HORA DE MARTE'), findsOneWidget);
    expect(
      find.textContaining('Gibosa creciente: la Luna crece'),
      findsOneWidget,
    );
  });

  group('las cartas', () {
    List<String> cartas(WidgetTester t) => [
      for (final i in t.widgetList<Image>(find.byType(Image)))
        if (_asset(i)?.startsWith('assets/tarot/') ?? false) _asset(i)!,
    ];

    testWidgets('dos placas nunca enseñan la misma', (t) async {
      for (final ultima in [null, 'el-sol', AtlasHomePanel.oracleCard]) {
        await montar(t, showTable: true, tableCard: ultima);
        final vistas = cartas(t);
        expect(vistas.length, 2, reason: '$vistas');
        expect(vistas.toSet().length, 2, reason: 'repetida: $vistas');
      }
    });

    testWidgets('la Mesa enseña la carta de la última tirada', (t) async {
      await montar(t, showTable: true, tableCard: 'el-sol');
      expect(cartas(t), contains('assets/tarot/el-sol.webp'));
      expect(find.text('Tu última tirada te espera'), findsOneWidget);
    });

    // Samuel, 08-oct: «Mesa de tarot» pisado por La Luna
    for (final width in [411.0, 360.0, 320.0]) {
      testWidgets('ningún texto se monta sobre una carta a $width', (t) async {
        await montar(t, showTable: true, width: width);
        final arte = [
          for (final e in find.byType(Image).evaluate())
            if (_asset(e.widget as Image)?.startsWith('assets/tarot/') ?? false)
              t.getRect(find.byWidget(e.widget)),
        ];
        for (final texto in [
          'Mesa de tarot',
          'Baraja, tira y desvela con tus manos',
          'Oráculo',
          'Pregunta o estudia',
        ]) {
          final r = t.getRect(find.text(texto));
          for (final a in arte) {
            // la carta va girada: su caja es algo mas ancha que el dibujo
            expect(
              r.overlaps(a.deflate(6)),
              isFalse,
              reason: '$width: «$texto» $r sobre $a',
            );
          }
        }
        expect(t.takeException(), isNull);
      });
    }
  });

  testWidgets('el grabado del cielo vivo es el domicilio del regente', (
    t,
  ) async {
    // Marte de noche: Escorpio; el horoscopo no repite lamina
    expect(reliquarySign('mars', isDay: false), Signo.escorpio);
    expect(reliquarySign('mars', isDay: true), Signo.aries);
    expect(
      reliquarySign('mars', isDay: false, avoid: Signo.escorpio),
      Signo.aries,
    );
    expect(reliquarySign('sun', isDay: true, avoid: Signo.leo), Signo.aries);
    expect(reliquarySign(null, isDay: true), Signo.cancer);
  });

  // La regla de los 48 que vigilaba las filas del cajon, en los mosaicos, y
  // tambien en pantalla estrecha y con letra grande, donde se apilan.
  for (final (width, letra) in [(411.0, 1.0), (320.0, 1.0), (360.0, 1.6)]) {
    testWidgets('ningún mosaico baja de 48 ni desborda ($width, x$letra)', (
      t,
    ) async {
      await montar(t, showTable: true, width: width, letra: letra);
      for (final key in [
        'atlas-cielo',
        'atlas-mesa',
        'atlas-oraculo',
        'atlas-horoscopo',
        'atlas-grimorio',
        'atlas-saber',
        'atlas-respirar',
        'atlas-tu-carta',
        'atlas-sigilo',
        'atlas-hoy',
      ]) {
        final size = t.getSize(find.byKey(Key(key)));
        expect(size.height, greaterThanOrEqualTo(48), reason: key);
        expect(size.width, greaterThanOrEqualTo(48), reason: key);
      }
      // las placas llenan el ancho util: nada de hueco a la derecha
      final panel = t.getRect(find.byType(AtlasHomePanel));
      for (final key in ['atlas-cielo', 'atlas-mesa', 'atlas-horoscopo']) {
        expect(t.getRect(find.byKey(Key(key))).width, panel.width, reason: key);
      }
      expect(t.takeException(), isNull, reason: 'algo se desbordo');
    });
  }

  // Samuel, 08-oct: «Mesa de tarot» en UNA linea a 390 dp, sin pisar la carta
  testWidgets('a 390 «Mesa de tarot» cabe en una línea', (t) async {
    await montar(t, showTable: true, width: 390);
    final titulo = t.getSize(find.text('Mesa de tarot'));
    expect(titulo.height, lessThan(36 * 1.5), reason: '$titulo');
  });

  testWidgets('«Tu carta» y «Hoy →» llevan a lo suyo', (t) async {
    final abiertos = await montar(t, showTable: true);
    await tocar(t, const Key('atlas-tu-carta'));
    expect(abiertos, ['carta']);
    await tocar(t, const Key('atlas-hoy'));
    expect(abiertos.last, 'hoy');
  });

  // Vidrio SELECTIVO: solo el cielo vivo y la Mesa desenfocan.
  testWidgets('solo dos placas llevan vidrio', (t) async {
    await montar(t, showTable: true);
    expect(find.byType(BackdropFilter), findsNWidgets(2));
  });

  // Movimiento reducido: ni ticker ni destellos.
  testWidgets('en reposo no queda nada animándose', (t) async {
    await montar(t, showTable: true, reposo: true);
    await t.pumpAndSettle();
    expect(t.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('con vida, la portada se mueve', (t) async {
    ReliquaryClock.ambientMotion = true;
    addTearDown(() => ReliquaryClock.ambientMotion = false);
    await montar(t, showTable: true);
    await t.pump(const Duration(seconds: 1));
    expect(t.binding.hasScheduledFrame, isTrue);
  });

  // Samuel, 07-oct (opcion B): el taller de letras entra por la placa del
  // Grimorio, donde se guardan los sigilos. Boton propio: tocarlo no abre el
  // Grimorio, y tocar la placa no abre el taller.
  group('«+ Sigilo» en la placa del Grimorio', () {
    for (final width in [411.0, 320.0]) {
      testWidgets('abre el taller, no el Grimorio, a $width de ancho', (
        t,
      ) async {
        final abiertos = await montar(t, showTable: true, width: width);
        await tocar(t, const Key('atlas-sigilo'));
        expect(abiertos, ['taller']);
        await tocar(t, const Key('atlas-grimorio'));
        expect(abiertos.last, '/grimorio');
      });
    }

    testWidgets('el lector de pantalla lo nombra aparte', (t) async {
      final handle = t.ensureSemantics();
      await montar(t, showTable: false);
      expect(
        find.bySemanticsLabel('Crear un sigilo de letras'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('no se monta sobre el título', (t) async {
      await montar(t, showTable: true, width: 320);
      final chip = t.getRect(find.byKey(const Key('atlas-sigilo')));
      final title = t.getRect(find.text('Grimorio'));
      expect(chip.overlaps(title), isFalse, reason: '$chip sobre $title');
    });
  });

  // Samuel, 07-oct: el motor de respiracion vive en el cielo vivo, la placa
  // del ahora. Boton propio, como «+ Sigilo».
  group('«Respirar» en el cielo vivo', () {
    testWidgets('abre la respiracion, no la Luna', (t) async {
      final abiertos = await montar(t, showTable: false);
      await tocar(t, const Key('atlas-respirar'));
      expect(abiertos, ['/respirar']);
      await tocar(t, const Key('atlas-cielo'));
      expect(abiertos.last, 'luna');
    });

    testWidgets('ni él ni el texto se montan sobre la Luna', (t) async {
      for (final width in [411.0, 320.0]) {
        await montar(t, showTable: false, width: width);
        final moonRect = t.getRect(find.byType(MoonDisc));
        for (final f in [
          find.byKey(const Key('atlas-respirar')),
          find.byKey(const Key('atlas-tu-carta')),
          find.textContaining('la Luna crece'),
        ]) {
          final r = t.getRect(f);
          expect(r.overlaps(moonRect), isFalse, reason: '$width: $r');
        }
      }
    });

    testWidgets('el lector de pantalla lo nombra aparte', (t) async {
      final handle = t.ensureSemantics();
      await montar(t, showTable: false, width: 320);
      expect(
        find.bySemanticsLabel('Abrir la práctica de respiración'),
        findsOneWidget,
      );
      handle.dispose();
    });
  });
}
