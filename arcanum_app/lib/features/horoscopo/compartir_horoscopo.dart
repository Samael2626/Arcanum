/// Compartir el horóscopo: pintar la tarjeta, guardarla y abrir la hoja.
///
/// Tres pasos y cada uno puede fallar por su cuenta, así que van separados y
/// con nombre. Van aquí y no dentro del widget porque un `RepaintBoundary` es
/// fácil de capturar mal —sin `pixelRatio`, con el widget aún sin pintar, o
/// dejando el fichero en un sitio que el sistema no limpia— y ese detalle no
/// debe repetirse cada vez que alguien añada un botón de compartir.
///
/// FICHERO TEMPORAL, NO GALERÍA. Guardar en la galería pide permiso de
/// almacenamiento en Android y de fotos en iOS, y obligaría a declararlo en
/// Data Safety y en la ficha. Compartir un fichero del directorio temporal no
/// pide ninguno: el sistema lo entrega a la app que elija la persona y lo borra
/// cuando quiera. Se comparte, no se archiva.
library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Densidad de captura. 3 sobre 360x450 da 1080x1350: 4:5 exacto, el formato
/// que menos recortan Instagram y WhatsApp.
const double densidadTarjeta = 3;

/// Convierte el widget que cuelga de [clave] en un PNG.
///
/// Devuelve null si el widget aún no está pintado. Eso pasa de verdad: si se
/// llama en el mismo frame en que se monta, el `RenderRepaintBoundary` todavía
/// no tiene capa y `toImage` lanza. Mejor null y no compartir que un fichero
/// vacío que el sistema enseña como imagen rota.
Future<Uint8List?> pintarTarjeta(GlobalKey clave) async {
  final objeto = clave.currentContext?.findRenderObject();
  if (objeto is! RenderRepaintBoundary) return null;
  try {
    final imagen = await objeto.toImage(pixelRatio: densidadTarjeta);
    final datos = await imagen.toByteData(format: ui.ImageByteFormat.png);
    imagen.dispose();
    return datos?.buffer.asUint8List();
  } catch (_) {
    return null;
  }
}

/// Escribe el PNG en el directorio temporal y devuelve su ruta.
///
/// Nombre fijo por día: compartir dos veces el mismo horóscopo no debe dejar
/// dos ficheros, y el de ayer se sobrescribe solo.
Future<String> guardarTarjeta(Uint8List png, {required String fecha}) async {
  final dir = await getTemporaryDirectory();
  final ruta = '${dir.path}/arcanum-horoscopo-$fecha.png';
  await File(ruta).writeAsBytes(png, flush: true);
  return ruta;
}

/// Abre la hoja de compartir del sistema con la tarjeta.
///
/// [origen] es obligatorio en iPad: sin él, `UIActivityViewController` no sabe
/// desde dónde desplegarse y la app se cae. En teléfono se ignora.
Future<void> abrirHojaDeCompartir({
  required String ruta,
  required String texto,
  Rect? origen,
}) => SharePlus.instance.share(
  ShareParams(
    files: [XFile(ruta, mimeType: 'image/png')],
    text: texto,
    sharePositionOrigin: origen,
  ),
);

/// El camino completo. Devuelve false si no hubo nada que compartir.
///
/// El `origen` sale del `RenderBox` del botón que lo lanzó, que es el gesto que
/// iOS espera: la hoja se despliega desde donde se tocó.
Future<bool> compartirTarjeta({
  required GlobalKey clave,
  required String fecha,
  required String texto,
  Rect? origen,
}) async {
  final png = await pintarTarjeta(clave);
  if (png == null) return false;
  final ruta = await guardarTarjeta(png, fecha: fecha);
  await abrirHojaDeCompartir(ruta: ruta, texto: texto, origen: origen);
  return true;
}
