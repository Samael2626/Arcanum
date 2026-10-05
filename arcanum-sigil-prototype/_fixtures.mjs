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
// ── interaccion: guias, que hay bajo el dedo y gestos grabados ──
const page4 = await b.newPage({ viewport: { width: 1400, height: 1000 } });
await page4.goto(INDEX); await page4.waitForTimeout(300);
const setup = async () => page4.evaluate(() => {
  setLevel(true); setTab('crear');
  Object.assign(state, { method: 'cooper', mode: 'fusion', absorb: true, compact: true, overlap: 0, intention: '', hidden: [], endStyles: {}, terminals: 'none', termPick: false, hideMode: false, stampMode: false, sel: null, magnet: true });
  state.layerSel.letters = null;
  state.layers = [newLayer('circle'), newLayer('star', { points: 7, rot: 10 }), newLayer('symbol', { sym: '♃︎', x: 250, y: 180 })];
  applyStyle(presetStyle('pergamino'), true);
  document.getElementById('intention').value = 'Mi practica mantiene enfoque sereno';
  generate();
  // se graban los eventos en coordenadas de lienzo, antes del manejador
  window.__ev = [];
  if (!window.__rec) {
    window.__rec = true;
    for (const t of ['pointerdown', 'pointermove', 'pointerup']) canvas.addEventListener(t, e => { const p = canvasPoint(e); window.__ev.push([t, p.x, p.y, e.altKey]); }, true);
  }
  const r = canvas.getBoundingClientRect();
  return { left: r.left, top: r.top, width: r.width, pxScale: SIZE / r.width, doc: { layers: state.layers } };
});
const geo = await setup();
const toClient = (x, y) => [geo.left + x / geo.pxScale, geo.top + y / geo.pxScale];
const probes = await page4.evaluate(() => {
  let seed = 11; const rnd = () => (seed = seed * 16807 % 2147483647) / 2147483647;
  const pts = Array.from({ length: 300 }, () => ({ x: 40 + rnd() * 720, y: 40 + rnd() * 720 }));
  // puntos cerca de cosas: centro, vertices de la estrella, anillo
  const lay = layoutLayers(state.layers, layerCtx('letters'));
  lay.parts.forEach(p => { p.g.vertices.slice(0, 6).forEach(([x, y]) => { pts.push({ x: x + 4, y: y - 3 }, { x: x + 7, y: y + 30 }); }); });
  pts.push({ x: 403, y: 250 }, { x: 396, y: 610 }, { x: 405, y: 405 }, { x: 250 + 3, y: 180 - 2 });
  const sym = state.layers.find(L => L.type === 'symbol').id, star = state.layers.find(L => L.type === 'star').id;
  const ex = [null, sym, star, 'letter:' + activeLetters()[0].ch];
  const snap = pts.map((pt, i) => { const e = ex[i % ex.length]; const q = snapPoint(pt, 'letters', e, null); return { pt, ex: e, q, guides: state.guides }; });
  const hits = pts.map(pt => (layerAt(pt, 'letters') || {}).id || null);
  const prims = pts.map(pt => { const p = primAt(pt, state.prims.filter(q => !q.hidden)); return p ? p.key : null; });
  const angles = []; for (let d = -30; d <= 400; d += 1) angles.push([d, snapAngle(d, null)]);
  state.guides = [];
  return { pts, snap, hits, prims, angles };
});
const snapshotState = () => page4.evaluate(() => ({
  sel: state.sel, layerSel: state.layerSel.letters, termPick: state.termPick, hideMode: state.hideMode, stampMode: state.stampMode,
  users: Object.fromEntries(state.letters.map(l => [l.ch, l.user])), hidden: [...state.hidden], endStyles: { ...state.endStyles },
  layers: state.layers.map(L => ({ id: L.id, type: L.type, x: L.x, y: L.y, dx: L.dx, dy: L.dy, sym: L.sym })), view: state.view,
  svg: buildSVG()
}));
const gestures = [];
// antes de cada gesto: sin seleccion (el radial no tapa nada) y modos fijados
const record = async (name, modes, fn) => {
  await page4.evaluate(m => { state.sel = null; state.layerSel.letters = null; Object.assign(state, { termPick: false, hideMode: false, stampMode: false }, m); document.getElementById('provModal').classList.remove('open'); render(); window.__ev = []; }, modes);
  const before = await page4.evaluate(() => ({ termPick: state.termPick, hideMode: state.hideMode, stampMode: state.stampMode, termBrush: state.termBrush, stampSym: state.stampSym }));
  await fn();
  const events = await page4.evaluate(() => window.__ev);
  if (!events.length) throw new Error(`el gesto «${name}» no llego al lienzo`);
  gestures.push({ name, before, events, after: await snapshotState() });
};
const drag = async (x0, y0, dx, dy, steps = 6, alt = false) => {
  const [cx, cy] = toClient(x0, y0);
  await page4.mouse.move(cx, cy); await page4.mouse.down();
  if (alt) await page4.keyboard.down('Alt');
  await page4.mouse.move(cx + dx, cy + dy, { steps });
  if (alt) await page4.keyboard.up('Alt');
  await page4.mouse.up();
};
const click = async (x, y) => { const [cx, cy] = toClient(x, y); await page4.mouse.click(cx, cy); };
const letterPt = () => page4.evaluate(() => { const p = state.prims.find(q => q.units.length === 1 && q.t === 'L' && !q.hidden && Math.hypot(q.b.x - q.a.x, q.b.y - q.a.y) > .3); const a = toCanvas(p.a), c = toCanvas(p.b); return { x: (a.x + c.x) / 2, y: (a.y + c.y) / 2 }; });
let lp = await letterPt();
await record('arrastrar una letra', {}, () => drag(lp.x, lp.y, 47, 23));
lp = await letterPt();
await record('arrastrar una letra con Alt (sin iman)', {}, () => drag(lp.x, lp.y, -31, 17, 5, true));
await record('arrastrar el simbolo hacia la vertical del centro', {}, () => drag(250, 180, (396 - 250) / geo.pxScale, 12, 6));
// la estrella se agarra por una punta de abajo, lejos del simbolo
const starPt = await page4.evaluate(() => { const lay = layoutLayers(state.layers, layerCtx('letters')); const p = lay.parts.find(q => q.L.type === 'star'); const v = p.g.vertices.reduce((b, q) => q[1] > b[1] ? q : b); return { x: v[0], y: v[1] - 2 }; });
await record('arrastrar la estrella', {}, () => drag(starPt.x, starPt.y, 30, -20, 5));
await record('tocar el vacio deselecciona', {}, async () => { await click(470, 300); await click(130, 130); });
const endPt = await page4.evaluate(() => toCanvas(freeEnds(state.prims.filter(p => !p.hidden))[0]));
await record('remate por punta', { termPick: true, termBrush: 'pattee' }, () => click(endPt.x, endPt.y));
await record('otra vez en la misma punta lo quita', { termPick: true, termBrush: 'pattee' }, () => click(endPt.x, endPt.y));
lp = await letterPt();
await record('ocultar un trazo', { hideMode: true }, () => click(lp.x, lp.y));
await record('colocar un simbolo con iman', { stampMode: true, stampSym: '♂︎' }, () => click(560, 603));
// regresion (aa9ea1a): con «colocar» activo, arrastrar un simbolo ya puesto lo mueve y no crea otro
await record('con colocar activo, arrastrar un simbolo lo mueve sin duplicarlo', { stampMode: true, stampSym: '☉︎' }, () => drag(558.6, 603, -40, -35, 5));
// ── radial: los mismos botones del prototipo, pulsados en orden ──
const radial = await page4.evaluate(() => {
  Object.assign(state, { method: 'unique', mode: 'fusion', absorb: true, compact: true, overlap: 0, intention: '', hidden: [], endStyles: {}, terminals: 'none', termPick: false, hideMode: false, stampMode: false, sel: null });
  state.layers = [newLayer('circle'), newLayer('inscription', { text: 'LUX' }), newLayer('symbol', { sym: '♃︎', x: 300, y: 160 })];
  state.layerSel.letters = null;
  document.getElementById('intention').value = 'AMOR DIOS';
  generate();
  const docIn = { intention: 'AMOR DIOS', method: 'unique', mode: 'fusion', layers: JSON.parse(JSON.stringify(state.layers)) };
  const steps = [];
  const snap = label => { const t = ctxTarget(); steps.push({ label, anchor: t && { kind: t.kind, x: t.x, top: t.top, bottom: t.bottom }, users: Object.fromEntries(state.letters.map(l => [l.ch, { ...l.user }])), layers: state.layers.map(L => ({ id: L.id, size: L.size, scale: L.scale, rot: L.rot })), svg: buildSVG() }); };
  const ids = state.layers.map(L => L.id);
  const letter = activeLetters()[1].ch;
  state.sel = letter; render(); snap('elegir letra');
  for (const b of ['btnRotR', 'btnRotR', 'btnFlipV', 'btnBigger', 'btnBigger', 'btnSmaller', 'btnFlipH', 'btnRotL']) { document.getElementById(b).click(); snap(b); }
  document.getElementById('btnLetterReset').click(); snap('btnLetterReset');
  state.sel = null;
  for (const [id, btns] of [[ids[2], ['btnLayerBigger', 'btnLayerBigger', 'btnLayerRotL', 'btnLayerSmaller']], [ids[1], ['btnLayerBigger', 'btnLayerRotR']], [ids[0], ['btnLayerSmaller', 'btnLayerSmaller', 'btnLayerRotR', 'btnLayerDelete']]]) {
    state.layerSel.letters = id; render(); snap('elegir capa ' + id);
    for (const b of btns) { document.getElementById(b).click(); snap(b); }
  }
  return { docIn, letter, ids, steps };
});
const interaction = { pxScale: geo.pxScale, doc: geo.doc, intention: 'Mi practica mantiene enfoque sereno', probes, gestures, radial };
await b.close();
fs.mkdirSync(path.dirname(OUT), { recursive: true });
fs.writeFileSync(OUT.replace('letras.json', 'interaccion.json'), JSON.stringify(interaction));
fs.writeFileSync(OUT, JSON.stringify(out));
fs.writeFileSync(OUT.replace('letras.json', 'capas.json'), JSON.stringify(capas));
console.log(`${out.length} casos de letras, ${capas.stacks.length} pilas de capas, ${capas.svgs.length} SVG completos y ${sinTexto.length} imagenes de referencia; interaccion: ${interaction.probes.pts.length} puntos y ${interaction.gestures.length} gestos -> ${path.relative(process.cwd(), path.dirname(OUT))}`);
