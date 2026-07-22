import 'package:arcanum_app/features/lecturas/domain/library_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// La capa de datos de Lecturas sostiene dos promesas que, si se rompieran,
/// fallarían en silencio: el original siempre está disponible, y una obra a
/// medio traducir se puede leer igual en vez de mostrar huecos.
void main() {
  group('LibraryParagraph', () {
    LibraryParagraph build({String? es, String? status}) =>
        LibraryParagraph.fromJson({
          'anchor': 'culpeper-complete-herbal.all-heal.3',
          'position': 3,
          'text_original': 'It is under the dominion of Mars',
          'text_es': es,
          'translation_status': status,
        });

    test('sin traducción cae al original, no a un hueco', () {
      final p = build();
      expect(p.hasTranslation, isFalse);
      expect(p.textFor(spanish: true), 'It is under the dominion of Mars');
      expect(p.textFor(spanish: false), 'It is under the dominion of Mars');
    });

    test('con traducción respeta el idioma pedido', () {
      final p = build(es: 'Está bajo el dominio de Marte', status: 'machine');
      expect(p.textFor(spanish: true), 'Está bajo el dominio de Marte');
      expect(p.textFor(spanish: false), 'It is under the dominion of Mars');
    });

    test('una traducción vacía no cuenta como traducción', () {
      expect(build(es: '').hasTranslation, isFalse);
    });

    test('declara si la tradujo una máquina o una persona', () {
      expect(
        build(status: 'machine').translationStatus,
        TranslationStatus.machine,
      );
      expect(build(status: 'human').translationStatus, TranslationStatus.human);
      expect(build(status: 'raro').translationStatus, isNull);
      expect(TranslationStatus.machine.label, 'Traducción automática');
    });

    test('el ida y vuelta a JSON no pierde nada', () {
      final p = build(es: 'Está bajo el dominio de Marte', status: 'human');
      final again = LibraryParagraph.fromJson(p.toJson());
      expect(again.anchor, p.anchor);
      expect(again.textOriginal, p.textOriginal);
      expect(again.textEs, p.textEs);
      expect(again.translationStatus, p.translationStatus);
    });
  });

  group('LibraryChapter', () {
    LibraryChapter build({Map<String, dynamic>? meta, String? advisory}) =>
        LibraryChapter.fromJson({
          'slug': 'all-heal',
          'title': 'All-Heal',
          'kind': 'herb',
          'position': 2,
          'meta': meta ?? {'ruling_planet': 'mars'},
          'work_slug': 'culpeper-complete-herbal',
          'work_title': 'The Complete Herbal',
          'advisory': advisory,
          'paragraphs': [
            {
              'anchor': 'culpeper-complete-herbal.all-heal.0',
              'position': 0,
              'text_original': 'IT is called All-heal',
            },
          ],
        });

    test('expone el planeta regente para enlazar con Materia Arcana', () {
      expect(build().rulingPlanet, 'mars');
      expect(build(meta: {}).rulingPlanet, isNull);
    });

    test('un kind desconocido no revienta: cae a text', () {
      expect(ChapterKind.parse('inventado'), ChapterKind.text);
      expect(ChapterKind.parse(null), ChapterKind.text);
      expect(ChapterKind.parse('herb'), ChapterKind.herb);
    });

    test('conserva el aviso histórico', () {
      // Debe viajar con el capítulo: si se entra directo a una entrada que
      // afirma curar la peste, el encuadre tiene que estar ahí.
      expect(
        build(advisory: 'Documento histórico de 1653.').advisory,
        contains('1653'),
      );
    });

    test('el ida y vuelta a JSON conserva el texto y las anclas', () {
      final c = build(advisory: 'aviso');
      final again = LibraryChapter.fromJson(c.toJson());
      expect(again.paragraphs.single.anchor, c.paragraphs.single.anchor);
      expect(
        again.paragraphs.single.textOriginal,
        c.paragraphs.single.textOriginal,
      );
      expect(again.rulingPlanet, 'mars');
      expect(again.advisory, 'aviso');
    });
  });

  group('LibraryWorkSummary', () {
    LibraryWorkSummary build(int translated) => LibraryWorkSummary.fromJson({
      'slug': 'culpeper-complete-herbal',
      'title': 'The Complete Herbal',
      'author': 'Nicholas Culpeper',
      'year': 1653,
      'language': 'en',
      'chapter_count': 423,
      'translated_chapters': translated,
    });

    test('sabe si la obra está traducida del todo', () {
      expect(build(10).fullyTranslated, isFalse);
      expect(build(423).fullyTranslated, isTrue);
    });

    test('reporta el avance para poder avisar en vez de mostrar huecos', () {
      expect(build(0).translationProgress, 0);
      expect(build(423).translationProgress, 1);
      expect(build(211).translationProgress, closeTo(0.5, 0.01));
    });

    test('una obra sin capítulos no divide por cero', () {
      final vacia = LibraryWorkSummary.fromJson({
        'slug': 'x',
        'title': 'T',
        'author': 'A',
        'language': 'en',
        'chapter_count': 0,
        'translated_chapters': 0,
      });
      expect(vacia.translationProgress, 0);
      expect(vacia.fullyTranslated, isFalse);
    });
  });

  group('LibraryWork', () {
    test('filtra el índice por tipo de capítulo', () {
      final work = LibraryWork.fromJson({
        'slug': 'culpeper-complete-herbal',
        'title': 'The Complete Herbal',
        'author': 'Nicholas Culpeper',
        'language': 'en',
        'license_note': 'Dominio público',
        'chapters': [
          {
            'slug': 'a',
            'title': 'A',
            'kind': 'herb',
            'position': 0,
            'paragraph_count': 5,
          },
          {
            'slug': 'b',
            'title': 'B',
            'kind': 'front',
            'position': 1,
            'paragraph_count': 2,
          },
          {
            'slug': 'c',
            'title': 'C',
            'kind': 'herb',
            'position': 2,
            'paragraph_count': 7,
          },
        ],
      });
      expect(work.byKind(ChapterKind.herb).map((c) => c.slug), ['a', 'c']);
      expect(work.byKind(ChapterKind.front).map((c) => c.slug), ['b']);
      expect(work.licenseNote, 'Dominio público');
    });
  });
}
