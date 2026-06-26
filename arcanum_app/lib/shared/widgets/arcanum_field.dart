import 'package:flutter/material.dart';

import '../../core/theme/arcanum_colors.dart';
import '../../core/theme/arcanum_theme.dart';

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
          borderSide:
              BorderSide(color: ArcanumColors.goldMuted.withValues(alpha: 0.5)),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: ArcanumColors.gold),
        ),
      ),
    );
  }
}
