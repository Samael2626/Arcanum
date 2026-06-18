import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/arcanum_theme.dart';

void main() => runApp(const ProviderScope(child: ArcanumApp()));

class ArcanumApp extends StatelessWidget {
  const ArcanumApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp.router(
        title: 'ARCANUM',
        debugShowCheckedModeBanner: false,
        theme: buildArcanumTheme(),
        routerConfig: appRouter,
      );
}
