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

import '../hoy/presentation/widgets/sky_today_card.dart';
import 'widgets/agenda_del_cielo.dart';
import 'widgets/historial_horoscopo.dart';

class HoroscopoScreen extends StatelessWidget {
  const HoroscopoScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: const [
        // SIN ENTRADILLA, desde el 12-sep-2026. Decia "Tu cielo de hoy, leido
        // sobre tu carta natal: el transito que aprieta, el anio que gobierna
        // y lo que eso dice hoy" -- justo debajo del subtitulo de la barra,
        // que dice "Tu cielo de hoy, sobre tu carta". La misma idea estirada,
        // dos veces seguidas. Se escribio cuando la seccion no tenia subtitulo
        // visible.
        SkyTodayCard(),
        // La agenda va justo detras del dia: se lee "hoy, y luego esto".
        AgendaDelCielo(),
        // El archivo va DEBAJO del de hoy y plegado: se viene a leer el de
        // hoy, y mirar atras es una segunda intencion.
        HistorialHoroscopo(),
      ],
    ),
  );
}

