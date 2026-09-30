// Casos de referencia del motor de letras para el puerto a Dart.
// Uso: node _fixtures.mjs  ->  arcanum_app/test/features/sigilos/fixtures/letras.json
// El prototipo es la fuente de verdad: si cambia el motor, se regeneran y el
// test de Dart dice que falta portar.
import { chromium } from 'playwright';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const __dirname = path.dirname(fileURLToPath(import.meta.url));
const INDEX = 'file:///' + path.join(__dirname, 'index.html').replace(/\\/g, '/');
const OUT = path.join(__dirname, '..', 'arcanum_app', 'test', 'features', 'sigilos', 'fixtures', 'letras.json');

const INTENTIONS = ['Mi práctica mantiene enfoque sereno', 'AMOR DIOS', 'KAROLVS', 'Luz y sombra', 'Samuel', 'Ñandú über straße',
  'Quiero paz', 'WMNZ', 'xyz', 'Hacia el horizonte', 'Bjork', 'Sé valiente cada día', 'OQ CG', 'BPR SJU'];
const cases = [];
for (const text of INTENTIONS) for (const method of ['cooper', 'novowels', 'unique']) for (const mode of ['fusion', 'block', 'cross']) {
  cases.push({ text, method, mode, absorb: true, compact: true, overlap: 0 });
}
// variantes: sin absorber, sin encaje, solape, ediciones, trazos ocultos, remates por punta
cases.push({ text: 'Mi practica mantiene enfoque sereno', method: 'unique', mode: 'fusion', absorb: false, compact: true, overlap: 0 });
cases.push({ text: 'Mi practica mantiene enfoque sereno', method: 'unique', mode: 'fusion', absorb: true, compact: false, overlap: 0 });
cases.push({ text: 'AMOR DIOS LUZ', method: 'unique', mode: 'block', absorb: true, compact: true, overlap: .3 });
cases.push({ text: 'AMOR DIOS', method: 'cooper', mode: 'fusion', absorb: true, compact: true, overlap: 0,
  edits: { D: { dx: .2, dy: -.1, ds: 1.15, drot: 30, fx: true, fy: false }, A: { dx: 0, dy: 0, ds: .8, drot: -15, fx: false, fy: true } } });
cases.push({ text: 'KAROLVS', method: 'unique', mode: 'cross', absorb: true, compact: true, overlap: 0, hideFirst: 2 });
cases.push({ text: 'Hacia el horizonte', method: 'cooper', mode: 'cross', absorb: true, compact: true, overlap: 0, perEnd: 'star' });

const b = await chromium.launch().catch(() => chromium.launch({ channel: 'msedge' }));
const page = await b.newPage();
await page.goto(INDEX); await page.waitForTimeout(300);
const out = await page.evaluate(cases => cases.map(cs => {
  Object.assign(state, { method: cs.method, mode: cs.mode, absorb: cs.absorb, compact: cs.compact, overlap: cs.overlap, intention: '', layers: [], hidden: [], endStyles: {} });
  document.getElementById('intention').value = cs.text;
  generate();
  if (cs.edits) { for (const l of state.letters) if (cs.edits[l.ch]) Object.assign(l.user, cs.edits[l.ch]); rebuild(); }
  if (cs.hideFirst) { state.hidden = state.prims.slice(0, cs.hideFirst).map(p => p.key); rebuild(); }
  const vis = state.prims.filter(p => !p.hidden);
  const ends = freeEnds(vis);
  const terms = {};
  for (const style of ['pattee', 'star', 'botonnee', 'crescent', 'hook']) { state.terminals = style; terms[style] = terminalList(vis).map(t => ({ key: t.e.key, style: t.style, shapes: t.shapes })); }
  state.terminals = 'none';
  if (cs.perEnd && ends.length) state.endStyles = { [ends[0].key]: cs.perEnd };
  const perEnd = terminalList(vis).map(t => ({ key: t.e.key, style: t.style, shapes: t.shapes }));
  return {
    input: cs,
    reduction: state.reduction && { cleaned: state.reduction.cleaned, units: state.reduction.units },
    letters: state.letters.map(l => ({ ch: l.ch, twin: l.twin, base: l.base ? { tx: l.base.tx, ty: l.base.ty, s: l.base.s } : null, legible: l.legible ?? null, shares: l.shares ?? null })),
    prims: state.prims.map(p => ({ key: p.key, units: p.units, kind: p.kind || null, hidden: !!p.hidden, d: primPath(p) })),
    view: state.view,
    ends: ends.map(e => e.key),
    terms, perEnd, endStyles: state.endStyles
  };
}), cases);
// ── capas, transliteracion y encuadre dentro de los marcos ──
const STACKS = [
  [['circle']], [['square', { rot: 15 }], ['triangle']], [['ringLatin', { sep: 'cross', symbol: 'jupiter' }]],
  [['ringLatin', { text: 'Straße ÁNGEL', sep: 'dot' }]], [['ringHebrew']], [['ringHebrew', { text: 'Metatron', sep: 'cross' }]],
  [['ringHebrew', { text: 'שְׁמוּאֵל' }]], [['ringHebrew', { text: 'Miguel Angel', symbol: 'moon' }]],
  [['star']], [['star', { points: 7, shape: 'wide', inner: 40, chords: false }]], [['star', { points: 9, contain: true }]],
  [['star', { points: 6 }]], [['star', { points: 8, rot: 22.5, width: 4 }]],
  [['inscription', { text: 'VOLUNTAS' }]], [['inscription', { pos: 'lowerArc', text: 'lux in tenebris', size: 18, spacing: 6 }]],
  [['inscription', { pos: 'top', text: 'Straße' }]], [['inscription', { pos: 'bottom' }]],
  [['caption']], [['caption', { title: 'Mi sello', sub: 'con ♄ Saturno' }]],
  [['symbol', { sym: '♃︎', x: 300, y: 200, size: 80, rot: 30 }]], [['symbol', { sym: '★', x: 500, y: 600 }]],
  [['circle', { scale: 90 }], ['ringLatin', { symbol: 'auto' }], ['star', { points: 7, dx: 12, dy: -8 }], ['inscription', { text: 'AMOR' }], ['triangle', { visible: false }], ['caption'], ['symbol', { sym: '☉︎', x: 400, y: 700 }]],
];
const TRANSLIT_NAMES = ['Samuel', 'Metatron', 'Marc', 'Isaac', 'Chesed', 'Sophia', 'Tzadkiel', 'Rafael Arcangel', 'Xavier', 'Anna', 'Óscar', 'Llull', 'Straße Ñoño', 'Yves', 'Cecilia', 'Joshua Ben'];
const page2 = await b.newPage();
await page2.goto(INDEX); await page2.waitForTimeout(300);
const capas = await page2.evaluate(({ STACKS, TRANSLIT_NAMES }) => {
  const ser = g => ({ inner: g.inner, center: g.center, vertices: g.vertices, radii: g.radii, prims: g.prims });
  const ctxs = [{ text: 'Mi practica mantiene enfoque sereno', planet: null, title: 'Mi practica', sub: '' }, { text: 'Samuel', planet: 'mars', title: 'Sello de Samuel', sub: '♂︎ Marte · hierro' }];
  const stacks = [];
  for (const ctx of ctxs) for (const st of STACKS) {
    const layers = st.map(([t, extra]) => newLayer(t, extra || {}));
    const lay = layoutLayersRaw(layers, ctx);
    stacks.push({ ctx, layers, contentR: lay.contentR, parts: lay.parts.map(p => ({ id: p.L.id, R: p.R ?? null, g: ser(p.g) })) });
  }
  const translit = TRANSLIT_NAMES.map(n => ({ name: n, consonantal: transliterate(n, 'consonantal').hebrew, full: transliterate(n, 'full').hebrew }));
  // encuadre del sigilo dentro de los marcos
  const framed = [0, 2, 21].map(i => {
    Object.assign(state, { method: 'cooper', mode: 'fusion', absorb: true, compact: true, overlap: 0, intention: '', hidden: [], endStyles: {} });
    state.layers = STACKS[i].map(([t, extra]) => newLayer(t, extra || {}));
    document.getElementById('intention').value = 'Mi practica mantiene enfoque sereno';
    generate();
    return { stack: i, contentR: layoutLayers(state.layers, layerCtx('letters')).contentR, k: state.view.k, cx: state.view.cx, cy: state.view.cy };
  });
  // ── SVG completo: el mismo que se exporta ──
  const SIG = [['Mi practica mantiene enfoque sereno', 'cooper', 'fusion'], ['KAROLVS', 'unique', 'cross'], ['AMOR DIOS', 'unique', 'block']];
  const LAYERSETS = [[], [['circle']], [['ringLatin', { symbol: 'jupiter', sep: 'cross' }], ['star', { points: 7 }]],
    [['ringHebrew'], ['inscription', { text: 'VOLUNTAS' }], ['caption'], ['symbol', { sym: '♃︎', x: 400, y: 150, rot: 20 }]]];
  const STYLES = [presetStyle('pergamino'), presetStyle('papel'), presetStyle('lacre'), presetStyle('oro'), presetStyle('burdeos'), presetStyle('plata'),
    { ...STYLE_BASE, ...metalStyle('mars') }, presetStyle('flash-venus'), presetStyle('flash-saturn'),
    { ...presetStyle('papel'), preset: 'propio', line: 'double', cap: 'square', width: 150 }, { ...presetStyle('lacre'), preset: 'propio', relief: true, glow: true, width: 80 }];
  const svgs = [];
  let n = 0;
  for (const [text, method, mode] of SIG) for (const ls of LAYERSETS) for (const st of STYLES) {
    n++;
    if ((n % 3) && st.preset !== 'pergamino' && ls.length !== 3) continue; // muestra, no producto completo
    const terminals = ['none', 'pattee', 'star', 'ring'][n % 4];
    Object.assign(state, { method, mode, absorb: true, compact: true, overlap: 0, intention: '', hidden: [], endStyles: {}, terminals, termScale: 100, transparent: n % 17 === 0 });
    state.layers = ls.map(([t, extra]) => newLayer(t, extra || {}));
    applyStyle(st, true);
    document.getElementById('intention').value = text;
    generate();
    if (n % 5 === 0) { const e = freeEnds(state.prims.filter(p => !p.hidden))[0]; if (e) state.endStyles = { [e.key]: 'lance' }; }
    svgs.push({ text, method, mode, layers: state.layers, style: state.style, terminals, endStyles: state.endStyles, transparent: state.transparent, svg: buildSVG() });
  }
  state.transparent = false;
  return { stacks, translit, framed, svgs };
}, { STACKS, TRANSLIT_NAMES });
// ── imagen de referencia: el navegador rasteriza los SVG sin texto ──
// (el texto depende de la fuente de cada lado; la geometria no)
const conTexto = c => c.layers.some(L => ['ringLatin', 'ringHebrew', 'inscription', 'caption'].includes(L.type));
const sinTexto = capas.svgs.map((c, i) => [c, i]).filter(([c]) => !conTexto(c));
const PNG_DIR = path.join(path.dirname(OUT), 'png');
fs.mkdirSync(PNG_DIR, { recursive: true });
for (const f of fs.readdirSync(PNG_DIR)) fs.unlinkSync(path.join(PNG_DIR, f));
const page3 = await b.newPage();
for (const [c, i] of sinTexto) {
  const url = await page3.evaluate(svg => new Promise(res => {
    const img = new Image();
    img.onload = () => { const cv = document.createElement('canvas'); cv.width = cv.height = 400; cv.getContext('2d').drawImage(img, 0, 0, 400, 400); res(cv.toDataURL('image/png')); };
    img.src = 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(svg);
  }), c.svg);
  fs.writeFileSync(path.join(PNG_DIR, `svg${i}.png`), Buffer.from(url.split(',')[1], 'base64'));
}
await b.close();
fs.mkdirSync(path.dirname(OUT), { recursive: true });
fs.writeFileSync(OUT, JSON.stringify(out));
fs.writeFileSync(OUT.replace('letras.json', 'capas.json'), JSON.stringify(capas));
console.log(`${out.length} casos de letras, ${capas.stacks.length} pilas de capas, ${capas.svgs.length} SVG completos y ${sinTexto.length} imagenes de referencia -> ${path.relative(process.cwd(), path.dirname(OUT))}`);
