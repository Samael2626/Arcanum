// Capitales de trazo unico sobre una caja 1x1 (y hacia abajo). Todas comparten
// la rejilla 0, .5, 1 para que los trazos de letras distintas coincidan y se
// fundan. Puerto literal de GLYPHS del prototipo (js/letras.js).
import 'geometry.dart';

const _pBowl = <GlyphPrim>[GLine(0, 0, 0, 1), GLine(0, 0, .55, 0), GArc(.55, .25, .25, -90, 90), GLine(.55, .5, 0, .5)];

const Map<String, List<GlyphPrim>> kGlyphs = {
  'A': [GLine(0, 1, .5, 0), GLine(.5, 0, 1, 1), GLine(.25, .5, .75, .5)],
  'B': [GLine(0, 0, 0, 1), GLine(0, 0, .55, 0), GArc(.55, .25, .25, -90, 90), GLine(0, .5, .6, .5), GArc(.6, .75, .25, -90, 90), GLine(.6, 1, 0, 1)],
  'C': [GArc(.5, .5, .5, 45, 315)],
  'D': [GLine(0, 0, 0, 1), GLine(0, 0, .5, 0), GArc(.5, .5, .5, -90, 90), GLine(.5, 1, 0, 1)],
  'E': [GLine(0, 0, 0, 1), GLine(0, 0, 1, 0), GLine(0, .5, .8, .5), GLine(0, 1, 1, 1)],
  'F': [GLine(0, 0, 0, 1), GLine(0, 0, 1, 0), GLine(0, .5, .8, .5)],
  'G': [GArc(.5, .5, .5, 0, 315), GLine(.5, .5, 1, .5)],
  'H': [GLine(0, 0, 0, 1), GLine(1, 0, 1, 1), GLine(0, .5, 1, .5)],
  'I': [GLine(.5, 0, .5, 1)],
  'J': [GLine(1, 0, 1, .65), GArc(.65, .65, .35, 0, 180)],
  'K': [GLine(0, 0, 0, 1), GLine(1, 0, 0, .5), GLine(0, .5, 1, 1)],
  'L': [GLine(0, 0, 0, 1), GLine(0, 1, 1, 1)],
  'M': [GLine(0, 1, 0, 0), GLine(0, 0, .5, .6), GLine(.5, .6, 1, 0), GLine(1, 0, 1, 1)],
  'N': [GLine(0, 1, 0, 0), GLine(0, 0, 1, 1), GLine(1, 1, 1, 0)],
  'O': [GArc(.5, .5, .5, 0, 360)],
  'P': _pBowl,
  'Q': [GArc(.5, .5, .5, 0, 360), GLine(.6, .6, 1, 1)],
  'R': [..._pBowl, GLine(.45, .5, 1, 1)],
  'S': [GArc(.5, .25, .25, -30, -270), GArc(.5, .75, .25, -90, 150)],
  'T': [GLine(0, 0, 1, 0), GLine(.5, 0, .5, 1)],
  'U': [GLine(0, 0, 0, .5), GArc(.5, .5, .5, 180, 0), GLine(1, .5, 1, 0)],
  'V': [GLine(0, 0, .5, 1), GLine(.5, 1, 1, 0)],
  'W': [GLine(0, 0, 0, 1), GLine(0, 1, .5, .4), GLine(.5, .4, 1, 1), GLine(1, 1, 1, 0)],
  'X': [GLine(0, 0, 1, 1), GLine(1, 0, 0, 1)],
  'Y': [GLine(0, 0, .5, .5), GLine(1, 0, .5, .5), GLine(.5, .5, .5, 1)],
  'Z': [GLine(0, 0, 1, 0), GLine(1, 0, 0, 1), GLine(0, 1, 1, 1)],
};

const kVowels = {'A', 'E', 'I', 'O', 'U'};
