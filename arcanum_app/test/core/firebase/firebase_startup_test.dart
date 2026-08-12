import 'package:arcanum_app/core/firebase/firebase_startup.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

/// Doble de FirebaseApp: la clase real no es instanciable en un test puro.
class _FakeApp implements FirebaseApp {
  _FakeApp(this.name);

  @override
  final String name;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _options = FirebaseOptions(
  apiKey: 'test-key',
  appId: 'test-app',
  messagingSenderId: 'test-sender',
  projectId: 'test-project',
);

void main() {
  test('si [DEFAULT] ya existe, la reutiliza y no inicializa', () async {
    final existing = _FakeApp('[DEFAULT]');
    var initializeCalls = 0;

    final app = await ensureFirebaseInitialized(
      options: _options,
      lookup: () => existing,
      initialize: ({FirebaseOptions? options}) async {
        initializeCalls++;
        return _FakeApp('otra');
      },
    );

    expect(app, same(existing));
    expect(initializeCalls, 0,
        reason: 'volver a inicializar es lo que provocaba duplicate-app');
  });

  test('si no hay app, inicializa con las opciones dadas', () async {
    final created = _FakeApp('[DEFAULT]');
    FirebaseOptions? recibidas;

    final app = await ensureFirebaseInitialized(
      options: _options,
      lookup: () => throw FirebaseException(plugin: 'core', code: 'no-app'),
      initialize: ({FirebaseOptions? options}) async {
        recibidas = options;
        return created;
      },
    );

    expect(app, same(created));
    expect(recibidas, same(_options));
  });

  test('ante duplicate-app recupera la app existente', () async {
    final existing = _FakeApp('[DEFAULT]');
    var lookups = 0;

    final app = await ensureFirebaseInitialized(
      options: _options,
      lookup: () {
        lookups++;
        // Primera consulta: aun no existe. Segunda: la creo otra ruta.
        if (lookups == 1) {
          throw FirebaseException(plugin: 'core', code: 'no-app');
        }
        return existing;
      },
      initialize: ({FirebaseOptions? options}) async =>
          throw FirebaseException(plugin: 'core', code: 'duplicate-app'),
    );

    expect(app, same(existing));
    expect(lookups, 2);
  });

  test('un error distinto se relanza, no se traga', () async {
    expect(
      () => ensureFirebaseInitialized(
        options: _options,
        lookup: () => throw FirebaseException(plugin: 'core', code: 'no-app'),
        initialize: ({FirebaseOptions? options}) async =>
            throw FirebaseException(plugin: 'core', code: 'invalid-api-key'),
      ),
      throwsA(isA<FirebaseException>()
          .having((e) => e.code, 'code', 'invalid-api-key')),
    );
  });

  test('un fallo de lookup que no sea no-app se relanza', () async {
    expect(
      () => ensureFirebaseInitialized(
        options: _options,
        lookup: () => throw FirebaseException(plugin: 'core', code: 'unknown'),
        initialize: ({FirebaseOptions? options}) async => _FakeApp('[DEFAULT]'),
      ),
      throwsA(isA<FirebaseException>().having((e) => e.code, 'code', 'unknown')),
    );
  });
}
