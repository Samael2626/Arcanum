import 'package:flutter/material.dart';

import '../../shared/widgets/coming_soon.dart';

class ArteScreen extends StatelessWidget {
  const ArteScreen({super.key});
  @override
  Widget build(BuildContext context) => const ComingSoon(
        glyph: '⚗',
        title: 'Arte',
        description:
            'Materia Arcana: hierbas, piedras, inciensos y metales, con sus correspondencias.',
      );
}
