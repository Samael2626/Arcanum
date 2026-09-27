// Pruebas de control por propiedades del Taller de Sigilos.
// Uso: node _fuzz.mjs [semilla] [n]
// Genera entradas aleatorias (con semilla, reproducibles) y exige invariantes
// en los tres motores, mas una prueba de estres de la interfaz.
import { chromium } from 'playwright';
import path from 'path';
import { fileURLToPath } from 'url';
const __dirname = path.dirname(fileURLToPath(import.meta.url));
// 3er argumento opcional: otro HTML (pruebas de mutacion)
const INDEX = 'file:///' + (process.argv[4] ? path.resolve(process.argv[4]) : path.join(__dirname, 'index.html')).split('\\').join('/');
const SEED = Number(process.argv[2] || 1), N = Number(process.argv[3] || 150);

const browser = await chromium.launch().catch(() => chromium.launch({ channel: 'msedge' }));
const page = await browser.newPage({ viewport: { width: 1400, height: 1000 } });
const errors = [];
page.on('pageerror', e => errors.push(String(e)));
page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
await page.goto(INDEX);
await page.waitForTimeout(300);

const res = await page.evaluate(({ SEED, N }) => {
  // PRNG con semilla (mulberry32)
  let a = SEED >>> 0;
  const rnd = () => { a |= 0; a = a + 0x6D2B79F5 | 0; let t = Math.imul(a ^ a >>> 15, 1 | a); t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; };
  const pick = arr => arr[Math.floor(rnd() * arr.length)];
  const int = (lo, hi) => lo + Math.floor(rnd() * (hi - lo + 1));
  const fails = [];
  const fail = (engine, input, why) => { if (fails.length < 40) fails.push(`${engine} [${input}] ${why}`); };
  const badNum = s => /NaN|undefined|Infinity/.test(s);
  const parses = s => !new DOMParser().parseFromString(s, 'image/svg+xml').querySelector('parsererror');
  const inCanvas = (x, y) => x >= -1 && x <= SIZE + 1 && y >= -1 && y <= SIZE + 1;

  const LAT = 'abcdefghijklmnopqrstuvwxyzáéíóúüñ';
  const latinWord = () => [...Array(int(1, 9))].map(() => rnd() < .06 ? pick('0123456789-.,!¿?') : pick(LAT)).join('');
  const intention = () => { const w = [...Array(int(1, 7))].map(latinWord); if (rnd() < .3) w[0] = w[0].toUpperCase(); return w.join(pick([' ', ' ', '  ', ', '])); };
  const HEB = 'אבגדהוזחטיכלמנסעפצקרשת', FIN = 'ךםןףץ', NIQ = '\u05B0\u05B4\u05B7\u05B8\u05BC\u05B9';
  const hebWord = () => { let w = ''; const n = int(1, 9); for (let i = 0; i < n; i++) { w += rnd() < .12 && i ? w[w.length - 1] : pick(HEB); if (rnd() < .1) w += pick(NIQ); } if (rnd() < .4) w += pick(FIN); return w; };
  const hebrew = () => [...Array(rnd() < .75 ? 1 : int(2, 3))].map(hebWord).join(' ');
  const stats = { letters: 0, rosa: 0, kamea: 0 };

  // ── Sigilo de letras ────────────────────────────────────────────
  setFamily('letters');
  for (let i = 0; i < N; i++) {
    const text = intention(), method = pick(['cooper', 'novowels', 'unique']), mode = pick(['fusion', 'block', 'cross']);
    state.method = method; state.mode = mode; state.compact = rnd() < .7; state.absorb = rnd() < .7;
    state.overlap = pick([0, .25, .5]); state.intention = '';
    document.getElementById('intention').value = text;
    const tag = `${text} | ${method}/${mode}`;
    try { generate(); } catch (e) { fail('letras', tag, 'excepcion: ' + e.message); continue; }
    stats.letters++;
    // sin letras tras la reduccion: lienzo vacio, nunca el sigilo anterior
    if (!state.letters.length) {
      if (state.prims.length) fail('letras', tag, 'sin letras pero quedan trazos (sigilo anterior)');
      if (state.intention !== text) fail('letras', tag, 'la intencion en estado no es la escrita');
      continue;
    }
    if (!state.prims.length) { fail('letras', tag, 'sin trazos'); continue; }
    if (state.prims.some(p => !p.units.length && p.kind !== 'cross')) fail('letras', tag, 'trazo sin procedencia');
    if (activeLetters().some(l => l.legible !== 1)) fail('letras', tag, 'letra no legible al 100% sin ocultar nada');
    const s1 = buildSVG(), s2 = buildSVG();
    if (s1 !== s2) fail('letras', tag, 'no determinista');
    if (badNum(s1)) fail('letras', tag, 'NaN/undefined en SVG');
    if (!parses(s1)) fail('letras', tag, 'SVG invalido');
    for (const p of state.prims) for (const q of primPoints(p)) { const c = toCanvas(q); if (!inCanvas(c.x, c.y)) { fail('letras', tag, `fuera del lienzo (${c.x.toFixed(0)},${c.y.toFixed(0)})`); break; } }
    if (mode === 'fusion') {
      let x0 = Infinity, x1 = -Infinity;
      for (const p of state.prims) for (const q of primPoints(p)) { x0 = Math.min(x0, q.x); x1 = Math.max(x1, q.x); }
      if (x1 - x0 > 1.001) fail('letras', tag, `fusion ensancha: ${(x1 - x0).toFixed(2)} cajas`);
    }
    if (mode === 'block') {
      const cells = activeLetters().map(l => l.base.tx.toFixed(3) + ',' + l.base.ty.toFixed(3));
      if (new Set(cells).size !== cells.length) fail('letras', tag, 'dos letras en la misma celda');
    }
    if (mode === 'cross') {
      const center = activeLetters().filter(l => l.base.tx === 0 && l.base.ty === 0).map(l => l.ch);
      const vow = activeLetters().filter(l => VOWELS.has(l.ch)).map(l => l.ch);
      const ok = vow.length ? center.join('') === vow.join('') : center.length === 1 && center[0] === activeLetters()[0].ch;
      if (!ok) fail('letras', tag, `centro de la cruz ${center.join('')} (vocales ${vow.join('')})`);
    }
    // cada gemela lo es de verdad: su forma coincide con la de su letra tras giro o reflejo
    for (const l of state.letters.filter(x => x.twin)) {
      if (!DIHEDRAL.some(D => shapeSig(l.twin.by, D) === shapeSig(l.ch))) fail('letras', tag, `gemela falsa ${l.ch}~${l.twin.by}`);
    }
  }

  // ── Edicion + galeria: ediciones aleatorias y vuelta de guardar/restaurar ──
  let roundtrips = 0;
  try { localStorage.clear(); } catch {}
  for (let i = 0; i < Math.ceil(N / 3); i++) {
    const text = [...Array(int(2, 4))].map(() => [...Array(int(3, 7))].map(() => pick('abcdefghilmnoprstuvz')).join('')).join(' ');
    state.mode = pick(['fusion', 'block', 'cross']); state.method = pick(['cooper', 'unique']); state.intention = '';
    document.getElementById('intention').value = text;
    generate();
    if (!state.letters.length) continue;
    const act = activeLetters();
    for (let e = 0; e < int(1, 6); e++) {
      state.sel = pick(act).ch;
      const op = pick(['rot', 'flipH', 'flipV', 'big', 'small', 'hide', 'term', 'endTerm', 'stamp', 'star', 'border']);
      if (op === 'rot') editSelected(u => { u.drot += pick([15, -15, 90]); }, 'girar');
      else if (op === 'flipH') editSelected(u => { u.fx = !u.fx; }, 'reflejar');
      else if (op === 'flipV') editSelected(u => { u.fy = !u.fy; }, 'reflejar');
      else if (op === 'big') editSelected(u => { u.ds = Math.min(2, u.ds * 1.15); }, 'escalar');
      else if (op === 'small') editSelected(u => { u.ds = Math.max(.4, u.ds / 1.15); }, 'escalar');
      else if (op === 'hide' && state.prims.length) toggleHidden(pick(state.prims).key);
      else if (op === 'term') { state.terminals = pick(TERMINALS).id; render(); }
      else if (op === 'endTerm') { const ends = freeEnds(state.prims.filter(p => !p.hidden)); if (ends.length) { state.endStyles[pick(ends).key] = pick(TERMINALS).id; render(); } }
      else if (op === 'stamp') { state.stamps.push({ x: int(40, 760), y: int(40, 760), sym: pick(STAMP_CATALOG.flatMap(g => g[1])).sym, size: int(20, 120) }); render(); }
      else if (op === 'star') { state.star.enabled = true; state.star.points = int(5, 9); render(); }
      else if (op === 'border') { state.border = pick(['none', 'circle', 'square', 'triangle']); state.view = fitView(); render(); }
    }
    const tag = `${text} | ${state.mode}`;
    const s1 = buildSVG();
    if (s1 !== buildSVG()) fail('edicion', tag, 'no determinista tras editar');
    if (badNum(s1) || !parses(s1)) fail('edicion', tag, 'SVG roto tras editar');
    if (activeLetters().some(l => l.legible > 1 || l.legible < 0)) fail('edicion', tag, 'legibilidad fuera de 0..1');
    // guardar y restaurar debe devolver exactamente el mismo signo
    const saved = JSON.parse(JSON.stringify(captureState()));
    state.intention = ''; document.getElementById('intention').value = 'otra cosa distinta'; generate();
    restoreState(saved);
    const s2 = buildSVG();
    if (s2 !== s1) fail('galeria', tag, 'restaurar no devuelve el mismo SVG');
    roundtrips++;
    // limpieza para el siguiente caso
    Object.assign(state, { stamps: [], endStyles: {}, terminals: 'none', border: 'none' }); state.star.enabled = false;
  }
  stats.roundtrips = roundtrips;

  // ── Rosa-Cruz ───────────────────────────────────────────────────
  setFamily('rosa');
  for (let i = 0; i < N; i++) {
    const heb = hebrew(), endBar = rnd() < .8;
    state.rosa.endBar = endBar;
    document.getElementById('rosaHebrew').value = heb;
    try { rosaTraceFromHebrew(); } catch (e) { fail('rosa', heb, 'excepcion: ' + e.message); continue; }
    stats.rosa++;
    const ro = state.rosa, words = cleanHebrew(heb).split(' ').filter(Boolean);
    if (ro.words.length !== words.length) fail('rosa', heb, `palabras ${ro.words.length} != ${words.length}`);
    const s = buildSVG();
    if (s !== buildSVG()) fail('rosa', heb, 'no determinista');
    if (badNum(s)) fail('rosa', heb, 'NaN en SVG');
    if (!parses(s)) fail('rosa', heb, 'SVG invalido');
    const starts = (s.match(/data-mark="start"/g) || []).length, ends = (s.match(/data-mark="end"/g) || []).length;
    if (starts !== ro.words.filter(w => w.length).length) fail('rosa', heb, `circulos ${starts}`);
    const wantEnds = endBar ? ro.words.filter(w => w.length > 1).length : 0;
    if (ends !== wantEnds) fail('rosa', heb, `barras ${ends} != ${wantEnds}`);
    ro.words.forEach((w, wi) => {
      const letters = w.map(v => v.he);
      for (let k = 0; k + 1 < w.length; k++) if (w[k].he === w[k + 1].he) fail('rosa', heb, 'dos vertices seguidos con la misma letra');
      w.forEach((v, k) => {
        if (!inCanvas(v.x, v.y)) fail('rosa', heb, 'vertice fuera del lienzo');
        if (v.pass) {
          const idx = letters.indexOf(v.pass.he);
          if (idx < 0) fail('rosa', heb, `lazo en letra ajena ${v.pass.he}`);
          if (v.pass.he === letters[0] || v.pass.he === letters[letters.length - 1]) fail('rosa', heb, 'lazo de paso en primera/ultima');
          if (idx <= k + 1) fail('rosa', heb, `lazo en letra ya visitada ${v.pass.he}`);
          if (v.pass.d >= PASS_DIST) fail('rosa', heb, 'lazo de paso demasiado lejos');
        }
        if (v.noose && !(v.turn < NOOSE_MAX_TURN)) fail('rosa', heb, 'lazo de vertice con giro grande');
      });
    });
    const g = gematria(ro.hebrew);
    if (g.std > g.gadol) fail('rosa', heb, 'gematria estandar > mayor');
  }

  // ── Kamea ───────────────────────────────────────────────────────
  setFamily('kamea');
  for (let i = 0; i < N; i++) {
    const k = pick(KAMEAS), heb = hebrew(), reduce = pick(['agrippa', 'zeros', 'aiq']), grid = rnd() < .5;
    state.kamea.planet = k.id; state.kamea.reduce = reduce; state.kamea.grid = grid; state.kamea.ends = pick(['agrippa', 'gd']);
    document.getElementById('kameaHebrew').value = heb;
    const tag = `${heb} | ${k.id}/${reduce}`;
    try { kameaTraceFromHebrew(); } catch (e) { fail('kamea', tag, 'excepcion: ' + e.message); continue; }
    stats.kamea++;
    const n = k.rows.length, max = n * n, pos = kameaGeom(k).pos;
    for (const w of state.kamea.words) for (const st of w) {
      if (!pos[st.cell]) { fail('kamea', tag, `casilla ${st.cell} no existe (valor ${st.v})`); continue; }
      if (st.v <= max && (st.cell !== st.v || st.reduced)) fail('kamea', tag, `valor ${st.v} cabe y se redujo a ${st.cell}`);
      if (st.v > max) {
        const m = reduce === 'agrippa' ? (max <= 36 ? 'aiq' : 'zeros') : reduce;
        const lead = Number(String(st.v)[0]);
        if (m === 'aiq' && st.cell !== lead) fail('kamea', tag, `aiq ${st.v} -> ${st.cell}, esperaba ${lead}`);
        if (m === 'zeros') {
          let c = st.v; while (c > max && c % 10 === 0) c /= 10; while (c > max) c = Math.floor(c / 10);
          if (st.cell !== c) fail('kamea', tag, `ceros ${st.v} -> ${st.cell}, esperaba ${c}`);
        }
      }
    }
    const s = buildSVG();
    if (s !== buildSVG()) fail('kamea', tag, 'no determinista');
    if (badNum(s)) fail('kamea', tag, 'NaN en SVG');
    if (!parses(s)) fail('kamea', tag, 'SVG invalido');
    const words = grid ? state.kamea.words : kameaFit(state.kamea.words);
    for (const w of words) for (const q of w) if (!inCanvas(q.x, q.y)) { fail('kamea', tag, `fuera del lienzo (${q.x.toFixed(0)},${q.y.toFixed(0)})`); break; }
    const distinct = w => w.filter((st, j) => j === 0 || st.cell !== w[j - 1].cell).length;
    const expStarts = state.kamea.words.filter(w => w.length).length;
    const expEnds = state.kamea.words.filter(w => distinct(w) > 1).length;
    const starts = (s.match(/data-mark="start"/g) || []).length, ends = (s.match(/data-mark="end"/g) || []).length;
    if (starts !== expStarts || ends !== expEnds) fail('kamea', tag, `extremos ${starts}/${ends}, esperaba ${expStarts}/${expEnds}`);
  }
  setFamily('letters');
  return { fails, stats };
}, { SEED, N });

// ── Estres de interfaz: clics aleatorios por todos los paneles ────
let s = SEED * 7919 >>> 0;
const rnd = () => { s = (s * 1103515245 + 12345) >>> 0; return s / 4294967296; };
const monkeyFails = [];
for (let step = 0; step < N * 2; step++) {
  const handles = await page.$$('button:visible, select:visible, input[type=checkbox]:visible, input[type=range]:visible');
  if (!handles.length) break;
  const h = handles[Math.floor(rnd() * handles.length)];
  const info = await h.evaluate(e => ({ tag: e.tagName, type: e.type, id: e.id, n: e.options ? e.options.length : 0, min: e.min, max: e.max }));
  // descargas y galeria no aportan al estres
  if (['btnSVG', 'btnPNG', 'btnRosaSVG', 'btnKameaSVG', 'btnSave'].includes(info.id)) continue;
  try {
    if (info.tag === 'SELECT') await h.selectOption({ index: Math.floor(rnd() * info.n) });
    else if (info.type === 'range') await h.fill(String(Math.round(Number(info.min) + rnd() * (Number(info.max) - Number(info.min)))));
    else await h.click({ timeout: 800 });
  } catch { /* elemento tapado por un modal: se cierra abajo */ }
  if (rnd() < .15) await page.keyboard.press('Escape');
  if (step % 25 === 0) {
    const bad = await page.evaluate(() => /NaN|undefined/.test(buildSVG()));
    if (bad) monkeyFails.push(`paso ${step}: NaN en SVG (familia ${await page.evaluate(() => state.family)})`);
  }
}

await browser.close();
const all = [...res.fails, ...monkeyFails, ...errors.map(e => 'error de pagina: ' + e)];
console.log(`semilla ${SEED}, n=${N}: letras ${res.stats.letters}, ediciones+galeria ${res.stats.roundtrips}, rosa ${res.stats.rosa}, kamea ${res.stats.kamea}, clics ${N * 2}`);
all.slice(0, 40).forEach(f => console.log('FAIL  ' + f));
console.log(`==== ${all.length} fallos ====`);
process.exit(all.length ? 1 : 0);
