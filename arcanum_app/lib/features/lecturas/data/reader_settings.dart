import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cómo quiere leer cada cual.
///
/// Vive en el dispositivo y no en el servidor: es una preferencia de ojos y de
/// pantalla, no parte de la cuenta. Quien lee en una tablet de noche no quiere
/// el mismo cuerpo de letra que en un móvil a mediodía, y sincronizarlo sería
/// pelearse con el usuario.
@immutable
class ReaderSettings {
  /// Cuerpo del texto. El rango cubre desde presbicia hasta lectura densa.
  final double fontSize;

  /// Ancho máximo de la mancha de texto. Una línea muy larga cansa: la
  /// tipografía clásica ronda los 60-70 caracteres por línea.
  final double maxWidth;

  final ReaderPalette palette;

  const ReaderSettings({
    this.fontSize = 18,
    this.maxWidth = 620,
    this.palette = ReaderPalette.night,
  });

  static const minFontSize = 15.0;
  static const maxFontSize = 26.0;
  static const minWidth = 460.0;
  static const maxWidthLimit = 760.0;

  ReaderSettings copyWith({
    double? fontSize,
    double? maxWidth,
    ReaderPalette? palette,
  }) => ReaderSettings(
    fontSize: (fontSize ?? this.fontSize).clamp(minFontSize, maxFontSize),
    maxWidth: (maxWidth ?? this.maxWidth).clamp(minWidth, maxWidthLimit),
    palette: palette ?? this.palette,
  );
}

/// Fondo de lectura. Sepia no es decoración: a media luz, el papel viejo cansa
/// menos que el negro puro, y de noche el negro cansa menos que el papel.
enum ReaderPalette {
  night('Noche'),
  sepia('Sepia');

  const ReaderPalette(this.label);
  final String label;
}

/// Guarda y restaura los ajustes del lector.
class ReaderSettingsController extends Notifier<ReaderSettings> {
  @override
  ReaderSettings build() {
    // Los ajustes guardados llegan un frame despues: se arranca con los
    // valores por defecto y se corrigen al restaurar. Bloquear el primer
    // fotograma del lector por un tamano de letra no compensa.
    _restore();
    return const ReaderSettings();
  }

  static const _kFont = 'lector_font_size';
  static const _kWidth = 'lector_max_width';
  static const _kPalette = 'lector_palette';

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = ReaderSettings(
        fontSize: prefs.getDouble(_kFont) ?? state.fontSize,
        maxWidth: prefs.getDouble(_kWidth) ?? state.maxWidth,
        palette: ReaderPalette.values.firstWhere(
          (p) => p.name == prefs.getString(_kPalette),
          orElse: () => state.palette,
        ),
      );
    } catch (error) {
      // Sin preferencias se lee igual, con los valores por defecto. Perder el
      // ajuste no puede impedir abrir un libro.
      debugPrint('ARCANUM lector: no se pudieron leer los ajustes ($error).');
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_kFont, state.fontSize);
      await prefs.setDouble(_kWidth, state.maxWidth);
      await prefs.setString(_kPalette, state.palette.name);
    } catch (error) {
      debugPrint('ARCANUM lector: no se pudieron guardar los ajustes ($error).');
    }
  }

  void setFontSize(double value) {
    state = state.copyWith(fontSize: value);
    _persist();
  }

  void setMaxWidth(double value) {
    state = state.copyWith(maxWidth: value);
    _persist();
  }

  void setPalette(ReaderPalette value) {
    state = state.copyWith(palette: value);
    _persist();
  }
}

final readerSettingsProvider =
    NotifierProvider<ReaderSettingsController, ReaderSettings>(
      ReaderSettingsController.new,
    );
