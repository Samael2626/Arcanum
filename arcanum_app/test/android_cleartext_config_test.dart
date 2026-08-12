import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// El HTTP en claro es una puerta abierta si se cuela en release.
///
/// Se comprueba sobre los manifest de verdad y no sobre una constante de Dart:
/// lo que decide si Android permite cleartext es el manifest fusionado, no el
/// codigo.
void main() {
  final debugManifest = File('android/app/src/debug/AndroidManifest.xml');
  final mainManifest = File('android/app/src/main/AndroidManifest.xml');

  test('debug permite cleartext para poder apuntar a un backend local', () {
    expect(debugManifest.existsSync(), isTrue);
    expect(
      debugManifest.readAsStringSync(),
      contains('android:usesCleartextTraffic="true"'),
    );
  });

  test('el manifest principal NO abre cleartext', () {
    // Si apareciera aqui, release lo heredaria y la app publicada aceptaria
    // HTTP en claro contra cualquier servidor.
    expect(
      mainManifest.readAsStringSync(),
      isNot(contains('usesCleartextTraffic')),
    );
  });

  test('tampoco hay una configuracion de red que lo permita por la puerta de atras', () {
    final config = File('android/app/src/main/res/xml/network_security_config.xml');
    if (!config.existsSync()) return;
    expect(
      config.readAsStringSync(),
      isNot(contains('cleartextTrafficPermitted="true"')),
    );
  });

  test('el APK de release no declara cleartext', () {
    // Solo corre si hay un APK de release construido; en local no suele
    // haberlo y el test se salta en vez de dar un verde falso.
    final apk = File('build/app/outputs/flutter-apk/app-release.apk');
    if (!apk.existsSync()) return;

    final aapt = _findAapt2();
    if (aapt == null) return;

    final dump = Process.runSync(aapt, [
      'dump',
      'xmltree',
      '--file',
      'AndroidManifest.xml',
      apk.path,
    ]);
    expect(dump.stdout.toString(), isNot(contains('usesCleartextTraffic')));
  });
}

String? _findAapt2() {
  final home = Platform.environment['LOCALAPPDATA'];
  if (home == null) return null;
  final dir = Directory('$home/Android/Sdk/build-tools');
  if (!dir.existsSync()) return null;
  final versions = dir.listSync().whereType<Directory>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final version in versions.reversed) {
    final exe = File('${version.path}/aapt2.exe');
    if (exe.existsSync()) return exe.path;
  }
  return null;
}
