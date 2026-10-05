// El sigilo se guarda en el Grimorio como entrada «Sigilo», cifrada como
// todas. Se cifra el DOCUMENTO (intencion, ediciones, capas, estilo), no el
// dibujo: el motor es determinista y lo regenera identico, y se puede seguir
// editando. La intencion nunca va en el titulo (que viaja en claro).
import 'dart:convert';

import 'package:arcanum_sigilos/arcanum_sigilos.dart';
import 'package:flutter/foundation.dart';

import '../../core/api/arcanum_api.dart';
import '../../core/astro/user_place.dart';
import '../../core/crypto/grimoire_crypto.dart';

/// Marca del contenido: una entrada «Sigilo» antigua puede ser texto escrito a
/// mano (el tipo ya existia en el editor), y esa se sigue mostrando como texto.
const kTallerMark = 'sigilo-letras';

String encodeSigilEntry(SigilDoc doc) =>
    jsonEncode({'taller': kTallerMark, 'doc': doc.toJson()});

/// Documento del sigilo si el contenido lo es; null si es texto.
SigilDoc? decodeSigilEntry(String content) {
  final t = content.trimLeft();
  if (!t.startsWith('{')) return null;
  try {
    final j = jsonDecode(t);
    if (j is Map<String, dynamic> && j['taller'] == kTallerMark) {
      return SigilDoc.fromJson(j['doc'] as Map<String, dynamic>);
    }
  } on FormatException {
    return null;
  }
  return null;
}

/// Marca de la kamea (familia historica de Agrippa): otro documento, mismo tipo de entrada.
const kKameaMark = 'sigilo-kamea';

String encodeKameaEntry(KameaDoc doc) =>
    jsonEncode({'taller': kKameaMark, 'doc': doc.toJson()});

/// Kamea guardada si el contenido lo es; null si no.
KameaDoc? decodeKameaEntry(String content) {
  final t = content.trimLeft();
  if (!t.startsWith('{')) return null;
  try {
    final j = jsonDecode(t);
    if (j is Map<String, dynamic> && j['taller'] == kKameaMark) {
      return KameaDoc.fromJson(j['doc'] as Map<String, dynamic>);
    }
  } on FormatException {
    return null;
  }
  return null;
}

/// Marca de la Rosa-Cruz (familia historica de Mathers): otro documento, mismo tipo de entrada.
const kRosaMark = 'sigilo-rosa';

String encodeRosaEntry(RosaDoc doc) =>
    jsonEncode({'taller': kRosaMark, 'doc': doc.toJson()});

/// Rosa-Cruz guardada si el contenido lo es; null si no.
RosaDoc? decodeRosaEntry(String content) {
  final t = content.trimLeft();
  if (!t.startsWith('{')) return null;
  try {
    final j = jsonDecode(t);
    if (j is Map<String, dynamic> && j['taller'] == kRosaMark) {
      return RosaDoc.fromJson(j['doc'] as Map<String, dynamic>);
    }
  } on FormatException {
    return null;
  }
  return null;
}

/// Reconstruccion personal con figura de una de las tres familias.
const kPersonalMark = 'sigilo-personal';

String encodePersonalEntry(PersonalDoc doc) =>
    jsonEncode({'taller': kPersonalMark, 'doc': doc.toJson()});

PersonalDoc? decodePersonalEntry(String content) {
  final t = content.trimLeft();
  if (!t.startsWith('{')) return null;
  try {
    final j = jsonDecode(t);
    if (j is Map<String, dynamic> && j['taller'] == kPersonalMark) {
      return PersonalDoc.fromJson(j['doc'] as Map<String, dynamic>);
    }
  } on FormatException {
    return null;
  }
  return null;
}

/// Lamina didactica de las tres familias; el nombre permanece cifrado.
const kCompareMark = 'sigilo-comparar';

String encodeCompareEntry(CompareDoc doc) =>
    jsonEncode({'taller': kCompareMark, 'doc': doc.toJson()});

CompareDoc? decodeCompareEntry(String content) {
  final t = content.trimLeft();
  if (!t.startsWith('{')) return null;
  try {
    final j = jsonDecode(t);
    if (j is Map<String, dynamic> && j['taller'] == kCompareMark) {
      return CompareDoc.fromJson(j['doc'] as Map<String, dynamic>);
    }
  } on FormatException {
    return null;
  }
  return null;
}

const _meses = [
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

/// Titulo neutro: la intencion queda dentro del contenido cifrado.
String sigilTitle(DateTime d) =>
    'Sigilo del ${d.day} de ${_meses[d.month - 1]}';

/// Titulo de una kamea: la tabla es una eleccion historica; el nombre trazado no sale del cifrado.
String kameaTitle(KameaDoc doc, DateTime d) =>
    'Kamea de ${doc.def.name}, ${d.day} de ${_meses[d.month - 1]}';

/// Titulo de una Rosa-Cruz: no lleva el nombre trazado, que va dentro del cifrado.
String rosaTitle(DateTime d) => 'Rosa-Cruz, ${d.day} de ${_meses[d.month - 1]}';

String personalTitle(DateTime d) =>
    'Sello personal, ${d.day} de ${_meses[d.month - 1]}';
String compareTitle(DateTime d) =>
    'Comparación de sigilos, ${d.day} de ${_meses[d.month - 1]}';

class SigilStore {
  final ArcanumApi api;
  final GrimoireCrypto crypto;
  final UserPlace? place;
  const SigilStore(this.api, this.crypto, this.place);

  /// Crea la entrada (o reescribe [entryId]) y devuelve su id.
  Future<String> save(SigilDoc doc, {String? entryId}) =>
      _persist(encodeSigilEntry(doc), sigilTitle, entryId);

  /// Igual para una kamea: su titulo nombra la tabla, que es una eleccion
  /// historica y no la intencion (el nombre trazado queda dentro, cifrado).
  Future<String> saveKamea(KameaDoc doc, {String? entryId}) =>
      _persist(encodeKameaEntry(doc), (d) => kameaTitle(doc, d), entryId);

  /// Y una Rosa-Cruz: el titulo no lleva el nombre.
  Future<String> saveRosa(RosaDoc doc, {String? entryId}) =>
      _persist(encodeRosaEntry(doc), rosaTitle, entryId);

  Future<String> savePersonal(PersonalDoc doc, {String? entryId}) =>
      _persist(encodePersonalEntry(doc), personalTitle, entryId);
  Future<String> saveCompare(CompareDoc doc, {String? entryId}) =>
      _persist(encodeCompareEntry(doc), compareTitle, entryId);

  Future<String> _persist(
    String plain,
    String Function(DateTime) title,
    String? entryId,
  ) async {
    final enc = await crypto.encryptText(plain);
    if (entryId != null) {
      // al seguir editando, el momento de creacion (luna, hora) no cambia
      await api.grimoireUpdate(entryId, {
        'encrypted_content': enc.ciphertext,
        'content_iv': enc.iv,
      });
      return entryId;
    }
    String? moonPhase, planetaryHour, dayPlanet;
    try {
      final p = place;
      if (p == null) {
        // sin lugar confirmado la luna es cierta; la hora y el regente no
        moonPhase = (await api.moon())['phase_name'] as String?;
      } else {
        final today = await api.today(lat: p.lat, lon: p.lon);
        moonPhase = today['moon']?['phase_name'] as String?;
        planetaryHour = today['planetary_hour']?['planet'] as String?;
        dayPlanet = today['day_ruler'] as String?;
      }
    } catch (error) {
      debugPrint(
        'ARCANUM taller: sin contexto astral para el sigilo ($error).',
      );
    }
    final now = DateTime.now();
    final res = await api.grimoireCreate({
      'entry_type': 'sigil',
      'title': title(now),
      'encrypted_content': enc.ciphertext,
      'content_iv': enc.iv,
      'moon_phase': moonPhase,
      'planetary_hour': planetaryHour,
      'day_planet': dayPlanet,
      'entry_date': now.toUtc().toIso8601String(),
    });
    return res['id'].toString();
  }
}
