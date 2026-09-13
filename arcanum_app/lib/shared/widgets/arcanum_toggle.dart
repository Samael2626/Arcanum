import 'package:flutter/material.dart';

import '../../core/theme/arcanum_colors.dart';
import '../../core/theme/arcanum_theme.dart';

/// La regla de seleccion de ARCANUM, en un solo sitio.
///
/// LOS TRES AVISOS VAN SIEMPRE JUNTOS. No es estilo, es lo que hace que el
/// componente cumpla; quitar uno rompe los otros dos:
///
///   1. COLOR   goldLight si esta elegido, ivoryMuted si no.
///   2. PESO    w400 en reposo, w600 en lo elegido.
///   3. FORMA   icono relleno en lo elegido, en contorno si no (donde hay).
///
/// POR QUE, con los numeros delante:
///
/// No hay borde ni relleno que pueda senalar el estado en esta paleta, y esto
/// se remidio desde cero al cambiar el material a Resina -- no se dio por
/// heredado, porque una superficie OPACA tiene otra aritmetica que una
/// translucida. Sobre Resina, con el especular al 8,5 % incluido:
///
///   elevado contra el panel .................... 1,15:1
///   hundido contra el panel .................... 1,55:1
///   ELEVADO contra HUNDIDO ..................... 1,79:1
///
/// Mejor que con el vidrio (alli el par era 1,20:1), porque al ser opaca la
/// superficie tiene color propio en vez de copiar el del fondo. Pero sigue
/// sin llegar al 3:1 de WCAG 1.4.11: para que el relleno solo lo lograra
/// habria que subir el elevado a #887790, un malva claro que no es esta app.
///
/// La salida es que el estado lo lleve el TEXTO: 1.4.11 excluye expresamente
/// lo textual, asi que el criterio que aplica es 1.4.3, y sobre Resina vamos
/// sobrados en los dos estados -- goldLight sobre el elevado 7,63:1 y sobre
/// el hundido 13,66:1; ivoryMuted 5,05:1 y 9,03:1. El peso y el icono relleno
/// estan para 1.4.1: sin ellos el color seria la UNICA senal, y quien no
/// distinga el oro del gris veria dos rotulos iguales.
///
/// El relleno y la sombra que se pintan aqui son material, no senal. Se
/// pueden cambiar. Los tres avisos de arriba, no -- sin los tres, esto
/// incumple.
abstract final class ArcanumSelection {
  /// Radio de la casa. El mismo de `ArcanumCard`, para que un conmutador no
  /// invente su propia esquina.
  static const radius = 16.0;

  /// Alto minimo de lo que se toca. Cielo y el selector de interprete ya lo
  /// respetaban; Saber estuvo en 40 hasta que se unifico esto.
  static const minTapHeight = 48.0;

  static const _duration = Duration(milliseconds: 220);

  /// Aviso 1 y 2: color y peso, que viajan juntos y por eso salen de la misma
  /// funcion. Pedir el color sin el peso no es posible a proposito.
  static TextStyle textStyle(bool selected, {double size = 16}) =>
      ArcanumText.body(
        size,
        color: selected ? ArcanumColors.goldLight : ArcanumColors.ivoryMuted,
      ).copyWith(fontWeight: selected ? FontWeight.w600 : FontWeight.w400);

  /// Aviso 3, donde hay icono. Sin icono el aviso lo cubre el peso.
  static IconData icon(bool selected, IconData outlined, IconData filled) =>
      selected ? filled : outlined;

  /// El material: Resina. No senala nada, solo da cuerpo a la pieza.
  ///
  /// SIN DESENFOQUE, y no es un detalle: es un degradado vertical opaco mas
  /// un reflejo especular. No fuerza `saveLayer`, no lee lo que hay detras y
  /// no se encarece por apilarse. El especular va al 8,5 % -- un gum-UI
  /// tipico anda por el 30-40 % -- y muere al 48 % de altura.
  ///
  /// Los dos degradados son verticales y van sobre superficie opaca, asi que
  /// se funden en UNO solo con mas paradas en vez de pintar dos capas. Es la
  /// razon de que aqui haya cuatro colores y no dos: los de arriba ya llevan
  /// el especular dentro.
  static BoxDecoration surface(bool selected) => BoxDecoration(
    borderRadius: BorderRadius.circular(radius),
    gradient: selected
        // Hundido: arranca oscuro arriba y aclara al pie. La luz se invierte,
        // y con ella el especular, que casi desaparece.
        ? const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF120F17),
              Color(0xFF0E0C12),
              Color(0xFF16121A),
            ],
            stops: [0, .48, 1],
          )
        // Elevado: la resina pulida, con el reflejo ya fundido en las dos
        // primeras paradas.
        : const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF413A45),
              Color(0xFF332D38),
              Color(0xFF1D1822),
            ],
            stops: [0, .26, 1],
          ),
    boxShadow: selected
        ? null
        : const [
            BoxShadow(
              color: Color(0x8C000000),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
  );
}

/// Una opcion del conmutador.
class ArcanumToggleOption {
  final String label;

  /// Rotulo para lectores de pantalla cuando el visible no basta por si solo.
  final String? semanticsLabel;

  /// Par contorno/relleno. Si falta, el aviso de forma lo lleva el peso.
  final IconData? iconOutlined;
  final IconData? iconFilled;

  const ArcanumToggleOption({
    required this.label,
    this.semanticsLabel,
    this.iconOutlined,
    this.iconFilled,
  }) : assert(
         (iconOutlined == null) == (iconFilled == null),
         'Un icono sin su pareja rompe el aviso de forma: o los dos o ninguno.',
       );
}

/// Conmutador segmentado de ARCANUM.
///
/// Reemplaza a las tres copias que habia sueltas -- Cielo (Ahora/Tu carta),
/// Oraculo (Consultar/Aprender) y Saber (Plantas/Biblioteca) --, que eran el
/// mismo widget escrito tres veces y ya habian divergido: dos usaban 48 de
/// alto y una 40, y el de Oraculo llevaba una caja exterior que las otras no.
///
/// El selector de interprete (LEE) NO usa esto y es correcto: es otra
/// disposicion, elegida entre cuatro y documentada en su sitio. Lo que si
/// comparte es [ArcanumSelection], que es donde vive la regla.
class ArcanumToggle extends StatelessWidget {
  final List<ArcanumToggleOption> options;
  final int index;
  final ValueChanged<int> onChanged;

  /// Ancho maximo del bloque. Cielo y Saber lo acotan a 340; Oraculo lo deja
  /// correr hasta el margen.
  final double? maxWidth;
  final EdgeInsets padding;
  final double fontSize;

  const ArcanumToggle({
    super.key,
    required this.options,
    required this.index,
    required this.onChanged,
    this.maxWidth = 340,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
    this.fontSize = 16,
  }) : assert(options.length >= 2, 'Un conmutador de una opcion no conmuta.');

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: padding,
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(child: _segment(i)),
          ],
        ],
      ),
    );
    if (maxWidth == null) return row;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth!),
        child: row,
      ),
    );
  }

  Widget _segment(int value) {
    final option = options[value];
    final selected = value == index;
    final style = ArcanumSelection.textStyle(selected, size: fontSize);

    return Semantics(
      button: true,
      selected: selected,
      label: option.semanticsLabel ?? option.label,
      child: InkWell(
        borderRadius: BorderRadius.circular(ArcanumSelection.radius),
        onTap: selected ? null : () => onChanged(value),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: ArcanumSelection.minTapHeight,
          ),
          child: AnimatedContainer(
            duration: ArcanumSelection._duration,
            alignment: Alignment.center,
            decoration: ArcanumSelection.surface(selected),
            child: ExcludeSemantics(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (option.iconOutlined != null) ...[
                    Icon(
                      ArcanumSelection.icon(
                        selected,
                        option.iconOutlined!,
                        option.iconFilled!,
                      ),
                      size: fontSize + 3,
                      color: style.color,
                    ),
                    const SizedBox(width: 7),
                  ],
                  Flexible(
                    child: Text(
                      option.label,
                      overflow: TextOverflow.ellipsis,
                      style: style,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
