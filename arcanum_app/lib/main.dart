import 'package:flutter/material.dart';

import 'core/router/app_router.dart';
import 'core/theme/arcanum_theme.dart';

void main() => runApp(const ArcanumApp());

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
