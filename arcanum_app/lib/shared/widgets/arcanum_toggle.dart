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
/// No hay borde ni relleno que pueda senalar el estado en esta paleta. Se
/// midio sobre la superficie real de la app (`ArcanumSurface` con humor
/// neutro e `intensity` 0.55, que da una base #131118):
///
///   relleno elevado  #211D2A contra la base .... 1,14:1
///   relleno hundido  #0B0A0E contra la base .... 1,05:1
///   elevado contra hundido ..................... 1,20:1
///   filete de oro al 30 % ...................... 1,80:1
///
/// Ninguno llega al 3:1 que pide WCAG 1.4.11, y no es cuestion de afinar: la
/// base contra negro absoluto da 1,12:1 (no hay suelo por debajo) y para
/// llegar a 3:1 por arriba haria falta subir a rgb(95,95,123), que ya no es
/// la penumbra de esta app.
///
/// La salida es que el estado lo lleve el TEXTO: 1.4.11 excluye expresamente
/// lo textual, asi que el criterio que aplica es 1.4.3, y ahi vamos sobrados
/// -- goldLight sobre el panel da 13,16:1 e ivoryMuted 8,70:1. El peso y el
/// icono relleno estan para 1.4.1: sin ellos el color seria la UNICA senal y
/// quien no distinga el oro del gris veria dos rotulos iguales.
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

  /// El material. No senala nada: solo da cuerpo a la pieza.
  static BoxDecoration surface(bool selected) => BoxDecoration(
    borderRadius: BorderRadius.circular(radius),
    gradient: selected
        // Hundido: la luz cae abajo, como el fondo de una pieza rehundida.
        ? const RadialGradient(
            center: Alignment(0, 0.56),
            radius: 1.1,
            colors: [Color(0xFF0F0D13), Color(0xFF0B0A0E)],
          )
        // Elevado: la luz sube hacia el borde de arriba.
        : const RadialGradient(
            center: Alignment(0, -0.4),
            radius: 1.1,
            colors: [Color(0xFF211D2A), Color(0xFF16131C)],
          ),
    boxShadow: selected
        ? null
        : const [
            BoxShadow(
              color: Color(0x59000000),
              blurRadius: 18,
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
