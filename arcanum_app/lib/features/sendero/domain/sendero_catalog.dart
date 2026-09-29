import 'package:flutter/material.dart';

class SenderoStep {
  const SenderoStep({
    required this.title,
    required this.body,
    this.route,
    this.creditNotice = false,
  });

  final String title;
  final String body;
  final String? route;
  final bool creditNotice;
}

class SenderoJourney {
  const SenderoJourney({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.steps,
    this.version = 1,
  });

  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final int version;
  final List<SenderoStep> steps;
}

const senderoJourneys = <SenderoJourney>[
  SenderoJourney(
    id: 'orientation',
    title: 'Primer umbral',
    subtitle: 'Orientación y libertad de movimiento',
    icon: Icons.explore_outlined,
    steps: [
      SenderoStep(
        title: 'Nada te encierra',
        body:
            'Sendero acompaña, no manda. Puedes cerrar, pausar o repetir cualquier guía cuando quieras.',
      ),
      SenderoStep(
        title: 'Las cinco cámaras',
        body:
            'El menú abre Cielo, Horóscopo, Grimorio, Saber y Oráculo. Tu perfil, ajustes y privacidad viven debajo.',
        route: '/hoy',
      ),
      SenderoStep(
        title: 'Las marcas de ayuda',
        body:
            'Cuando veas un signo de interrogación, tócalo. Explica el concepto sin sacarte de tu práctica.',
      ),
    ],
  ),
  SenderoJourney(
    id: 'cielo',
    title: 'Cielo',
    subtitle: 'Carta natal, tránsitos y hora planetaria',
    icon: Icons.wb_twilight_outlined,
    steps: [
      SenderoStep(
        title: 'Tu mapa natal',
        body:
            'Cielo conserva la figura del instante en que naciste. Tu fecha, hora y lugar determinan el mapa.',
        route: '/hoy',
      ),
      SenderoStep(
        title: 'Lo que toca hoy',
        body:
            'Los tránsitos muestran la relación entre el cielo actual y tu carta. La hora planetaria depende de tu lugar actual.',
        route: '/hoy',
      ),
    ],
  ),
  SenderoJourney(
    id: 'horoscopo',
    title: 'Horóscopo',
    subtitle: 'Una lectura diaria sobre tu propia carta',
    icon: Icons.brightness_4_outlined,
    steps: [
      SenderoStep(
        title: 'No es un texto por signo',
        body:
            'La lectura nace de tus tránsitos reales. El sello muestra primero el cielo; abrirlo revela la interpretación.',
        route: '/horoscopo',
      ),
      SenderoStep(
        title: 'Antes de consumir',
        body:
            'Generar una lectura nueva puede usar tu cupo diario o créditos. ARCANUM debe advertírtelo antes; tú decides.',
        route: '/horoscopo',
        creditNotice: true,
      ),
    ],
  ),
  SenderoJourney(
    id: 'grimorio',
    title: 'Grimorio',
    subtitle: 'Diario privado y pasajes guardados',
    icon: Icons.menu_book_outlined,
    steps: [
      SenderoStep(
        title: 'Tu cámara privada',
        body:
            'Escribe observaciones, sueños y prácticas. El contenido personal se cifra antes de salir del dispositivo.',
        route: '/grimorio',
      ),
      SenderoStep(
        title: 'Pasajes que regresan',
        body:
            'Desde Saber puedes guardar fragmentos de una obra y encontrarlos después junto a tus notas.',
        route: '/grimorio/pasajes',
      ),
    ],
  ),
  SenderoJourney(
    id: 'saber',
    title: 'Saber',
    subtitle: 'Plantas, correspondencias y obras clásicas',
    icon: Icons.local_library_outlined,
    steps: [
      SenderoStep(
        title: 'Materia y biblioteca',
        body:
            'Explora correspondencias tradicionales o entra en una obra. Tu posición de lectura se conserva.',
        route: '/saber',
      ),
      SenderoStep(
        title: 'Leer con memoria',
        body:
            'Marca la página estable, guarda un pasaje y añade una nota cifrada. Así una lectura se vuelve práctica.',
        route: '/saber',
      ),
    ],
  ),
  SenderoJourney(
    id: 'oraculo',
    title: 'Oráculo',
    subtitle: 'Tarot, consulta y estudio del mazo',
    icon: Icons.style_outlined,
    steps: [
      SenderoStep(
        title: 'Elige la vía',
        body:
            'Puedes tirar cartas, formular una pregunta o estudiar el mazo. La consulta interpreta; no reemplaza tu juicio.',
        route: '/oraculo',
      ),
      SenderoStep(
        title: 'Toda tirada tiene peso',
        body:
            'Una tirada puede usar cupo diario o créditos según su tamaño. Revisa el coste y acéptalo antes de confirmar.',
        route: '/oraculo',
        creditNotice: true,
      ),
    ],
  ),
  SenderoJourney(
    id: 'fragmentos',
    title: 'Fragmentos Arcanos',
    subtitle: 'Huella de una práctica real',
    icon: Icons.auto_awesome_outlined,
    steps: [
      SenderoStep(
        title: 'No son un premio por mirar',
        body:
            'Los Fragmentos reconocen prácticas válidas dentro de ARCANUM. Sendero los presenta, pero nunca fabrica saldo.',
      ),
      SenderoStep(
        title: 'Una sola huella',
        body:
            'Repetir una guía no repite recompensas. Cuando una práctica otorgue Fragmentos, verás la razón y el movimiento.',
      ),
    ],
  ),
  SenderoJourney(
    id: 'account',
    title: 'Tu cuenta',
    subtitle: 'Perfil, permisos, privacidad y repetición',
    icon: Icons.shield_outlined,
    steps: [
      SenderoStep(
        title: 'Tú conservas el mando',
        body:
            'En Ajustes revisas permisos y cuenta. En Privacidad encuentras el uso de datos y sus controles.',
        route: '/settings',
      ),
      SenderoStep(
        title: 'Regresa cuando quieras',
        body:
            'Sendero queda disponible en el menú y en Ajustes. Repetir una guía no borra tu avance.',
        route: '/settings',
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
