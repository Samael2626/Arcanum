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
await b.close();
fs.mkdirSync(path.dirname(OUT), { recursive: true });
fs.writeFileSync(OUT, JSON.stringify(out));
console.log(`${out.length} casos -> ${path.relative(process.cwd(), OUT)}`);
