// Piezas comunes de las familias historicas del taller (Kamea, Rosa-Cruz):
// chips, compartir como PNG o SVG y la pregunta al salir sin guardar.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:arcanum_sigilos/arcanum_sigilos.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/arcanum_colors.dart';
import '../../core/theme/arcanum_theme.dart';

typedef FamiliaScene = ({List<SceneGroup> bg, List<SceneGroup> fg});

Widget familiaChip(String label, bool on, VoidCallback onTap) => ChoiceChip(
      label: Text(label),
      selected: on,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      labelStyle: TextStyle(color: on ? ArcanumColors.background : ArcanumColors.ivory, fontSize: 14),
      selectedColor: ArcanumColors.gold,
      backgroundColor: ArcanumColors.surfaceHigh,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      side: const BorderSide(color: ArcanumColors.goldMuted),
    );

Widget familiaOutlined(String label, VoidCallback? onTap) => OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48), foregroundColor: ArcanumColors.gold),
      child: Text(label, textAlign: TextAlign.center),
    );

/// Escribe el archivo y abre el menu de compartir. [scene] y [svg] reciben si
/// el fondo va transparente. Devuelve false si no se pudo preparar.
Future<bool> compartirFamilia({
  required bool png,
  required bool transparent,
  required String baseName,
  required FamiliaScene Function(bool transparent) scene,
  required String Function(bool transparent) svg,
}) async {
  try {
    final dir = await getTemporaryDirectory();
    final String path;
    if (png) {
      final rec = ui.PictureRecorder();
      final c = Canvas(rec)..scale(1600 / kSize);
      final s = scene(transparent);
      paintScene(c, s.bg);
      paintScene(c, s.fg);
      final img = await rec.endRecording().toImage(1600, 1600);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      img.dispose();
      path = '${dir.path}/$baseName.png';
      await File(path).writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
    } else {
      path = '${dir.path}/$baseName.svg';
      await File(path).writeAsString(svg(transparent), flush: true);
    }
    await SharePlus.instance.share(ShareParams(files: [XFile(path, mimeType: png ? 'image/png' : 'image/svg+xml')]));
    return true;
  } catch (e) {
    debugPrint('ARCANUM taller: no se pudo compartir ($e).');
    return false;
  }
}

Future<bool> confirmarSalida(BuildContext context, String queSePierde) async {
  final leave = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: ArcanumColors.surface,
      title: Text('¿Salir sin guardar?', style: ArcanumText.heading(22)),
      content: Text(queSePierde, style: ArcanumText.body(15)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Seguir aquí')),
        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Salir')),
      ],
    ),
  );
  return leave == true;
}
