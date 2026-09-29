'use strict';
// ════════════════════════════════════════════════════════════════
//  Glifos arcanos dibujados a trazo propio
//  No dependen de la fuente del sistema (Segoe UI Symbol solo existe en
//  Windows; en Android y en Flutter los simbolos saldrian distintos o en
//  blanco). Caja 100x100, centro (50, 50). s = trazo, f = relleno.
//  Son dibujos de ARCANUM de simbolos estandar, no calcos de una fuente
//  historica concreta.
// ════════════════════════════════════════════════════════════════
const GLYPH_BOX = 100, GLYPH_W = 7;
const gc = (cx, cy, r) => `M ${cx - r} ${cy} A ${r} ${r} 0 1 0 ${cx + r} ${cy} A ${r} ${r} 0 1 0 ${cx - r} ${cy} Z`;
// brazo de la cruz patada, girado sobre el centro
const patteeArm = a => {
  const rt = (x, y) => { const c = Math.cos(a * Math.PI / 180), s = Math.sin(a * Math.PI / 180), u = x - 50, v = y - 50; return `${(50 + u * c - v * s).toFixed(2)} ${(50 + u * s + v * c).toFixed(2)}`; };
  return `M ${rt(50, 50)} L ${rt(33, 8)} Q ${rt(50, 16)} ${rt(67, 8)} Z`;
};
const TRI_UP = 'M 50 12 L 90 82 L 10 82 Z', TRI_DOWN = 'M 10 18 L 90 18 L 50 88 Z';
const MERCURY = { s: `M 34 10 C 36 26, 64 26, 66 10 ${gc(50, 42, 17)} M 50 59 L 50 94 M 35 78 L 65 78` };
const GLYPHS_ARCANE = {
  // planetas
  '♄': { s: 'M 40 8 L 40 70 M 26 22 L 56 22 M 40 52 C 46 36, 70 36, 70 52 C 70 64, 58 70, 62 84 C 64 92, 72 92, 76 86' },
  '♃': { s: 'M 22 32 C 26 14, 52 14, 50 32 C 48 46, 32 56, 22 66 L 84 66 M 66 14 L 66 92' },
  '♂': { s: `${gc(40, 60, 25)} M 58 42 L 86 14 M 62 14 L 86 14 L 86 38` },
  '☉': { s: gc(50, 50, 38), f: gc(50, 50, 7) },
  '♀': { s: `${gc(50, 34, 24)} M 50 58 L 50 94 M 32 78 L 68 78` },
  '☿': MERCURY,
  '☽': { s: 'M 40 12 A 38 38 0 1 1 40 88 A 46 46 0 0 0 40 12 Z' },
  // zodiaco
  '♈': { s: 'M 50 90 L 50 38 C 50 14, 16 10, 14 32 C 13 44, 26 48, 32 40 M 50 38 C 50 14, 84 10, 86 32 C 87 44, 74 48, 68 40' },
  '♉': { s: `${gc(50, 62, 24)} M 14 16 C 22 42, 78 42, 86 16` },
  '♊': { s: 'M 36 24 L 36 76 M 64 24 L 64 76 M 16 16 Q 50 32 84 16 M 16 84 Q 50 68 84 84' },
  '♋': { s: `${gc(28, 38, 11)} M 28 27 C 48 18, 72 20, 88 32 ${gc(72, 62, 11)} M 72 73 C 52 82, 28 80, 12 68` },
  '♌': { s: `${gc(28, 66, 13)} M 38 58 C 28 36, 40 14, 60 16 C 80 18, 78 40, 66 58 C 56 72, 60 88, 76 86 C 82 85, 86 80, 86 76` },
  '♍': { s: 'M 12 26 L 12 80 M 12 36 C 14 22, 32 22, 32 36 L 32 80 M 32 36 C 34 22, 52 22, 52 36 L 52 70 C 52 86, 70 90, 80 76 C 88 62, 72 50, 62 62 C 54 72, 60 86, 70 94' },
  '♎': { s: 'M 12 80 L 88 80 M 12 64 L 34 64 C 24 52, 28 30, 50 30 C 72 30, 76 52, 66 64 L 88 64' },
  '♏': { s: 'M 10 26 L 10 78 M 10 36 C 12 22, 30 22, 30 36 L 30 78 M 30 36 C 32 22, 50 22, 50 36 L 50 70 C 50 82, 60 86, 72 80 L 88 72 M 76 64 L 88 72 L 82 84' },
  '♐': { s: 'M 16 84 L 84 16 M 56 16 L 84 16 L 84 44 M 30 46 L 54 70' },
  '♑': { s: 'M 10 24 L 26 70 L 38 26 C 44 20, 50 40, 52 60 C 54 78, 76 84, 82 68 C 88 52, 68 46, 60 60 C 54 72, 50 86, 38 92' },
  '♒': { s: 'M 10 42 L 26 30 L 42 42 L 58 30 L 74 42 L 90 30 M 10 70 L 26 58 L 42 70 L 58 58 L 74 70 L 90 58' },
  '♓': { s: 'M 22 12 C 44 32, 44 68, 22 88 M 78 12 C 56 32, 56 68, 78 88 M 24 50 L 76 50' },
  // elementos (triangulos alquimicos)
  '🜂': { s: TRI_UP },
  '🜄': { s: TRI_DOWN },
  '🜁': { s: `${TRI_UP} M 26 58 L 74 58` },
  '🜃': { s: `${TRI_DOWN} M 26 42 L 74 42` },
  // principios alquimicos
  '🜍': { s: 'M 50 8 L 78 56 L 22 56 Z M 50 56 L 50 94 M 32 76 L 68 76' },
  '🜔': { s: `${gc(50, 50, 38)} M 12 50 L 88 50` },
  // nodos y aspectos
  '☊': { s: `M 28 74 L 28 48 C 28 18, 72 18, 72 48 L 72 74 ${gc(22, 82, 9)} ${gc(78, 82, 9)}` },
  '☋': { s: `M 28 26 L 28 52 C 28 82, 72 82, 72 52 L 72 26 ${gc(22, 18, 9)} ${gc(78, 18, 9)}` },
  '☌': { s: `${gc(38, 62, 22)} M 54 46 L 84 16` },
  '☍': { s: `${gc(24, 76, 13)} ${gc(76, 24, 13)} M 33 67 L 67 33` },
  '△': { s: 'M 50 16 L 86 80 L 14 80 Z' },
  '□': { s: 'M 18 18 L 82 18 L 82 82 L 18 82 Z' },
  '⚹': { s: 'M 50 10 L 50 90 M 15 30 L 85 70 M 15 70 L 85 30' },
  // signos
  '✦': { f: 'M 50 6 C 54 40, 60 46, 94 50 C 60 54, 54 60, 50 94 C 46 60, 40 54, 6 50 C 40 46, 46 40, 50 6 Z' },
  '✧': { s: 'M 50 8 C 54 40, 60 46, 92 50 C 60 54, 54 60, 50 92 C 46 60, 40 54, 8 50 C 40 46, 46 40, 50 8 Z' },
  '◎': { s: `${gc(50, 50, 38)} ${gc(50, 50, 20)}` },
  '⊕': { s: `${gc(50, 50, 38)} M 50 12 L 50 88 M 12 50 L 88 50` },
  '✠': { f: [0, 90, 180, 270].map(patteeArm).join(' ') },
  '☥': { s: 'M 50 46 C 32 36, 34 8, 50 8 C 66 8, 68 36, 50 46 Z M 50 46 L 50 94 M 24 54 L 76 54' }
};
const glyphKey = sym => String(sym).replace(/[︎️]/g, '');
const hasGlyph = sym => !!GLYPHS_ARCANE[glyphKey(sym)];
// SVG de un glifo centrado en (x, y), de `size` px, girado `rot` grados
function glyphSVG(sym, x, y, size, rot, color, op = 1, attrs = '') {
  const g = GLYPHS_ARCANE[glyphKey(sym)], k = size / GLYPH_BOX;
  const o = op < 1 ? ` opacity="${op.toFixed(2)}"` : '';
  return `<g data-glyph="${glyphKey(sym)}" transform="translate(${x.toFixed(2)} ${y.toFixed(2)}) rotate(${(rot || 0).toFixed(2)}) scale(${k.toFixed(4)}) translate(-50 -50)"${o}${attrs}>` +
    (g.s ? `<path d="${g.s}" fill="none" stroke="${color}" stroke-width="${GLYPH_W}" stroke-linecap="round" stroke-linejoin="round"/>` : '') +
    (g.f ? `<path d="${g.f}" fill="${color}" stroke="none"/>` : '') + '</g>';
}
const glyphPaths = {};
function paintGlyph(ctx, sym, x, y, size, rot, color) {
  const key = glyphKey(sym), g = GLYPHS_ARCANE[key];
  if (!glyphPaths[key]) glyphPaths[key] = { s: g.s && new Path2D(g.s), f: g.f && new Path2D(g.f) };
  const p = glyphPaths[key];
  ctx.save();
  ctx.translate(x, y); ctx.rotate((rot || 0) * Math.PI / 180); ctx.scale(size / GLYPH_BOX, size / GLYPH_BOX); ctx.translate(-50, -50);
  ctx.strokeStyle = color; ctx.fillStyle = color; ctx.lineWidth = GLYPH_W; ctx.lineCap = 'round'; ctx.lineJoin = 'round';
  if (p.s) ctx.stroke(p.s);
  if (p.f) ctx.fill(p.f);
  ctx.restore();
}
// Icono para la interfaz (botones, paletas): el mismo dibujo
const glyphIcon = (sym, px = 22) => `<svg viewBox="0 0 100 100" width="${px}" height="${px}" aria-hidden="true">${glyphSVG(sym, 50, 50, 100, 0, 'currentColor')}</svg>`;
