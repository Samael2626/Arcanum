'use strict';
// Rosa-Cruz: Lamen, transliteracion y trazo del manuscrito F
// ── Rosa-Cruz: motor separado ───────────────────────────────────
// Fuentes (verificadas el 26-sep-2026):
//  [OM] Mathers (G.H. Frater D.D.C.F.), manuscrito F "Sigils from the
//       Rose": circulo en la letra inicial y linea de letra en letra; dos
//       letras iguales seguidas = quiebro u onda; letra del nombre por la
//       que la linea pasa (Resh en Metatron) = lazo. El texto no habla de
//       marca final, pero sus figuras (Metatron, Elohim) acaban en barra corta.
//  [OM] Documento 5=6 "The Rose Cross Lamen": madres; dobles en el orden
//       Peh Resh Beth Daleth Gimel Tav Kaph; zodiaco con Heh arriba.
//  Wikimedia Commons, Rose_Cross_Lamen.svg: posiciones y sentido
//       antihorario. Coincide con las listas: en Metatron, Teth-Resh-Vav
//       quedan casi en linea (giro de ~1 grado), por eso el lazo en Resh.
// Nunca se mezcla con el sigilo de letras latinas.
const HEB_VALUE = { 'א': 1, 'ב': 2, 'ג': 3, 'ד': 4, 'ה': 5, 'ו': 6, 'ז': 7, 'ח': 8, 'ט': 9, 'י': 10, 'כ': 20, 'ל': 30, 'מ': 40, 'נ': 50, 'ס': 60, 'ע': 70, 'פ': 80, 'צ': 90, 'ק': 100, 'ר': 200, 'ש': 300, 'ת': 400 };
const FINAL_TO_BASE = { 'ך': 'כ', 'ם': 'מ', 'ן': 'נ', 'ף': 'פ', 'ץ': 'צ' };
const BASE_TO_FINAL = Object.fromEntries(Object.entries(FINAL_TO_BASE).map(([f, b]) => [b, f]));
const GADOL_FINAL = { 'ך': 500, 'ם': 600, 'ן': 700, 'ף': 800, 'ץ': 900 };
const baseLetter = ch => FINAL_TO_BASE[ch] || ch;

// Anillos en orden de lectura: angulo de la primera letra y paso
// (negativo = antihorario en pantalla, como en el Lamen)
const ROSE_RINGS = [
  { id: 'mother', label: 'Madres', r: 105, r0: 62, r1: 148, start: -90, step: -120, letters: ['א', 'מ', 'ש'] },
  { id: 'double', label: 'Dobles', r: 186, r0: 148, r1: 224, start: -90 - 360 / 14, step: -360 / 7, letters: ['פ', 'ר', 'ב', 'ד', 'ג', 'ת', 'כ'] },
  { id: 'simple', label: 'Simples', r: 261, r0: 224, r1: 298, start: -90, step: -30, letters: ['ה', 'ו', 'ז', 'ח', 'ט', 'י', 'ל', 'נ', 'ס', 'ע', 'צ', 'ק'] }
];
const ROSE_INFO = {
  'א': ['Álef', 'Aire', ''], 'מ': ['Mem', 'Agua', ''], 'ש': ['Shin', 'Fuego', ''],
  'ב': ['Bet', 'Mercurio', '☿'], 'ג': ['Guímel', 'Luna', '☽'], 'ד': ['Dálet', 'Venus', '♀'], 'כ': ['Kaf', 'Júpiter', '♃'],
  'פ': ['Pe', 'Marte', '♂'], 'ר': ['Resh', 'Sol', '☉'], 'ת': ['Tav', 'Saturno', '♄'],
  'ה': ['He', 'Aries', '♈'], 'ו': ['Vav', 'Tauro', '♉'], 'ז': ['Zain', 'Géminis', '♊'], 'ח': ['Jet', 'Cáncer', '♋'],
  'ט': ['Tet', 'Leo', '♌'], 'י': ['Yod', 'Virgo', '♍'], 'ל': ['Lámed', 'Libra', '♎'], 'נ': ['Nun', 'Escorpio', '♏'],
  'ס': ['Sámej', 'Sagitario', '♐'], 'ע': ['Ayin', 'Capricornio', '♑'], 'צ': ['Tsadi', 'Acuario', '♒'], 'ק': ['Qof', 'Piscis', '♓']
};
// Colores de las letras: escala del Rey de la Golden Dawn, caminos 11-32
// (Alef..Tav). Coinciden con los que da el manuscrito F para Metatron:
// azul, verde-amarillo, naranja, rojo-naranja y verde-azul (Mem, Tet,
// Resh, Vav, Nun). El tono exacto de cada nombre es eleccion del taller.
const ROSE_COLORS = {
  'א': ['amarillo pálido brillante', '#f3eb9a'], 'ב': ['amarillo', '#f2cf1d'], 'ג': ['azul', '#2f63d6'], 'ד': ['verde esmeralda', '#1d9a58'],
  'ה': ['escarlata', '#de2a1f'], 'ו': ['rojo anaranjado', '#ef5a1c'], 'ז': ['naranja', '#f28a1c'], 'ח': ['ámbar', '#f0aa1a'],
  'ט': ['amarillo verdoso', '#c9d21c'], 'י': ['verde amarillento', '#9acb1f'], 'כ': ['violeta', '#7b31b3'], 'ל': ['verde esmeralda', '#1d9a58'],
  'מ': ['azul profundo', '#1c3fa3'], 'נ': ['verde azulado', '#1a8c8c'], 'ס': ['azul', '#2f63d6'], 'ע': ['índigo', '#3c2b8f'],
  'פ': ['escarlata', '#de2a1f'], 'צ': ['violeta', '#7b31b3'], 'ק': ['carmesí', '#b3123c'], 'ר': ['naranja', '#f28a1c'],
  'ש': ['naranja escarlata brillante', '#f0431c'], 'ת': ['índigo', '#3c2b8f']
};
const roseLabel = he => { const [, corr, sym] = ROSE_INFO[he]; return sym ? sym + '︎' : corr; };
const PETALS = Object.fromEntries(ROSE_RINGS.flatMap(ring => ring.letters.map((he, i) => {
  const a = ring.start + ring.step * i;
  return [he, { he, ring, a, x: C + Math.cos(rad(a)) * ring.r, y: C + Math.sin(rad(a)) * ring.r }];
})));

// ── Transliteracion latin -> hebreo ─────────────────────────────
// Ambas son reconstruccion [RC]: la Golden Dawn trabaja con nombres ya
// escritos en hebreo. Por eso el resultado es editable a mano.
const TRANSLIT = {
  consonantal: { label: 'Consonántica', rule: 'Como se escribe el hebreo: vocal inicial = Álef (Yod si es i); a y e interiores no se escriben; i = Yod; o, u = Vav; a final = He. Letras dobles latinas se escriben una vez. Finales (ך ם ן ף ץ) al acabar la palabra.' },
  full: { label: 'Letra a letra', rule: 'Cada letra latina, vocales incluidas, con su letra hebrea: a = Álef, e/i/y = Yod, o = Ayin, u = Vav.' }
};
const LAT_CONS = { sh: 'ש', ch: 'ח', th: 'ת', tz: 'צ', ts: 'צ', ph: 'פ', b: 'ב', c: 'כ', d: 'ד', f: 'פ', g: 'ג', h: 'ה', j: 'י', k: 'כ', l: 'ל', m: 'מ', n: 'נ', p: 'פ', q: 'ק', r: 'ר', s: 'ס', t: 'ט', v: 'ו', w: 'ו', x: 'כס', z: 'ז' };
const LAT_FULL_VOWELS = { a: 'א', e: 'י', i: 'י', y: 'י', o: 'ע', u: 'ו' };
const LAT_KEYS = Object.keys(LAT_CONS).sort((a, b) => b.length - a.length);
const isVowel = c => 'aeiouy'.includes(c);

function translitWord(word, method) {
  let w = word;
  if (method === 'consonantal') w = w.replace(/([b-df-hj-np-tv-z])\1+/g, '$1');
  const out = [];
  for (let i = 0; i < w.length;) {
    const c = w[i], first = i === 0, last = i === w.length - 1;
    if (isVowel(c)) {
      let he = '', note = '';
      if (method === 'full') he = LAT_FULL_VOWELS[c];
      else if (first) { he = c === 'i' || c === 'y' ? 'י' : 'א'; note = 'vocal inicial'; }
      else if (c === 'i' || c === 'y') he = 'י';
      else if (c === 'o' || c === 'u') he = 'ו';
      else if (c === 'a' && last) { he = 'ה'; note = 'a final'; }
      else note = 'vocal no escrita';
      out.push({ latin: c, he, note });
      i++; continue;
    }
    const k = LAT_KEYS.find(k0 => w.startsWith(k0, i));
    if (!k) { out.push({ latin: c, he: '', note: 'sin correspondencia' }); i++; continue; }
    let he = LAT_CONS[k];
    // c suave ante e/i suena s
    if (k === 'c' && method === 'consonantal' && 'ei'.includes(w[i + 1] || '')) he = 'ס';
    out.push({ latin: k, he, note: '' });
    i += k.length;
  }
  // forma final en la ultima letra escrita
  for (let j = out.length - 1; j >= 0; j--) {
    if (!out[j].he) continue;
    const hs = [...out[j].he], lastHe = hs[hs.length - 1];
    if (BASE_TO_FINAL[lastHe]) { hs[hs.length - 1] = BASE_TO_FINAL[lastHe]; out[j].he = hs.join(''); out[j].note = (out[j].note ? out[j].note + ', ' : '') + 'forma final'; }
    break;
  }
  return out;
}
// Nombres de origen hebreo: se escriben con su grafia original (Biblia
// hebrea), no sonido a sonido. Samuel es שמואל (1 S 1:20), no סמול.
const HEBREW_NAMES = {
  samuel: 'שמואל', miguel: 'מיכאל', gabriel: 'גבריאל', rafael: 'רפאל', daniel: 'דניאל', david: 'דוד',
  jose: 'יוסף', maria: 'מרים', miriam: 'מרים', juan: 'יוחנן', ana: 'חנה', sara: 'שרה', elias: 'אליהו',
  adan: 'אדם', eva: 'חוה', isabel: 'אלישבע', elisabet: 'אלישבע', jacob: 'יעקב', jacobo: 'יעקב',
  isaias: 'ישעיהו', jeremias: 'ירמיהו', salomon: 'שלמה', abraham: 'אברהם', isaac: 'יצחק', moises: 'משה',
  josue: 'יהושע', natanael: 'נתנאל', manuel: 'עמנואל', emanuel: 'עמנואל', matias: 'מתתיהו', mateo: 'מתתיהו',
  rut: 'רות', ester: 'אסתר', debora: 'דבורה', judit: 'יהודית', simon: 'שמעון', benjamin: 'בנימין', jonas: 'יונה'
};
function transliterate(name, method) {
  const words = name.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase().split(/[^a-z]+/).filter(Boolean);
  const tokens = words.flatMap((w, i) => [...(i ? [{ latin: ' ', he: ' ', note: '' }] : []),
    ...(method === 'consonantal' && HEBREW_NAMES[w] ? [{ latin: w, he: HEBREW_NAMES[w], note: 'nombre bíblico: grafía hebrea original' }] : translitWord(w, method))]);
  return { tokens, hebrew: tokens.map(t => t.he).join('') };
}
const hasHebrew = s => /[א-ת]/.test(s);
const cleanHebrew = s => s.replace(/[֑-ׇ]/g, '').replace(/[^א-ת ]/g, '').replace(/\s+/g, ' ').trim();

function gematria(heb) {
  let std = 0, gadol = 0;
  for (const ch of heb) {
    const v = HEB_VALUE[baseLetter(ch)];
    if (!v) continue;
    std += v; gadol += GADOL_FINAL[ch] || v;
  }
  return { std, gadol };
}

// ── Trazo segun el manuscrito F ─────────────────────────────────
const NOOSE_MAX_TURN = 15;   // grados: por debajo, la linea "pasa" recta
const OVERLAP_SHIFT = 20;    // px que se aparta un trazo que repasa otro
// Dos segmentos casi colineales que se solapan: uno esconderia al otro
function segmentsOverlap(c, d, a, b) {
  const dx = d.x - c.x, dy = d.y - c.y, l = Math.hypot(dx, dy);
  if (l < 1) return false;
  const ux = dx / l, uy = dy / l;
  const off = p => Math.abs((p.x - c.x) * uy - (p.y - c.y) * ux);
  if (off(a) > 4 || off(b) > 4) return false;
  const t = p => (p.x - c.x) * ux + (p.y - c.y) * uy;
  return Math.min(Math.max(t(a), t(b)), l) - Math.max(Math.min(t(a), t(b)), 0) > 10;
}
// Letra del nombre por la que pasa un trazo: el manuscrito dobla la linea
// hasta ella y la marca con lazo. Regla calibrada con las 8 laminas del
// manuscrito F [AR]: solo si la letra aun no se ha visitado y no es la
// primera ni la ultima (ya llevan circulo y barra). Haniel la cumple (40 px);
// Hagiel pasa a 56 px y Tzabaoth pasa por un Alef ya visitado: sin lazo.
const PASS_DIST = 48;
function distToSegment(p, a, b) {
  const dx = b.x - a.x, dy = b.y - a.y, l2 = dx * dx + dy * dy;
  const t = l2 ? Math.max(0, Math.min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / l2)) : 0;
  return { d: Math.hypot(p.x - a.x - t * dx, p.y - a.y - t * dy), t };
}
function roseTrace(word) {
  const verts = [];
  for (const ch of word) {
    const b = baseLetter(ch);
    if (!PETALS[b]) continue;
    const last = verts[verts.length - 1];
    if (last && last.he === b) { last.repeat++; continue; }
    verts.push({ ...PETALS[b], ch, repeat: 1 });
  }
  const letters = verts.map(v => v.he), first = letters[0], lastL = letters[letters.length - 1];
  for (let k = 0; k < verts.length - 1; k++) {
    const a = verts[k], b = verts[k + 1];
    const visited = new Set(verts.slice(0, k + 2).map(v => v.he));
    let best = null;
    for (const he of new Set(letters)) {
      if (he === first || he === lastL || visited.has(he)) continue;
      const m = distToSegment(PETALS[he], a, b);
      if (m.d < PASS_DIST && m.t > 0 && m.t < 1 && (!best || m.d < best.d)) best = { he, d: m.d, t: m.t };
    }
    // el lazo va sobre la linea, en el punto mas cercano a la letra: en la
    // lamina de Haniel el lazo y el vertice del Alef son puntos distintos
    if (best) a.pass = { he: best.he, d: best.d, t: best.t };
  }
  // Un trazo que repasa otro ya dibujado se separa un poco, como en las
  // figuras del manuscrito (Elohim: Alef, Lamed y He comparten eje y el
  // original los dibuja en zigzag). Sin esto la linea queda escondida.
  for (let k = 1; k < verts.length - 1; k++) {
    const a = verts[k], b = verts[k + 1];
    const hides = verts.slice(0, k).some((c, j) => segmentsOverlap(c, verts[j + 1], a, b));
    if (!hides) continue;
    const dx = b.x - a.x, dy = b.y - a.y, l = Math.hypot(dx, dy) || 1;
    b.x += -dy / l * OVERLAP_SHIFT; b.y += dx / l * OVERLAP_SHIFT;
    b.shifted = true;
  }
  const dirs = verts.slice(1).map((v, i) => {
    const dx = v.x - verts[i].x, dy = v.y - verts[i].y, l = Math.hypot(dx, dy) || 1;
    return { x: dx / l, y: dy / l };
  });
  verts.forEach((v, i) => {
    v.inDir = dirs[i - 1] || null; v.outDir = dirs[i] || null;
    v.turn = v.inDir && v.outDir ? Math.abs(Math.atan2(v.inDir.x * v.outDir.y - v.inDir.y * v.outDir.x, v.inDir.x * v.outDir.x + v.inDir.y * v.outDir.y)) * 180 / Math.PI : null;
    v.noose = v.turn !== null && v.turn < NOOSE_MAX_TURN;
    v.crook = v.repeat > 1;
  });
  return verts;
}

// Geometria unica del sello (canvas y SVG la comparten)
const START_R = 13, NOOSE_R = 7, CROOK_L = 30, CROOK_A = 12;
// Tramos sueltos del sello: de letra en letra, con el quiebro incluido
function roseSegments(verts) {
  const P = (p, d, t, n = 0) => [p.x + d.x * t - d.y * n, p.y + d.y * t + d.x * n];
  const pt = v => f2(v[0]) + ' ' + f2(v[1]);
  const segs = [];
  for (let i = 1; i < verts.length; i++) {
    const a = verts[i - 1], v = verts[i], di = v.inDir;
    const from = i === 1 ? P(a, a.outDir, START_R) : [a.x, a.y];
    let d = `M ${pt(from)}`;
    if (i === 1 && a.crook) d += ` C ${pt(P(a, a.outDir, START_R + CROOK_L / 3, CROOK_A))} ${pt(P(a, a.outDir, START_R + 2 * CROOK_L / 3, -CROOK_A))} ${pt(P(a, a.outDir, START_R + CROOK_L))}`;
    if (v.crook) d += ` L ${pt(P(v, di, -CROOK_L))} C ${pt(P(v, di, -2 * CROOK_L / 3, CROOK_A))} ${pt(P(v, di, -CROOK_L / 3, -CROOK_A))} ${pt([v.x, v.y])}`;
    else d += ` L ${pt([v.x, v.y])}`;
    segs.push({ d, from: a.he, to: v.he, x1: from[0], y1: from[1], x2: v.x, y2: v.y });
  }
  return segs;
}
function roseSigilShapes(verts, endBar) {
  if (!verts.length) return [];
  const P = (p, d, t, n = 0) => [p.x + d.x * t - d.y * n, p.y + d.y * t + d.x * n];
  const pt = v => f2(v[0]) + ' ' + f2(v[1]);
  const shapes = [{ mark: 'start', d: `M ${f2(verts[0].x + START_R)} ${f2(verts[0].y)} A ${START_R} ${START_R} 0 1 0 ${f2(verts[0].x - START_R)} ${f2(verts[0].y)} A ${START_R} ${START_R} 0 1 0 ${f2(verts[0].x + START_R)} ${f2(verts[0].y)} Z` }];
  if (verts.length > 1 || verts[0].crook) {
    const v0 = verts[0], d0 = v0.outDir || { x: 1, y: 0 };
    // la linea sale del borde del circulo inicial
    let d = `M ${pt(P(v0, d0, START_R))}`;
    // letra inicial repetida: quiebro justo al salir
    if (v0.crook) d += ` C ${pt(P(v0, d0, START_R + CROOK_L / 3, CROOK_A))} ${pt(P(v0, d0, START_R + 2 * CROOK_L / 3, -CROOK_A))} ${pt(P(v0, d0, START_R + CROOK_L))}`;
    for (let i = 1; i < verts.length; i++) {
      const v = verts[i], di = v.inDir;
      if (v.crook) {
        // quiebro (onda) en la linea al llegar a la letra repetida
        d += ` L ${pt(P(v, di, -CROOK_L))} C ${pt(P(v, di, -2 * CROOK_L / 3, CROOK_A))} ${pt(P(v, di, -CROOK_L / 3, -CROOK_A))} ${pt([v.x, v.y])}`;
      } else d += ` L ${pt([v.x, v.y])}`;
    }
    shapes.push({ mark: 'line', d });
  }
  verts.forEach((v, i) => {
    if (v.pass) {
      // punto del segmento mas cercano a la letra (tras apartar trazos)
      const nx = verts[i + 1], d = v.outDir;
      const px = v.x + (nx.x - v.x) * v.pass.t, py = v.y + (nx.y - v.y) * v.pass.t;
      const c = [px - d.y * NOOSE_R, py + d.x * NOOSE_R];
      shapes.push({ mark: 'noose', d: `M ${f2(c[0] + NOOSE_R)} ${f2(c[1])} A ${NOOSE_R} ${NOOSE_R} 0 1 0 ${f2(c[0] - NOOSE_R)} ${f2(c[1])} A ${NOOSE_R} ${NOOSE_R} 0 1 0 ${f2(c[0] + NOOSE_R)} ${f2(c[1])} Z` });
    }
    if (!v.noose) return;
    const n = [v.x - v.inDir.y * NOOSE_R, v.y + v.inDir.x * NOOSE_R];
    shapes.push({ mark: 'noose', d: `M ${f2(n[0] + NOOSE_R)} ${f2(n[1])} A ${NOOSE_R} ${NOOSE_R} 0 1 0 ${f2(n[0] - NOOSE_R)} ${f2(n[1])} A ${NOOSE_R} ${NOOSE_R} 0 1 0 ${f2(n[0] + NOOSE_R)} ${f2(n[1])} Z` });
  });
  if (endBar && verts.length > 1) {
    const e = verts[verts.length - 1], de = e.inDir;
    shapes.push({ mark: 'end', d: `M ${pt(P(e, de, 0, -10))} L ${pt(P(e, de, 0, 10))}` });
  }
  return shapes;
}
// Petalos del diagrama: cuna entre radios y separadores entre letras
function petalPath(p) {
  const h = Math.abs(p.ring.step) / 2, a0 = rad(p.a - h), a1 = rad(p.a + h), { r0, r1 } = p.ring;
  const at = (r, a) => f2(C + Math.cos(a) * r) + ' ' + f2(C + Math.sin(a) * r);
  const large = h * 2 > 180 ? 1 : 0;
  return `M ${at(r0, a0)} L ${at(r1, a0)} A ${r1} ${r1} 0 ${large} 1 ${at(r1, a1)} L ${at(r0, a1)} A ${r0} ${r0} 0 ${large} 0 ${at(r0, a0)} Z`;
}
function roseDiagram(used) {
  return Object.values(PETALS).map(p => ({ he: p.he, d: petalPath(p), used: used.has(p.he), x: p.x, y: p.y, label: roseLabel(p.he) }));
}

function roseSVG(th) {
  const ro = state.rosa, used = new Set(ro.trace.map(v => v.he)), out = [];
  if (ro.diagram) {
    out.push(`<g data-layer="rose-diagram" stroke="${th.faint}" stroke-width="1.2">`);
    for (const p of roseDiagram(used)) {
      out.push(ro.colors ? `<path d="${p.d}" fill="${ROSE_COLORS[p.he][1]}" fill-opacity="${p.used ? .55 : .22}"/>` : `<path d="${p.d}" fill="${p.used ? th.faint : 'none'}"/>`);
      out.push(`<text x="${f2(p.x)}" y="${f2(p.y - 4)}" stroke="none" text-anchor="middle" dominant-baseline="middle" font-family="Arial Hebrew, Segoe UI, serif" font-size="20" fill="${th.ink}">${p.he}</text>`);
      out.push(hasGlyph(p.label) ? glyphSVG(p.label, p.x, p.y + 15, 12, 0, th.frame, 1, ' stroke-width="1"') : `<text x="${f2(p.x)}" y="${f2(p.y + 15)}" stroke="none" text-anchor="middle" dominant-baseline="middle" font-family="Georgia, serif" font-size="11" fill="${th.frame}">${esc(p.label)}</text>`);
    }
    out.push('</g>');
  }
  out.push(`<g data-layer="rose" fill="none" stroke="${th.accent}" stroke-linecap="round" stroke-linejoin="round">`);
  ro.words.forEach((w, i) => {
    out.push(`<g data-word="${i + 1}">`);
    const shapes = roseSigilShapes(w, ro.endBar);
    if (ro.colors) {
      roseSegments(w).forEach((g, j) => {
        const id = `rg${i}_${j}`;
        out.push(`<linearGradient id="${id}" gradientUnits="userSpaceOnUse" x1="${f2(g.x1)}" y1="${f2(g.y1)}" x2="${f2(g.x2)}" y2="${f2(g.y2)}"><stop offset="0" stop-color="${ROSE_COLORS[g.from][1]}"/><stop offset="1" stop-color="${ROSE_COLORS[g.to][1]}"/></linearGradient>`);
        out.push(`<path data-mark="segment" d="${g.d}" stroke="url(#${id})" stroke-width="4.2"/>`);
      });
      for (const s of shapes) {
        if (s.mark === 'line') continue;
        const he = s.mark === 'start' ? w[0].he : s.mark === 'end' ? w[w.length - 1].he : null;
        out.push(`<path data-mark="${s.mark}" d="${s.d}" stroke="${he ? ROSE_COLORS[he][1] : th.accent}" stroke-width="3"/>`);
      }
    } else for (const s of shapes) out.push(`<path data-mark="${s.mark}" d="${s.d}" stroke-width="${s.mark === 'line' ? 3.2 : 2.4}"/>`);
    out.push('</g>');
  });
  out.push('</g>');
  return out.join('');
}

// Traza desde el campo hebreo (editable) y rellena la explicacion
function rosaTraceFromHebrew() {
  const ro = state.rosa;
  ro.hebrew = cleanHebrew($('rosaHebrew').value);
  // una palabra, un sigilo: el manuscrito traza YHVH y TZABAOTH por separado
  ro.words = ro.hebrew.split(' ').filter(Boolean).map(roseTrace);
  ro.trace = ro.words.flat();
  const g = gematria(ro.hebrew);
  const letters = [...ro.hebrew].filter(ch => ch !== ' ');
  const marks = [];
  const nm = he => ROSE_INFO[he][0];
  ro.words.forEach((w, i) => {
    if (!w.length) return;
    const pre = ro.words.length > 1 ? `palabra ${i + 1}: ` : '';
    marks.push(`${pre}círculo en ${w[0].he} (inicio)`);
    w.filter(v => v.crook).forEach(v => marks.push(`${pre}quiebro en ${v.he} (${nm(v.he)}, ${v.repeat} veces seguidas)`));
    w.filter(v => v.pass).forEach(v => marks.push(`${pre}lazo junto a ${v.pass.he} (${nm(v.pass.he)}): el trazo pasa a ${Math.round(v.pass.d)} px de ella antes de visitarla`));
    w.filter(v => v.noose).forEach(v => marks.push(`${pre}lazo en ${v.he} (${nm(v.he)}): la línea pasa casi recta, gira ${v.turn.toFixed(1)}°`));
    w.filter(v => v.shifted).forEach(v => marks.push(`${pre}trazo hacia ${v.he} (${nm(v.he)}) apartado para no tapar otro`));
    if (ro.endBar && w.length > 1) marks.push(`${pre}barra en ${w[w.length - 1].he} (final)`);
  });
  const tokens = ro.tokens && ro.tokensFor === ro.hebrew ? ro.tokens : null;
  $('rosaBox').innerHTML =
    (ro.name ? `<div class="line"><b>Nombre</b><span>${esc(ro.name)}</span></div>` : '') +
    (tokens ? `<div class="line"><b>Regla</b><span>${esc(TRANSLIT[ro.method].label)} ${badge('RC')}: ${esc(TRANSLIT[ro.method].rule)}</span></div>` +
      `<div class="line"><b>Letras</b><span>${tokens.filter(t => t.latin !== ' ').map(t => `${esc(t.latin)}→${t.he || '∅'}${t.note ? ' <i>(' + esc(t.note) + ')</i>' : ''}`).join(' · ')}</span></div>` : '<div class="line"><b>Origen</b><span>Hebreo escrito o corregido a mano.</span></div>') +
    `<div class="line"><b>Hebreo</b><span dir="rtl" lang="he">${esc(ro.hebrew) || '—'}</span></div>` +
    `<div class="line"><b>Recorrido</b><span>${ro.words.map(w => w.map(v => `${v.he} ${ROSE_INFO[v.he][1]}${v.pass ? ` (pasa junto a ${v.pass.he})` : ''}`).join(' → ')).join(' <b>|</b> ') || '—'}</span></div>` +
    `<div class="line"><b>Gematría</b><span>${g.std} <span title="En hebreo: Mispar Hechrachi">(estándar)</span>` + (g.gadol !== g.std ? ` · ${g.gadol} <span title="En hebreo: Mispar Gadol">(mayor: las letras finales valen de 500 a 900)</span>` : '') + `</span></div>` +
    `<div class="line"><b>Marcas</b><span>${marks.join('; ') || '—'}.</span></div>` +
    (ro.colors && ro.trace.length ? `<div class="line"><b>Colores</b><span dir="ltr">${[...new Set(ro.trace.map(v => v.he))].map(he => `<bdi lang="he">${he}</bdi>&nbsp;<span style="color:${ROSE_COLORS[he][1]}">■</span>&nbsp;${ROSE_COLORS[he][0]}`).join(' · ')}</span></div>` +
      `<div class="line"><b>Síntesis</b><span>${ro.hebrew === 'מטטרון' ? `Mathers da para Metatron ${cita('una cidra rojiza', 'a reddish-citron')} ${badge('OM')}.` : 'El manuscrito solo da la síntesis de Metatron; el taller no inventa una fórmula para mezclar colores.'}</span></div>` : '') +
    `<div class="line"><b>Letras</b><span>${letters.length}</span></div>`;
  render();
}
function rosaGenerate() {
  const ro = state.rosa, name = $('rosaName').value.trim();
  if (!name) { showToast('Escribe un nombre'); return; }
  ro.name = name; ro.method = $('selTranslit').value;
  if (hasHebrew(name)) { ro.tokens = null; $('rosaHebrew').value = cleanHebrew(name); }
  else {
    const t = transliterate(name, ro.method);
    ro.tokens = t.tokens; ro.tokensFor = cleanHebrew(t.hebrew);
    $('rosaHebrew').value = t.hebrew;
  }
  rosaTraceFromHebrew();
}
function rosaProvenance() {
  const ro = state.rosa, g = gematria(ro.hebrew);
  return `<h3>Rosa-Cruz</h3><p>${esc(ro.name || '—')} → <span dir="rtl" lang="he">${esc(ro.hebrew || '—')}</span> · gematría ${g.std}</p>` +
    '<h3>Cómo se traza (manuscrito F de Mathers)</h3><ol>' +
    `<li>Círculo en la letra inicial: ${cita('comienza con un círculo en el lugar de la letra inicial sobre la Rosa', 'commence with a circle at the point of the initial letter on the Rose')}.</li>` +
    '<li>Línea desde ese círculo hasta la siguiente letra, y así hasta acabar el nombre.</li>' +
    `<li>Dos letras iguales seguidas: ${cita('un quiebro u onda en la línea en ese punto', 'a crook or wave in the line at that point')}.</li>` +
    `<li>Letra del nombre por la que la línea pasa hacia otra, como Resh en Metatron: ${cita('un lazo en la línea en ese punto', 'a noose in the line at that point')}. Aquí se marca en dos casos: cuando la línea pasa casi recta por una letra del recorrido (giro menor de 15°) y cuando un trazo pasa a menos de 48 px de una letra del nombre que aún no ha visitado, que no sea la primera ni la última; el lazo va sobre la línea, en el punto más cercano a la letra, como en la lámina de Haniel. Calibrado con las ocho láminas del manuscrito. ${badge('AR')}</li>` +
    `<li>Cada palabra es un sigilo aparte, con su círculo y su barra, como YHVH y TZABAOTH en la lámina de Netzach. ${badge('OM')}</li>` +
    `<li>Colores: ${cita('en los colores respectivos de las letras, y sumarlos en una síntesis de color', 'in the respective colours of the letters and add these together to form a synthesis of colour')}. Son los de la escala del Rey (caminos 11 a 32); los cinco de Metatron coinciden con el manuscrito. Que cada tramo degrade de una letra a la siguiente es elección del taller. ${badge('RC')}</li>` +
    `<li>Final: el texto no menciona ninguna marca, pero las figuras del propio manuscrito (Metatron y Elohim) terminan en una barra corta. Va activada. ${badge('OM')}</li>` +
    `<li>Si un trazo repasa una línea ya dibujada, se aparta un poco para que se vea, como en la figura de Elohim del manuscrito. ${badge('AR')}</li></ol>` +
    '<h3>Fuentes</h3><ul>' +
    `<li>Mathers (firmaba G.H. Frater D.D.C.F.), manuscrito F, <i title="Título original: Sigils from the Rose">Sigilos de la Rosa</i>. ${badge('OM')}</li>` +
    `<li>Aurora Dorada (Golden Dawn), grado 5=6, <i title="Título original: The Rose Cross Lamen">El Lamen de la Rosa-Cruz</i>: las tres madres; las siete dobles en el orden Pe, Resh, Bet, Dálet, Guímel, Tav y Kaf; el zodiaco con He arriba. ${badge('OM')}</li>` +
    '<li>Dibujo del Lamen de la Rosa-Cruz en Wikimedia Commons: posición y sentido de los tres anillos.</li>' +
    `<li>Paso del latín al hebreo: reconstrucción de este taller; por eso el hebreo se puede corregir. ${badge('RC')}</li></ul>` +
    '<p class="note">Títulos y citas traducidos del inglés: pasa el ratón por encima para ver el original.</p>';
}
