import 'package:arcanum_app/features/arte/materia_plate_loader.dart';
import 'package:arcanum_app/features/arte/materia_plate_reveal.dart';
import 'package:arcanum_app/shared/widgets/arcanum_mood.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// El asset de una imagen montada.
///
/// Las caras se piden con `cacheWidth`, y eso envuelve el proveedor en un
/// ResizeImage: castear a AssetImage a secas revienta.
String _assetDe(Image imagen) {
  final proveedor = imagen.image;
  final asset = proveedor is ResizeImage ? proveedor.imageProvider : proveedor;
  return (asset as AssetImage).assetName;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('familias del revelado', () {
    test('el elemento del catalogo elige familia, en los dos idiomas', () {
      expect(RevealElement.from('fuego'), RevealElement.fuego);
      expect(RevealElement.from('fire'), RevealElement.fuego);
      expect(RevealElement.from('agua'), RevealElement.agua);
      expect(RevealElement.from('water'), RevealElement.agua);
      expect(RevealElement.from('tierra'), RevealElement.tierra);
      expect(RevealElement.from('earth'), RevealElement.tierra);
      expect(RevealElement.from('aire'), RevealElement.aire);
      expect(RevealElement.from('air'), RevealElement.aire);
    });

    test('lo desconocido, lo vacio y lo ausente caen en aire', () {
      // Una pieza sin elemento no puede quedarse sin revelado: se abriria de
      // golpe y seria la unica del catalogo que no respira.
      expect(RevealElement.from(null), RevealElement.aire);
      expect(RevealElement.from(''), RevealElement.aire);
      expect(RevealElement.from('quintaesencia'), RevealElement.aire);
      expect(RevealElement.from('  Fuego  '), RevealElement.fuego);
    });

    test('son cuatro y no nueve, que es el punto', () {
      expect(RevealElement.values, hasLength(4));
    });
  });

  group('MateriaPlateReveal', () {
    late MateriaPlate ruda;

    setUpAll(() async {
      await MateriaPlates.instance.ensureLoaded();
      ruda = MateriaPlates.instance.resolve('ruda')!;
    });

    Widget montar({required bool revelar, String? element}) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: MateriaPlateReveal(
            plate: ruda,
            mood: ArcanumMood.neutral,
            size: 148,
            element: element,
            revelar: revelar,
            semanticLabel: 'Ruda',
          ),
        ),
      ),
    );

    /// Monta y deja las caras decodificadas.
    ///
    /// El widget no arranca el revelado hasta tener las dos en memoria -- para
    /// que la hoja no abra sobre un hueco -- y con el reloj del test parado
    /// eso no pasa solo: hay que precargar en tiempo real.
    Future<void> abrir(
      WidgetTester tester, {
      required bool revelar,
      String? element,
    }) async {
      await tester.pumpWidget(montar(revelar: revelar, element: element));
      await tester.runAsync(() async {
        for (final cara in [ruda.entonadoPath, ruda.grabadoPath]) {
          await precacheImage(
            AssetImage(cara),
            tester.element(find.byType(MateriaPlateReveal)),
          );
        }
      });
      await tester.pump();
      await tester.pump();
    }

    testWidgets('cerrada ensena una sola cara: la entonada', (tester) async {
      await abrir(tester, revelar: false);

      final imagenes = tester.widgetList<Image>(find.byType(Image)).toList();
      expect(imagenes, hasLength(1));
      expect(_assetDe(imagenes.single), ruda.entonadoPath);
    });

    testWidgets('al abrir entra el grabado sobre la entonada', (tester) async {
      await abrir(tester, revelar: true, element: 'fuego');
      await tester.pump(const Duration(milliseconds: 120));

      final assets = tester
          .widgetList<Image>(find.byType(Image))
          .map(_assetDe)
          .toList();
      // Las dos a la vez: la entonada sigue debajo mientras el grabado se
      // revela. Si desapareciera, la transicion seria un corte.
      expect(assets, containsAll([ruda.entonadoPath, ruda.grabadoPath]));
    });

    testWidgets('fuego ya termino a los 700 ms', (tester) async {
      await abrir(tester, revelar: true, element: 'fuego');
      await tester.pump(const Duration(milliseconds: 700));
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('aire a esa altura sigue disipandose', (tester) async {
      // Casi el doble que fuego: las cuatro familias no comparten curva ni
      // duracion, que es lo que las hace reconocibles sin leer nada.
      await abrir(tester, revelar: true, element: 'aire');
      await tester.pump(const Duration(milliseconds: 700));
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpAndSettle();
    });

    testWidgets('cambiar de elemento cambia la familia sin recrear', (
      tester,
    ) async {
      // La pieza puede cambiar bajo el mismo widget. Si el spec se resolviera
      // una sola vez, la siguiente se abriria con la curva de la anterior.
      await abrir(tester, revelar: true, element: 'fuego');
      await tester.pumpAndSettle();
      await tester.pumpWidget(montar(revelar: false, element: 'aire'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(montar(revelar: true, element: 'aire'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpAndSettle();
    });

    testWidgets('la lamina se anuncia una vez, no dos', (tester) async {
      // Son dos caras de la MISMA pieza: un lector de pantalla que las lea por
      // separado narra dos imagenes donde el usuario ve una.
      await abrir(tester, revelar: true, element: 'agua');
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.bySemanticsLabel('Ruda'), findsOneWidget);
      await tester.pumpAndSettle();
    });
  });
}
