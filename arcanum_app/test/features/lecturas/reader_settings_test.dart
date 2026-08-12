import 'package:arcanum_app/features/lecturas/data/reader_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('los ajustes arrancan en valores legibles', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final settings = container.read(readerSettingsProvider);
    expect(settings.fontSize, 18);
    expect(settings.palette, ReaderPalette.night);
  });

  test('cambiar un ajuste lo persiste en el dispositivo', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(readerSettingsProvider.notifier).setFontSize(22);
    container.read(readerSettingsProvider.notifier).setPalette(
      ReaderPalette.sepia,
    );
    await Future<void>.delayed(Duration.zero);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble('lector_font_size'), 22);
    expect(prefs.getString('lector_palette'), 'sepia');
  });

  test('al volver a abrir, se restauran los ajustes guardados', () async {
    SharedPreferences.setMockInitialValues({
      'lector_font_size': 24.0,
      'lector_max_width': 700.0,
      'lector_palette': 'sepia',
    });

    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(readerSettingsProvider);
    // La restauracion es asincrona a proposito: no se bloquea el primer
    // fotograma del lector por un tamano de letra.
    await Future<void>.delayed(Duration.zero);

    final settings = container.read(readerSettingsProvider);
    expect(settings.fontSize, 24);
    expect(settings.maxWidth, 700);
    expect(settings.palette, ReaderPalette.sepia);
  });

  test('un valor absurdo se recorta en vez de romper la lectura', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(readerSettingsProvider.notifier).setFontSize(400);
    expect(
      container.read(readerSettingsProvider).fontSize,
      ReaderSettings.maxFontSize,
    );

    container.read(readerSettingsProvider.notifier).setFontSize(1);
    expect(
      container.read(readerSettingsProvider).fontSize,
      ReaderSettings.minFontSize,
    );
  });
}
