import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/arcanum_api.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/theme/arcanum_colors.dart';
import '../../core/theme/arcanum_theme.dart';
import '../../shared/astro_symbols.dart';
import '../../shared/widgets/arcanum_card.dart';
import '../../shared/widgets/gold_button.dart';

// ── Datos esotéricos de los 12 signos ──────────────────────────────────────

class _SignLore {
  final String elemento;
  final String polaridad;
  final String regente;
  final String descripcion;
  final List<String> correspondencias;
  const _SignLore({
    required this.elemento,
    required this.polaridad,
    required this.regente,
    required this.descripcion,
    required this.correspondencias,
  });
}

const Map<String, _SignLore> _signLore = {
  'aries': _SignLore(
    elemento: 'Fuego',
    polaridad: 'Positivo (Masculino)',
    regente: 'Marte',
    descripcion:
        'Aries es el primer signo del zodíaco, el impulso primigenio que '
        'rompe el silencio del invierno. Agrippa lo vincula al ariete del '
        'sacrificio: la fuerza que franquea los umbrales sin vacilar. Su '
        'fuego es cardinal, origen, voluntad pura sin forma todavía.\n\n'
        'Culpeper le atribuye gobierno sobre la cabeza, el rostro y el '
        'cerebro. Las plantas de Marte en Aries poseen espinas, sabor acre '
        'o propiedades febrífugas: estimulan la sangre y la acción. Son '
        'hierbas de iniciación, no de contemplación.\n\n'
        'En la práctica mágica, Aries favorece ritos de comienzo, ruptura '
        'de obstáculos, coraje y protección activa. La Hora de Marte en '
        'domingo o martes amplifica estas corrientes. Los trabajos bajo '
        'este signo no esperan: se ejecutan en el instante de máxima resolución.',
    correspondencias: [
      'Plantas: ortiga, aloe, cebolla, ajo silvestre, romero',
      'Piedras: rubí, cornalina, diamante',
      'Metal: hierro',
      'Inciensos: incienso de dragón, benjuí, pimienta negra',
      'Color: rojo escarlata',
    ],
  ),
  'taurus': _SignLore(
    elemento: 'Tierra',
    polaridad: 'Negativo (Femenino)',
    regente: 'Venus',
    descripcion:
        'Tauro es la Tierra hecha sensación: lo que se puede tocar, oler, '
        'saborear y poseer. Agrippa lo asocia al toro de los misterios '
        'de Mitra, guardián del mundo material y de sus riquezas ocultas. '
        'Su naturaleza fija ancla el poder en lo concreto.\n\n'
        'Las hierbas de Venus en Tauro son aromáticas, dulces o afrodisíacas: '
        'tomillo, mirto, rosa, violeta. Culpeper las destina a fortalecer '
        'el corazón y la garganta, órganos que Tauro rige según la anatomía '
        'astrológica clásica.\n\n'
        'En magia, Tauro gobierna prosperidad, amor encarnado, fertilidad '
        'de la tierra y resistencia. Los talismanes de Tauro se labran en '
        'cobre o plata bajo Luna creciente en tierra fértil; duran porque '
        'su poder radica en la permanencia, no en el destello.',
    correspondencias: [
      'Plantas: rosa, mirto, tomillo, verbena, tomillo silvestre',
      'Piedras: esmeralda, malaquita, lapislázuli',
      'Metal: cobre',
      'Inciensos: sándalo, rosa, patchouli',
      'Color: verde y rosa',
    ],
  ),
  'gemini': _SignLore(
    elemento: 'Aire',
    polaridad: 'Positivo (Masculino)',
    regente: 'Mercurio',
    descripcion:
        'Géminis es el signo de la doble naturaleza, el mensajero entre '
        'los mundos. Agrippa lo vincula a los Dioscuros, los gemelos '
        'divinos que median entre la muerte y la vida, entre lo visible '
        'y lo invisible. Su modalidad mutable lo convierte en el más ágil '
        'de los signos de aire.\n\n'
        'Culpeper le asigna los pulmones, los brazos y los nervios. Las '
        'hierbas de Mercurio en Géminis actúan sobre el sistema nervioso '
        'y el intelecto: lavanda, helécho, perejil, mejorana. Son plantas '
        'de palabras, de viajes mentales y de comunicación con los espíritus.\n\n'
        'En la práctica oculta, Géminis rige los oráculos, la escritura '
        'automática, el aprendizaje acelerado y los pactos verbales. La '
        'Luna en Géminis favorece el scrying y la consulta a entidades '
        'del aire. Los sigilos se trazan en dos tiempos, como los dos '
        'rostros del gemelo.',
    correspondencias: [
      'Plantas: lavanda, helécho, perejil, mejorana, anís',
      'Piedras: ágata, citrino, alejandrita',
      'Metal: mercurio (azogue), plata',
      'Inciensos: lavanda, benjuí, mastix',
      'Color: amarillo, gris perla',
    ],
  ),
  'cancer': _SignLore(
    elemento: 'Agua',
    polaridad: 'Negativo (Femenino)',
    regente: 'Luna',
    descripcion:
        'Cáncer es el signo de las profundidades, de la memoria ancestral '
        'y del vientre primordial. Agrippa lo asocia al cangrejo que habita '
        'en la zona entre lo terrestre y lo acuático, guardián del umbral '
        'entre los vivos y los muertos.\n\n'
        'La Luna rige Cáncer y, a través de él, todo cuanto crece bajo '
        'el suelo: bulbos, raíces y las plantas blancas o acuosas que '
        'Culpeper destina al estómago y al pecho. Sauce, lirio de agua, '
        'amapola blanca, madreselva.\n\n'
        'En magia, Cáncer rige los lazos familiares, la protección del '
        'hogar, los sueños proféticos y la memoria. Los ritos lunares '
        'funcionan con especial potencia cuando la Luna transita su propio '
        'domicilio. Los talismanes se cargan sumergidos en agua bajo Luna '
        'llena.',
    correspondencias: [
      'Plantas: sauce, lirio blanco, amapola, madreselva, aloe',
      'Piedras: perla, piedra de luna, calcita blanca',
      'Metal: plata',
      'Inciensos: mirra, sándalo blanco, jazmín',
      'Color: blanco nacarado, plata',
    ],
  ),
  'leo': _SignLore(
    elemento: 'Fuego',
    polaridad: 'Positivo (Masculino)',
    regente: 'Sol',
    descripcion:
        'Leo es la expresión más plena del principio solar: luz que ilumina '
        'sin pedir permiso, voluntad que se convierte en orden del cosmos. '
        'Agrippa lo vincula al corazón de la bestia celeste, centro del '
        'ser donde reside el fuego vital.\n\n'
        'Las hierbas del Sol en Leo son amarillas, doradas o de poder '
        'fortísimo: girasol, laurel, angélica, azafrán. Culpeper las '
        'destina al corazón, la columna vertebral y los ojos. Fortalecen '
        'la voluntad y la vitalidad cuando el cuerpo flaquea.\n\n'
        'En la práctica mágica, Leo rige el poder personal, el éxito '
        'visible, la autoridad y la protección solar. Los ritos de Leo '
        'se ejecutan al mediodía del domingo, Hora del Sol. Los talismanes '
        'se graban en oro o en latón dorado y se cargan bajo el sol del '
        'mediodía.',
    correspondencias: [
      'Plantas: laurel, girasol, angélica, azafrán, romero dorado',
      'Piedras: rubí, cornalina dorada, ámbar',
      'Metal: oro',
      'Inciensos: incienso, mirra, áloe vera quemado',
      'Color: dorado, naranja solar',
    ],
  ),
  'virgo': _SignLore(
    elemento: 'Tierra',
    polaridad: 'Negativo (Femenino)',
    regente: 'Mercurio',
    descripcion:
        'Virgo es la Tierra que discierne: el signo del análisis, de la '
        'clasificación de las hierbas y del servicio al orden cósmico. '
        'Agrippa lo asocia a Deméter con su gavilla, la diosa que conoce '
        'cada semilla por su nombre y su virtud.\n\n'
        'Culpeper asigna a Virgo el intestino delgado y el sistema '
        'digestivo. Las plantas de Mercurio en Virgo son las del herbolario '
        'analítico: lavanda, eneldo, helecho, regaliz, fumaria. '
        'Purifican, clasifican, separan lo útil de lo inútil.\n\n'
        'En magia, Virgo rige la preparación ritual, la purificación, '
        'los talismanes herbales y la curación. Es el signo del mago '
        'artesano: los ritos de Virgo son meticulosos, lentos y de '
        'efecto duradero. La Luna en Virgo favorece limpiezas, destierros '
        'y elaboración de aceites y polvos.',
    correspondencias: [
      'Plantas: lavanda, eneldo, helecho, regaliz, menta',
      'Piedras: sardónice, jade, ágata musgo',
      'Metal: mercurio (azogue), platino',
      'Inciensos: lavanda, olíbano, hierbas secas molidas',
      'Color: verde oliva, beige terroso',
    ],
  ),
  'libra': _SignLore(
    elemento: 'Aire',
    polaridad: 'Positivo (Masculino)',
    regente: 'Venus',
    descripcion:
        'Libra es la balanza de la justicia cósmica y el principio de '
        'la armonía entre opuestos. Agrippa lo vincula a Astrea, la '
        'diosa de la justicia que sostenía las estrellas en equilibrio '
        'antes de retirarse al cielo.\n\n'
        'Las plantas de Venus en Libra son las del diplomático: '
        'violeta, frambuesa, naranja dulce, verbena. Culpeper las '
        'dirige a los riñones y las caderas, sede del equilibrio '
        'corporal. Equilibran los humores y suavizan la dureza.\n\n'
        'En la práctica oculta, Libra rige los pactos, los rituales '
        'de reconciliación, la justicia y las relaciones elegidas. '
        'Los trabajos de Libra requieren dos participantes o dos '
        'elementos en tensión. El altar de Libra lleva siempre '
        'dos velas iguales, una a cada lado de la balanza.',
    correspondencias: [
      'Plantas: violeta, frambuesa, menta dulce, verbena, narciso',
      'Piedras: ópalo, turmalina rosada, crisoberilo',
      'Metal: cobre, bronce',
      'Inciensos: rosa, sándalo dulce, ylang-ylang',
      'Color: azul pastel, rosa empolvado',
    ],
  ),
  'scorpio': _SignLore(
    elemento: 'Agua',
    polaridad: 'Negativo (Femenino)',
    regente: 'Marte',
    descripcion:
        'Escorpio es el signo de la transformación radical: el veneno '
        'que mata y que sana, la muerte que precede al renacimiento. '
        'Agrippa lo vincula al escorpión que guardaba las puertas del '
        'inframundo en la astronomía babilónica.\n\n'
        'Culpeper le asigna los órganos reproductores y la vesícula. '
        'Las plantas de Marte en Escorpio son las de la transformación '
        'y la frontera: acónito (venenoso — peligro mortal), artemisa, '
        'aloes amargos, diente de dragón. Son hierbas de umbral, no '
        'de uso cotidiano.\n\n'
        'En magia, Escorpio rige la necromancia, los ritos de paso, '
        'la sexualidad sagrada y el destierro profundo. Los trabajos '
        'de Escorpio son los más potentes y los más peligrosos: '
        'requieren purificación rigurosa antes y después. La Luna '
        'en Escorpio es la más mágica y la más exigente.',
    correspondencias: [
      'Plantas: artemisa, aloes amargos, cactus, ortiga, raíz de galangal',
      'Piedras: obsidiana, granate, turmalina negra',
      'Metal: hierro, acero',
      'Inciensos: mirra, incienso negro, opopónax',
      'Color: negro, carmesí oscuro',
    ],
  ),
  'sagittarius': _SignLore(
    elemento: 'Fuego',
    polaridad: 'Positivo (Masculino)',
    regente: 'Júpiter',
    descripcion:
        'Sagitario es el arquero centauro que apunta más allá del '
        'horizonte visible. Agrippa lo asocia a Quirón, el sabio '
        'maestro que unía la naturaleza animal y la filosofía divina '
        'en un solo ser.\n\n'
        'Las plantas de Júpiter en Sagitario son expansivas, jugosas '
        'y de gran porte: bálsamo de Judea, roble, higo, musgo de '
        'roble. Culpeper las asigna a los muslos y el hígado, sede '
        'del fuego digestivo y de la alegría.\n\n'
        'En la práctica mágica, Sagitario rige la expansión, '
        'la búsqueda de sabiduría, los viajes iniciáticos y la '
        'prosperidad filosófica. Los ritos de Sagitario invocan '
        'al maestro interior y a las energías de Júpiter cuando '
        'transita su domicilio. Los talismanes se elaboran en '
        'estaño bajo el arco de mediodía.',
    correspondencias: [
      'Plantas: higo, roble, bálsamo, nuez, clavo de olor',
      'Piedras: topacio azul, amatista, turquesa',
      'Metal: estaño',
      'Inciensos: cáscara de naranja, canela, cedro',
      'Color: azul royal, púrpura',
    ],
  ),
  'capricorn': _SignLore(
    elemento: 'Tierra',
    polaridad: 'Negativo (Femenino)',
    regente: 'Saturno',
    descripcion:
        'Capricornio es la cima de la montaña: el signo del esfuerzo '
        'sostenido, de la estructura que dura más que sus creadores. '
        'Agrippa lo vincula al dios-pez Pan-Cronos, la figura que '
        'unía el tiempo con el mundo material.\n\n'
        'Las hierbas de Saturno en Capricornio son amargas, lentas '
        'y persistentes: belladona (venenosa — peligro mortal), '
        'consuelda, milenrama, ciprés. Culpeper las destina a los '
        'huesos, las rodillas y la piel. Forman lentamente, '
        'pero forman para siempre.\n\n'
        'En magia, Capricornio rige los límites, el tiempo como '
        'aliado, las estructuras de largo plazo y el trabajo de '
        'los ancestros. Los ritos de Saturno se ejecutan en sábado, '
        'en horas frías, con materiales negros o plomizos. '
        'No piden rápido: piden permanente.',
    correspondencias: [
      'Plantas: ciprés, consuelda, milenrama, abeto, tejo',
      'Piedras: ónix, obsidiana, turmalina negra, azabache',
      'Metal: plomo',
      'Inciensos: mirra, benjuí, madera de cedro oscuro',
      'Color: negro, gris carbón',
    ],
  ),
  'aquarius': _SignLore(
    elemento: 'Aire',
    polaridad: 'Positivo (Masculino)',
    regente: 'Saturno',
    descripcion:
        'Acuario es el portador de agua que no bebe: vierte el '
        'conocimiento sobre la humanidad desde fuera del tiempo. '
        'Agrippa lo vincula al Ángel que derrama el agua celeste '
        'sobre los campos, símbolo del espíritu que transmite '
        'sin poseer.\n\n'
        'Las plantas de Saturno en Acuario son las de la ruptura '
        'y la renovación: olmo, endrino, regaliz negro. Culpeper '
        'les asigna las pantorrillas, los tobillos y el sistema '
        'circulatorio. Actúan sobre flujos: de sangre, de información, '
        'de corrientes ocultas.\n\n'
        'En la práctica mágica, Acuario rige la ruptura de cadenas, '
        'los trabajos de colectivo y los contactos con entidades '
        'no-humanas. Los ritos de Acuario son los más impersonales '
        'de todos: su poder viene de la visión de conjunto, no del '
        'deseo individual. La Hora de Saturno el sábado abre '
        'sus canales más profundos.',
    correspondencias: [
      'Plantas: olmo, endrino, regaliz, espino, cuasia',
      'Piedras: amatista, zafiro, labradorita',
      'Metal: plomo, aluminio',
      'Inciensos: benzoin, mirra fría, incienso planetario de Saturno',
      'Color: violeta eléctrico, azul índigo',
    ],
  ),
  'pisces': _SignLore(
    elemento: 'Agua',
    polaridad: 'Negativo (Femenino)',
    regente: 'Júpiter',
    descripcion:
        'Piscis es el último signo: el océano sin orillas donde todo '
        'regresa a su origen. Agrippa lo vincula a los dos peces '
        'atados por un hilo de luz que tira en direcciones opuestas: '
        'el alma entre lo espiritual y lo carnal.\n\n'
        'Las plantas de Júpiter en Piscis son las de la disolución '
        'y el trance: nenúfar, musgo de pantano, valeriana, '
        'sauce llorón. Culpeper las asigna a los pies y al sistema '
        'linfático. Ablandan los bordes, inducen el sueño '
        'y la apertura psíquica.\n\n'
        'En magia, Piscis rige la adivinación, los sueños proféticos, '
        'el trabajo con los muertos y la disolución del ego antes '
        'de una iniciación. Es el signo de la magia más difícil '
        'de sostener y la más profunda cuando se logra. '
        'Los talismanes de Piscis se sumergen en agua de mar '
        'bajo la Luna llena.',
    correspondencias: [
      'Plantas: nenúfar, valeriana, sauce, musgo de pantano, loto',
      'Piedras: aguamarina, piedra de luna, amatista suave',
      'Metal: estaño, plata',
      'Inciensos: ámbar gris, jazmín nocturno, sándalo marino',
      'Color: verde agua, violeta pálido',
    ],
  ),
};

// ── Widget: tarjeta del signo solar ────────────────────────────────────────

class _SunSignCard extends StatelessWidget {
  final String signKey; // 'aquarius', 'gemini', etc.
  const _SunSignCard({required this.signKey});

  void _openModal(BuildContext context) {
    final lore = _signLore[signKey];
    if (lore == null) return;
    final signName = signEs[signKey] ?? signKey;
    final glyph = signGlyph[signKey] ?? '✶';

    showModalBottomSheet(
      context: context,
      backgroundColor: ArcanumColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(28, 18, 28, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: ArcanumColors.goldMuted,
                        borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 20),
              // Cabecera: glifo + nombre del signo
              Row(
                children: [
                  Text(glyph,
                      style: const TextStyle(
                          fontSize: 36, color: ArcanumColors.gold)),
                  const SizedBox(width: 14),
                  Text(signName,
                      style: ArcanumText.heading(30, color: ArcanumColors.gold)),
                ],
              ),
              const SizedBox(height: 20),
              // Atributos fundamentales
              _modalRow('ELEMENTO', lore.elemento),
              const SizedBox(height: 10),
              _modalRow('POLARIDAD', lore.polaridad),
              const SizedBox(height: 10),
              _modalRow('REGENTE', lore.regente),
              const SizedBox(height: 22),
              // Descripción esotérica
              Text('NATURALEZA', style: ArcanumText.label()),
              const SizedBox(height: 10),
              Text(lore.descripcion,
                  style: ArcanumText.body(16),
                  textAlign: TextAlign.justify),
              const SizedBox(height: 22),
              // Correspondencias
              Text('CORRESPONDENCIAS', style: ArcanumText.label()),
              const SizedBox(height: 10),
              ...lore.correspondencias.map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('·  ',
                            style: TextStyle(
                                color: ArcanumColors.gold, fontSize: 18)),
                        Expanded(child: Text(c, style: ArcanumText.body(15))),
                      ],
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _modalRow(String label, String value) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: ArcanumText.label()),
          ),
          Expanded(
            child: Text(value,
                style: ArcanumText.body(16, color: ArcanumColors.ivory)),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final glyph = signGlyph[signKey] ?? '✶';
    final name = signEs[signKey] ?? signKey;

    return ArcanumCard(
      child: Column(
        children: [
          // Etiqueta de sección con "?" interactivo
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('TU SIGNO SOLAR', style: ArcanumText.label()),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _openModal(context),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: ArcanumColors.goldMuted.withValues(alpha: 0.7)),
                  ),
                  child: const Text('?',
                      style: TextStyle(
                          color: ArcanumColors.gold,
                          fontSize: 11,
                          height: 1,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Glifo solar + glifo del signo + nombre
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('☉',
                  style: const TextStyle(
                      fontSize: 28, color: ArcanumColors.goldMuted)),
              const SizedBox(width: 10),
              Text(glyph,
                  style: const TextStyle(
                      fontSize: 36, color: ArcanumColors.gold)),
              const SizedBox(width: 12),
              Text(name, style: ArcanumText.heading(26, color: ArcanumColors.gold)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Pantalla principal ──────────────────────────────────────────────────────

class CielosScreen extends ConsumerWidget {
  const CielosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    if (auth.status == AuthStatus.unknown) {
      return const Center(
          child: CircularProgressIndicator(color: ArcanumColors.gold, strokeWidth: 2));
    }
    if (!auth.isAuthenticated) return const _LoginPrompt();
    return const _NatalView();
  }
}

class _LoginPrompt extends StatelessWidget {
  const _LoginPrompt();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('✶', style: TextStyle(fontSize: 60, color: ArcanumColors.goldMuted)),
            const SizedBox(height: 20),
            Text('Tu cielo te espera', textAlign: TextAlign.center, style: ArcanumText.heading(30)),
            const SizedBox(height: 12),
            Text('Inicia sesión para revelar tu carta natal y los tránsitos del cielo de hoy sobre ella.',
                textAlign: TextAlign.center,
                style: ArcanumText.body(16, color: ArcanumColors.ivoryMuted)),
            const SizedBox(height: 28),
            GoldButton(label: 'Iniciar sesión', onPressed: () => context.go('/login')),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.go('/register'),
              child: Text('Crear cuenta', style: ArcanumText.body(15, color: ArcanumColors.gold)),
            ),
          ],
        ),
      ),
    );
  }
}

class _NatalView extends ConsumerStatefulWidget {
  const _NatalView();
  @override
  ConsumerState<_NatalView> createState() => _NatalViewState();
}

class _NatalViewState extends ConsumerState<_NatalView> {
  late final ArcanumApi _api = ref.read(arcanumApiProvider);
  late Future<(Map<String, dynamic>, Map<String, dynamic>)> _future = _load();

  Future<(Map<String, dynamic>, Map<String, dynamic>)> _load() async {
    final natal = await _api.natalChart();
    final transits = await _api.transits();
    return (natal, transits);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: RefreshIndicator(
          color: ArcanumColors.gold,
          backgroundColor: ArcanumColors.surface,
          onRefresh: () async => setState(() => _future = _load()),
          child: FutureBuilder<(Map<String, dynamic>, Map<String, dynamic>)>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: ArcanumColors.gold, strokeWidth: 2));
              }
              if (snap.hasError) {
                return ListView(children: [
                  const SizedBox(height: 120),
                  Text('No se pudo trazar tu carta',
                      textAlign: TextAlign.center, style: ArcanumText.heading(22)),
                  const SizedBox(height: 8),
                  Text('${snap.error}',
                      textAlign: TextAlign.center,
                      style: ArcanumText.body(14, color: ArcanumColors.ivoryMuted)),
                ]);
              }
              final chart = snap.data!.$1['chart_data'] as Map<String, dynamic>;
              final transits = snap.data!.$2;
              return _content(chart, transits);
            },
          ),
        ),
      ),
    );
  }

  Widget _content(Map<String, dynamic> chart, Map<String, dynamic> transits) {
    final asc = chart['ascendant'] as Map<String, dynamic>;
    final mc = chart['midheaven'] as Map<String, dynamic>;
    final planets = (chart['planets'] as List).cast<Map<String, dynamic>>();
    final aspects = (transits['aspects_to_natal'] as List).cast<Map<String, dynamic>>();

    // Extraer signo solar: primer planeta con name='sun'
    final sunPlanet = planets.firstWhere(
      (p) => p['name'] == 'sun',
      orElse: () => <String, dynamic>{},
    );
    final sunSign = (sunPlanet['sign'] as String?) ?? '';

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      children: [
        const ArcanumHeader(subtitle: 'Tu carta natal'),
        const SizedBox(height: 24),
        if (sunSign.isNotEmpty) ...[
          _SunSignCard(signKey: sunSign),
          const SizedBox(height: 18),
        ],
        ArcanumCard(
          child: Column(children: [
            const SectionLabel('ÁNGULOS', infoKey: 'ascendente'),
            const SizedBox(height: 14),
            _angle('Ascendente', asc),
            const Divider(color: ArcanumColors.surfaceHigh, height: 28),
            _angle('Medio Cielo', mc),
          ]),
        ),
        const SizedBox(height: 18),
        ArcanumCard(
          child: Column(children: [
            const SectionLabel('PLANETAS', infoKey: 'carta_natal'),
            const SizedBox(height: 12),
            ...planets.map(_planetRow),
          ]),
        ),
        const SizedBox(height: 18),
        ArcanumCard(
          child: Column(children: [
            const SectionLabel('TRÁNSITOS DE HOY', infoKey: 'transitos'),
            const SizedBox(height: 12),
            if (aspects.isEmpty)
              Text('Cielo en calma: sin aspectos exactos a tu carta ahora.',
                  textAlign: TextAlign.center,
                  style: ArcanumText.body(15, color: ArcanumColors.ivoryMuted))
            else
              ...aspects.map(_aspectRow),
          ]),
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: () => ref.read(authProvider.notifier).logout(),
            child: Text('Cerrar sesión',
                style: ArcanumText.body(14, color: ArcanumColors.ivoryMuted)),
          ),
        ),
      ],
    );
  }

  Widget _angle(String label, Map<String, dynamic> a) {
    final sign = a['sign'] as String;
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(label, style: ArcanumText.body(16, color: ArcanumColors.ivoryMuted)),
      const SizedBox(width: 12),
      Text('${signGlyph[sign] ?? ''} ${signEs[sign] ?? sign}',
          style: ArcanumText.heading(22, color: ArcanumColors.gold)),
    ]);
  }

  Widget _planetRow(Map<String, dynamic> p) {
    final name = p['name'] as String;
    final sign = p['sign'] as String;
    final retro = p['retrograde'] == true;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(children: [
        SizedBox(
            width: 34,
            child: Text(planetGlyph[name] ?? '?',
                style: const TextStyle(fontSize: 22, color: ArcanumColors.gold))),
        Expanded(child: Text(planetEs[name] ?? name, style: ArcanumText.body(16))),
        Text('${signGlyph[sign] ?? ''} ${signEs[sign] ?? sign}',
            style: ArcanumText.body(15, color: ArcanumColors.ivoryMuted)),
        if (retro)
          const Padding(
            padding: EdgeInsets.only(left: 6),
            child: Text('℞', style: TextStyle(color: ArcanumColors.burgundy, fontSize: 15)),
          ),
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Text('C${p['house']}',
              style: ArcanumText.body(13, color: ArcanumColors.goldMuted)),
        ),
      ]),
    );
  }

  Widget _aspectRow(Map<String, dynamic> a) {
    final t = a['transit'] as String;
    final n = a['natal'] as String;
    final asp = a['aspect'] as String;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Text(
        '${planetGlyph[t] ?? ''} ${planetEs[t] ?? t}  ${aspectEs[asp] ?? asp}  ${planetGlyph[n] ?? ''} ${planetEs[n] ?? n} natal',
        textAlign: TextAlign.center,
        style: ArcanumText.body(15),
      ),
    );
  }
}
