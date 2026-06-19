import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:arcanum_app/features/onboarding/application/onboarding_controller.dart';
import 'package:arcanum_app/features/onboarding/presentation/onboarding_screen.dart';

void main() {
  // Use an in-memory mock for SharedPreferences so the controller can read/write
  // without touching real storage.
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget wrap() => const ProviderScope(
        child: MaterialApp(home: OnboardingScreen()),
      );

  testWidgets('starts on welcome step and shows sigil + title',
      (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pump();
    expect(find.text('Bienvenido a tu grimorio'), findsOneWidget);
    expect(find.text('⛧'), findsOneWidget);
    expect(find.text('Comenzar'), findsOneWidget);
  });

  testWidgets('has no back button on the first step', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pump();
    // AppBar leading is null on step 0
    final back = find.byTooltip('Back');
    expect(back, findsNothing);
  });

  testWidgets('next advances step and back retreats it', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(onboardingProvider.notifier);
    expect(container.read(onboardingProvider).step, 0);
    notifier.next();
    expect(container.read(onboardingProvider).step, 1);
    notifier.next();
    expect(container.read(onboardingProvider).step, 2);
    notifier.back();
    expect(container.read(onboardingProvider).step, 1);
  });

  testWidgets('setters persist data into OnboardingData', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(onboardingProvider.notifier);

    await notifier.setDisplayName('Samael');
    final dob = DateTime(1990, 5, 12);
    await notifier.setBirthDate(dob);
    await notifier.setBirthTime('13:42');
    await notifier.setBirthPlace('Bogotá, Colombia');

    final data = container.read(onboardingProvider).data;
    expect(data.displayName, 'Samael');
    expect(data.birthDate, dob);
    expect(data.birthTime, '13:42');
    expect(data.birthPlace, 'Bogotá, Colombia');
  });

  testWidgets('finish flips onboarding_completed to true', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(onboardingProvider.notifier);

    expect(await notifier.isCompleted(), isFalse);
    await notifier.finish();
    expect(await notifier.isCompleted(), isTrue);
  });

  testWidgets('reset clears completion flag', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(onboardingProvider.notifier);

    await notifier.finish();
    expect(await notifier.isCompleted(), isTrue);
    await notifier.reset();
    expect(await notifier.isCompleted(), isFalse);
  });

  testWidgets('isLast is true on step 4', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final n = container.read(onboardingProvider.notifier);
    n.next();
    n.next();
    n.next();
    n.next();
    expect(container.read(onboardingProvider).step, 4);
    expect(container.read(onboardingProvider).isLast, isTrue);
    expect(container.read(onboardingProvider).isFirst, isFalse);
  });
}
