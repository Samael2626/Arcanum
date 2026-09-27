/// Lore de las ocho fases lunares, una ficha por fase.
///
/// POR QUE HACE FALTA, si ya existe `glossary['luna']`. Esa entrada explica el
/// CICLO entero en dos lineas ("creciente atrae, menguante destierra"), que es
/// lo que necesita un boton "?" generico. Lo que no resuelve es lo que la nota
/// al pie del horoscopo y del Oraculo nombra en concreto: "luna llena
/// menguante" subrayado y tocable. Al tocarlo hace falta la ficha de ESA fase,
/// no la del ciclo.
///
/// LAS CLAVES SON LAS DEL BACKEND, a proposito: `lunar_calendar._PHASES`
/// reparte los 360 grados de elongacion en ocho tramos de 45 y devuelve el
/// `phase_slug`. Si aqui se inventara otra particion --las cuatro fases de
/// toda la vida, por ejemplo-- la mitad de los dias caeria en una fase sin
/// ficha y el subrayado dorado abriria un hueco. `moon_phase_lore_test` lo
/// vigila.
///
/// LA DOCTRINA NO ES NUEVA. Sale de donde ya estaba escrita en la app, en el
/// lore de la Luna de `hoy_lore.dart`: "creciente atrae y edifica; menguante
/// destierra y disuelve. Los talismanes se cargan en plata bajo su luz". Cada
/// ficha reparte esa regla por su tramo del ciclo; ninguna la contradice.
///
/// `full` y `new` son los dos unicos tramos AMBIGUOS en direccion: abarcan 45
/// grados a caballo del punto exacto, asi que pueden salir creciente o
/// menguante segun `MoonInfo.is_waxing`. Por eso sus fichas hablan del momento
/// y no de la direccion, y quien las muestre puede anadir la palabra.
library;

/// Una fase del ciclo, en las tres piezas que la pantalla necesita.
class MoonPhaseLore {
  /// Como se nombra en pantalla. Coincide con el `phase_name` del backend.
  final String titulo;

  /// Que es y que ensena esta fase. Primero lo que se ve, luego lo que
  /// significa: quien lee puede no haber mirado la Luna en su vida.
  final String descripcion;

  /// Que se hace con ella. Es lo unico que convierte la ficha en instrumento
  /// y no en enciclopedia, y por eso es obligatorio.
  final String practica;

  /// Para que se presta, en pocas palabras. Mismo papel que `planetFavors`.
  final String favorece;

  const MoonPhaseLore({
    required this.titulo,
    required this.descripcion,
    required this.practica,
    required this.favorece,
  });
}

const Map<String, MoonPhaseLore> moonPhaseLore = {
  'new': MoonPhaseLore(
    titulo: 'Luna Nueva',
    descripcion:
        'No hay luz que ver: la Luna va por el mismo sitio que el Sol y su cara '
        'oscura es la que mira a la Tierra. Es el único momento del ciclo en '
        'que no hay nada que mirar.\n\n'
        'Es el comienzo antes del comienzo, la semilla todavía bajo tierra. Lo '
        'que se decide aquí no se ve, y por eso nadie lo discute todavía — '
        'tampoco tú.',
    practica:
        'Siembra la intención y cállatela. Se empieza lo que aún no tiene '
        'forma, y no se enseña ni se somete a juicio: una intención contada el '
        'primer día se gasta en contarla. No es día de cerrar tratos ni de '
        'exhibir nada.',
    favorece: 'sembrar intención, empezar en privado, ayuno, retiro',
  ),
  'waxing_crescent': MoonPhaseLore(
    titulo: 'Creciente',
    descripcion:
        'La primera uña de luz, visible al atardecer y poco rato. Ya hay algo '
        'que ver, y es poco.\n\n'
        'Lo que sembraste asoma. Tiene la fragilidad de todo lo que acaba de '
        'salir: se sostiene si lo alimentas y se pierde si le pides que ya '
        'rinda.',
    practica:
        'Da el primer paso visible y aliméntalo. Una llamada, una línea '
        'escrita, un trámite. Lo que no se hace es exigirle resultados a algo '
        'que lleva tres días en pie.',
    favorece: 'primeros pasos, atraer, alimentar lo recién empezado',
  ),
  'first_quarter': MoonPhaseLore(
    titulo: 'Cuarto Creciente',
    descripcion:
        'Media Luna exacta, creciendo. La luz y la sombra reparten la cara a '
        'partes iguales.\n\n'
        'Es la primera resistencia del ciclo: lo empezado se topa con algo que '
        'no había previsto. No es señal de que vaya mal — es la mitad del '
        'camino, donde se ve el coste real.',
    practica:
        'Empuja contra el obstáculo, decide y sostén la decisión. Aquí se '
        'abandona lo que se iba a abandonar de todos modos, así que si sigues, '
        'sigue en firme.',
    favorece: 'decisión, empuje, sostener lo empezado bajo presión',
  ),
  'waxing_gibbous': MoonPhaseLore(
    titulo: 'Gibosa Creciente',
    descripcion:
        'Casi llena, abombada, y todavía subiendo. Le falta poco y se nota.\n\n'
        'Es el tramo impaciente del ciclo: lo que hiciste ya está casi, y '
        'justo por eso tienta rehacerlo entero.',
    practica:
        'Afina, corrige y pule lo que ya está en pie. Lo que no se hace es '
        'cambiar el plan: a tres días del final, rehacer es empezar otra vez.',
    favorece: 'ajustar, revisar, perfeccionar, ensayar',
  ),
  'full': MoonPhaseLore(
    titulo: 'Luna Llena',
    descripcion:
        'Toda la cara iluminada, enfrente del Sol, de un horizonte al otro '
        'durante la noche entera. Es el pico de luz del ciclo.\n\n'
        'Con la luz entera se ve lo que estaba a oscuras, y no siempre es lo '
        'que esperabas mirar. Es fase de culminación y de revelación, no de '
        'arranque.',
    practica:
        'Mira lo que ha salido a la vista y no lo apartes. Es el momento de '
        'cargar los talismanes en plata bajo su luz, y de la adivinación. No '
        'se empieza nada que necesite crecer: a partir de mañana, la corriente '
        'va en contra.',
    favorece: 'culminar, cargar talismanes, adivinación, ver lo oculto',
  ),
  'waning_gibbous': MoonPhaseLore(
    titulo: 'Gibosa Menguante',
    descripcion:
        'Todavía abombada, pero ya devolviendo luz. Sale tarde y se queda '
        'hasta la mañana.\n\n'
        'Empieza la mitad que quita. Lo que la Luna llena te enseñó ya lo '
        'sabes: ahora toca hacer algo con ello en vez de seguir mirándolo.',
    practica:
        'Cuenta, enseña y devuelve. Es el tramo de agradecer, de dar lo que '
        'sobra y de soltar el primer peso — el fácil, el que ya sabías que '
        'sobraba.',
    favorece: 'agradecer, compartir, enseñar, soltar lo evidente',
  ),
  'last_quarter': MoonPhaseLore(
    titulo: 'Cuarto Menguante',
    descripcion:
        'Media Luna exacta otra vez, ahora de bajada. La mitad iluminada es la '
        'contraria que en cuarto creciente.\n\n'
        'Es el corte del ciclo. En cuarto creciente se decidía seguir; aquí se '
        'decide dejar, y cuesta lo mismo.',
    practica:
        'Corta lo que ya no. Rompe el hábito, cierra la cuenta, termina la '
        'conversación que llevas meses aplazando. El destierro hecho aquí no '
        'necesita fuerza: va a favor de la corriente.',
    favorece: 'cortar, desterrar, romper hábitos, cerrar cuentas',
  ),
  'waning_crescent': MoonPhaseLore(
    titulo: 'Menguante',
    descripcion:
        'La última uña de luz, visible solo de madrugada y poco rato. Casi '
        'nada, y a punto de no haber nada.\n\n'
        'Es el descanso antes de la Luna Nueva. El ciclo ya dio lo que tenía '
        'que dar y lo único que queda por hacer es dejar sitio.',
    practica:
        'Limpia y descansa. Barrido, baño de sal, ayuno, tirar lo que no se '
        'usa. No se empieza nada: lo que arranque estos días arranca sin luz '
        'que lo sostenga.',
    favorece: 'limpieza, destierro, descanso, vaciar',
  ),
};

/// La ficha de una fase, o `null` si el slug no está cubierto.
///
/// Devuelve `null` en vez de una ficha de relleno a propósito: quien pinta el
/// término subrayado tiene que poder NO subrayarlo. Un subrayado dorado que al
/// tocarlo no abre nada es peor que no subrayar.
MoonPhaseLore? moonPhaseLoreOf(String? slug) =>
    slug == null ? null : moonPhaseLore[slug];
