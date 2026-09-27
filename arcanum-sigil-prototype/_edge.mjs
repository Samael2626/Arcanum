// Casos limite dirigidos del Taller de Sigilos: entradas que un generador
// aleatorio rara vez produce. Uso: node _edge.mjs
import { chromium } from 'playwright';
import path from 'path';
import { fileURLToPath } from 'url';
const __dirname = path.dirname(fileURLToPath(import.meta.url));
const INDEX = 'file:///' + path.join(__dirname, 'index.html').split('\\').join('/');
const browser = await chromium.launch().catch(() => chromium.launch({ channel: 'msedge' }));
const page = await browser.newPage({ viewport: { width: 1400, height: 1000 } });
const errors = [];
page.on('pageerror', e => errors.push(String(e)));
await page.goto(INDEX);
await page.waitForTimeout(300);

const results = [];
const check = (name, ok, detail = '') => { results.push(ok); console.log((ok ? 'PASS' : 'FAIL') + '  ' + name + (detail ? '  - ' + detail : '')); };
const svgOk = () => page.evaluate(() => { const s = buildSVG(); return !/NaN|undefined|Infinity/.test(s) && !new DOMParser().parseFromString(s, 'image/svg+xml').querySelector('parsererror'); });

// ── Sigilo de letras ──────────────────────────────────────────────
const LETTERS = [
  ['vacio', ''], ['solo espacios', '     '], ['solo digitos', '12345 678'], ['solo signos', '¿¡!?.,;:'],
  ['una letra', 'a'], ['una letra repetida', 'aaaa aaaa'], ['todas las letras', 'abcdefghijklmnopqrstuvwxyz'],
  ['acentos y enie', 'Ñandú ágil éxito'], ['mayusculas', 'LUZ DEL ALBA'], ['largo', 'mi practica mantiene enfoque sereno cada dia con calma y fuerza'],
  ['M y W juntas', 'MUNDO WEB'], ['solo vocales', 'aeiou'], ['hebreo en letras', 'שלום'], ['mezcla', 'luz אור'], ['emoji', 'luz ✨ y fuego 🔥']
];
for (const [name, text] of LETTERS) for (const mode of ['fusion', 'block', 'cross']) for (const method of ['cooper', 'novowels', 'unique']) {
  const r = await page.evaluate(({ text, mode, method }) => {
    setFamily('letters');
    state.mode = mode; state.method = method; state.intention = '';
    document.getElementById('intention').value = text;
    try { generate(); } catch (e) { return { err: e.message }; }
    return { prims: state.prims.length, letters: state.letters.map(l => l.ch).join('') };
  }, { text, mode, method });
  const ok = !r.err && await svgOk();
  if (!ok) check(`letras [${name}] ${mode}/${method}`, false, r.err || 'SVG roto');
}
check('letras: 15 casos limite x 3 modos x 3 reducciones sin excepciones ni SVG roto', !results.includes(false));

// Vacio no debe dejar trazos de un sigilo anterior
const stale = await page.evaluate(() => {
  setFamily('letters'); state.intention = '';
  document.getElementById('intention').value = 'AMOR'; generate();
  const before = state.prims.length;
  document.getElementById('intention').value = '12345'; generate();
  return { before, after: state.prims.length, letters: state.letters.map(l => l.ch).join('') };
});
check('letras: una entrada sin letras no presenta el sigilo anterior como suyo', stale.after === 0 || stale.letters === 'AMOR', JSON.stringify(stale));

// ── Rosa y Kamea ──────────────────────────────────────────────────
const HEB = [
  ['vacio', ''], ['espacios', '   '], ['una letra', 'א'], ['misma letra repetida', 'אאאא'], ['solo finales', 'ךםןףץ'],
  ['con puntos vocalicos', 'שָׁלוֹם'], ['tres palabras', 'אב גד הו'], ['palabra de una letra y otra', 'ו מטטרון'],
  ['largo', 'אבגדהוזחטיכלמנסעפצקרשת'], ['latin', 'abc'], ['mezcla', 'luz אור'], ['ida y vuelta', 'אבאבאבאב']
];
for (const [name, heb] of HEB) {
  const r = await page.evaluate(heb => {
    const out = {};
    setFamily('rosa');
    document.getElementById('rosaHebrew').value = heb;
    try { rosaTraceFromHebrew(); } catch (e) { out.rosaErr = e.message; }
    out.rosaWords = state.rosa.words.length;
    setFamily('kamea');
    for (const k of KAMEAS) for (const red of ['agrippa', 'zeros', 'aiq']) for (const grid of [true, false]) {
      state.kamea.planet = k.id; state.kamea.reduce = red; state.kamea.grid = grid;
      document.getElementById('kameaHebrew').value = heb;
      try { kameaTraceFromHebrew(); } catch (e) { out.kameaErr = `${k.id}/${red}: ${e.message}`; }
      const s = buildSVG();
      if (/NaN|undefined|Infinity/.test(s)) out.kameaNaN = `${k.id}/${red}/${grid}`;
    }
    return out;
  }, heb);
  const ok = !r.rosaErr && !r.kameaErr && !r.kameaNaN && await svgOk();
  check(`rosa y kamea [${name}]`, ok, r.rosaErr || r.kameaErr || r.kameaNaN || '');
}

// Una sola casilla repetida (אאאא): un circulo, sin linea ni barra, en todas las vistas
const one = await page.evaluate(() => {
  setFamily('kamea'); state.kamea.planet = 'saturn'; state.kamea.grid = false;
  document.getElementById('kameaHebrew').value = 'אאאא'; kameaTraceFromHebrew();
  const s = buildSVG();
  return { starts: (s.match(/data-mark="start"/g) || []).length, lines: (s.match(/data-mark="line"/g) || []).length, ends: (s.match(/data-mark="end"/g) || []).length };
});
check('kamea: una sola casilla da un circulo, sin linea ni barra', one.starts === 1 && one.lines === 0 && one.ends === 0, JSON.stringify(one));

// Ida y vuelta muchas veces: carriles en paralelo, sin salirse del cuadro
const lanes = await page.evaluate(() => {
  setFamily('kamea'); state.kamea.planet = 'saturn'; state.kamea.grid = false;
  document.getElementById('kameaHebrew').value = 'אבאבאבאבאבאב'; kameaTraceFromHebrew();
  const pts = kameaFit(state.kamea.words).flat();
  const d = (buildSVG().match(/data-mark="line" d="([^"]+)"/) || [])[1] || '';
  const nums = d.match(/-?\d+\.\d+/g).map(Number);
  return { inside: nums.every(v => v > -1 && v < SIZE + 1), curves: (d.match(/ C /g) || []).length, n: pts.length };
});
check('kamea: ida y vuelta x6 en carriles, dentro del cuadro', lanes.inside && lanes.curves >= 5, JSON.stringify(lanes));

check('sin errores de pagina', errors.length === 0, errors.slice(0, 2).join(' | '));
await browser.close();
const fails = results.filter(x => !x).length;
console.log(`\n==== ${results.length} checks, ${fails} FAIL ====`);
process.exit(fails ? 1 : 0);
