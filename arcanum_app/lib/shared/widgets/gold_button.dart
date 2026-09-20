import 'package:flutter/material.dart';

import '../../core/theme/arcanum_colors.dart';
import '../../core/theme/arcanum_theme.dart';

/// El boton primario de ARCANUM: oro macizo, sin filete.
///
/// Era un `OutlinedButton` con borde de oro y letra de oro sobre nada. Pasa a
/// ir RELLENO por la regla congelada: el primario es el unico que no necesita
/// canto porque su propio color ya contrasta 8,64:1 contra el fondo, medido.
/// La letra va en el fondo de la app sobre el oro, que da los mismos 8,64:1
/// por el otro lado.
///
/// Deshabilitado NO se pinta con el oro rebajado: al 38 % cae a 2,13:1 y deja
/// de leerse. Se apaga la superficie y se deja la letra en `ivoryMuted`, que
/// sigue pasando.
class GoldButton extends StatelessWidget {
  final String label;
  final bool loading;
  /// Nulo deshabilita el boton: se usa cuando la accion aun no es posible
  /// (por ejemplo, un precio de tienda que todavia no ha cargado).
  final VoidCallback? onPressed;
  const GoldButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: ArcanumColors.gold,
          foregroundColor: ArcanumColors.background,
          disabledBackgroundColor: ArcanumColors.surfaceHigh,
          disabledForegroundColor: ArcanumColors.ivoryMuted,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: ArcanumColors.background,
                ),
              )
            : Text(
                label,
                style: ArcanumText.heading(
                  20,
                  color: ArcanumColors.background,
                ),
              ),
      ),
    );
  }
}
