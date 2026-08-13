import 'package:arcanum_app/features/name_threshold/domain/phonetic_converter.dart';
import 'package:arcanum_app/features/name_threshold/domain/reading_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final converter = SpanishHebrewConverter();

  test('convierte por sonidos del espanol LatAm', () {
    expect(
      converter.propose('José', ReadingDialect.latinAmerica).proposedHebrew,
      'חוסה',
    );
    expect(
      converter.propose('Chávez', ReadingDialect.latinAmerica).proposedHebrew,
      'צ׳אבס',
    );
    expect(
      converter.propose('Muñoz', ReadingDialect.latinAmerica).proposedHebrew,
      'מוניוס',
    );
  });

  test('b y v comparten sonido en espanol', () {
    final be = converter.propose('Bela', ReadingDialect.latinAmerica);
    final ve = converter.propose('Vela', ReadingDialect.latinAmerica);
    expect(be.proposedHebrew, ve.proposedHebrew);
  });

  test('x exige eleccion y no produce conversion silenciosa', () {
    final proposal = converter.propose('Ximena', ReadingDialect.latinAmerica);
    expect(proposal.proposedHebrew, isNull);
    expect(proposal.ambiguities.single.id, 'x_sound');

    final resolved = converter.resolve(
      'Ximena',
      ReadingDialect.latinAmerica,
      proposal.ambiguities.single.options[1],
    );
    expect(resolved.canConfirm, isTrue);
    expect(resolved.proposedHebrew, 'חימנה');
  });

  test('ll exige eleccion', () {
    final proposal = converter.propose(
      'Guillermo',
      ReadingDialect.latinAmerica,
    );
    expect(proposal.ambiguities.single.id, 'll_sound');
  });

  test('portugues no se automatiza y vasco queda manual', () {
    expect(
      converter.propose('João', ReadingDialect.portuguese).unavailableReason,
      contains('próximamente'),
    );
    expect(
      converter.propose('Iñaki', ReadingDialect.basqueManual).unavailableReason,
      contains('manualmente'),
    );
  });
}
