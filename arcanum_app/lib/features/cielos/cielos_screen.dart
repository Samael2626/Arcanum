import 'package:flutter/material.dart';

import '../../shared/widgets/coming_soon.dart';

class CielosScreen extends StatelessWidget {
  const CielosScreen({super.key});
  @override
  Widget build(BuildContext context) => const ComingSoon(
        glyph: '✶',
        title: 'Cielos',
        description:
            'Tu carta natal —planetas, casas y aspectos— y los tránsitos del cielo actual sobre ella.',
      );
}
