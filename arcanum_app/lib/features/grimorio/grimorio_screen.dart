import 'package:flutter/material.dart';

import '../../shared/widgets/coming_soon.dart';

class GrimorioScreen extends StatelessWidget {
  const GrimorioScreen({super.key});
  @override
  Widget build(BuildContext context) => const ComingSoon(
        glyph: '❦',
        title: 'Grimorio',
        description:
            'Tu libro personal de rituales y lecturas, cifrado de extremo a extremo.',
      );
}
