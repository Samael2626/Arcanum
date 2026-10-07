// El sigilo se guarda en el Grimorio como entrada «Sigilo», cifrada como
// todas. Se cifra el DOCUMENTO (intencion, ediciones, capas, estilo), no el
// dibujo: el motor es determinista y lo regenera identico, y se puede seguir
// editando. La intencion nunca va en el titulo (que viaja en claro).
// Ciclo: intencion -> composicion -> carga (se anota cada una) -> olvido
// (la intencion se borra; el dibujo queda con la fecha en que se solto).
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:arcanum_sigilos/arcanum_sigilos.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/arcanum_api.dart';
import '../../core/astro/user_place.dart';
import '../../core/crypto/grimoire_crypto.dart';

/// Marca del contenido: una entrada «Sigilo» antigua puede ser texto escrito a
/// mano (el tipo ya existia en el editor), y esa se sigue mostrando como texto.
const kTallerMark = 'sigilo-letras';

/// Una carga: cuando, cuanto duro y bajo que cielo (lo que se sepa).
class SigilCharge {
  final DateTime at;
  final int seconds;
  final String? moon, hour, dayRuler;
  const SigilCharge({
    required this.at,
    required this.seconds,
    this.moon,
    this.hour,
    this.dayRuler,
  });

  Map<String, Object?> toJson() => {
    'at': at.toUtc().toIso8601String(),
    'secs': seconds,
    if (moon != null) 'moon': moon,
    if (hour != null) 'hour': hour,
    if (dayRuler != null) 'day': dayRuler,
  };

  factory SigilCharge.fromJson(Map<String, dynamic> j) => SigilCharge(
    at: DateTime.parse(j['at'] as String).toLocal(),
    seconds: (j['secs'] as num).toInt(),
    moon: j['moon'] as String?,
    hour: j['hour'] as String?,
    dayRuler: j['day'] as String?,
  );
}

/// Lo que va cifrado en la entrada: el documento, sus cargas y, si se solto,
/// la fecha (entonces el documento ya no lleva la intencion).
class SigilEntry {
  final SigilDoc doc;
  final List<SigilCharge> charges;
  final DateTime? released;
  SigilEntry(this.doc, {List<SigilCharge>? charges, this.released})
    : charges = charges ?? [];

  bool get isReleased => released != null;
}

String encodeSigilEntry(SigilEntry e) => jsonEncode({
  'taller': kTallerMark,
  'doc': e.doc.toJson(),
  if (e.charges.isNotEmpty) 'charges': [for (final c in e.charges) c.toJson()],
  if (e.released != null) 'released': e.released!.toUtc().toIso8601String(),
});

/// Resultado de leer una entrada «Sigilo».
sealed class SigilDecoded {
  const SigilDecoded();
}

class SigilReadable extends SigilDecoded {
  final SigilEntry entry;
  const SigilReadable(this.entry);
}

/// Es un sigilo del taller pero no se puede dibujar (version mas nueva o datos
/// rotos). Nunca se muestra el contenido en crudo: lleva la intencion en claro.
class SigilUnreadable extends SigilDecoded {
  final bool newerVersion;
  const SigilUnreadable({required this.newerVersion});
}

/// null si el contenido es texto (entrada «Sigilo» escrita a mano).
SigilDecoded? decodeSigilEntry(String content) {
  final t = content.trimLeft();
  if (!t.startsWith('{')) return null;
  final Object? j;
  try {
    j = jsonDecode(t);
  } on FormatException {
    return null;
  }
  if (j is! Map<String, dynamic> || j['taller'] != kTallerMark) return null;
  try {
    final d = j['doc'] as Map<String, dynamic>;
    if ((d['v'] as int? ?? 0) > SigilDoc.kVersion) {
      return const SigilUnreadable(newerVersion: true);
    }
    final released = j['released'] as String?;
    return SigilReadable(
      SigilEntry(
        SigilDoc.fromJson(d),
        charges: [
          for (final c in (j['charges'] as List? ?? const []))
            SigilCharge.fromJson(c as Map<String, dynamic>),
        ],
        released: released == null ? null : DateTime.parse(released).toLocal(),
      ),
    );
  } catch (error) {
    // datos rotos: se dice, sin tumbar la pantalla del Grimorio
    debugPrint('ARCANUM taller: sigilo ilegible ($error).');
    return const SigilUnreadable(newerVersion: false);
  }
}

const kMonthsEs = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

String dayMonthEs(DateTime d) => '${d.day} de ${kMonthsEs[d.month - 1]}';

/// Titulo neutro: la intencion queda dentro del contenido cifrado.
String sigilTitle(DateTime d) => 'Sigilo del ${dayMonthEs(d)}';

/// Copia del sigilo soltado: sin intencion y con la fecha. El original no se
/// toca hasta que el guardado sale bien.
SigilEntry releasedCopy(SigilEntry e, DateTime at) => SigilEntry(
  SigilDoc.fromJson(e.doc.toJson())..forget(),
  charges: [...e.charges],
  released: at,
);

/// Lado de la miniatura de la lista: el doble de lo que ocupa (52 dp) en 3x.
const kPreviewPx = 160;

/// PNG pequeño del sigilo, con su fondo, para la lista del Grimorio.
Future<Uint8List?> renderSigilPreview(SigilDoc doc) async {
  if (doc.sigil.prims.isEmpty) return null;
  final rec = ui.PictureRecorder();
  final c = ui.Canvas(rec)..scale(kPreviewPx / kSize);
  final s = doc.scene();
  paintScene(c, s.bg);
  // trazo minimo: a 160 px los trazos finos se perderian
  paintScene(c, s.fg, minW: 2 * kSize / kPreviewPx);
  final img = await rec.endRecording().toImage(kPreviewPx, kPreviewPx);
  try {
    return (await img.toByteData(
      format: ui.ImageByteFormat.png,
    ))?.buffer.asUint8List();
  } finally {
    img.dispose();
  }
}

/// Quien dibuja la miniatura (en los tests, uno de mentira: rasterizar no
/// termina dentro del reloj falso de los tests de widgets).
final sigilPreviewProvider = Provider<Future<Uint8List?> Function(SigilDoc)>(
  (ref) => renderSigilPreview,
);

class SigilStore {
  final ArcanumApi api;
  final GrimoireCrypto crypto;
  final UserPlace? place;
  final Future<Uint8List?> Function(SigilDoc) preview;
  const SigilStore(
    this.api,
    this.crypto,
    this.place, {
    this.preview = renderSigilPreview,
  });

  /// Miniatura cifrada como el contenido. Si falla, la entrada se guarda sin
  /// ella (la lista cae a la capitular): nunca bloquea el guardado.
  Future<Map<String, String>> _previewFields(SigilDoc doc) async {
    try {
      final png = await preview(doc);
      if (png == null) return const {};
      final enc = await crypto.encryptText(base64Encode(png));
      return {'encrypted_preview': enc.ciphertext, 'preview_iv': enc.iv};
    } catch (error) {
      debugPrint('ARCANUM taller: sin miniatura del sigilo ($error).');
      return const {};
    }
  }

  /// Cielo de ahora: luna siempre que se pueda; hora y regente solo con lugar
  /// confirmado (sin el, serian de otro sitio). Nunca falla: sin red, nada.
  Future<({String? moon, String? hour, String? dayRuler})> sky() async {
    try {
      final p = place;
      if (p == null) {
        return (
          moon: (await api.moon())['phase_name'] as String?,
          hour: null,
          dayRuler: null,
        );
      }
      final today = await api.today(lat: p.lat, lon: p.lon);
      return (
        moon: today['moon']?['phase_name'] as String?,
        hour: today['planetary_hour']?['planet'] as String?,
        dayRuler: today['day_ruler'] as String?,
      );
    } catch (error) {
      debugPrint(
        'ARCANUM taller: sin contexto astral para el sigilo ($error).',
      );
      return (moon: null, hour: null, dayRuler: null);
    }
  }

  Future<SigilCharge> chargeNow(int seconds) async {
    final s = await sky();
    return SigilCharge(
      at: DateTime.now(),
      seconds: seconds,
      moon: s.moon,
      hour: s.hour,
      dayRuler: s.dayRuler,
    );
  }

  /// Crea la entrada (o reescribe [entryId]) y devuelve su id.
  Future<String> save(SigilEntry e, {String? entryId}) async {
    final enc = await crypto.encryptText(encodeSigilEntry(e));
    final thumb = await _previewFields(e.doc);
    if (entryId != null) {
      // al seguir editando, el momento de creacion (luna, hora) no cambia
      await api.grimoireUpdate(entryId, {
        'encrypted_content': enc.ciphertext,
        'content_iv': enc.iv,
        ...thumb,
      });
      return entryId;
    }
    final s = await sky();
    final now = DateTime.now();
    final res = await api.grimoireCreate({
      'entry_type': 'sigil',
      'title': sigilTitle(now),
      'encrypted_content': enc.ciphertext,
      'content_iv': enc.iv,
      ...thumb,
      'moon_phase': s.moon,
      'planetary_hour': s.hour,
      'day_planet': s.dayRuler,
      'entry_date': now.toUtc().toIso8601String(),
    });
    return res['id'].toString();
  }
}
