import 'reading_identity.dart';

class ConversionOption {
  final String id;
  final String label;
  final String hebrew;

  const ConversionOption({
    required this.id,
    required this.label,
    required this.hebrew,
  });
}

class ConversionAmbiguity {
  final String id;
  final String question;
  final List<ConversionOption> options;

  const ConversionAmbiguity({
    required this.id,
    required this.question,
    required this.options,
  });
}

class ConversionProposal {
  final String ruleVersion;
  final String pronunciation;
  final String? proposedHebrew;
  final List<ConversionAmbiguity> ambiguities;
  final String? unavailableReason;

  const ConversionProposal({
    required this.ruleVersion,
    required this.pronunciation,
    required this.proposedHebrew,
    this.ambiguities = const [],
    this.unavailableReason,
  });

  bool get canConfirm =>
      proposedHebrew != null &&
      ambiguities.isEmpty &&
      unavailableReason == null;
}

class SpanishHebrewConverter {
  static const ruleVersion = 'phon-he-1.0.0';

  ConversionProposal propose(String original, ReadingDialect dialect) {
    final clean = original.trim();
    if (clean.isEmpty) {
      return const ConversionProposal(
        ruleVersion: ruleVersion,
        pronunciation: '',
        proposedHebrew: null,
        unavailableReason: 'Escribe una parte del nombre.',
      );
    }
    if (dialect == ReadingDialect.portuguese) {
      return const ConversionProposal(
        ruleVersion: ruleVersion,
        pronunciation: '',
        proposedHebrew: null,
        unavailableReason:
            'Portugués: próximamente. No automatizamos sin reglas auditadas.',
      );
    }
    if (dialect == ReadingDialect.basqueManual) {
      return const ConversionProposal(
        ruleVersion: ruleVersion,
        pronunciation: '',
        proposedHebrew: null,
        unavailableReason:
            'Vasco: escribe manualmente la forma hebrea que quieras usar.',
      );
    }
    if (!_validInput.hasMatch(clean)) {
      return const ConversionProposal(
        ruleVersion: ruleVersion,
        pronunciation: '',
        proposedHebrew: null,
        unavailableReason: 'La entrada contiene caracteres no admitidos.',
      );
    }

    final normalized = _fold(clean.toLowerCase());
    final ambiguity = _firstAmbiguity(normalized, dialect);
    if (ambiguity != null) {
      return ConversionProposal(
        ruleVersion: ruleVersion,
        pronunciation: _pronunciationLabel(clean, dialect),
        proposedHebrew: null,
        ambiguities: [ambiguity],
      );
    }

    final words = normalized
        .split(RegExp(r"[\s\-']+"))
        .where((w) => w.isNotEmpty);
    final hebrew = words.map((word) => _convertWord(word, dialect)).join('־');
    if (hebrew.isEmpty) {
      return const ConversionProposal(
        ruleVersion: ruleVersion,
        pronunciation: '',
        proposedHebrew: null,
        unavailableReason: 'No puedo proponer una forma responsable.',
      );
    }
    return ConversionProposal(
      ruleVersion: ruleVersion,
      pronunciation: _pronunciationLabel(clean, dialect),
      proposedHebrew: hebrew,
    );
  }

  ConversionProposal resolve(
    String original,
    ReadingDialect dialect,
    ConversionOption option,
  ) => ConversionProposal(
    ruleVersion: ruleVersion,
    pronunciation:
        '${_pronunciationLabel(original, dialect)} · ${option.label}',
    proposedHebrew: option.hebrew,
  );

  static final _validInput = RegExp(
    r"^[A-Za-zÁÉÍÓÚÜÑáéíóúüñÇçÀÂÃÊÔÕàâãêôõ\s'\-]+$",
  );

  String _pronunciationLabel(String value, ReadingDialect dialect) =>
      '${dialect.label}: ${value.trim()}';

  ConversionAmbiguity? _firstAmbiguity(String word, ReadingDialect dialect) {
    if (word.contains('x')) {
      return ConversionAmbiguity(
        id: 'x_sound',
        question: '¿Cómo suena la x en este nombre?',
        options: [
          ConversionOption(
            id: 'x_ks',
            label: 'Como ks',
            hebrew: _convertWord(word.replaceAll('x', 'ks'), dialect),
          ),
          ConversionOption(
            id: 'x_j',
            label: 'Como j',
            hebrew: _convertWord(word.replaceAll('x', 'j'), dialect),
          ),
          ConversionOption(
            id: 'x_s',
            label: 'Como s',
            hebrew: _convertWord(word.replaceAll('x', 's'), dialect),
          ),
        ],
      );
    }
    if (word.contains('ll')) {
      return ConversionAmbiguity(
        id: 'll_sound',
        question: '¿Cómo pronuncias ll?',
        options: [
          ConversionOption(
            id: 'll_y',
            label: 'Como y',
            hebrew: _convertWord(word.replaceAll('ll', 'y'), dialect),
          ),
          ConversionOption(
            id: 'll_palatal',
            label: 'Como ll diferenciada',
            hebrew: _convertWord(word.replaceAll('ll', 'ly'), dialect),
          ),
        ],
      );
    }
    if (word.startsWith('h')) {
      return ConversionAmbiguity(
        id: 'initial_h',
        question: '¿La h es muda?',
        options: [
          ConversionOption(
            id: 'h_silent',
            label: 'Muda',
            hebrew: _convertWord(word.substring(1), dialect),
          ),
          ConversionOption(
            id: 'h_spoken',
            label: 'Suena como h aspirada',
            hebrew: 'ה${_convertWord(word.substring(1), dialect)}',
          ),
        ],
      );
    }
    return null;
  }

  String _convertWord(String word, ReadingDialect dialect) {
    final output = StringBuffer();
    var index = 0;
    while (index < word.length) {
      final current = word[index];
      final next = index + 1 < word.length ? word[index + 1] : '';
      final last = index == word.length - 1;

      if (current == 'c' && next == 'h') {
        output.write('צ׳');
        index += 2;
        continue;
      }
      if (current == 'q' && next == 'u') {
        output.write('ק');
        index += 2;
        continue;
      }
      if (current == 'g' && next == 'u' && index + 2 < word.length) {
        final after = word[index + 2];
        if (after == 'e' || after == 'i') {
          output.write('ג');
          index += 2;
          continue;
        }
      }
      if (current == 'g' && (next == 'e' || next == 'i')) {
        output.write('ח');
        index++;
        continue;
      }
      if (current == 'c') {
        if (next == 'e' || next == 'i') {
          output.write(dialect == ReadingDialect.peninsular ? 'ת׳' : 'ס');
        } else {
          output.write('ק');
        }
        index++;
        continue;
      }
      if (current == 'z') {
        output.write(dialect == ReadingDialect.peninsular ? 'ת׳' : 'ס');
        index++;
        continue;
      }
      if (current == 'n' && next == '~') {
        output.write('ני');
        index += 2;
        continue;
      }

      if (_vowels.contains(current)) {
        if (index == 0) output.write('א');
        if (current == 'a' && output.toString().endsWith('׳')) {
          output.write('א');
        }
        if (current == 'i') output.write('י');
        if (current == 'o' || current == 'u') output.write('ו');
        if (last && (current == 'a' || current == 'e')) output.write('ה');
        index++;
        continue;
      }

      output.write(_consonants[current] ?? current);
      index++;
    }
    return _finalize(output.toString());
  }

  String _finalize(String value) {
    if (value.isEmpty) return value;
    final replacements = {'כ': 'ך', 'מ': 'ם', 'נ': 'ן', 'פ': 'ף', 'צ': 'ץ'};
    final last = value.substring(value.length - 1);
    return replacements.containsKey(last)
        ? '${value.substring(0, value.length - 1)}${replacements[last]}'
        : value;
  }

  static const _vowels = {'a', 'e', 'i', 'o', 'u'};
  static const _consonants = <String, String>{
    'b': 'ב',
    'v': 'ב',
    'd': 'ד',
    'f': 'פ',
    'g': 'ג',
    'h': '',
    'j': 'ח',
    'k': 'ק',
    'l': 'ל',
    'm': 'מ',
    'n': 'נ',
    'p': 'פ',
    'r': 'ר',
    's': 'ס',
    't': 'ט',
    'w': 'ו',
    'y': 'י',
    '~': '',
  };

  static String _fold(String value) => value
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('ñ', 'n~')
      .replaceAll('ç', 's')
      .replaceAll(RegExp('[àâã]'), 'a')
      .replaceAll(RegExp('[ê]'), 'e')
      .replaceAll(RegExp('[ôõ]'), 'o');
}
