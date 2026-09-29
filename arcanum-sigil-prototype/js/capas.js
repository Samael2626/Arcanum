'use strict';
// Capas de presentacion, guias inteligentes, panel de capas y paletas
// ── Capas de presentacion ───────────────────────────────────────
// Circulos, cuadrados, triangulos, anillos con nombre, estrellas,
// inscripciones, rotulos y simbolos, apilados como capas. Las capas de
// marco se anidan solas (cada una dentro del hueco de la anterior) y el
// sigilo va en el hueco final; cada capa tiene ademas su tamano, giro y
// desplazamiento para cruzarse si se quiere. Una sola geometria (lista de
// primitivas) sirve al lienzo y al SVG.
const STAR_STEP = { 5: 2, 6: 2, 7: 3, 8: 3, 9: 4 };
// Radio interior de la estrella {n/k} exacta (pentagrama 0,382...)
const starRatio = (n, k) => Math.cos(Math.PI * k / n) / Math.cos(Math.PI * (k - 1) / n);
// Simbolos arcanos. Solo los 7 planetas clasicos, como el resto de
// ARCANUM (orden caldeo). U+FE0E fuerza glifo de texto, no emoji.
const STAMP_CATALOG = [
  ['Planetas', [['♄', 'Saturno'], ['♃', 'Júpiter'], ['♂', 'Marte'], ['☉', 'Sol'], ['♀', 'Venus'], ['☿', 'Mercurio'], ['☽', 'Luna']]],
  ['Zodiaco', [['♈', 'Aries'], ['♉', 'Tauro'], ['♊', 'Géminis'], ['♋', 'Cáncer'], ['♌', 'Leo'], ['♍', 'Virgo'], ['♎', 'Libra'], ['♏', 'Escorpio'], ['♐', 'Sagitario'], ['♑', 'Capricornio'], ['♒', 'Acuario'], ['♓', 'Piscis']]],
  ['Elementos', [['🜂', 'Fuego'], ['🜄', 'Agua'], ['🜁', 'Aire'], ['🜃', 'Tierra']]],
  ['Principios alquímicos', [['🜍', 'Azufre'], ['☿', 'Mercurio'], ['🜔', 'Sal']]],
  ['Nodos y aspectos', [['☊', 'Nodo norte'], ['☋', 'Nodo sur'], ['☌', 'Conjunción'], ['☍', 'Oposición'], ['△', 'Trígono'], ['□', 'Cuadratura'], ['⚹', 'Sextil']]],
  ['Signos', [['✦', 'Estrella'], ['✧', 'Estrella abierta'], ['◎', 'Círculo doble'], ['⊕', 'Cruz en círculo'], ['✠', 'Cruz patada'], ['☥', 'Anj']]]
].map(([group, items]) => [group, items.map(([s, name]) => ({ sym: s + '︎', name }))]);
const STAMP_NAMES = Object.fromEntries(STAMP_CATALOG.flatMap(([, items]) => items.map(i => [i.sym, i.name])));
const STAMP_SIZE = 56;
const RING_SEPS = { none: null, dot: '·', cross: '✠' };
const PLANET_GLYPH = { saturn: '♄', jupiter: '♃', mars: '♂', sun: '☉', venus: '♀', mercury: '☿', moon: '☽' };
const SYMBOL_FONT = 'Segoe UI Symbol, serif';

const LAYER_TYPES = {
  circle: { label: 'Círculo', nested: true },
  square: { label: 'Cuadrado', nested: true },
  triangle: { label: 'Triángulo', nested: true },
  ringLatin: { label: 'Anillo latino', nested: true },
  ringHebrew: { label: 'Anillo hebreo', nested: true },
  star: { label: 'Estrella', nested: true },
  inscription: { label: 'Inscripción', nested: true },
  caption: { label: 'Rótulo', nested: false },
  symbol: { label: 'Símbolo', nested: false }
};
const LAYER_DEFAULTS = {
  circle: { opacity: 70 }, square: { opacity: 70 }, triangle: { opacity: 70 },
  ringLatin: { text: '', sep: 'none', symbol: '' },
  ringHebrew: { text: '', sep: 'dot', symbol: '' },
  star: { points: 5, shape: 'sharp', inner: 50, chords: true, contain: false, width: 2.5, opacity: 70 },
  inscription: { text: '', pos: 'upperArc', size: 22, spacing: 4, opacity: 90 },
  caption: { title: '', sub: '' },
  symbol: { sym: '♄︎', x: C, y: 120, size: STAMP_SIZE }
};
let layerSeq = 0;
function newLayer(type, extra = {}) {
  return { id: `c${++layerSeq}`, type, visible: true, scale: 100, rot: 0, dx: 0, dy: 0, width: 3, opacity: 100, ...LAYER_DEFAULTS[type], ...extra };
}
const isNested = L => LAYER_TYPES[L.type].nested && !(L.type === 'inscription' && (L.pos === 'top' || L.pos === 'bottom'));
const layersOf = scope => scope === 'personal' ? state.personal.layers : state.layers;
const layerById = (scope, id) => layersOf(scope).find(L => L.id === id) || null;
const layerName = L => LAYER_TYPES[L.type].label + (L.type === 'star' ? ` ${L.points}` : L.type === 'symbol' ? ` ${L.sym}` : '');

// Contexto de texto por defecto: la intencion (letras) o el nombre (sello)
function layerCtx(scope) {
  if (scope === 'personal') {
    const planet = personalPlanet(), k = KAMEA_BY_ID[planet];
    const name = personalName() || 'SIN NOMBRE';
    return { text: name, planet, title: `Sello de ${name}`, sub: `${k.sym}︎ ${k.name} · ${PLANET_METAL[planet]}` };
  }
  return { text: state.intention, planet: null, title: state.intention, sub: '' };
}
const rotPt = (x, y, cx, cy, deg) => {
  const a = rad(deg), c = Math.cos(a), s = Math.sin(a), u = x - cx, v = y - cy;
  return [cx + u * c - v * s, cy + u * s + v * c];
};
function ringSymbol(L, ctx) {
  if (!L.symbol) return null;
  const pid = L.symbol === 'auto' ? ctx.planet : L.symbol;
  return pid && PLANET_GLYPH[pid] ? PLANET_GLYPH[pid] + '︎' : null;
}
// Letras repartidas por un circulo, empezando arriba (giro incluido);
// el hebreo avanza en sentido antihorario porque se lee de derecha a izquierda
function circleText(items, cx, cy, r, size, dir, rot, fonts, op) {
  const n = items.length || 1;
  return items.map((ch, i) => {
    const a = -90 + rot + dir * i * 360 / n;
    const x = cx + Math.cos(rad(a)) * r, y = cy + Math.sin(rad(a)) * r;
    if (hasGlyph(ch)) return { k: 'glyph', x, y, rot: a + 90, size: size * 1.05, ch, op };
    return { k: 'text', x, y, rot: a + 90, size, ch, font: /[א-ת]/.test(ch) ? fonts.heb : fonts.lat, op };
  });
}
const LAT_FONTS = { lat: 'Georgia, serif', heb: 'Arial Hebrew, Segoe UI, serif' };

// Geometria de una capa: primitivas, hueco interior y puntos para las guias
function layerGeom(L, R, ctx) {
  const cx = C + L.dx, cy = C + L.dy, op = L.opacity / 100, w = L.width;
  const out = { prims: [], inner: R, center: [cx, cy], vertices: [], radii: [] };
  const poly = (pts, closed = true, width = w, o = op) => out.prims.push({ k: 'poly', pts, closed, w: width, op: o });
  switch (L.type) {
    case 'circle':
      out.prims.push({ k: 'circle', cx, cy, r: R, w, op });
      out.inner = R - 14; out.radii.push([cx, cy, R]);
      break;
    case 'square': {
      const h = R / Math.SQRT2, pts = [[-h, -h], [h, -h], [h, h], [-h, h]].map(([x, y]) => rotPt(cx + x, cy + y, cx, cy, L.rot));
      poly(pts); out.vertices.push(...pts); out.inner = h - 12;
      break;
    }
    case 'triangle': {
      const pts = [-90, 30, 150].map(a => rotPt(cx + Math.cos(rad(a)) * R, cy + Math.sin(rad(a)) * R, cx, cy, L.rot));
      poly(pts); out.vertices.push(...pts); out.inner = R / 2 - 10;
      break;
    }
    case 'ringLatin': case 'ringHebrew': {
      const heb = L.type === 'ringHebrew', s = R / (heb ? 338 : 334), wf = w / 3;
      const rings = heb ? [[338, 3], [328, 1.5], [258, 3]] : [[334, 4], [262, 4]];
      for (const [r, ww] of rings) { out.prims.push({ k: 'circle', cx, cy, r: r * s, w: ww * wf, op }); out.radii.push([cx, cy, r * s]); }
      const text = (L.text || '').trim() || ctx.text || '';
      let items;
      if (heb) {
        const hw = (hasHebrew(text) ? cleanHebrew(text) : transliterate(text, 'consonantal').hebrew).split(' ').filter(Boolean);
        const sep = RING_SEPS[L.sep] || '·';
        items = hw.flatMap((wd, i) => [...(i ? [sep] : []), ...wd]);
      } else {
        const letters = [...text.normalize('NFD').replace(/[̀-ͯ]/g, '').toUpperCase().replace(/[^A-Z]/g, '')];
        const sep = RING_SEPS[L.sep];
        items = sep ? letters.flatMap((c, i) => i ? [sep, c] : [c]) : letters;
      }
      const sym = ringSymbol(L, ctx);
      if (sym) items = [sym, ...items];
      const size = Math.max(18, Math.min(heb ? 34 : 40, (heb ? 620 : 700) / (items.length || 1))) * s;
      const tr = (heb ? 293 : 298) * s;
      out.prims.push(...circleText(items, cx, cy, tr, size, heb ? -1 : 1, L.rot, LAT_FONTS, op));
      out.radii.push([cx, cy, tr]);
      out.inner = (heb ? 258 : 262) * s - 14;
      break;
    }
    case 'star': {
      const n = L.points, k = STAR_STEP[n];
      const rIn = L.shape === 'wide' ? R * L.inner / 100 : R * starRatio(n, k);
      const a0 = rad(L.rot) - Math.PI / 2, pts = [];
      for (let i = 0; i < n * 2; i++) {
        const a = a0 + i * Math.PI / n, r = i % 2 ? rIn : R;
        pts.push([cx + Math.cos(a) * r, cy + Math.sin(a) * r]);
      }
      poly(pts, true, w, op);
      const tips = pts.filter((_, i) => !(i % 2));
      if (L.chords) tips.forEach((t, j) => out.prims.push({ k: 'poly', pts: [t, tips[(j + k) % n]], closed: false, w: w / 2, op: op * .6 }));
      out.vertices.push(...pts); out.radii.push([cx, cy, R]);
      // si contiene, lo de dentro cabe en el poligono central; si no, se cruza
      out.inner = L.contain ? rIn * Math.cos(Math.PI / n) - 6 : R * .72;
      break;
    }
    case 'inscription': {
      const txt = [...((L.text || '').trim() || ctx.text || '').toUpperCase()];
      const adv = L.size * .62 + L.spacing;
      if (L.pos === 'top' || L.pos === 'bottom') {
        const y = (L.pos === 'top' ? L.size * 1.1 : SIZE - L.size * 1.1) + L.dy, x0 = C + L.dx - (txt.length - 1) * adv / 2;
        txt.forEach((ch, i) => out.prims.push({ k: 'text', x: x0 + i * adv, y, rot: 0, size: L.size, ch, font: LAT_FONTS.lat, op }));
        out.center = [C + L.dx, y];
        break;
      }
      const r = R - L.size * .6, arc = Math.min(2.4, txt.length * adv / Math.max(r, 1)), lower = L.pos === 'lowerArc';
      txt.forEach((ch, i) => {
        const t = txt.length === 1 ? .5 : i / (txt.length - 1);
        const a = (lower ? Math.PI / 2 + arc / 2 - arc * t : -Math.PI / 2 - arc / 2 + arc * t) + rad(L.rot);
        out.prims.push({ k: 'text', x: cx + Math.cos(a) * r, y: cy + Math.sin(a) * r, rot: (lower ? a - Math.PI / 2 : a + Math.PI / 2) * 180 / Math.PI, size: L.size, ch, font: LAT_FONTS.lat, op });
      });
      out.radii.push([cx, cy, r]);
      out.inner = R - L.size * 1.4;
      break;
    }
    case 'caption': {
      const title = (L.title || '').trim() || ctx.title || '', sub = (L.sub || '').trim() || ctx.sub || '';
      if (title) out.prims.push({ k: 'text', x: C + L.dx, y: 64 + L.dy, rot: 0, size: 28, ch: title, font: 'italic', op });
      if (sub) out.prims.push({ k: 'text', x: C + L.dx, y: SIZE - 42 + L.dy, rot: 0, size: 17, ch: sub, font: SYMBOL_FONT, op: op * .8 });
      out.center = [C + L.dx, 64 + L.dy];
      break;
    }
    case 'symbol':
      out.prims.push(hasGlyph(L.sym) ? { k: 'glyph', x: L.x, y: L.y, rot: L.rot, size: L.size, ch: L.sym, op } : { k: 'text', x: L.x, y: L.y, rot: L.rot, size: L.size, ch: L.sym, font: SYMBOL_FONT, op });
      out.center = [L.x, L.y];
      break;
  }
  return out;
}
// Pila completa: cada marco se encaja en el hueco del anterior
// La geometria de capas es pura (capas + contexto): se calcula una vez por
// estado y la reusan pintado, toque, guias y barra
const layCache = new Map();
function layoutLayers(layers, ctx) {
  const key = JSON.stringify([layers, ctx]);
  let v = layCache.get(key);
  if (!v) {
    v = layoutLayersRaw(layers, ctx);
    layCache.set(key, v);
    if (layCache.size > 12) layCache.delete(layCache.keys().next().value);
  }
  return v;
}
function layoutLayersRaw(layers, ctx) {
  let avail = 345;
  const parts = [];
  for (const L of layers) {
    if (!L.visible) continue;
    if (isNested(L)) {
      const R = avail * L.scale / 100, g = layerGeom(L, R, ctx);
      parts.push({ L, g, R });
      avail = Math.max(24, g.inner);
    } else parts.push({ L, g: layerGeom(L, 0, ctx) });
  }
  // con rotulo, el sigilo deja sitio arriba y abajo
  if (parts.some(p => p.L.type === 'caption')) avail = Math.min(avail, 285);
  return { parts, contentR: avail };
}
// Render de primitivas: canvas y SVG leen la misma lista
// centro optico de una linea de texto respecto de su base (fraccion del cuerpo)
const TEXT_MID = .35;
function paintPrims(ctx, prims, color) {
  ctx.save(); ctx.strokeStyle = color; ctx.fillStyle = color; ctx.lineJoin = 'round'; ctx.lineCap = 'round';
  for (const p of prims) {
    ctx.globalAlpha = p.op;
    if (p.k === 'circle') { ctx.lineWidth = p.w; ctx.beginPath(); ctx.arc(p.cx, p.cy, p.r, 0, Math.PI * 2); ctx.stroke(); }
    else if (p.k === 'poly') { ctx.lineWidth = p.w; ctx.beginPath(); ctx.moveTo(...p.pts[0]); p.pts.slice(1).forEach(q => ctx.lineTo(...q)); if (p.closed) ctx.closePath(); ctx.stroke(); }
    else if (p.k === 'glyph') paintGlyph(ctx, p.ch, p.x, p.y, p.size, p.rot, color);
    else {
      ctx.save(); ctx.translate(p.x, p.y); ctx.rotate(rad(p.rot));
      const italic = p.font.startsWith('italic');
      ctx.font = `${italic ? 'italic ' : ''}${p.size}px ${italic ? 'Georgia, serif' : p.font}`;
      // linea base alfabetica y el mismo desplazamiento que en el SVG: pixel a pixel igual
      ctx.textAlign = 'center'; ctx.textBaseline = 'alphabetic'; ctx.fillText(p.ch, 0, p.size * TEXT_MID); ctx.restore();
    }
  }
  ctx.restore();
}
function primsSVG(prims, color) {
  return prims.map(p => {
    const o = p.op < 1 ? ` opacity="${f2(p.op)}"` : '';
    if (p.k === 'circle') return `<circle cx="${f2(p.cx)}" cy="${f2(p.cy)}" r="${f2(p.r)}" fill="none" stroke="${color}" stroke-width="${f2(p.w)}"${o}/>`;
    if (p.k === 'poly') return `<path d="M ${p.pts.map(q => f2(q[0]) + ' ' + f2(q[1])).join(' L ')}${p.closed ? ' Z' : ''}" fill="none" stroke="${color}" stroke-width="${f2(p.w)}" stroke-linejoin="round" stroke-linecap="round"${o}/>`;
    if (p.k === 'glyph') return glyphSVG(p.ch, p.x, p.y, p.size, p.rot, color, p.op);
    const italic = p.font.startsWith('italic');
    return `<text transform="translate(${f2(p.x)} ${f2(p.y)}) rotate(${f2(p.rot)})" y="${f2(p.size * TEXT_MID)}" text-anchor="middle" font-family="${italic ? 'Georgia, serif' : p.font}"${italic ? ' font-style="italic"' : ''} font-size="${f2(p.size)}" fill="${color}"${o}>${esc(p.ch)}</text>`;
  }).join('');
}
const layersSVG = (parts, color, which) => parts.filter(which).map(p => `<g data-layer="${p.L.type}">${primsSVG(p.g.prims, color)}</g>`).join('');

// ── Guias inteligentes (iman) ───────────────────────────────────
// Al arrastrar, se alinea con el centro, otros elementos, angulos de 15
// grados, radios de los anillos y vertices. Solo se dibujan las guias que
// actuan (una o dos): nada fijo que sature. Alt suelta el iman.
function snapTargets(scope, excludeId) {
  const pts = [[C, C]], radii = [];
  const lay = layoutLayers(layersOf(scope), layerCtx(scope));
  for (const p of lay.parts) {
    if (p.L.id === excludeId) continue;
    pts.push(p.g.center, ...p.g.vertices);
    radii.push(...p.g.radii);
  }
  if (scope === 'letters' && state.view) {
    for (const l of activeLetters()) if (l.base && excludeId !== 'letter:' + l.ch) pts.push(Object.values(toCanvas({ x: l.base.tx + l.user.dx, y: l.base.ty + l.user.dy })));
    for (const e of freeEnds(state.prims.filter(q => !q.hidden))) { const q = toCanvas(e); pts.push([q.x, q.y]); }
  }
  return { pts, radii };
}
function snapPoint(pt, scope, excludeId, ev) {
  state.guides = [];
  if (!state.magnet || (ev && ev.altKey)) return pt;
  const r = canvas.getBoundingClientRect(), T = 9 * SIZE / (r.width || SIZE);
  const { pts, radii } = snapTargets(scope, excludeId);
  // 1) sobre un punto (vertice, centro): gana a todo
  let best = null;
  for (const [x, y] of pts) { const d = Math.hypot(x - pt.x, y - pt.y); if (d < T && (!best || d < best.d)) best = { x, y, d }; }
  if (best) { state.guides = [{ k: 'point', x: best.x, y: best.y }]; return { x: best.x, y: best.y }; }
  // 2) alineado en vertical u horizontal con algo
  let bx = null, by = null;
  for (const [x, y] of pts) {
    if (Math.abs(x - pt.x) < T && (!bx || Math.abs(x - pt.x) < bx.d)) bx = { v: x, d: Math.abs(x - pt.x) };
    if (Math.abs(y - pt.y) < T && (!by || Math.abs(y - pt.y) < by.d)) by = { v: y, d: Math.abs(y - pt.y) };
  }
  const out = { x: bx ? bx.v : pt.x, y: by ? by.v : pt.y };
  if (bx) state.guides.push({ k: 'v', x: bx.v });
  if (by) state.guides.push({ k: 'h', y: by.v });
  if (bx || by) return out;
  // 3) polar: angulo de 15 grados y radio de un anillo
  const dx = pt.x - C, dy = pt.y - C, rr = Math.hypot(dx, dy);
  if (rr > 40) {
    let a = Math.atan2(dy, dx) * 180 / Math.PI;
    const as = Math.round(a / 15) * 15;
    let R = rr;
    const rs = radii.filter(([cx, cy]) => Math.hypot(cx - C, cy - C) < 1).map(q => q[2]).reduce((b, q) => Math.abs(q - rr) < T && (b === null || Math.abs(q - rr) < Math.abs(b - rr)) ? q : b, null);
    if (rs !== null) { R = rs; state.guides.push({ k: 'circle', r: rs }); }
    if (Math.abs(rad(as - a)) * rr < T) { a = as; state.guides.push({ k: 'ray', a: as }); }
    if (state.guides.length) return { x: C + Math.cos(rad(a)) * R, y: C + Math.sin(rad(a)) * R };
  }
  return pt;
}
// Giro con iman: se pega a multiplos de 15 grados
const snapAngle = (deg, ev) => (!state.magnet || (ev && ev.altKey)) ? deg : (Math.abs(deg - Math.round(deg / 15) * 15) <= 4 ? Math.round(deg / 15) * 15 : deg);
function paintGuides(ctx, th) {
  if (!state.guides.length) return;
  ctx.save(); ctx.strokeStyle = th.ui; ctx.fillStyle = th.ui; ctx.lineWidth = 1.4; ctx.setLineDash([7, 6]); ctx.globalAlpha = .9;
  for (const g of state.guides) {
    ctx.beginPath();
    if (g.k === 'v') { ctx.moveTo(g.x, 0); ctx.lineTo(g.x, SIZE); }
    else if (g.k === 'h') { ctx.moveTo(0, g.y); ctx.lineTo(SIZE, g.y); }
    else if (g.k === 'ray') { ctx.moveTo(C, C); ctx.lineTo(C + Math.cos(rad(g.a)) * 400, C + Math.sin(rad(g.a)) * 400); }
    else if (g.k === 'circle') ctx.arc(C, C, g.r, 0, Math.PI * 2);
    else { ctx.setLineDash([]); ctx.arc(g.x, g.y, 7, 0, Math.PI * 2); }
    ctx.stroke();
  }
  ctx.restore();
}
// Rejilla de ayuda (no se exporta)
function paintGrid(ctx, th) {
  if (state.grid === 'none') return;
  ctx.save(); ctx.strokeStyle = th.faint; ctx.lineWidth = 1; ctx.globalAlpha = .7;
  if (state.grid === 'polar') {
    for (let r = 50; r <= 350; r += 50) { ctx.beginPath(); ctx.arc(C, C, r, 0, Math.PI * 2); ctx.stroke(); }
    for (let a = 0; a < 360; a += 15) { ctx.beginPath(); ctx.moveTo(C, C); ctx.lineTo(C + Math.cos(rad(a)) * 350, C + Math.sin(rad(a)) * 350); ctx.stroke(); }
  } else {
    for (let v = 0; v <= SIZE; v += 50) { ctx.beginPath(); ctx.moveTo(v, 0); ctx.lineTo(v, SIZE); ctx.moveTo(0, v); ctx.lineTo(SIZE, v); ctx.stroke(); }
  }
  ctx.restore();
}
// Marca de la capa seleccionada (solo en pantalla)
function paintLayerSelection(ctx, th, scope) {
  const L = layerById(scope, state.layerSel[scope]);
  if (!L || !L.visible) return;
  const lay = layoutLayers(layersOf(scope), layerCtx(scope)), p = lay.parts.find(q => q.L.id === L.id);
  if (!p) return;
  ctx.save(); ctx.strokeStyle = th.ui; ctx.lineWidth = 2; ctx.setLineDash([4, 5]);
  if (L.type === 'symbol') { ctx.beginPath(); ctx.arc(L.x, L.y, L.size * .72, 0, Math.PI * 2); ctx.stroke(); }
  else if (p.R) { ctx.beginPath(); ctx.arc(p.g.center[0], p.g.center[1], p.R + 6, 0, Math.PI * 2); ctx.stroke(); }
  ctx.restore();
}

// Toque sobre el lienzo: que capa hay bajo el dedo
function layerAt(pt, scope) {
  const lay = layoutLayers(layersOf(scope), layerCtx(scope));
  for (const p of [...lay.parts].reverse()) {
    if (p.L.type === 'symbol' && Math.hypot(pt.x - p.L.x, pt.y - p.L.y) < Math.max(24, p.L.size * .7)) return p.L;
  }
  for (const p of [...lay.parts].reverse()) {
    if (p.L.type === 'symbol') continue;
    const near = p.g.radii.some(([cx, cy, r]) => Math.abs(Math.hypot(pt.x - cx, pt.y - cy) - r) < 12)
      || p.g.prims.some(q => q.k === 'poly' && q.pts.some((a, i) => { const b = q.pts[(i + 1) % q.pts.length]; if (!q.closed && i === q.pts.length - 1) return false; return distToSegment(pt, { x: a[0], y: a[1] }, { x: b[0], y: b[1] }).d < 10; }))
      || p.g.prims.some(q => q.k === 'text' && Math.hypot(pt.x - q.x, pt.y - q.y) < q.size * .6);
    if (near) return p.L;
  }
  return null;
}

// ── Panel de capas (comun a Sigilo de letras y Sello personal) ───
const LAYER_PRESETS = {
  goetia: { label: 'Goetia', make: scope => [newLayer('ringLatin', { symbol: scope === 'personal' ? 'auto' : '' })] },
  pentaculo: { label: 'Pentáculo', make: scope => [newLayer('ringHebrew', { symbol: scope === 'personal' ? 'auto' : '' })] },
  agrippa: { label: 'Agrippa', make: () => [newLayer('caption')] },
  vacio: { label: 'Vaciar', make: () => [] }
};
function setLayers(scope, list) {
  if (scope === 'personal') state.personal.layers = list; else state.layers = list;
}
function layersChanged(scope) {
  renderLayerPanel(scope);
  if (scope === 'personal') renderPersonalInfo();
  render();
}
function addLayer(scope, type, extra = {}) {
  const L = newLayer(type, extra);
  // los marcos nuevos entran por dentro de los que ya hay (antes de rotulos y simbolos)
  const list = layersOf(scope);
  const idx = LAYER_TYPES[type].nested ? list.filter(isNested).length : list.length;
  const pos = LAYER_TYPES[type].nested ? list.findIndex((q, i) => !isNested(q) && list.slice(0, i).filter(isNested).length >= idx) : -1;
  if (pos >= 0) list.splice(pos, 0, L); else list.push(L);
  state.layerSel[scope] = L.id;
  // lo nuevo queda seleccionado: la letra que lo estuviera deja de estarlo
  if (scope === 'letters') state.sel = null;
  layersChanged(scope);
  return L;
}
function moveLayer(scope, id, d) {
  const list = layersOf(scope), i = list.findIndex(L => L.id === id), j = i + d;
  if (i < 0 || j < 0 || j >= list.length) return;
  [list[i], list[j]] = [list[j], list[i]];
  layersChanged(scope);
}
function removeLayer(scope, id) {
  setLayers(scope, layersOf(scope).filter(L => L.id !== id));
  if (state.layerSel[scope] === id) state.layerSel[scope] = null;
  layersChanged(scope);
}
const PLANET_OPTS = scope => `<option value="">Sin símbolo</option>${scope === 'personal' ? '<option value="auto">Planeta del sello</option>' : ''}${KAMEAS.map(k => `<option value="${k.id}">${k.sym}︎ ${k.name}</option>`).join('')}`;
function layerEditorHTML(scope, L) {
  const f = (label, input, adv = false) => `<div class="field"${adv ? ' data-adv' : ''}><label>${label}</label>${input}</div>`;
  const rng = (key, min, max, step = 1, suffix = '') => `<input type="range" data-k="${key}" min="${min}" max="${max}" step="${step}" value="${L[key]}"><span class="val">${L[key]}${suffix}</span>`;
  const sel = (key, opts) => `<select data-k="${key}">${opts.map(([v, t]) => `<option value="${v}"${String(L[key]) === String(v) ? ' selected' : ''}>${t}</option>`).join('')}</select>`;
  const txt = (key, ph) => `<input type="text" data-k="${key}" maxlength="42" value="${esc(L[key] || '')}" placeholder="${ph}">`;
  const chk = (key, label, title = '') => `<label class="check" data-adv title="${title}"><input type="checkbox" data-k="${key}"${L[key] ? ' checked' : ''}>${label}</label>`;
  let h = '';
  if (L.type === 'ringLatin' || L.type === 'ringHebrew') {
    h += txt('text', scope === 'personal' ? 'Texto (vacío: el nombre del sello)' : 'Texto (vacío: la intención)');
    h += f('Separadores', sel('sep', [['none', 'Ninguno'], ['dot', 'Puntos'], ['cross', 'Cruces']]));
    h += f('Símbolo arriba', `<select data-k="symbol">${PLANET_OPTS(scope).replace(`value="${L.symbol}"`, `value="${L.symbol}" selected`)}</select>`);
  }
  if (L.type === 'star') {
    h += f('Puntas', sel('points', [5, 6, 7, 8, 9].map(n => [n, n])));
    h += f('Forma', sel('shape', [['sharp', 'Angulosa (exacta)'], ['wide', 'Ancha']]));
    if (L.shape === 'wide') h += f('Interior', rng('inner', 30, 80, 1, '%'), true);
    h += chk('chords', 'Acordes internos') + chk('contain', 'Lo de dentro cabe en su centro', 'Encoge lo que va dentro para que quepa en el polígono central');
  }
  if (L.type === 'inscription') {
    h += txt('text', 'Lema, nombre o frase');
    h += f('Posición', sel('pos', [['upperArc', 'Arco superior'], ['lowerArc', 'Arco inferior'], ['top', 'Arriba'], ['bottom', 'Abajo']]));
    h += f('Letra', rng('size', 12, 40), true) + f('Espaciado', rng('spacing', 0, 20), true);
  }
  if (L.type === 'caption') h += txt('title', 'Título (vacío: automático)') + txt('sub', 'Subtítulo (vacío: automático)');
  if (L.type === 'symbol') {
    h += f('Símbolo', `<select data-k="sym">${STAMP_CATALOG.map(([g, items]) => `<optgroup label="${g}">${items.map(i => `<option value="${i.sym}"${i.sym === L.sym ? ' selected' : ''}>${i.sym} ${i.name}</option>`).join('')}</optgroup>`).join('')}</select>`);
    h += f('Tamaño', rng('size', 18, 160), true);
  }
  if (isNested(L)) h += f('Tamaño', rng('scale', 40, 160, 1, '%'), true);
  h += f('Giro', rng('rot', 0, 359, 1, '°'), true);
  if (L.type !== 'symbol' && L.type !== 'caption' && L.type !== 'inscription') h += f('Grosor', rng('width', 1, 10, .5), true);
  h += f('Opacidad', rng('opacity', 10, 100, 1, '%'), true);
  if (L.type !== 'symbol') h += `<div class="row"><button class="btn-dim" data-act="center">Centrar</button></div>`;
  return h;
}
function renderLayerPanel(scope) {
  const box = $(`layerList_${scope}`);
  if (!box) return;
  const list = layersOf(scope), selId = state.layerSel[scope];
  box.innerHTML = list.length ? '' : '<div class="helper">Sin capas. Añade una o usa una plantilla.</div>';
  list.forEach((L, i) => {
    const row = document.createElement('div');
    row.className = 'layer-row' + (L.id === selId ? ' sel' : '') + (L.visible ? '' : ' off');
    row.innerHTML = `<input type="checkbox" title="Visible"${L.visible ? ' checked' : ''}><span class="layer-name">${esc(layerName(L))}</span>` +
      (L.id === selId ? `<button class="btn-dim" data-m="-1" title="Subir (más afuera)"${i ? '' : ' disabled'}>▲</button><button class="btn-dim" data-m="1" title="Bajar (más adentro)"${i < list.length - 1 ? '' : ' disabled'}>▼</button><button class="btn-dim" data-x title="Quitar">✕</button>` : '');
    row.querySelector('input').addEventListener('change', e => { L.visible = e.target.checked; layersChanged(scope); });
    row.querySelector('.layer-name').addEventListener('click', () => { state.layerSel[scope] = L.id === selId ? null : L.id; layersChanged(scope); });
    row.querySelectorAll('[data-m]').forEach(b => b.addEventListener('click', () => moveLayer(scope, L.id, Number(b.dataset.m))));
    const x = row.querySelector('[data-x]');
    if (x) x.addEventListener('click', () => removeLayer(scope, L.id));
    box.append(row);
  });
  const ed = $(`layerEditor_${scope}`), L = layerById(scope, selId);
  ed.hidden = !L;
  if (!L) { ed.innerHTML = ''; return; }
  ed.innerHTML = `<h4>${esc(layerName(L))}</h4>` + layerEditorHTML(scope, L);
  ed.querySelectorAll('[data-k]').forEach(el => {
    const k = el.dataset.k, ev = el.type === 'range' || el.type === 'text' ? 'input' : 'change';
    el.addEventListener(ev, e => {
      let v = el.type === 'checkbox' ? el.checked : el.type === 'range' ? Number(el.value) : el.value;
      if (['points', 'size'].includes(k) && el.tagName === 'SELECT') v = Number(v);
      if (k === 'rot') { v = snapAngle(v, e); el.value = v; }
      L[k] = v;
      if (el.type === 'range') el.nextElementSibling.textContent = v + ({ scale: '%', opacity: '%', inner: '%', rot: '°' }[k] || '');
      // cambiar la forma o la posicion cambia los campos del editor
      if (['shape', 'pos', 'points', 'sym'].includes(k)) renderLayerPanel(scope);
      if (scope === 'personal') renderPersonalInfo();
      render();
    });
  });
  const c = ed.querySelector('[data-act="center"]');
  if (c) c.addEventListener('click', () => { L.dx = 0; L.dy = 0; layersChanged(scope); });
}
// Catalogo de simbolos arcanos por grupos (dentro de la paleta)
const stampCatalogHTML = () => STAMP_CATALOG.map(([group, items]) => `<div class="stamp-group">${group}</div><div class="stamp-grid">${items.map(it => `<button class="stamp-btn" data-s="${it.sym}" title="${it.name}" aria-label="${it.name}">${glyphIcon(it.sym)}</button>`).join('')}</div>`).join('');
function mountLayerPanel(scope, host) {
  const frames = Object.entries(LAYER_TYPES).filter(([k]) => k !== 'symbol');
  host.innerHTML = `<div class="layer-list" id="layerList_${scope}"></div>` +
    `<button class="btn" id="btnAddLayer_${scope}" data-pal="addPalette_${scope}" aria-expanded="false">+ Añadir ▾</button>` +
    `<div class="palette" id="addPalette_${scope}" hidden>` +
    `<div class="stamp-group">Marcos y textos</div><div class="pal-grid">${frames.map(([k, t]) => `<button class="btn-dim" data-add="${k}">${t.label}</button>`).join('')}</div>` +
    `<div${scope === 'letters' ? ' id="stampCatalog"' : ''}>${stampCatalogHTML()}</div>` +
    `<div class="stamp-group">Plantillas (sustituyen las capas)</div><div class="pal-grid layer-presets">${Object.entries(LAYER_PRESETS).map(([k, p]) => `<button class="btn-dim" data-preset="${k}" title="${k === 'vacio' ? 'Quitar todas las capas' : 'Cargar la plantilla ' + p.label + ' (sustituye las capas)'}">${p.label}</button>`).join('')}</div>` +
    `</div>` +
    `<div class="layer-editor" id="layerEditor_${scope}" hidden></div>`;
  host.querySelectorAll('[data-preset]').forEach(b => b.addEventListener('click', () => {
    closePalettes();
    setLayers(scope, LAYER_PRESETS[b.dataset.preset].make(scope));
    state.layerSel[scope] = null;
    if (scope === 'personal') state.personal.template = b.dataset.preset;
    layersChanged(scope);
  }));
  host.querySelectorAll('[data-add]').forEach(b => b.addEventListener('click', () => { closePalettes(); addLayer(scope, b.dataset.add); }));
  // elegir un simbolo deja listo el modo colocar: un toque en el lienzo lo pone
  host.querySelectorAll('.stamp-btn').forEach(b => b.addEventListener('click', () => {
    closePalettes();
    state.stampSym = b.dataset.s; state.stampMode = true; state.hideMode = false; state.termPick = false;
    syncControls(); showToast(b.title + ': toca el lienzo para colocarlo');
  }));
  renderLayerPanel(scope);
}
function syncLayerTools() {
  const g = { none: ['gridNone', 'Rejilla: no'], polar: ['gridPolar', 'Rejilla polar'], square: ['gridSquare', 'Rejilla cuadrada'] }[state.grid];
  $('btnGrid').innerHTML = icon(g[0]); $('btnGrid').title = g[1] + ' (no se exporta). Toca para cambiar';
  $('btnGrid').classList.toggle('on', state.grid !== 'none');
}
// ── Paletas: un boton abre su catalogo; elegir o tocar fuera lo cierra ──
function closePalettes(except) {
  document.querySelectorAll('.palette').forEach(p => { if (p.id !== except) p.hidden = true; });
  document.querySelectorAll('[data-pal]').forEach(b => b.setAttribute('aria-expanded', String(b.dataset.pal === except && !$(except).hidden)));
}
document.addEventListener('click', e => {
  const trig = e.target.closest('[data-pal]');
  if (trig) {
    const p = $(trig.dataset.pal), open = p.hidden;
    // abrir «Añadir» cancela un «colocar» pendiente
    if (open && state.stampMode) { state.stampMode = false; syncControls(); }
    closePalettes(trig.dataset.pal);
    p.hidden = !open; trig.setAttribute('aria-expanded', String(open));
    return;
  }
  if (!e.target.closest('.palette')) closePalettes();
});
