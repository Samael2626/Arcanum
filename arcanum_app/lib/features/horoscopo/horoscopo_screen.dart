/// El horoscopo con pantalla propia, sin robarle sitio a la barra de abajo.
///
/// La barra inferior sigue teniendo cinco destinos y ninguno cambia. Este vive
/// en una rama sin destino, a la que solo se llega por el boton flotante del
/// shell: asi el horoscopo gana protagonismo sin obligar a fusionar dos
/// secciones ni a apretar seis etiquetas en pantallas estrechas.
///
/// EL ORDEN ES EL PROTAGONISMO: primero el sello del regente (que ademas es lo
/// unico que se toca para generar), despues la banda del anio y por ultimo el
/// texto. `SkyTodayCard` ya compone exactamente ese orden y se reutiliza tal
/// cual: escribir una segunda pieza que pidiera los mismos endpoints y pintara
/// lo mismo seria garantizar que las dos se separen a la primera correccion.
library;

import 'package:flutter/material.dart';

import '../../core/theme/arcanum_colors.dart';
import '../../core/theme/arcanum_theme.dart';
import '../hoy/presentation/widgets/sky_today_card.dart';

class HoroscopoScreen extends StatelessWidget {
  const HoroscopoScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    body: ListView(
      // El hueco de abajo es el del boton flotante: sin el, la ultima linea
      // del texto queda debajo del boton en las pantallas cortas.
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: const [
        _Entradilla(),
        SizedBox(height: 14),
        SkyTodayCard(),
      ],
    ),
  );
}

/// Una linea que dice de que va esto antes de que la persona toque nada.
class _Entradilla extends StatelessWidget {
  const _Entradilla();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Text(
      'Tu cielo de hoy, leído sobre tu carta natal: el tránsito que aprieta, '
      'el año que gobierna y lo que eso dice hoy.',
      style: ArcanumText.body(13, color: ArcanumColors.ivoryMuted),
    ),
  );
}
