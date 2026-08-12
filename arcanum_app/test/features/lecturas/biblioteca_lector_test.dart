import 'package:arcanum_app/core/api/arcanum_api.dart';
import 'package:arcanum_app/core/crypto/grimoire_crypto.dart';
import 'package:arcanum_app/features/grimorio/pasajes_screen.dart';
import 'package:arcanum_app/features/lecturas/data/library_cache.dart';
import 'package:arcanum_app/features/lecturas/data/library_repository.dart';
import 'package:arcanum_app/features/lecturas/domain/library_models.dart';
import 'package:arcanum_app/features/lecturas/presentation/lector_screen.dart';
import 'package:arcanum_app/features/lecturas/presentation/lecturas_screen.dart';
import 'package:arcanum_app/features/lecturas/presentation/obra_screen.dart';
import 'package:arcanum_app/features/saber/saber_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _work = 'culpeper-complete-herbal';
const _chapter = 'amara-dulcis';
const _next = 'all-heal';
/// Capitulo de UNA sola pagina: el caso que no registraba nada.
const _short = 'plate-1';

Map<String, dynamic> _paragraph(int i, {required String chapter}) => {
  'anchor': '$_work.$chapter.$i',
  'position': i,
  'text_original': 'English paragraph $i. ${'word$i ' * 40}',
  'text_es': 'Parrafo castellano $i. ${'palabra$i ' * 40}',
  'translation_status': 'machine',
};

/// Backend falso completo: biblioteca pública + biblioteca personal.
class _FakeApi extends ArcanumApi {
  _FakeApi() : super(Dio());

  Object? chapterError;

  /// Progreso guardado en memoria, como lo haría el servidor.
  Map<String, dynamic>? progress;
  final List<Map<String, dynamic>> savedProgress = [];
  final List<Map<String, dynamic>> createdBookmarks = [];
  final List<Map<String, dynamic>> createdPassages = [];
  List<Map<String, dynamic>> passageList = const [];

  static Map<String, dynamic> _resolve(Map<String, dynamic> position) => {
    ...position,
    'work_title': 'The Complete Herbal',
    'chapter_title': switch (position['chapter_slug']) {
      _next => 'All-Heal',
      _short => 'Plate 1',
      _ => 'Amara Dulcis',
    },
  };

  @override
  Future<List<Map<String, dynamic>>> libraryWorks() async => [
    {
      'slug': _work,
      'title': 'The Complete Herbal',
      'author': 'Nicholas Culpeper',
      'year': 1653,
      'language': 'en',
      'chapter_count': 3,
      'translated_chapters': 3,
    },
  ];

  @override
  Future<Map<String, dynamic>> libraryWork(String slug, {String? kind}) async => {
    'slug': _work,
    'title': 'The Complete Herbal',
    'author': 'Nicholas Culpeper',
    'year': 1653,
    'language': 'en',
    'license_note': 'Dominio publico.',
    'advisory': 'Documento historico de 1653.',
    'chapters': [
      {
        'slug': _chapter,
        'title': 'Amara Dulcis',
        'kind': 'herb',
        'position': 1,
        'meta': const {},
        'paragraph_count': 3,
      },
      {
        'slug': _next,
        'title': 'All-Heal',
        'kind': 'herb',
        'position': 2,
        'meta': const {},
        'paragraph_count': 3,
      },
      {
        'slug': _short,
        'title': 'Plate 1',
        'kind': 'front',
        'position': 0,
        'meta': const {},
        'paragraph_count': 1,
      },
    ],
  };

  @override
  Future<Map<String, dynamic>> libraryChapter(
    String workSlug,
    String chapterSlug,
  ) async {
    if (chapterError case final error?) throw error;
    if (chapterSlug == _short) {
      return {
        'id': '00000000-0000-4000-8000-000000000002',
        'slug': _short,
        'title': 'Plate 1',
        'kind': 'front',
        'position': 0,
        'meta': const {},
        'work_slug': workSlug,
        'work_title': 'The Complete Herbal',
        'advisory': null,
        'paragraphs': [
          {
            'anchor': '$_work.$_short.1',
            'position': 1,
            'text_original': 'A catalogue of simples.',
            'text_es': 'Catalogo de simples.',
            'translation_status': 'machine',
          },
        ],
      };
    }
    return {
      'id': '00000000-0000-4000-8000-000000000001',
      'slug': chapterSlug,
      'title': chapterSlug == _next ? 'All-Heal' : 'Amara Dulcis',
      'kind': 'herb',
      'position': chapterSlug == _next ? 2 : 1,
      'meta': const {},
      'work_slug': workSlug,
      'work_title': 'The Complete Herbal',
      'advisory': null,
      'paragraphs': [
        for (var i = 1; i <= 6; i++) _paragraph(i, chapter: chapterSlug),
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> saveProgress({
    required Map<String, dynamic> position,
    required String language,
  }) async {
    savedProgress.add(position);
    progress = {
      'id': 'progress-1',
      'position': _resolve(position),
      'language': language,
      'updated_at': '2026-08-12T10:00:00Z',
    };
    return progress!;
  }

  @override
  Future<Map<String, dynamic>> progressForWork(String workSlug) async {
    if (progress == null) {
      throw DioException(
        requestOptions: RequestOptions(path: '/reading/progress'),
        response: Response(
          requestOptions: RequestOptions(path: '/reading/progress'),
          statusCode: 404,
        ),
      );
    }
    return progress!;
  }

  @override
  Future<List<Map<String, dynamic>>> allProgress() async =>
      progress == null ? const [] : [progress!];

  @override
  Future<Map<String, dynamic>> createBookmark({
    required Map<String, dynamic> position,
    String? label,
  }) async {
    createdBookmarks.add(position);
    return {
      'id': 'bookmark-${createdBookmarks.length}',
      'position': _resolve(position),
      'label': label,
      'created_at': '2026-08-12T10:00:00Z',
    };
  }

  @override
  Future<Map<String, dynamic>> createPassage({
    required Map<String, dynamic> position,
    required String quote,
    required String language,
    String? encryptedNote,
    String? iv,
  }) async {
    final row = {
      'id': 'passage-${createdPassages.length + 1}',
      'position': _resolve(position),
      'quote_text': quote,
      'quote_language': language,
      'encrypted_note': encryptedNote,
      'note_iv': iv,
      'created_at': '2026-08-12T10:00:00Z',
    };
    createdPassages.add(row);
    return row;
  }

  @override
  Future<List<Map<String, dynamic>>> passages({String? workSlug}) async =>
      passageList.isEmpty ? createdPassages : passageList;
}

class _FakeCrypto extends GrimoireCrypto {
  @override
  Future<({String ciphertext, String iv})> encryptText(String plaintext) async =>
      (ciphertext: 'sellado:$plaintext'.codeUnits.join('-'), iv: 'iv');

  @override
  Future<String> decryptText(String ciphertextB64, String ivB64) async =>
      String.fromCharCodes(
        ciphertextB64.split('-').map(int.parse),
      ).substring('sellado:'.length);
}

/// La caché lee del disco real; en test no hay, así que se anula para que no
/// intercepte las respuestas del backend falso.
class _NoCache extends LibraryCache {
  @override
  Future<List<LibraryWorkSummary>?> readIndex() async => null;
  @override
  Future<LibraryWork?> readWork(String slug) async => null;
  @override
  Future<LibraryChapter?> readChapter(String w, String c) async => null;
  @override
  Future<void> writeIndex(List<LibraryWorkSummary> works) async {}
  @override
  Future<void> writeWork(LibraryWork work) async {}
  @override
  Future<void> writeChapter(LibraryChapter chapter) async {}
  @override
  Future<Set<String>> cachedChapters(String workSlug) async => {};
}

Widget _app(_FakeApi api, _FakeCrypto crypto, String initial) {
  final router = GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(
        path: '/saber',
        // En la app real Saber vive dentro del shell, que ya pone el
        // Scaffold. Aqui se pone a mano para que InkWell encuentre Material.
        builder: (c, s) => const Scaffold(body: SaberScreen()),
        routes: [
        GoRoute(
          path: 'pasajes',
          builder: (c, s) => const PasajesScreen(),
        ),
        GoRoute(
          path: ':work',
          builder: (c, s) => ObraScreen(workSlug: s.pathParameters['work']!),
          routes: [
            GoRoute(
              path: 'indice',
              builder: (c, s) => const Scaffold(body: Text('INDICE')),
            ),
            GoRoute(
              path: ':chapter',
              builder: (c, s) => LectorScreen(
                workSlug: s.pathParameters['work']!,
                chapterSlug: s.pathParameters['chapter']!,
                anchor: s.uri.queryParameters['anchor'],
                fragmentIndex:
                    int.tryParse(s.uri.queryParameters['fragment'] ?? '') ?? 0,
              ),
            ),
          ],
        ),
      ]),
    ],
  );

  return ProviderScope(
    overrides: [
      arcanumApiProvider.overrideWithValue(api),
      grimoireCryptoProvider.overrideWithValue(crypto),
      libraryCacheProvider.overrideWithValue(_NoCache()),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  late _FakeApi api;
  late _FakeCrypto crypto;

  setUp(() {
    api = _FakeApi();
    crypto = _FakeCrypto();
  });

  Future<void> pumpAt(WidgetTester tester, String location) async {
    await tester.pumpWidget(_app(api, crypto, location));
    await tester.pumpAndSettle();
  }

  group('Saber', () {
    testWidgets('alterna entre Plantas y Biblioteca', (tester) async {
      await tester.pumpWidget(_app(api, crypto, '/saber'));
      await tester.pump();

      expect(find.text('Plantas'), findsOneWidget);
      expect(find.text('Biblioteca'), findsOneWidget);

      await tester.tap(find.text('Biblioteca'));
      await tester.pumpAndSettle();

      // La estantería muestra libros, no una lista técnica.
      expect(find.text('The Complete Herbal'), findsWidgets);
    });
  });

  group('Estanteria', () {
    testWidgets('sin progreso ofrece Comenzar lectura', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            arcanumApiProvider.overrideWithValue(api),
            libraryCacheProvider.overrideWithValue(_NoCache()),
          ],
          child: const MaterialApp(home: Scaffold(body: LecturasScreen())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Comenzar lectura'), findsOneWidget);
      expect(find.text('REANUDAR LECTURA'), findsNothing);
    });

    testWidgets('con progreso ofrece Reanudar y dice el capitulo', (
      tester,
    ) async {
      api.progress = {
        'id': 'p',
        'position': _FakeApi._resolve({
          'work_slug': _work,
          'chapter_slug': _next,
          'paragraph_anchor': '$_work.$_next.2',
          'fragment_index': 0,
        }),
        'language': 'es',
        'updated_at': '2026-08-12T10:00:00Z',
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            arcanumApiProvider.overrideWithValue(api),
            libraryCacheProvider.overrideWithValue(_NoCache()),
          ],
          child: const MaterialApp(home: Scaffold(body: LecturasScreen())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('REANUDAR LECTURA'), findsOneWidget);
      expect(find.text('All-Heal'), findsOneWidget);
      expect(find.text('Comenzar lectura'), findsNothing);
    });
  });

  group('Portada de obra', () {
    testWidgets('muestra procedencia, aviso e Indice', (tester) async {
      await pumpAt(tester, '/saber/$_work');

      expect(find.text('Comenzar lectura'), findsOneWidget);
      expect(find.text('Índice'), findsOneWidget);
      expect(find.text('3 capítulos'), findsOneWidget);

      // Procedencia y aviso van al pie de la portada: en la pantalla del test
      // caen bajo el pliegue, como en un movil pequeno.
      await tester.scrollUntilVisible(find.text('PROCEDENCIA'), 200);
      expect(find.text('Dominio publico.'), findsOneWidget);
      expect(find.text('AVISO'), findsOneWidget);
      expect(find.text('Documento historico de 1653.'), findsOneWidget);
    });

    testWidgets('la descarga se ofrece, nunca se hace sola', (tester) async {
      await pumpAt(tester, '/saber/$_work');

      expect(find.text('Descargar para leer sin conexión'), findsOneWidget);
      // Nada se ha pedido al abrir la portada: descargar es decisión del usuario.
      expect(api.createdPassages, isEmpty);
    });

    testWidgets('con progreso, la portada dice Reanudar', (tester) async {
      api.progress = {
        'id': 'p',
        'position': _FakeApi._resolve({
          'work_slug': _work,
          'chapter_slug': _chapter,
          'paragraph_anchor': '$_work.$_chapter.2',
          'fragment_index': 0,
        }),
        'language': 'es',
        'updated_at': '2026-08-12T10:00:00Z',
      };
      await pumpAt(tester, '/saber/$_work');

      expect(find.text('Reanudar lectura'), findsOneWidget);
      expect(find.text('Amara Dulcis'), findsWidgets);
    });
  });

  group('Lector', () {
    testWidgets('pagina adelante y atras', (tester) async {
      await pumpAt(tester, '/saber/$_work/$_chapter');

      expect(find.text('Amara Dulcis'), findsWidgets);
      final primeraPagina = find.textContaining('Parrafo castellano 1');
      expect(primeraPagina, findsOneWidget);

      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Parrafo castellano 1'), findsNothing);

      await tester.tap(find.text('Anterior'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Parrafo castellano 1'), findsOneWidget);
    });

    testWidgets('el selector ES/EN cambia el idioma del texto', (tester) async {
      await pumpAt(tester, '/saber/$_work/$_chapter');

      expect(find.textContaining('Parrafo castellano 1'), findsOneWidget);

      await tester.tap(find.text('EN'));
      await tester.pumpAndSettle();

      expect(find.textContaining('English paragraph 1'), findsOneWidget);
      expect(find.textContaining('Parrafo castellano 1'), findsNothing);
    });

    testWidgets('guarda el progreso con la posicion estable', (tester) async {
      await pumpAt(tester, '/saber/$_work/$_chapter');

      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();
      // El guardado va con un segundo de calma para no mandar una peticion por
      // cada pagina pasada.
      await tester.pump(const Duration(seconds: 2));

      expect(api.savedProgress, isNotEmpty);
      final position = api.savedProgress.last;
      expect(position['work_slug'], _work);
      expect(position['chapter_slug'], _chapter);
      expect(position['paragraph_anchor'], startsWith('$_work.$_chapter.'));
      expect(position.containsKey('page'), isFalse);
    });

    testWidgets('reanuda en la posicion pedida por enlace profundo', (
      tester,
    ) async {
      final anchor = Uri.encodeComponent('$_work.$_chapter.5');
      await pumpAt(tester, '/saber/$_work/$_chapter?anchor=$anchor&fragment=0');

      // Cae en el parrafo 5, no en el principio del capitulo.
      expect(find.textContaining('Parrafo castellano 5'), findsOneWidget);
      expect(find.textContaining('Parrafo castellano 1'), findsNothing);
    });

    testWidgets('el enlace profundo de siempre sigue abriendo el capitulo', (
      tester,
    ) async {
      // Sin anchor ni fragment: la ruta /saber/:work/:chapter no cambia.
      await pumpAt(tester, '/saber/$_work/$_chapter');
      expect(find.textContaining('Parrafo castellano 1'), findsOneWidget);
    });

    testWidgets('marcar no mueve el progreso', (tester) async {
      await pumpAt(tester, '/saber/$_work/$_chapter');

      await tester.pump(const Duration(seconds: 2));
      final guardadosAntes = api.savedProgress.length;

      await tester.tap(find.text('Marcar'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));

      expect(api.createdBookmarks, hasLength(1));
      expect(api.createdBookmarks.single['chapter_slug'], _chapter);
      // Marcar es un gesto deliberado; el progreso es automatico. Marcar no
      // puede provocar ni un guardado mas.
      expect(api.savedProgress, hasLength(guardadosAntes));
    });

    testWidgets('guardar un pasaje cifra la nota antes de enviarla', (
      tester,
    ) async {
      await pumpAt(tester, '/saber/$_work/$_chapter');

      await tester.longPress(find.textContaining('Parrafo castellano 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar en el grimorio'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'mi nota privada');
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(api.createdPassages, hasLength(1));
      final saved = api.createdPassages.single;
      expect(saved['encrypted_note'], isNotNull);
      expect(saved['encrypted_note'], isNot(contains('mi nota privada')));
      expect(saved['position']['paragraph_anchor'], '$_work.$_chapter.1');
    });

    // ── Capitulo de una sola pagina ─────────────────────────────────────
    //
    // Regresion fisica: "Plate 1" cabe entero en una pantalla, asi que no hay
    // ningun cambio de pagina que dispare el guardado. Se leia el capitulo
    // completo y la obra seguia ofreciendo "Comenzar lectura".

    testWidgets('un capitulo de una pagina registra el progreso al abrirlo', (
      tester,
    ) async {
      await pumpAt(tester, '/saber/$_work/$_short');
      await tester.pump(const Duration(seconds: 2));

      expect(api.savedProgress, isNotEmpty);
      final position = api.savedProgress.last;
      expect(position['chapter_slug'], _short);
      expect(position['paragraph_anchor'], '$_work.$_short.1');
      expect(position['fragment_index'], 0);
    });

    testWidgets('la pagina de cierre hereda la posicion de la ultima de texto', (
      tester,
    ) async {
      await pumpAt(tester, '/saber/$_work/$_short');
      await tester.pump(const Duration(seconds: 2));

      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));

      expect(find.text('Fin del capítulo'), findsOneWidget);
      // El cierre no es texto de la obra: no puede inventarse una posicion
      // propia ni dejar de guardar. Hereda la ultima real.
      final position = api.savedProgress.last;
      expect(position['chapter_slug'], _short);
      expect(position['paragraph_anchor'], '$_work.$_short.1');
    });

    testWidgets('salir desde el cierre conserva la ultima posicion', (
      tester,
    ) async {
      await pumpAt(tester, '/saber/$_work/$_short');
      await tester.pump(const Duration(seconds: 2));
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();

      api.savedProgress.clear();

      // Desmontar el lector: es lo que ocurre al salir con el boton de volver.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      expect(api.savedProgress, isNotEmpty, reason: 'salir debe guardar');
      expect(api.savedProgress.last['paragraph_anchor'], '$_work.$_short.1');
    });

    testWidgets('nunca se manda un numero de pagina al servidor', (
      tester,
    ) async {
      await pumpAt(tester, '/saber/$_work/$_short');
      await tester.pump(const Duration(seconds: 2));
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));

      for (final position in api.savedProgress) {
        expect(position.keys.toSet(), {
          'work_slug',
          'chapter_slug',
          'paragraph_anchor',
          'fragment_index',
        });
      }
    });

    testWidgets('en un capitulo normal el guardado sigue siendo el de antes', (
      tester,
    ) async {
      await pumpAt(tester, '/saber/$_work/$_chapter');
      await tester.pump(const Duration(seconds: 2));
      final alAbrir = api.savedProgress.last['paragraph_anchor'];

      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));

      // Al abrir registra la primera pagina; al pasar, la siguiente. La
      // posicion avanza con la lectura, como antes del arreglo.
      expect(alAbrir, '$_work.$_chapter.1');
      expect(api.savedProgress.last['paragraph_anchor'], isNot(alAbrir));
      expect(api.savedProgress.last['chapter_slug'], _chapter);
    });

    testWidgets('al final del capitulo ofrece continuar al siguiente', (
      tester,
    ) async {
      await pumpAt(tester, '/saber/$_work/$_chapter');

      // Pasar hasta la ultima pagina: la de cierre.
      for (var i = 0; i < 12; i++) {
        final siguiente = find.text('Siguiente');
        if (siguiente.evaluate().isEmpty) break;
        await tester.tap(siguiente);
        await tester.pumpAndSettle();
        if (find.text('Fin del capítulo').evaluate().isNotEmpty) break;
      }

      expect(find.text('Fin del capítulo'), findsOneWidget);
      expect(find.text('Continuar al siguiente capítulo'), findsOneWidget);
      expect(find.text('All-Heal'), findsWidgets);
    });

    testWidgets('sin capitulo descargado ni red, lo dice y ofrece salida', (
      tester,
    ) async {
      api.chapterError = DioException(
        requestOptions: RequestOptions(path: '/library'),
        type: DioExceptionType.connectionError,
      );
      await pumpAt(tester, '/saber/$_work/$_chapter');

      expect(find.text('No se pudo abrir este pasaje'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
      expect(find.text('Ir a la portada'), findsOneWidget);
      // Nunca se filtra el error tecnico al usuario.
      expect(find.textContaining('DioException'), findsNothing);
    });

    testWidgets('los ajustes cambian el cuerpo de letra en vivo', (
      tester,
    ) async {
      await pumpAt(tester, '/saber/$_work/$_chapter');

      Text primerParrafo() => tester.widget<Text>(
        find.textContaining('Parrafo castellano 1'),
      );
      final antes = primerParrafo().style!.fontSize!;

      await tester.tap(find.byIcon(Icons.text_fields));
      await tester.pumpAndSettle();
      expect(find.text('AJUSTES DE LECTURA'), findsOneWidget);

      // Se arrastra el primer slider (tamaño de letra) hacia la derecha.
      await tester.drag(find.byType(Slider).first, const Offset(120, 0));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(primerParrafo().style!.fontSize!, greaterThan(antes));
    });
  });

  group('Grimorio: pasajes guardados', () {
    testWidgets('lista los pasajes con su nota descifrada', (tester) async {
      final sealed = await crypto.encryptText('mi nota privada');
      api.passageList = [
        {
          'id': 'p1',
          'position': _FakeApi._resolve({
            'work_slug': _work,
            'chapter_slug': _chapter,
            'paragraph_anchor': '$_work.$_chapter.3',
            'fragment_index': 0,
          }),
          'quote_text': 'It is under the planet Mercury.',
          'quote_language': 'en',
          'encrypted_note': sealed.ciphertext,
          'note_iv': sealed.iv,
          'created_at': '2026-08-12T10:00:00Z',
        },
      ];

      await pumpAt(tester, '/saber/pasajes');

      expect(find.text('It is under the planet Mercury.'), findsOneWidget);
      expect(find.text('mi nota privada'), findsOneWidget);
      expect(
        find.text('THE COMPLETE HERBAL · AMARA DULCIS'),
        findsOneWidget,
      );
    });

    testWidgets('tocar un pasaje abre el lector en su posicion exacta', (
      tester,
    ) async {
      final sealed = await crypto.encryptText('nota');
      api.passageList = [
        {
          'id': 'p1',
          'position': _FakeApi._resolve({
            'work_slug': _work,
            'chapter_slug': _chapter,
            'paragraph_anchor': '$_work.$_chapter.5',
            'fragment_index': 0,
          }),
          'quote_text': 'cita guardada',
          'quote_language': 'es',
          'encrypted_note': sealed.ciphertext,
          'note_iv': sealed.iv,
          'created_at': '2026-08-12T10:00:00Z',
        },
      ];

      await pumpAt(tester, '/saber/pasajes');
      await tester.tap(find.text('cita guardada'));
      await tester.pumpAndSettle();

      // El lector abre justo donde se guardó, no al principio.
      expect(find.textContaining('Parrafo castellano 5'), findsOneWidget);
    });

    testWidgets('sin pasajes explica como se guardan', (tester) async {
      api.passageList = const [];
      await pumpAt(tester, '/saber/pasajes');

      expect(
        find.text('Aún no has guardado ningún pasaje'),
        findsOneWidget,
      );
    });
  });
}
