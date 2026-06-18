import 'package:flutter/material.dart';

import '../../shared/widgets/coming_soon.dart';

class OraculoScreen extends StatelessWidget {
  const OraculoScreen({super.key});
  @override
  Widget build(BuildContext context) => const ComingSoon(
        glyph: '⛤',
        title: 'Oráculo',
        description:
            'Tarot y consulta con la IA ritual, interpretados en el contexto de tu cielo.',
      );
}
