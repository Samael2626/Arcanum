import 'package:arcanum_app/core/api/arcanum_api.dart';
import 'package:arcanum_app/core/auth/auth_controller.dart';
import 'package:arcanum_app/core/crypto/grimoire_crypto.dart';
import 'package:arcanum_app/features/grimorio/grimorio_detail.dart';
import 'package:arcanum_app/features/grimorio/grimorio_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _AuthenticatedAuthNotifier extends AuthNotifier {
  @override
  AuthState build() =>
      const AuthState(AuthStatus.authenticated, {'id': 'user-a'});

  void switchUser(String id) {
    state = AuthState(AuthStatus.authenticated, {'id': id});
  }
}

class _FakeArcanumApi extends ArcanumApi {
  _FakeArcanumApi() : super(Dio());

  Object? listError;
  Object? getError;
  List<Map<String, dynamic>> entries = const [];
  Map<String, dynamic> detail = const {};
  int listCalls = 0;

  @override
  Future<List<Map<String, dynamic>>> grimoireList() async {
    listCalls++;
    if (listError case final error?) throw error;
    return entries;
  }

  @override
  Future<Map<String, dynamic>> grimoireGet(String id) async {
    if (getError case final error?) throw error;
    return detail;
  }
}

class _FakeGrimoireCrypto extends GrimoireCrypto {
  Object? error;
  String plaintext = 'Contenido secreto';

  @override
  Future<String> decryptText(String ciphertextB64, String ivB64) async {
    if (error case final value?) throw value;
    return plaintext;
  }
}

Widget _app(
  Widget child, {
  required _FakeArcanumApi api,
  _FakeGrimoireCrypto? crypto,
}) {
  return ProviderScope(
    overrides: [
      arcanumApiProvider.overrideWithValue(api),
      authProvider.overrideWith(_AuthenticatedAuthNotifier.new),
      if (crypto != null) grimoireCryptoProvider.overrideWithValue(crypto),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  testWidgets('un fallo al listar no se presenta como grimorio vacío', (
    tester,
  ) async {
    final api = _FakeArcanumApi()..listError = Exception('offline');

    await tester.pumpWidget(_app(const GrimorioScreen(), api: api));
    await tester.pump();

    expect(find.text('El grimorio no pudo abrirse'), findsOneWidget);
    expect(find.textContaining('primera palabra'), findsNothing);

    api.listError = null;
    await tester.tap(find.text('Reintentar'));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('primera palabra'), findsOneWidget);
  });

  testWidgets('la hoja muestra la hora planetaria guardada', (tester) async {
    final api = _FakeArcanumApi()
      ..entries = const [
        {
          'id': 'entry-1',
          'entry_type': 'note',
          'title': 'Prueba solar',
          'entry_date': '2026-07-12T15:00:00Z',
          'day_planet': 'sun',
          'planetary_hour': 'venus',
        },
      ];

    await tester.pumpWidget(_app(const GrimorioScreen(), api: api));
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('hora de Venus'), findsOneWidget);
    expect(find.text('hora de Sol'), findsNothing);
  });

  testWidgets('cambiar de cuenta descarta la lista de la sesion anterior', (
    tester,
  ) async {
    final api = _FakeArcanumApi()
      ..entries = const [
        {
          'id': 'entry-a',
          'entry_type': 'note',
          'title': 'Entrada de A',
          'entry_date': '2026-07-12T15:00:00Z',
          'day_planet': 'sun',
        },
      ];
    final container = ProviderContainer(
      overrides: [
        arcanumApiProvider.overrideWithValue(api),
        authProvider.overrideWith(_AuthenticatedAuthNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: GrimorioScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('Entrada de A'), findsOneWidget);

    api.entries = const [
      {
        'id': 'entry-b',
        'entry_type': 'note',
        'title': 'Entrada de B',
        'entry_date': '2026-07-13T15:00:00Z',
        'day_planet': 'moon',
      },
    ];
    (container.read(authProvider.notifier) as _AuthenticatedAuthNotifier)
        .switchUser('user-b');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('Entrada de A'), findsNothing);
    expect(find.text('Entrada de B'), findsOneWidget);
    expect(api.listCalls, 2);
  });

  testWidgets('un fallo de API no se presenta como fallo criptográfico', (
    tester,
  ) async {
    final api = _FakeArcanumApi()..getError = Exception('502');

    await tester.pumpWidget(
      _app(
        const GrimorioDetail(id: 'entry-1'),
        api: api,
        crypto: _FakeGrimoireCrypto(),
      ),
    );
    await tester.pump();

    expect(find.text('No se pudo abrir la entrada'), findsOneWidget);
    expect(find.textContaining('clave de este dispositivo'), findsNothing);
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('un fallo AES conserva el diagnóstico criptográfico', (
    tester,
  ) async {
    final api = _FakeArcanumApi()
      ..detail = const {'encrypted_content': 'ciphertext', 'content_iv': 'iv'};
    final crypto = _FakeGrimoireCrypto()..error = Exception('bad key');

    await tester.pumpWidget(
      _app(
        const GrimorioDetail(id: 'entry-1'),
        api: api,
        crypto: crypto,
      ),
    );
    await tester.pump();

    expect(find.text('El sello resiste'), findsOneWidget);
    expect(find.textContaining('clave de este dispositivo'), findsOneWidget);
    expect(find.text('Reintentar'), findsNothing);
  });
}
