'use strict';
// ════════════════════════════════════════════════════════════════
//  TALLER DE SIGILOS v3 — sigilo de letras
//  Metodo de la palabra (Spare; Frater U.D., Practical Sigil Magic,
//  cap. 2): se tachan las letras repetidas y las que quedan se funden
//  y estilizan "con las letras reconocibles, aunque cueste".
//  Las letras son el material: se dibujan con su forma real sobre una
//  caja comun, los trazos que coinciden se comparten y cada trazo
//  conserva de que letra sale. Determinista: sin azar.
// ════════════════════════════════════════════════════════════════

const SIZE = 800, C = SIZE / 2, CORE_R = 250, EPS = 0.012;
const $ = id => document.getElementById(id);
const rad = d => d * Math.PI / 180;
const esc = s => String(s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#039;' }[c]));
// Procedencia en lenguaje llano: el codigo interno no se muestra
const TAG_INFO = {
  HP: ['Fuente histórica', 'Documentado en manuscritos, monedas o ediciones antiguas.'],
  OM: ['Ocultismo moderno', 'Autor moderno identificable (siglos XIX y XX).'],
  RC: ['Reconstrucción', 'Reconstrucción actual: útil, pero sin una fuente directa.'],
  AR: ['Decisión de ARCANUM', 'Elección de diseño de la app, no de una fuente.']
};
const badge = tag => tag.split('/').map(t => `<span class="tag tag-${t.toLowerCase()}" title="${TAG_INFO[t][1]}">${TAG_INFO[t][0]}</span>`).join(' ');
const tagText = tag => tag.split('/').map(t => TAG_INFO[t][0]).join(' y ');
// Escapa el texto y convierte [HP] [OM] [RC] [AR] en etiquetas legibles
const withBadges = t => esc(t).replace(/\[(HP|OM|RC|AR)\]/g, (_, k) => badge(k));
// Cita traducida al espanol; el original en ingles queda en el tooltip
const cita = (es, en) => `<q title="Original en inglés: ${esc(en)}">${es}</q>`;

// ── Capitales de trazo unico ────────────────────────────────────
// Caja 1x1, y hacia abajo. L = segmento; A = arco con angulos en
// grados medidos en sentido horario (convencion de canvas/SVG).
// Todas comparten rejilla (0, .5, 1) para que los trazos coincidan.
const L = (x1, y1, x2, y2) => ({ t: 'L', x1, y1, x2, y2 });
const A = (cx, cy, r, a0, a1) => ({ t: 'A', cx, cy, r, a0, a1 });
const P_BOWL = [L(0, 0, 0, 1), L(0, 0, .55, 0), A(.55, .25, .25, -90, 90), L(.55, .5, 0, .5)];
const GLYPHS = {
  A: [L(0, 1, .5, 0), L(.5, 0, 1, 1), L(.25, .5, .75, .5)],
  B: [L(0, 0, 0, 1), L(0, 0, .55, 0), A(.55, .25, .25, -90, 90), L(0, .5, .6, .5), A(.6, .75, .25, -90, 90), L(.6, 1, 0, 1)],
  C: [A(.5, .5, .5, 45, 315)],
  D: [L(0, 0, 0, 1), L(0, 0, .5, 0), A(.5, .5, .5, -90, 90), L(.5, 1, 0, 1)],
  E: [L(0, 0, 0, 1), L(0, 0, 1, 0), L(0, .5, .8, .5), L(0, 1, 1, 1)],
  F: [L(0, 0, 0, 1), L(0, 0, 1, 0), L(0, .5, .8, .5)],
  G: [A(.5, .5, .5, 0, 315), L(.5, .5, 1, .5)],
  H: [L(0, 0, 0, 1), L(1, 0, 1, 1), L(0, .5, 1, .5)],
  I: [L(.5, 0, .5, 1)],
  J: [L(1, 0, 1, .65), A(.65, .65, .35, 0, 180)],
  K: [L(0, 0, 0, 1), L(1, 0, 0, .5), L(0, .5, 1, 1)],
  L: [L(0, 0, 0, 1), L(0, 1, 1, 1)],
  M: [L(0, 1, 0, 0), L(0, 0, .5, .6), L(.5, .6, 1, 0), L(1, 0, 1, 1)],
  N: [L(0, 1, 0, 0), L(0, 0, 1, 1), L(1, 1, 1, 0)],
  O: [A(.5, .5, .5, 0, 360)],
  P: P_BOWL,
  Q: [A(.5, .5, .5, 0, 360), L(.6, .6, 1, 1)],
  R: [...P_BOWL, L(.45, .5, 1, 1)],
  S: [A(.5, .25, .25, -30, -270), A(.5, .75, .25, -90, 150)],
  T: [L(0, 0, 1, 0), L(.5, 0, .5, 1)],
  U: [L(0, 0, 0, .5), A(.5, .5, .5, 180, 0), L(1, .5, 1, 0)],
  V: [L(0, 0, .5, 1), L(.5, 1, 1, 0)],
  W: [L(0, 0, 0, 1), L(0, 1, .5, .4), L(.5, .4, 1, 1), L(1, 1, 1, 0)],
  X: [L(0, 0, 1, 1), L(1, 0, 0, 1)],
  Y: [L(0, 0, .5, .5), L(1, 0, .5, .5), L(.5, .5, .5, 1)],
  Z: [L(0, 0, 1, 0), L(1, 0, 0, 1), L(0, 1, 1, 1)]
};
const VOWELS = new Set(['A', 'E', 'I', 'O', 'U']);

// ── Reduccion nombrada ──────────────────────────────────────────
const REDUCTIONS = {
  cooper: { label: 'Cooper — iniciales únicas', tag: 'OM', rule: 'Inicial de cada palabra, sin repetir. Si quedan menos de 3, se completa con las letras únicas del texto [AR].' },
  novowels: { label: 'Únicas sin vocales', tag: 'OM', rule: 'Se quitan vocales y repeticiones. Variante moderna, no receta exclusiva de Spare.' },
  unique: { label: 'Letras únicas', tag: 'OM', rule: 'Se tacha toda letra repetida (Spare; Frater U∴D∴, método de la palabra).' }
};

function reduce(text, method) {
  const norm = text.normalize('NFD').replace(/[̀-ͯ]/g, '').toUpperCase();
  const words = norm.split(/[^A-Z]+/).filter(Boolean);
  const cleaned = words.join('');
  const uniq = s => [...new Set(s)];
  let units;
  if (method === 'cooper') {
    units = uniq(words.map(w => w[0]));
    if (units.length < 3) units = uniq([...units, ...cleaned]);
  } else if (method === 'novowels') {
    units = uniq(cleaned.replace(/[AEIOU]/g, ''));
  } else {
    units = uniq(cleaned);
  }
  return { original: text, cleaned, units, ...REDUCTIONS[method] };
}

// ── Transformaciones ────────────────────────────────────────────
// T = { tx, ty, s, rot, fx, fy }: reflejo, giro (horario) y escala
// alrededor del centro de la caja; luego traslacion al punto (tx, ty).
function xform(x, y, T) {
  let u = x - .5, v = y - .5;
  if (T.fx) u = -u;
  if (T.fy) v = -v;
  const c = Math.cos(rad(T.rot)), s = Math.sin(rad(T.rot));
  return { x: T.tx + (u * c - v * s) * T.s, y: T.ty + (u * s + v * c) * T.s };
}
function xformAngle(a, T) {
  if (T.fx) a = 180 - a;
  if (T.fy) a = -a;
  return a + T.rot;
}
function normArc(c, r, a0, a1, units) {
  const span = Math.min(360, Math.abs(a1 - a0));
  const lo = ((Math.min(a0, a1) % 360) + 360) % 360;
  return { t: 'A', c, r, a0: lo, a1: lo + span, units };
}
function placePrim(pr, T, units) {
  if (pr.t === 'L') return { t: 'L', a: xform(pr.x1, pr.y1, T), b: xform(pr.x2, pr.y2, T), units: [...units] };
  return normArc(xform(pr.cx, pr.cy, T), pr.r * T.s, xformAngle(pr.a0, T), xformAngle(pr.a1, T), [...units]);
}
const ID_T = { tx: .5, ty: .5, s: 1, rot: 0, fx: false, fy: false };

// ── Fusion de trazos compartidos ────────────────────────────────
// Dos segmentos colineales que se solapan son un solo trazo; dos arcos
// del mismo circulo que se solapan tambien. El trazo resultante guarda
// todas las letras que lo usan.
function mergeLine(p, q) {
  const dx = q.b.x - q.a.x, dy = q.b.y - q.a.y, len = Math.hypot(dx, dy);
  if (len < 1e-9) return null;
  const ux = dx / len, uy = dy / len;
  const off = pt => Math.abs((pt.x - q.a.x) * uy - (pt.y - q.a.y) * ux);
  if (off(p.a) > EPS || off(p.b) > EPS) return null;
  const t = pt => (pt.x - q.a.x) * ux + (pt.y - q.a.y) * uy;
  const p0 = Math.min(t(p.a), t(p.b)), p1 = Math.max(t(p.a), t(p.b));
  if (Math.min(p1, len) - Math.max(p0, 0) < 0.02) return null;
  const t0 = Math.min(0, p0), t1 = Math.max(len, p1);
  return { t: 'L', a: { x: q.a.x + ux * t0, y: q.a.y + uy * t0 }, b: { x: q.a.x + ux * t1, y: q.a.y + uy * t1 } };
}
function mergeArc(p, q) {
  if (Math.hypot(p.c.x - q.c.x, p.c.y - q.c.y) > EPS || Math.abs(p.r - q.r) > EPS) return null;
  for (const sh of [-360, 0, 360]) {
    const lo = p.a0 + sh, hi = p.a1 + sh;
    if (Math.min(hi, q.a1) - Math.max(lo, q.a0) >= 2) {
      const a0 = Math.min(lo, q.a0);
      return normArc(q.c, q.r, a0, Math.min(Math.max(hi, q.a1), a0 + 360));
    }
  }
  return null;
}
function mergeAll(prims) {
  const list = prims.map(p => ({ ...p, units: [...p.units] }));
  let changed = true;
  while (changed) {
    changed = false;
    scan: for (let i = 0; i < list.length; i++) {
      for (let j = i + 1; j < list.length; j++) {
        const p = list[i], q = list[j];
        if (p.t !== q.t) continue;
        const m = p.t === 'L' ? mergeLine(q, p) : mergeArc(q, p);
        if (!m) continue;
        m.units = [...new Set([...p.units, ...q.units])];
        m.kind = p.kind || q.kind;
        list.splice(j, 1);
        list[i] = m;
        changed = true;
        break scan;
      }
    }
  }
  return list;
}

// Firma geometrica estable: sirve de clave para ocultar trazos y para
// comparar formas de letras.
const r2 = v => (Math.round(v * 100) / 100 + 0).toFixed(2);
function sig(p) {
  if (p.t === 'L') return 'L' + [p.a, p.b].map(q => r2(q.x) + ',' + r2(q.y)).sort().join('|');
  const base = r2(p.c.x) + ',' + r2(p.c.y) + ',' + r2(p.r);
  if (p.a1 - p.a0 >= 359.5) return 'O' + base;
  return 'A' + base + ',' + (Math.round(p.a0) % 360) + ',' + Math.round(p.a1 - p.a0);
}

// ── Letras gemelas (absorcion) ──────────────────────────────────
// Frater U.D.: una M puede leerse como W invertida, asi que no hace
// falta dibujar ambas. Se comprueba de verdad: la forma de una letra
// debe coincidir con otra ya presente tras girarla o reflejarla.
const DIHEDRAL = [
  { rot: 90, fx: false, fy: false, how: 'giro de 90°' },
  { rot: 180, fx: false, fy: false, how: 'giro de 180°' },
  { rot: 270, fx: false, fy: false, how: 'giro de 270°' },
  { rot: 0, fx: true, fy: false, how: 'reflejo horizontal' },
  { rot: 0, fx: false, fy: true, how: 'reflejo vertical' },
  { rot: 90, fx: true, fy: false, how: 'giro y reflejo' },
  { rot: 270, fx: true, fy: false, how: 'giro y reflejo' }
];
const shapeCache = {};
function shapeSig(ch, D) {
  const k = ch + (D ? D.rot + D.fx + D.fy : 'id');
  if (!shapeCache[k]) {
    const T = D ? { ...ID_T, rot: D.rot, fx: D.fx, fy: D.fy } : ID_T;
    shapeCache[k] = mergeAll(GLYPHS[ch].map(p => placePrim(p, T, [ch]))).map(sig).sort().join(';');
  }
  return shapeCache[k];
}
function findTwin(ch, kept) {
  const own = shapeSig(ch);
  for (const k of kept) for (const D of DIHEDRAL) if (shapeSig(k, D) === own) return { by: k, how: D.how };
  return null;
}

// ── Composiciones ───────────────────────────────────────────────
const MODES = {
  fusion: {
    label: 'Fusión', tag: 'OM',
    help: 'Todas las letras en la misma caja, una encima de otra. Los trazos que coinciden se comparten. Es el monograma de Spare: el más compacto y el menos legible.',
    hand: ['Dibuja un cuadrado de guía.', 'Escribe la primera letra ocupando todo el cuadrado.', 'Escribe encima cada letra siguiente, en el mismo cuadrado, reutilizando los trazos que ya existen.', 'Si una letra es giro o reflejo de otra ya dibujada, ya está dentro: no la repitas.', 'Si el conjunto se amontona, gira, refleja o escala una letra.', 'Borra la guía y redibuja el signo de memoria.']
  },
  block: {
    label: 'Bloque', tag: 'HP/AR',
    help: 'Cada letra en su celda; las celdas vecinas comparten el borde. Monograma de bloque, como los bizantinos. El solape acerca las letras hacia la fusión.',
    hand: ['Dibuja una rejilla de celdas cuadradas, tantas como letras.', 'Escribe una letra por celda, en el orden de la reducción.', 'Donde dos letras tocan el mismo borde, deja un solo trazo.', 'Borra la rejilla y redibuja el signo de memoria.']
  },
  cross: {
    label: 'Cruz', tag: 'HP',
    help: 'Vocales fundidas en el centro y consonantes en los brazos de una cruz, como el monograma KAROLVS de Carlomagno (769). El más legible.',
    hand: ['Funde las vocales en un cuadrado central (si no hay, usa la primera letra).', 'Traza una cruz desde el centro.', 'Coloca las consonantes como en KAROLVS: la primera a la izquierda, la segunda arriba, la tercera abajo y la cuarta a la derecha (K…S se lee en horizontal, R…L en vertical).', 'Si sobran consonantes, añade una segunda letra más afuera en cada brazo.']
  }
};
// Orden del monograma KAROLVS (diploma de Carlomagno): K izquierda, R arriba,
// L abajo, S derecha. Primera y ultima consonante en horizontal; las de en medio en vertical
const ARMS = [[-1, 0], [0, -1], [0, 1], [1, 0]];

// Devuelve la transformacion base de cada letra activa y los trazos
// propios de la composicion (brazos de la cruz).
// Encaje compacto (Fusion): cada letra prueba a desplazarse media caja y
// se queda donde comparte mas trazo con las ya puestas. Sin deformar letras.
// Cooper, fig. 4: la I no se dibuja aparte, es el asta de la D.
const COMPACT_SHIFTS = [0, -0.5, 0.5];
const primLength = p => p.t === 'L' ? Math.hypot(p.b.x - p.a.x, p.b.y - p.a.y) : p.r * rad(p.a1 - p.a0);
const totalLength = ps => ps.reduce((acc, p) => acc + primLength(p), 0);
function bboxArea(ps) {
  let x0 = Infinity, x1 = -Infinity, y0 = Infinity, y1 = -Infinity;
  for (const p of ps) for (const q of primPoints(p)) { x0 = Math.min(x0, q.x); x1 = Math.max(x1, q.x); y0 = Math.min(y0, q.y); y1 = Math.max(y1, q.y); }
  return (x1 - x0) * (y1 - y0);
}
function compactShift(ch, placed) {
  const baseLen = totalLength(mergeAll(placed));
  const at = dx => mergeAll(GLYPHS[ch].map(p => placePrim(p, { tx: dx, ty: 0, s: 1, rot: 0, fx: false, fy: false }, [ch])));
  // un desplazamiento solo vale si no agranda el signo: compacto, no ancho
  const maxArea = bboxArea([...placed, ...at(0)]) + 1e-6;
  let best = { dx: 0, gain: 0 };
  for (const dx of COMPACT_SHIFTS) {
    const own = at(dx);
    if (bboxArea([...placed, ...own]) > maxArea) continue;
    const gain = baseLen + totalLength(own) - totalLength(mergeAll([...placed, ...own]));
    if (gain > best.gain + 1e-6) best = { dx, gain };
  }
  return best.dx;
}

function layoutLetters(active, mode, overlap) {
  const base = {}, extra = [];
  const T = (tx, ty, s = 1) => ({ tx, ty, s, rot: 0, fx: false, fy: false });
  if (mode === 'fusion') {
    const placed = [];
    // primero las letras con mas trazo (anclan el signo); luego las pequenas encajan
    const glyphLen = ch => totalLength(mergeAll(GLYPHS[ch].map(p => placePrim(p, ID_T, [ch]))));
    const order = state.compact ? [...active].sort((a, b) => glyphLen(b.ch) - glyphLen(a.ch) || active.indexOf(a) - active.indexOf(b)) : active;
    order.forEach(l => {
      const dx = state.compact && placed.length ? compactShift(l.ch, placed) : 0;
      base[l.ch] = T(dx, 0);
      placed.push(...GLYPHS[l.ch].map(p => placePrim(p, base[l.ch], [l.ch])));
    });
  } else if (mode === 'block') {
    const n = active.length, cols = Math.ceil(Math.sqrt(n)), rows = Math.ceil(n / cols), step = 1 - overlap;
    active.forEach((l, i) => {
      const r = Math.floor(i / cols), c = i % cols;
      const inRow = r === rows - 1 ? n - cols * (rows - 1) : cols;
      base[l.ch] = T((c - (inRow - 1) / 2) * step, (r - (rows - 1) / 2) * step);
    });
  } else {
    let center = active.filter(l => VOWELS.has(l.ch));
    if (!center.length && active.length) center = [active[0]];
    const arms = active.filter(l => !center.includes(l));
    center.forEach(l => { base[l.ch] = T(0, 0); });
    const S = .8, D0 = 1.55, DK = 1.3;
    let lastReach = [.5, .5, .5, .5];
    arms.forEach((l, i) => {
      const arm = i % 4, ring = Math.floor(i / 4), d = D0 + ring * DK;
      const [dx, dy] = ARMS[arm];
      base[l.ch] = T(dx * d, dy * d, S);
      const from = lastReach[arm] + .1, to = d - S / 2 - .1;
      extra.push({ t: 'L', a: { x: dx * from, y: dy * from }, b: { x: dx * to, y: dy * to }, units: [], kind: 'cross' });
      lastReach[arm] = d + S / 2;
    });
  }
  return { base, extra };
}

// ── Estado ──────────────────────────────────────────────────────
const state = {
  family: 'letters',
  compare: { name: '', planet: 'sun' },
  personal: { source: 'letters', template: 'goetia', layers: [], name: '', planet: 'auto', view: 'paper', day: new Date().getDay() },
  layers: [],
  layerSel: { letters: null, personal: null },
  magnet: true,
  grid: 'none',
  guides: [],
  seal: { collection: 'agrippa1651', filter: 'all', id: 'saturno-sello', view: 'trace' },
  kamea: { planet: 'saturn', reduce: 'agrippa', ends: 'agrippa', grid: false, hebrew: '', words: [] },
  intention: '',
  method: 'cooper',
  reduction: null,
  mode: 'fusion',
  overlap: 0,
  absorb: true,
  compact: true,
  letters: [],     // { ch, twin, user: { dx, dy, ds, drot, fx, fy } }
  extra: [],
  prims: [],
  hidden: [],
  decisions: [],
  sel: null,
  hideMode: false,
  theme: 'build',
  terminals: 'none',   // remate general
  termBrush: 'dot',    // remate que se pone en modo uno a uno
  termScale: 100,
  endStyles: {},       // extremo (clave geometrica) -> remate propio
  termPick: false,
  colors: false,
  transparent: false,
  stampSym: '♄︎',
  stampMode: false,
  view: null,
  dragging: null,
  rosa: { colors: false, name: '', method: 'consonantal', tokens: null, tokensFor: '', hebrew: '', trace: [], words: [], diagram: true, endBar: true }
};
const newUser = () => ({ dx: 0, dy: 0, ds: 1, drot: 0, fx: false, fy: false });

function effT(l) {
  const b = l.base, u = l.user;
  return { tx: b.tx + u.dx, ty: b.ty + u.dy, s: b.s * u.ds, rot: b.rot + u.drot, fx: b.fx !== u.fx, fy: b.fy !== u.fy };
}
const activeLetters = () => state.letters.filter(l => !l.twin);

// Absorcion + composicion. Se recalcula al cambiar reduccion o modo.
function applyLayout() {
  const kept = [];
  for (const l of state.letters) {
    l.twin = state.absorb ? findTwin(l.ch, kept) : null;
    if (!l.twin) kept.push(l.ch);
  }
  const { base, extra } = layoutLetters(activeLetters(), state.mode, state.overlap);
  for (const l of activeLetters()) l.base = base[l.ch];
  state.extra = extra;
  rebuild();
}

// Coloca las letras, funde trazos compartidos y mide legibilidad.
function rebuild() {
  const raw = [];
  for (const l of activeLetters()) {
    const T = effT(l);
    l.own = GLYPHS[l.ch].map(p => placePrim(p, T, [l.ch]));
    raw.push(...l.own);
  }
  raw.push(...state.extra.map(e => ({ ...e })));
  state.prims = mergeAll(raw).map(p => ({ ...p, key: sig(p) }));
  const hidden = new Set(state.hidden);
  state.prims.forEach(p => { p.hidden = hidden.has(p.key); });
  for (const l of activeLetters()) {
    const mine = state.prims.filter(p => p.units.includes(l.ch));
    l.legible = mine.length ? mine.filter(p => !p.hidden).length / mine.length : 0;
    l.shares = [...new Set(mine.flatMap(p => p.units))].filter(u => u !== l.ch);
  }
  if (!state.dragging) state.view = fitView();
  render();
}

// ── Vista: mundo -> lienzo ──────────────────────────────────────
function primPoints(p) {
  if (p.t === 'L') return [p.a, p.b];
  const out = [];
  for (let i = 0; i <= 24; i++) {
    const a = rad(p.a0 + (p.a1 - p.a0) * i / 24);
    out.push({ x: p.c.x + Math.cos(a) * p.r, y: p.c.y + Math.sin(a) * p.r });
  }
  return out;
}
function fitView() {
  let x0 = Infinity, x1 = -Infinity, y0 = Infinity, y1 = -Infinity;
  for (const p of state.prims) for (const q of primPoints(p)) {
    x0 = Math.min(x0, q.x); x1 = Math.max(x1, q.x); y0 = Math.min(y0, q.y); y1 = Math.max(y1, q.y);
  }
  if (!isFinite(x0)) return { cx: 0, cy: 0, k: CORE_R, oy: 0 };
  // el cuadro del sigilo cabe en el hueco que dejan las capas de marco
  const contentR = layoutLayers(state.layers, layerCtx('letters')).contentR;
  // la media diagonal del cuadro (CORE_R * kf * raiz de 2) no pasa del hueco
  const kf = Math.min(1, contentR * .99 / Math.SQRT2 / CORE_R);
  return { cx: (x0 + x1) / 2, cy: (y0 + y1) / 2, k: CORE_R * kf / (Math.max(x1 - x0, y1 - y0, .5) / 2), oy: 0 };
}
const toCanvas = p => ({ x: C + (p.x - state.view.cx) * state.view.k, y: C + state.view.oy + (p.y - state.view.cy) * state.view.k });
const toWorld = (x, y) => ({ x: (x - C) / state.view.k + state.view.cx, y: (y - C - state.view.oy) / state.view.k + state.view.cy });

// ── Terminales: extremos libres ─────────────────────────────────
function distToPrim(pt, p) {
  if (p.t === 'L') {
    const dx = p.b.x - p.a.x, dy = p.b.y - p.a.y, l2 = dx * dx + dy * dy;
    const t = l2 ? Math.max(0, Math.min(1, ((pt.x - p.a.x) * dx + (pt.y - p.a.y) * dy) / l2)) : 0;
    return Math.hypot(pt.x - p.a.x - t * dx, pt.y - p.a.y - t * dy);
  }
  const ang = Math.atan2(pt.y - p.c.y, pt.x - p.c.x) * 180 / Math.PI;
  if (((ang - p.a0) % 360 + 360) % 360 <= p.a1 - p.a0) return Math.abs(Math.hypot(pt.x - p.c.x, pt.y - p.c.y) - p.r);
  return Math.min(...primEnds(p).map(e => Math.hypot(pt.x - e.x, pt.y - e.y)));
}
// Extremos con direccion hacia fuera (ox, oy): el remate crece desde
// la punta del trazo, no a traves de el.
function primEnds(p) {
  const end = (x, y, ox, oy) => ({ x, y, ox, oy, key: r2(x) + ',' + r2(y) });
  if (p.t === 'L') {
    const d = Math.hypot(p.b.x - p.a.x, p.b.y - p.a.y) || 1, ux = (p.b.x - p.a.x) / d, uy = (p.b.y - p.a.y) / d;
    return [end(p.a.x, p.a.y, -ux, -uy), end(p.b.x, p.b.y, ux, uy)];
  }
  if (p.a1 - p.a0 >= 359.5) return [];
  const at = a => [p.c.x + Math.cos(rad(a)) * p.r, p.c.y + Math.sin(rad(a)) * p.r];
  return [end(...at(p.a0), Math.sin(rad(p.a0)), -Math.cos(rad(p.a0))), end(...at(p.a1), -Math.sin(rad(p.a1)), Math.cos(rad(p.a1)))];
}

// ── Terminales (remates de trazo) ───────────────────────────────
// [HP] anillo: rasgo mas comun en los sellos de la Goetia, heredero de
// los "caracteres con anteojos" medievales. Cruz y cruz patada: 17 % de
// terminales en el analisis de los 72 sellos (nota Motor-Alquimia-Goetica).
// El resto es repertorio visual sin fuente primaria concreta [AR].
const TERMINALS = [
  { id: 'none', name: 'Ninguno' },
  { id: 'dot', name: 'Punto', tag: 'OM' },
  { id: 'ring', name: 'Anillo', tag: 'HP' },
  { id: 'bar', name: 'Barra', tag: 'HP' },
  { id: 'cross', name: 'Cruz', tag: 'HP' },
  { id: 'pattee', name: 'Cruz patada', tag: 'HP' },
  { id: 'botonnee', name: 'Cruz botonada', tag: 'AR' },
  { id: 'arrow', name: 'Flecha', tag: 'AR' },
  { id: 'point', name: 'Punta', tag: 'AR' },
  { id: 'lance', name: 'Lanza', tag: 'AR' },
  { id: 'trident', name: 'Tridente', tag: 'AR' },
  { id: 'crescent', name: 'Media luna', tag: 'AR' },
  { id: 'star', name: 'Estrella', tag: 'AR' },
  { id: 'hook', name: 'Gancho', tag: 'AR' }
];
// Geometria de un remate en coordenadas de lienzo: q = punta, o = hacia
// fuera, s = tamano. Devuelve paths SVG; fill = relleno o solo trazo.
// Canvas los pinta con Path2D, asi ambas salidas son identicas.
function terminalShapes(q, o, style, s) {
  const n = { x: -o.y, y: o.x };
  const P = (a, b = 0) => [q.x + o.x * a + n.x * b, q.y + o.y * a + n.y * b];
  const pt = v => f2(v[0]) + ' ' + f2(v[1]);
  const poly = (pts, close = true) => 'M ' + pts.map(pt).join(' L ') + (close ? ' Z' : '');
  const circle = (c, r) => `M ${f2(c[0] + r)} ${f2(c[1])} A ${f2(r)} ${f2(r)} 0 1 0 ${f2(c[0] - r)} ${f2(c[1])} A ${f2(r)} ${f2(r)} 0 1 0 ${f2(c[0] + r)} ${f2(c[1])} Z`;
  const line = (a, b) => ({ d: poly([a, b], false), fill: false });
  switch (style) {
    case 'dot': return [{ d: circle(P(0), s * .55), fill: true }];
    case 'ring': return [{ d: circle(P(s * .6), s * .6), fill: false }];
    case 'bar': return [line(P(0, -s), P(0, s))];
    case 'cross': return [line(P(0), P(s * 1.8)), line(P(s * .9, -s * .9), P(s * .9, s * .9))];
    case 'pattee': {
      // cuatro brazos que se ensanchan hacia fuera; el brazo trasero toca la punta
      const L = s * 1.05, c = s * 1.05, w0 = s * .14, w1 = s * .95;
      return [[1, 0], [-1, 0], [0, 1], [0, -1]].map(([a, b]) => {
        const Q = (t, w) => P(c + a * t - b * w, b * t + a * w);
        return { d: poly([Q(0, -w0), Q(L, -w1 / 2), Q(L, w1 / 2), Q(0, w0)]), fill: true };
      });
    }
    case 'botonnee': return [line(P(0), P(s * 1.6)), line(P(s * .8, -s * .8), P(s * .8, s * .8)),
      { d: circle(P(s * 1.75), s * .28), fill: true }, { d: circle(P(s * .8, -s * .95), s * .28), fill: true }, { d: circle(P(s * .8, s * .95), s * .28), fill: true }];
    case 'arrow': return [line(P(0), P(s * 1.2)), { d: poly([P(s * .35, -s * .75), P(s * 1.2), P(s * .35, s * .75)], false), fill: false }];
    case 'point': return [{ d: poly([P(-s * .1, -s * .7), P(s * 1.2), P(-s * .1, s * .7)]), fill: true }];
    case 'lance': return [{ d: poly([P(0), P(s * .7, -s * .45), P(s * 1.7), P(s * .7, s * .45)]), fill: true }];
    case 'trident': return [line(P(0), P(s * 1.5)), { d: poly([P(s * 1.3, -s * .85), P(s * .45, -s * .85), P(s * .45, s * .85), P(s * 1.3, s * .85)], false), fill: false }];
    case 'crescent': return [{ d: `M ${pt(P(s * .9, s * .9))} C ${pt(P(-s * .3, s * .9))} ${pt(P(-s * .3, -s * .9))} ${pt(P(s * .9, -s * .9))}`, fill: false }];
    case 'star': {
      // estrella de 5 puntas con una punta apuntando al trazo
      const c = P(s * 1.05), pts = [];
      const base = Math.atan2(-o.y, -o.x);
      for (let i = 0; i < 10; i++) {
        const r = i % 2 ? s * .42 : s * 1.05, a = base + i * Math.PI / 5;
        pts.push([c[0] + Math.cos(a) * r, c[1] + Math.sin(a) * r]);
      }
      return [{ d: poly(pts), fill: true }];
    }
    case 'hook': return [{ d: `M ${pt(P(0))} C ${pt(P(s * 1.3))} ${pt(P(s * 1.5, s * 1.2))} ${pt(P(s * .5, s * 1.1))}`, fill: false }];
    default: return [];
  }
}
// Remates de todos los extremos libres: estilo por extremo o el general
function terminalList(visible) {
  const s = LINE_W * 3 * state.termScale / 100;
  const out = [];
  for (const e of freeEnds(visible)) {
    const style = state.endStyles[e.key] || state.terminals;
    if (style === 'none') continue;
    out.push({ e, style, shapes: terminalShapes(toCanvas(e), { x: e.ox, y: e.oy }, style, s) });
  }
  return out;
}
// Los brazos de la cruz son composicion: no llevan terminales
function freeEnds(visible) {
  const out = [];
  visible.forEach((p, i) => p.kind !== 'cross' && primEnds(p).forEach(e => {
    if (!visible.some((q, j) => j !== i && distToPrim(e, q) < .03)) out.push(e);
  }));
  return out;
}

// ── Pintado (canvas) ────────────────────────────────────────────
const THEMES = {
  build: { bg: '#efe6d2', ink: '#1b1612', faint: 'rgba(27,22,18,.16)', accent: '#9b1c2e', frame: 'rgba(27,22,18,.55)', ui: '#9b1c2e' },
  present: { bg: '#0a080d', ink: '#c99a1a', faint: 'rgba(201,154,26,.2)', accent: '#f3d27a', frame: 'rgba(184,134,11,.6)', ui: '#f3d27a' }
  // custom: lo rellena applyStyle con el estilo elegido
};
const LETTER_COLORS = ['#1f5fa8', '#c77700', '#2e7d32', '#8e44ad', '#b3261e', '#00838f', '#6d4c41', '#ad1457', '#558b2f', '#283593', '#e64a19', '#00695c'];
const LINE_W = 7;
