import 'package:flutter/material.dart';

class SenderoStep {
  const SenderoStep({
    required this.title,
    required this.body,
    required this.target,
    this.route,
    this.buttonLabel,
  });

  final String title;
  final String body;
  final String target;
  final String? route;
  final String? buttonLabel;
}

class SenderoJourney {
  const SenderoJourney({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.steps,
    this.version = 1,
    this.available = true,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final int version;
  final bool available;
  final List<SenderoStep> steps;
}

const senderoJourneys = <SenderoJourney>[
  SenderoJourney(
    id: 'orientation',
    title: 'Primer umbral',
    subtitle: 'Descubre la portada y las ayudas sobre la app',
    icon: Icons.explore_outlined,
    version: 3,
    steps: [
      SenderoStep(
        title: 'Elige una práctica',
        body: 'Toca Horóscopo en la portada. Cada mosaico abre una sección.',
        target: 'section_horoscopo',
        route: '/hoy',
      ),
      SenderoStep(
        title: 'Este es tu cielo de hoy',
        body:
            'Puedes abrir tu lectura si quieres. Antes de gastar cupo o créditos, verás una confirmación. También puedes seguir sin gastar.',
        target: 'horoscope_card',
        route: '/horoscopo',
        buttonLabel: 'Terminar sin gastar',
      ),
    ],
  ),
  SenderoJourney(
    id: 'cielo',
    title: 'Cielo',
    subtitle: 'Carta natal, tránsitos y hora planetaria',
    icon: Icons.wb_twilight_outlined,
    version: 2,
    steps: [
      SenderoStep(
        title: 'Mira tu carta',
        body: 'Toca «Tu carta» para ver el cielo del instante en que naciste.',
        target: 'cielo_toggle',
        route: '/hoy',
      ),
      SenderoStep(
        title: 'Una palabra, una ayuda',
        body: 'El signo ? explica tu carta sin sacarte de Cielo.',
        target: 'help',
        route: '/hoy',
      ),
    ],
  ),
  SenderoJourney(
    id: 'horoscopo',
    title: 'Horóscopo',
    subtitle: 'Una lectura diaria sobre tu propia carta',
    icon: Icons.brightness_4_outlined,
    version: 2,
    steps: [
      SenderoStep(
        title: 'Tu lectura tiene contexto',
        body: 'Abre la ayuda para conocer los tránsitos de tu carta.',
        target: 'help',
        route: '/horoscopo',
      ),
      SenderoStep(
        title: 'La lectura es tu decisión',
        body:
            'Abrir el sello puede gastar cupo diario o créditos. Puedes explorar sin gastarlos ahora.',
        target: 'horoscope_card',
        route: '/horoscopo',
        buttonLabel: 'Seguir sin gastar',
      ),
    ],
  ),
  SenderoJourney(
    id: 'grimorio',
    title: 'Grimorio',
    subtitle: 'Diario privado y pasajes guardados',
    icon: Icons.menu_book_outlined,
    version: 2,
    steps: [
      SenderoStep(
        title: 'Abre una página nueva',
        body: 'Toca la pluma. Nada se guarda hasta que tú lo decidas.',
        target: 'grimorio_new',
        route: '/grimorio',
      ),
    ],
  ),
  SenderoJourney(
    id: 'saber',
    title: 'Saber',
    subtitle: 'Plantas, correspondencias y obras clásicas',
    icon: Icons.local_library_outlined,
    version: 2,
    steps: [
      SenderoStep(
        title: 'De las plantas a los libros',
        body: 'Toca «Biblioteca» para explorar las obras y guardar pasajes.',
        target: 'saber_toggle',
        route: '/saber',
      ),
    ],
  ),
  SenderoJourney(
    id: 'oraculo',
    title: 'Oráculo',
    subtitle: 'Tarot, consulta y estudio del mazo',
    icon: Icons.style_outlined,
    version: 2,
    steps: [
      SenderoStep(
        title: 'Conoce el tarot',
        body:
            'Abre la ayuda. Luego puedes estudiar el mazo en «Aprender» o consultar; una tirada usa cupo diario o créditos.',
        target: 'help',
        route: '/oraculo',
      ),
      SenderoStep(
        title: 'Una tirada, solo si tú quieres',
        body:
            'Elige cartas y pregunta. Antes de tirar verás el coste y podrás cancelar sin gastar.',
        target: 'oracle_draw',
        route: '/oraculo',
        buttonLabel: 'Seguir sin gastar',
      ),
    ],
  ),
  SenderoJourney(
    id: 'fragmentos',
    title: 'Fragmentos Arcanos',
    subtitle: 'Tu recompensa de Sendero y el camino al crédito',
    icon: Icons.auto_awesome_outlined,
    steps: [
      SenderoStep(
        title: 'Tu práctica deja huella',
        body:
            'Cada lección de Sendero te entrega un Fragmento una sola vez. Estudiar cada carta del mazo también suma uno la primera vez. Aquí ves tu saldo real.',
        target: 'fragments_balance',
        route: '/fragmentos',
        buttonLabel: 'Entendido',
      ),
    ],
  ),
  SenderoJourney(
    id: 'account',
    title: 'Tu cuenta',
    subtitle: 'Perfil, permisos, privacidad y repetición',
    icon: Icons.shield_outlined,
    version: 2,
    steps: [
      SenderoStep(
        title: 'La cuenta vive en el menú',
        body: 'Ábrelo para encontrar perfil, ajustes y privacidad.',
        target: 'menu',
        route: '/hoy',
      ),
      SenderoStep(
        title: 'Tus decisiones están en Ajustes',
        body: 'Toca Ajustes. Sendero seguirá disponible cuando lo necesites.',
        target: 'settings',
      ),
    ],
  ),
];

SenderoJourney? senderoJourneyById(String id) {
  for (final journey in senderoJourneys) {
    if (journey.id == id) return journey;
  }
  return null;
}
