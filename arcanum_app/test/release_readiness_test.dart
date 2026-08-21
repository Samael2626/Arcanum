import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Android release identity', () {
    test('uses the final package and a matching activity', () {
      final gradle = File('android/app/build.gradle').readAsStringSync();
      final activity = File(
        'android/app/src/main/kotlin/com/arcanum/magick/MainActivity.kt',
      );

      expect(gradle, contains('namespace = "com.arcanum.magick"'));
      expect(gradle, contains('applicationId = "com.arcanum.magick"'));
      expect(activity.existsSync(), isTrue);
      expect(
        activity.readAsStringSync(),
        contains('package com.arcanum.magick'),
      );
      expect(
        File(
          'android/app/src/main/kotlin/com/example/arcanum_app/MainActivity.kt',
        ).existsSync(),
        isFalse,
      );
    });

    test('never falls back to the debug key for release', () {
      final gradle = File('android/app/build.gradle').readAsStringSync();
      final gitignore = File('.gitignore').readAsStringSync();

      expect(gradle, isNot(contains('signingConfig = signingConfigs.debug')));
      expect(gradle, contains('Firma release ausente'));
      expect(gitignore, contains('/android/key.properties'));
      expect(gitignore, contains('*.jks'));
    });

    test('contains public product metadata', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();

      expect(pubspec, isNot(contains('A new Flutter project')));
      expect(manifest, contains('android:label="Arcanum"'));
    });

    test('uses one Android toolchain and official repositories', () {
      final rootGradle = File('android/build.gradle').readAsStringSync();
      final properties = File('android/gradle.properties').readAsStringSync();

      expect(rootGradle, isNot(contains('buildscript {')));
      expect(rootGradle, isNot(contains('mirrors.aliyun.com')));
      expect(rootGradle, contains('google()'));
      expect(rootGradle, contains('mavenCentral()'));
      expect(properties, contains('org.gradle.jvmargs=-Xmx2G'));
    });

    test('targets Android 16 for Google Play submissions', () {
      final gradle = File('android/app/build.gradle').readAsStringSync();

      expect(gradle, contains('compileSdk = 36'));
      expect(gradle, contains('targetSdkVersion = 36'));
    });
  });
}
