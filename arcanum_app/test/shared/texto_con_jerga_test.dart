// La lectura se pinta entera aunque se parta para subrayar.
//
// El riesgo de este widget no es que no subraye: es que al trocear el texto se
// coma un pedazo, o que deje vivos los reconocedores de gestos de la lectura
// anterior. Los dos casos estan aqui.
import 'package:arcanum_app/core/theme/arcanum_theme.dart';
import 'package:arcanum_app/shared/widgets/texto_con_jerga.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _conJerga =
    'La obra del hod terrestre marcó tu pasado. Hoy tu Venus natal lo nota, y '
    'el Caballero de Copas entra de golpe.';

const _sinJerga =
    'Estás soltando la urgencia de probarte con la seguridad que ya no te '
    'enseña. Enciende una vela blanca al anochecer.';

Future<void> _pinta(WidgetTester tester, String texto) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildArcanumTheme(),
      home: Scaffold(body: SingleChildScrollView(child: TextoConJerga(texto))),
    ),
  );
  await tester.pump();
}

/// Todo el texto que el widget pinta, juntando los trozos del `Text.rich`.
///
/// `includeSemanticsLabels: false` NO es un detalle: por defecto `toPlainText`
/// devuelve la etiqueta de accesibilidad en lugar del texto, asi que la
/// primera version de este test leia "hod, toca para saber que significa" y
/// acusaba al widget de comerse la lectura. El widget estaba bien; lo que
/// media mal era el test.
String _pintado(WidgetTester tester) {
  final t = tester.widget<Text>(find.byType(Text).first);
  return t.textSpan?.toPlainText(includeSemanticsLabels: false) ?? t.data ?? '';
}

void main() {
  testWidgets('no se come ni un caracter al trocear el texto', (tester) async {
    // Si un indice se descuadra, el usuario pierde un pedazo de su lectura y
    // nadie se entera. Por eso se compara el texto ENTERO.
    await _pinta(tester, _conJerga);
    expect(_pintado(tester), _conJerga);
  });

  testWidgets('sin jerga pinta un Text normal y no falla', (tester) async {
    await _pinta(tester, _sinJerga);
    expect(_pintado(tester), _sinJerga);
  });

  testWidgets('los terminos con ficha quedan subrayados y los demas no', (
    tester,
  ) async {
    await _pinta(tester, _conJerga);
    final span = tester.widget<Text>(find.byType(Text).first).textSpan!;

    final subrayados = <String>[];
    span.visitChildren((hijo) {
      if (hijo is TextSpan &&
          hijo.style?.decoration == TextDecoration.underline &&
          (hijo.text ?? '').isNotEmpty) {
        subrayados.add(hijo.text!);
      }
      return true;
    });

    expect(subrayados, containsAll(<String>['hod', 'natal', 'Caballero']));
    expect(
      subrayados.any((s) => s.contains('marcó')),
      isFalse,
      reason: 'se subrayó texto corriente',
    );
  });

  testWidgets('tocar un termino abre su hoja', (tester) async {
    await _pinta(tester, _conJerga);
    final span = tester.widget<Text>(find.byType(Text).first).textSpan!;

    TapGestureRecognizerHolder? encontrado;
    span.visitChildren((hijo) {
      if (hijo is TextSpan && hijo.text == 'hod' && hijo.recognizer != null) {
        encontrado = TapGestureRecognizerHolder(hijo);
      }
      return true;
    });
    expect(encontrado, isNotNull, reason: 'el término no es tocable');

    encontrado!.disparar();
    await tester.pumpAndSettle();

    // La hoja del glosario: título en dorado y sus dos apartados.
    expect(find.text('Hod'), findsOneWidget);
    expect(find.text('QUÉ APORTA EN LA CARTA'), findsOneWidget);
  });

  testWidgets('al cambiar de lectura no se quedan vivos los gestos viejos', (
    tester,
  ) async {
    // Un TapGestureRecognizer sin liberar es una fuga silenciosa: la app no
    // falla, solo va acumulando. Si `dispose` no se llamara, el framework
    // protesta al terminar el test.
    await _pinta(tester, _conJerga);
    await _pinta(tester, _sinJerga);
    await _pinta(tester, _conJerga);
    expect(_pintado(tester), _conJerga);
  });
}

/// Envoltorio minimo para disparar el onTap de un span sin simular el toque
/// sobre coordenadas, que en un parrafo largo es fragil.
class TapGestureRecognizerHolder {
  final TextSpan span;
  TapGestureRecognizerHolder(this.span);
  void disparar() {
    final r = span.recognizer;
    if (r is TapGestureRecognizer) r.onTap?.call();
  }
}
