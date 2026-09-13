import 'package:flutter/material.dart';

import '../../core/theme/arcanum_colors.dart';
import '../../core/theme/arcanum_theme.dart';

/// Campo de texto de ARCANUM.
///
/// LA UNICA EXCEPCION A LA REGLA DE CANTOS, Y NO POR EL MOTIVO QUE PARECE
///
/// La regla congelada dice cero filete en todo panel y todo control, y estos
/// dos subrayados son un filete. Se quedan igual, y conviene saber por que
/// para que nadie los "arregle" mas adelante:
///
///   · El de FOCO (`gold` pleno) es el indicador de foco. Quitarlo no infringe
///     1.4.11 -- infringe 2.4.7 Focus Visible, que es OTRO criterio, y uno del
///     que la regla congelada nunca hablo: alli se discutio el contraste del
///     limite de un componente y el uso del color, nunca el foco. Un campo sin
///     anillo de foco y con solo un cursor parpadeando deja de ser navegable
///     por teclado.
///
///   · El de REPOSO (`goldMuted` al 50 %) es lo unico que hace que el campo se
///     VEA. Sin el no hay nada que enfocar, porque no se encuentra. Y esta
///     medido que en esta paleta nada por debajo de un trazo pleno llega al
///     3:1: no hay relleno ni sombra que lo sustituya.
///
/// O sea que la regla, aplicada al pie de la letra aqui, dejaria un campo
/// imposible de encontrar y de enfocar. Por eso es excepcion, esta escrita, y
/// no se toca sin resolver antes el 2.4.7.
class ArcanumField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscure;
  final TextInputType? keyboardType;
  final VoidCallback? onTap;
  final bool readOnly;
  const ArcanumField({
    super.key,
    required this.controller,
    required this.label,
    this.obscure = false,
    this.keyboardType,
    this.onTap,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      onTap: onTap,
      readOnly: readOnly,
      style: ArcanumText.body(16),
      cursorColor: ArcanumColors.gold,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: ArcanumText.body(14, color: ArcanumColors.ivoryMuted),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(
            color: ArcanumColors.goldMuted.withValues(alpha: 0.5),
          ),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: ArcanumColors.gold),
        ),
      ),
    );
  }
}
