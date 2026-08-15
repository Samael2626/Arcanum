/// Los tres puentes opt-in entre el perfil privado de lectura y el resto
/// de la app.
///
/// No son el mismo puente. Tarot y Cielos se resuelven en memoria y no
/// sacan un solo byte del dispositivo. El Oraculo es una llamada de red a
/// un tercero: cruzarlo significa publicar texto en un servidor ajeno. Por
/// eso [leavesDevice] es parte del tipo y no un detalle de la UI: cualquier
/// pantalla que pinte un puente puede leer la consecuencia real sin
/// adivinarla.
enum ThresholdBridge {
  tarot(
    label: 'Tarot',
    consentCaption:
        'La resonancia de tu nombre acompana tus tiradas. Se resuelve en el '
        'telefono y no se envia a ningun servidor.',
    footnote: 'Acompana la tirada. No la interpreta: las cartas dicen lo que dicen.',
    leavesDevice: false,
  ),
  skies(
    label: 'Cielos',
    consentCaption:
        'La resonancia de tu nombre acompana tu carta natal. Se resuelve en '
        'el telefono y no se envia a ningun servidor.',
    footnote: 'Acompana la carta. No altera ningun calculo del cielo.',
    leavesDevice: false,
  ),
  oracle(
    label: 'Oraculo',
    consentCaption:
        'La lectura simbolica viaja al servidor junto a tu pregunta. No viaja '
        'tu nombre ni tu apellido, pero esa frase sale de una ficha del '
        'catalogo: quien tenga el catalogo podria deducir de cual. Los puentes '
        'de Tarot y Cielos no envian nada.',
    footnote:
        'Viaja con tu pregunta. Sugiere un eco; no afirma nada sobre quien pregunta.',
    leavesDevice: true,
  );

  const ThresholdBridge({
    required this.label,
    required this.consentCaption,
    required this.footnote,
    required this.leavesDevice,
  });

  /// Nombre del modulo al que cruza.
  final String label;

  /// Consecuencia literal de encenderlo, en la voz que lee la persona.
  final String consentCaption;

  /// Pie de la tarjeta de resonancia dentro de ese modulo.
  final String footnote;

  /// Si encenderlo publica texto fuera del dispositivo.
  final bool leavesDevice;
}
