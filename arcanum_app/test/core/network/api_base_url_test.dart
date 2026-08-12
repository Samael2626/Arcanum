import 'package:arcanum_app/core/network/dio_client.dart';
import 'package:flutter_test/flutter_test.dart';

/// El override de backend local existe para poder probar la app contra un
/// servidor de pruebas en el movil. Es exactamente el tipo de ayuda de
/// desarrollo que, si se cuela en una compilacion de tienda, publica la app
/// contra el servidor equivocado sin que nadie lo note.
void main() {
  group('sin override', () {
    test('el destino por defecto es Railway por HTTPS', () {
      expect(resolveBaseUrl(override: '', debug: true), kProductionBaseUrl);
      expect(resolveBaseUrl(override: '', debug: false), kProductionBaseUrl);
      expect(kProductionBaseUrl, startsWith('https://'));
    });

    test('un override en blanco no cuenta como override', () {
      // Un define mal pasado llega como cadena vacia o con espacios: eso es
      // "no hay override", no "apunta a ninguna parte".
      expect(resolveBaseUrl(override: '   ', debug: true), kProductionBaseUrl);
    });

    test('la app compilada sin define apunta a produccion', () {
      // kBaseUrl es lo que usa Dio de verdad. En la suite no hay dart-define,
      // asi que este test caza cualquier cambio que altere el destino real.
      expect(kBaseUrl, kProductionBaseUrl);
      expect(kApiBaseUrlOverride, isEmpty);
    });
  });

  group('con override explicito', () {
    const local = 'http://127.0.0.1:8000';

    test('en debug se respeta el backend local', () {
      expect(resolveBaseUrl(override: local, debug: true), local);
    });

    test('en release se IGNORA y se mantiene produccion', () {
      // Aunque alguien pase el define a una build de release.
      expect(resolveBaseUrl(override: local, debug: false), kProductionBaseUrl);
    });

    test('en release tampoco se acepta otro HTTPS', () {
      // No es solo cuestion de cleartext: en release no se cambia de servidor.
      expect(
        resolveBaseUrl(override: 'https://otro-servidor.example', debug: false),
        kProductionBaseUrl,
      );
    });

    test('se recortan los espacios del define', () {
      expect(resolveBaseUrl(override: ' $local ', debug: true), local);
    });
  });
}
