// El revelado de la lamina: de la cara entonada al grabado de epoca.
//
// La pieza cerrada se ve entonada -- virada a la tinta de ARCANUM -- y al
// abrirse la hoja de lore aparece el grabado tal y como se imprimio, a color.
// El paso de una cara a otra no es el mismo para todas: lo manda el ELEMENTO
// de la pieza, en cuatro familias.
//
// POR QUE POR ELEMENTO Y NO POR CATEGORIA
//
// El catalogo tiene nueve tipos (hierba, piedra, incienso, signo...), y nueve
// animaciones no serian un lenguaje: serian ruido que nadie llega a reconocer.
// Cuatro si se aprenden. Y el elemento ya es la correspondencia que decide el
// color de la pieza en toda la app, asi que el movimiento acaba diciendo lo
// mismo que dice el color -- que es lo que hace que parezca un sistema.
//
// Las curvas NO salen de _FlipSpec del Tarot. Ahi las cuatro familias son los
// palos de un mazo y el gesto es voltear un naipe; aqui son los elementos y el
// gesto es que una plancha cobre color. Comparten la disciplina (que cada
// familia se distinga a ojo cerrado) y nada mas.
import 'package:flutter/material.dart';

import '../../shared/widgets/arcanum_mood.dart';
import 'materia_plate_loader.dart';

/// Las cuatro familias del revelado.
enum RevealElement {
  /// Prende desde un punto y se come la lamina.
  fuego,

  /// Sube desde abajo, como una marea que cubre la plancha.
  agua,

  /// Un velo que se disipa en diagonal.
  aire,

  /// Cae y se asienta con peso.
  tierra;

  /// El elemento del catalogo, que llega en espanol o en ingles segun el
  /// registro. Lo que no cuadre cae en [aire]: es la familia mas neutra de las
  /// cuatro y disimula mejor que un revelado seco.
  static RevealElement from(String? element) {
    switch (element?.trim().toLowerCase()) {
      case 'fuego':
      case 'fire':
        return fuego;
      case 'agua':
      case 'water':
        return agua;
      case 'tierra':
      case 'earth':
        return tierra;
      case 'aire':
      case 'air':
      default:
        return aire;
    }
  }
}

/// Como se abre cada familia: cuanto dura, con que curva y con que mascara.
class _RevealSpec {
  const _RevealSpec({
    required this.duracion,
    required this.curva,
    required this.mascara,
    this.asiento = 0,
  });

  final Duration duracion;
  final Curve curva;

  /// El degradado que decide, en cada instante, que parte del grabado ya se ve.
  final Shader Function(Rect area, double t) mascara;

  /// Cuanto cae la lamina antes de asentarse, en pixeles. Solo tierra.
  final double asiento;

  static const _duroBlando = 0.14;

  /// Los topes del degradado para un frente que avanza: una banda estrecha de
  /// transicion en vez de un corte a cuchillo, que delataria la mascara.
  static List<double> _frente(double t, {double banda = _duroBlando}) {
    final cabeza = (t * (1 + banda)).clamp(0.0, 1.0);
    final cola = (cabeza - banda).clamp(0.0, 1.0);
    return [0, cola, cabeza, 1];
  }

  static const List<Color> _revelado = [
    Colors.white,
    Colors.white,
    Colors.transparent,
    Colors.transparent,
  ];

  static final Map<RevealElement, _RevealSpec> todas = {
    // Prende en un punto bajo y se propaga. Rapido al arrancar y con cola
    // larga, que es como se comporta algo que se enciende.
    RevealElement.fuego: _RevealSpec(
      duracion: const Duration(milliseconds: 620),
      curva: Curves.easeOutQuart,
      // Aqui quien avanza es el RADIO, no los topes: el borde de la llama
      // guarda siempre el mismo grosor relativo mientras el circulo crece.
      mascara: (area, t) => RadialGradient(
        center: const Alignment(0, 0.62),
        radius: 0.05 + t * 1.55,
        colors: _revelado,
        stops: const [0, 0.52, 0.86, 1],
      ).createShader(area),
    ),
    // Sube. Ni arranca ni termina de golpe: una marea no tiene aristas.
    RevealElement.agua: _RevealSpec(
      duracion: const Duration(milliseconds: 900),
      curva: Curves.easeInOutSine,
      mascara: (area, t) => LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: _revelado,
        stops: _frente(t, banda: 0.22),
      ).createShader(area),
    ),
    // Se disipa en diagonal, con una banda ancha: lo que se va no tiene borde.
    RevealElement.aire: _RevealSpec(
      duracion: const Duration(milliseconds: 1100),
      curva: Curves.easeOutCubic,
      mascara: (area, t) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: _revelado,
        stops: _frente(t, banda: 0.46),
      ).createShader(area),
    ),
    // Cae de arriba y se posa. El peso esta en el asiento, no en la curva.
    RevealElement.tierra: _RevealSpec(
      duracion: const Duration(milliseconds: 760),
      curva: Curves.easeOutQuint,
      asiento: 14,
      mascara: (area, t) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: _revelado,
        stops: _frente(t, banda: 0.10),
      ).createShader(area),
    ),
  };
}

/// La lamina de una pieza, que pasa de entonada a grabado al abrirse.
///
/// Solo sirve a las piezas con lamina comprobada. El resto del catalogo no
/// pasa por aqui: sigue con su grabado vectorial y abre la hoja como siempre.
class MateriaPlateReveal extends StatefulWidget {
  const MateriaPlateReveal({
    super.key,
    required this.plate,
    required this.mood,
    required this.size,
    this.alto,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.element,
    this.revelar = true,
    this.semanticLabel,
  });

  final MateriaPlate plate;
  final ArcanumMood mood;

  /// Ancho de la caja. Sin [alto] la caja es cuadrada, como en la ficha.
  final double size;

  /// Alto de la caja cuando no es cuadrada -- la tarjeta del catalogo pide
  /// una banda apaisada, no un cuadrado.
  final double? alto;

  /// `contain` respeta la plancha entera; `cover` la lleva a sangre y recorta.
  /// La tarjeta usa `cover` y la ficha `contain`, a proposito: en la rejilla
  /// manda el reconocimiento y en la ficha manda la obra.
  final BoxFit fit;

  /// Donde se ancla el recorte. Las botanicas llevan la figura en el tercio
  /// alto, asi que en `cover` se ancla arriba y no al centro.
  final Alignment alignment;

  /// El elemento de la pieza, que elige la familia del revelado.
  final String? element;

  /// En false se queda en la cara entonada. Asi la misma lamina sirve para la
  /// tarjeta del grid, que no se abre nunca.
  final bool revelar;

  final String? semanticLabel;

  @override
  State<MateriaPlateReveal> createState() => _MateriaPlateRevealState();
}

class _MateriaPlateRevealState extends State<MateriaPlateReveal>
    with SingleTickerProviderStateMixin {
  late _RevealSpec _spec = _specDe(widget.element);
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: _spec.duracion,
  );
  late Animation<double> _t = CurvedAnimation(parent: _c, curve: _spec.curva);

  static _RevealSpec _specDe(String? element) =>
      _RevealSpec.todas[RevealElement.from(element)]!;

  bool _listas = false;
  bool _cargando = false;
  bool _carasListas = false;
  bool _reveladoIniciado = false;
  Animation<double>? _routeAnimation;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final routeAnimation = ModalRoute.of(context)?.animation;
    if (!identical(routeAnimation, _routeAnimation)) {
      _routeAnimation?.removeStatusListener(_onRouteStatus);
      _routeAnimation = routeAnimation;
      _routeAnimation?.addStatusListener(_onRouteStatus);
    }
    if (!_listas && !_cargando) _precargar();
    _intentarRevelado();
  }

  void _onRouteStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) _intentarRevelado();
  }

  void _intentarRevelado() {
    if (!mounted || !widget.revelar || !_carasListas || _reveladoIniciado) {
      return;
    }
    final routeAnimation = _routeAnimation;
    if (routeAnimation != null &&
        routeAnimation.status != AnimationStatus.completed) {
      return;
    }
    _reveladoIniciado = true;
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _c.value = 1;
      return;
    }
    _c.forward(from: 0);
  }

  /// Las dos caras en memoria ANTES de empezar.
  ///
  /// Sin esto el revelado arranca sobre una lamina que todavia se esta
  /// decodificando: se ve en el retrato del primer instante, donde no habia ni
  /// grabado ni cara entonada, solo el hueco. Un WebP de 440 px tarda poco,
  /// pero poco no es nada, y justo cae donde mas se nota -- al abrir la hoja.
  Future<void> _precargar() async {
    _cargando = true;
    final entonada = AssetImage(widget.plate.entonadoPath);
    final grabado = AssetImage(widget.plate.grabadoPath);
    await precacheImage(entonada, context);
    if (!mounted) return;
    setState(() => _listas = true);
    if (!widget.revelar) {
      _cargando = false;
      return;
    }
    await precacheImage(grabado, context);
    if (!mounted) return;
    _cargando = false;
    _carasListas = true;
    _intentarRevelado();
  }

  @override
  void didUpdateWidget(covariant MateriaPlateReveal old) {
    super.didUpdateWidget(old);
    // Si la pieza cambia de elemento sin que Flutter recree el State -- misma
    // posicion en el arbol, otra pieza dentro -- la familia tiene que cambiar
    // con ella. Con el spec resuelto una sola vez, una hierba de agua se abria
    // con la curva de la pieza anterior y nadie lo veia venir.
    if (widget.element != old.element) {
      _spec = _specDe(widget.element);
      _c.duration = _spec.duracion;
      _t = CurvedAnimation(parent: _c, curve: _spec.curva);
    }
    if (widget.plate.slug != old.plate.slug) {
      _listas = false;
      _cargando = false;
      _carasListas = false;
      _reveladoIniciado = false;
      _c.value = 0;
      _precargar();
      return;
    }
    if (widget.revelar != old.revelar) {
      if (widget.revelar) {
        _reveladoIniciado = false;
        _carasListas ? _intentarRevelado() : _precargar();
      } else {
        _reveladoIniciado = false;
        _c.reverse();
      }
    }
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_onRouteStatus);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lado = widget.size;
    return RepaintBoundary(
      child: SizedBox(
        width: lado,
        height: widget.alto ?? lado,
        child: Semantics(
          label: widget.semanticLabel,
          image: true,
          child: AnimatedBuilder(
            animation: _t,
            builder: (_, _) {
              final t = _t.value;
              return Stack(
                fit: StackFit.expand,
                children: [
                  _cara(widget.plate.entonadoPath, lado),
                  if (t > 0)
                    Transform.translate(
                      // El asiento solo mueve la cara que llega, y solo en
                      // tierra: la entonada se queda quieta debajo para que
                      // parezca que una se posa sobre la otra.
                      offset: Offset(0, -_spec.asiento * (1 - t)),
                      child: ShaderMask(
                        blendMode: BlendMode.dstIn,
                        shaderCallback: (area) => _spec.mascara(area, t),
                        child: _cara(widget.plate.grabadoPath, lado),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// `cacheWidth` no es un detalle: sin el, una rejilla de laminas de 440 px
  /// dibujadas a 102 decodifica cuatro veces mas pixeles de los que pinta.
  Widget _cara(String asset, double lado) => Image.asset(
    asset,
    fit: widget.fit,
    alignment: widget.alignment,
    cacheWidth: (lado * MediaQuery.devicePixelRatioOf(context)).round(),
    excludeFromSemantics: true,
    gaplessPlayback: true,
  );
}

/// La pieza como se ve en la rejilla: siempre entonada, nunca revelada.
///
/// La tarjeta del grid no cambia de estado a proposito. Con mas de cien
/// piezas a la vista, unas cuantas a medio voltear segun lo que se toco antes
/// no es un catalogo: es ruido. El grabado a color se gana abriendo la pieza.
///
/// Cae en [respaldo] mientras el manifest carga y para las piezas que todavia
/// no tienen lamina comprobada.
class MateriaPlateThumb extends StatefulWidget {
  const MateriaPlateThumb({
    super.key,
    required this.slug,
    required this.mood,
    required this.size,
    required this.respaldo,
    this.alto,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.semanticLabel,
  });

  final String slug;
  final ArcanumMood mood;
  final double size;
  final double? alto;
  final BoxFit fit;
  final Alignment alignment;
  final Widget respaldo;
  final String? semanticLabel;

  @override
  State<MateriaPlateThumb> createState() => _MateriaPlateThumbState();
}

class _MateriaPlateThumbState extends State<MateriaPlateThumb> {
  MateriaPlate? _plate;

  @override
  void initState() {
    super.initState();
    _buscar();
  }

  @override
  void didUpdateWidget(covariant MateriaPlateThumb old) {
    super.didUpdateWidget(old);
    if (old.slug != widget.slug) _buscar();
  }

  void _buscar() {
    final plates = MateriaPlates.instance;
    if (plates.isLoaded) {
      _plate = plates.resolve(widget.slug);
      return;
    }
    plates.ensureLoaded().then((_) {
      if (mounted) setState(() => _plate = plates.resolve(widget.slug));
    });
  }

  @override
  Widget build(BuildContext context) {
    final plate = _plate;
    if (plate == null) return widget.respaldo;
    return MateriaPlateReveal(
      plate: plate,
      mood: widget.mood,
      size: widget.size,
      alto: widget.alto,
      fit: widget.fit,
      alignment: widget.alignment,
      revelar: false,
      semanticLabel: widget.semanticLabel,
    );
  }
}

/// La franja de arriba de una tarjeta del catalogo, con la lamina dentro.
///
/// CUANTO SITIO SE LLEVA, Y POR QUE NO ES FIJO
///
/// La primera version daba el 64 % a todas y se midio despues: las botanicas
/// perdian la mitad de la plancha (45-54 % visible) mientras los mapas de Bayer
/// entraban casi enteros (92 %). No era un caso raro -- 27 de las 39 piezas con
/// lamina son hierbas, asi que el catalogo entero se veia cortado.
///
/// La causa es que una franja apaisada no puede contener una plancha vertical:
/// `cover` tira lo que sobra. Asi que la franja se adapta a la lamina:
///
///   plancha muy vertical (>= 1,6)  ->  78 %
///   plancha algo vertical (>= 1,15) ->  72 %
///   plancha apaisada               ->  64 %
///
/// Mover el anclaje no era alternativa: decide QUE mitad se ve, no cuanta.
class MateriaPlateBanda extends StatelessWidget {
  const MateriaPlateBanda({
    super.key,
    required this.slug,
    required this.mood,
    required this.ancho,
    required this.altoCelda,
    required this.respaldo,
    this.semanticLabel,
  });

  final String slug;
  final ArcanumMood mood;
  final double ancho;
  final double altoCelda;

  /// Lo que se pinta cuando la pieza no tiene lamina comprobada: su silueta,
  /// centrada y sin ir a sangre, porque un trazo no es una plancha.
  final Widget respaldo;

  final String? semanticLabel;

  /// Las tres proporciones. Fuera de la clase para que se puedan leer de un
  /// vistazo y para que un test las compruebe sin montar la pantalla.
  static const double franjaApaisada = 0.64;
  static const double franjaVertical = 0.72;
  static const double franjaMuyVertical = 0.78;

  static double franjaPara(double? relacion) {
    if (relacion == null) return franjaApaisada;
    if (relacion >= 1.6) return franjaMuyVertical;
    if (relacion >= 1.15) return franjaVertical;
    return franjaApaisada;
  }

  @override
  Widget build(BuildContext context) {
    final plates = MateriaPlates.instance;
    return FutureBuilder<void>(
      // El manifest se carga una vez y queda cacheado: a partir de la primera
      // tarjeta esto resuelve en el mismo frame.
      future: plates.isLoaded ? null : plates.ensureLoaded(),
      builder: (context, _) {
        final plate = plates.isLoaded ? plates.resolve(slug) : null;
        final alto = altoCelda * franjaPara(plate?.relacion);
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: SizedBox(
            height: alto,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (plate == null)
                  Center(child: respaldo)
                else
                  MateriaPlateReveal(
                    plate: plate,
                    mood: mood,
                    size: ancho,
                    alto: alto,
                    fit: BoxFit.cover,
                    // La figura de una plancha botanica vive en el tercio
                    // alto; anclarla al centro le corta la flor.
                    alignment: const Alignment(0, -0.34),
                    revelar: false,
                    semanticLabel: semanticLabel,
                  ),
                // El degradado que cose la lamina con la tarjeta. Sin el, el
                // recorte acaba en un canto recto y parece una foto pegada.
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        mood.edge.withValues(alpha: 0.10),
                        mood.edge,
                      ],
                      stops: const [0.44, 0.78, 1],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
