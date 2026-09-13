import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'arcanum_mood.dart';

/// Resina: el material de ARCANUM.
///
/// Sustituye a `ArcanumSurface`. Un degradado vertical OPACO tenido por el
/// humor, con un reflejo especular corto en el borde de arriba. Nada mas.
///
/// QUE SE FUE, Y POR QUE
///
/// `ArcanumSurface` pintaba cinco capas: radial base, fuga de luz, bloom,
/// grano y vinneta. De esas, la cara de verdad era el GRANO: motas de 1 px
/// dibujadas una a una, `(w*h/260).clamp(80, 520)` llamadas a `drawRect` por
/// panel. En una lista de veinte filas eso son hasta 10.400 rectangulos por
/// repintado, y cada fila nueva paga el suyo al desplazarse.
///
/// Un material pulido y una textura de papel se contradicen, asi que el grano
/// se va por motivo visual -- y de paso se lleva el unico coste de pintura que
/// quedaba pendiente de medir.
///
/// Aqui no hay `BackdropFilter`: no fuerza `saveLayer`, no lee lo que tiene
/// detras y no se encarece al apilarse. Y como el reflejo es vertical y opaco
/// como el fondo, los dos van fundidos en UN gradiente con mas paradas en vez
/// de dos capas.
///
/// EL TOPE DE LUZ, QUE ARREGLA UN FALLO QUE YA EXISTIA
///
/// La cima no puede aclararse sin limite o el texto deja de leerse encima. Y
/// esto no es un problema que traiga la resina: medido sobre el codigo actual,
/// un `ArcanumSurface` con humor de sol daba una cima de #835513, donde el
/// `goldMuted` de los rotulos se quedaba en 1,33:1 -- muy por debajo del 4,5:1
/// que pide el texto. El bloom del glow al 30 % era el que lo aclaraba.
///
/// Aqui la cima se limita a una luminancia relativa de [_maxTopLuminance],
/// que es el punto exacto donde `goldLabel` todavia da 4,5:1. De los nueve
/// humores solo `air` y `sun` se pasaban; a los dos se les baja hacia su
/// propio `edge` hasta entrar. Los demas no se tocan.
class ArcanumResin extends StatelessWidget {
  final ArcanumMood mood;
  final Widget? child;
  final BorderRadius? borderRadius;

  /// Cuanto tine el humor, de 0 (apagado) a 1 (pleno). Misma escala que tenia
  /// `ArcanumSurface`, para que las pantallas migren con su valor intacto.
  final double intensity;

  /// Respiracion de la luz (0..1). Solo mueve el reflejo: sin esto, la
  /// superficie es estatica. Lo usa la atmosfera del Grimorio.
  final double? drift;

  const ArcanumResin({
    super.key,
    required this.mood,
    this.child,
    this.borderRadius,
    this.intensity = 1.0,
    this.drift,
  });

  /// Reflejo especular, en marfil. Un gum-UI tipico anda por el 30-40 %.
  static const _specular = 0.035;

  /// Altura a la que muere el reflejo.
  static const _specularEnd = 0.48;

  /// Tope de luminancia relativa de la cima: el punto donde `goldLabel`
  /// (#B79845) da exactamente 4,5:1. Ver la nota de arriba.
  static const _maxTopLuminance = 0.0343;

  static double _channel(double c) =>
      c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

  static double _luminance(Color c) =>
      0.2126 * _channel(c.r) + 0.7152 * _channel(c.g) + 0.0722 * _channel(c.b);

  /// Baja [top] hacia [floor] hasta que su luminancia entra en el tope. Doce
  /// pasos bastan: la diferencia visible entre uno y el siguiente es nula y
  /// evita un bucle abierto en la fase de construccion.
  static Color _capLight(Color top, Color floor) {
    if (_luminance(top) <= _maxTopLuminance) return top;
    for (var i = 1; i <= 12; i++) {
      final c = Color.lerp(top, floor, i / 12)!;
      if (_luminance(c) <= _maxTopLuminance) return c;
    }
    return floor;
  }

  @override
  Widget build(BuildContext context) {
    final base = Color.lerp(mood.edge, mood.core, intensity.clamp(0.0, 1.0))!;

    // La respiracion solo abre y cierra el reflejo. No mueve geometria ni
    // anade capas: es el mismo gradiente con otro alfa.
    final vivo = drift == null
        ? _specular
        : _specular * (0.72 + 0.28 * (0.5 + 0.5 * math.sin(drift! * 6.283)));

    final cima = _capLight(
      Color.alphaBlend(const Color(0xFFF5F0E8).withValues(alpha: vivo), base),
      mood.edge,
    );

    Widget painted = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [cima, base, mood.edge],
          stops: const [0.0, _specularEnd, 1.0],
        ),
      ),
      child: child,
    );
    if (borderRadius != null) {
      painted = ClipRRect(borderRadius: borderRadius!, child: painted);
    }
    return painted;
  }
}
