'use strict';
// Radial del elemento tocado, escena del sigilo, pintado y SVG
// ── Barra contextual: los botones del elemento tocado, junto a el ──
function ctxTarget() {
  const fam = state.family;
  if (fam !== 'letters' && fam !== 'personal') return null;
  if (state.dragging || layerDrag || state.termPick || state.hideMode || state.stampMode) return null;
  if (fam === 'letters' && state.sel && state.prims.length) {
    const l = state.letters.find(x => x.ch === state.sel && !x.twin);
    if (l) {
      // caja de la letra en el lienzo, a partir de sus trazos
      const ys = [], xs = [];
      for (const p of state.prims) {
        if (p.hidden || !p.units.includes(l.ch)) continue;
        if (p.t === 'L') for (const q of [toCanvas(p.a), toCanvas(p.b)]) { xs.push(q.x); ys.push(q.y); }
        else { const c = toCanvas(p.c), r = p.r * state.view.k; xs.push(c.x - r, c.x + r); ys.push(c.y - r, c.y + r); }
      }
      if (xs.length) return { kind: 'letter', name: l.ch, x: (Math.min(...xs) + Math.max(...xs)) / 2, top: Math.min(...ys), bottom: Math.max(...ys) };
    }
  }
  const scope = scopeNow(), L = layerById(scope, state.layerSel[scope]);
  if (!L || !L.visible) return null;
  const name = L.type === 'symbol' ? `${L.sym} ${STAMP_NAMES[L.sym] || ''}` : layerName(L);
  if (L.type === 'symbol') return { kind: 'layer', L, name, x: L.x, top: L.y - L.size * .75, bottom: L.y + L.size * .75 };
  const p = layoutLayers(layersOf(scope), layerCtx(scope)).parts.find(q => q.L.id === L.id);
  if (!p) return null;
  if (p.R) return { kind: 'layer', L, name, x: p.g.center[0], top: p.g.center[1] - p.R, bottom: p.g.center[1] + p.R };
  const ys = p.g.prims.flatMap(q => q.k === 'text' ? [q.y - q.size, q.y] : q.k === 'poly' ? q.pts.map(a => a[1]) : []);
  return { kind: 'layer', L, name, x: C, top: ys.length ? Math.min(...ys) : C, bottom: ys.length ? Math.max(...ys) : C };
}
function editLayer(fn) {
  const scope = scopeNow(), L = layerById(scope, state.layerSel[scope]);
  if (!L) { showToast('Toca primero un elemento en el lienzo'); return; }
  fn(L); layersChanged(scope);
}
// Galeria antigua (borde, estrella, inscripcion, estampas) -> capas
function legacyLayers(s) {
  const out = [];
  if (s.border === 'ringLatin' || s.border === 'ringHebrew') out.push(newLayer(s.border, { text: s.ringText || '', sep: s.ringSep || (s.border === 'ringHebrew' ? 'dot' : 'none') }));
  else if (['circle', 'square', 'triangle'].includes(s.border)) out.push(newLayer(s.border));
  if (s.star && s.star.enabled) out.push(newLayer('star', { points: s.star.points, shape: s.star.shape || 'wide', inner: s.star.inner, chords: s.star.chords, contain: !!s.star.fitInside, rot: s.star.rotation || 0, opacity: s.star.opacity || 80 }));
  if (s.inscription && s.inscription.enabled) out.push(newLayer('inscription', { text: s.inscription.text, pos: s.inscription.pos, size: s.inscription.size, spacing: s.inscription.spacing }));
  (s.stamps || []).forEach(st => out.push(newLayer('symbol', { sym: st.sym, x: st.x, y: st.y, size: st.size || STAMP_SIZE })));
  return out;
}

function strokePrim(ctx, p) {
  ctx.beginPath();
  if (p.t === 'L') {
    const a = toCanvas(p.a), b = toCanvas(p.b);
    ctx.moveTo(a.x, a.y); ctx.lineTo(b.x, b.y);
  } else {
    const c = toCanvas(p.c);
    ctx.arc(c.x, c.y, p.r * state.view.k, rad(p.a0), rad(p.a1), false);
  }
  ctx.stroke();
}

// Escena del sigilo de letras: soporte, capas, trazos, remates y simbolos
function lettersScene(th, transparent) {
  const st = state.style, lw = LINE_W * st.width / 100;
  const lay = layoutLayers(state.layers, layerCtx('letters'));
  const visible = state.prims.filter(p => !p.hidden);
  const fg = [];
  for (const p of lay.parts) if (p.L.type !== 'symbol') fg.push({ layer: p.L.type, color: th.ink, items: p.g.prims });
  fg.push({ layer: 'core', color: th.ink, w: lw, cap: st.cap, sigil: true, items: visible.map(p => ({ d: primPath(p), units: p.units })) });
  const terms = terminalList(visible);
  if (terms.length) fg.push({ layer: 'terminals', color: th.ink, w: lw * .8, cap: st.cap, sigil: true, items: terms.flatMap(t => t.shapes.map(sh => ({ d: sh.d, fill: !!sh.fill }))) });
  for (const p of lay.parts) if (p.L.type === 'symbol') fg.push({ layer: 'symbol', color: th.ink, items: p.g.prims });
  return { bg: transparent ? [] : bgScene(th), fg: applyFx(fg.filter(g => g.items.length), th) };
}

// opt: { size, theme, transparent, interactive }
function paint(ctx, opt) {
  const th = THEMES[opt.theme], sc = opt.size / SIZE;
  ctx.setTransform(1, 0, 0, 1, 0, 0);
  ctx.clearRect(0, 0, opt.size, opt.size);
  ctx.setTransform(sc, 0, 0, sc, 0, 0);
  ctx.lineCap = 'round'; ctx.lineJoin = 'round';
  if (state.family === 'personal') { paintPersonal(ctx); return; }
  if (state.family === 'compare') { paintCompare(ctx); return; }
  if (state.family !== 'letters') {
    // Rosa-Cruz, Kamea y sellos: el lienzo pinta el mismo SVG que se exporta
    if (!opt.transparent) paintScene(ctx, bgScene(th));
    paintSVGImage(ctx, buildSVG());
    return;
  }
  if (!state.prims.length || !state.view) { if (!opt.transparent) paintScene(ctx, bgScene(th)); return; }
  const scene = lettersScene(th, opt.transparent);
  paintScene(ctx, scene.bg);
  if (opt.interactive) paintGrid(ctx, th);
  const hl = opt.interactive ? state.sel : null;
  paintScene(ctx, scene.fg, { minW: 2 / sc, dim: it => hl && it.units && !it.units.includes(hl) ? .28 : 1 });
  if (!opt.interactive) return;
  // marcas de edicion: solo en pantalla, nunca se exportan
  const lw = LINE_W * state.style.width / 100;
  if (state.hideMode) {
    ctx.save(); ctx.setLineDash([10, 10]); ctx.strokeStyle = th.faint; ctx.lineWidth = lw * .6;
    state.prims.filter(p => p.hidden).forEach(p => strokePrim(ctx, p));
    ctx.restore();
  }
  if (state.colors) {
    ctx.save(); ctx.lineWidth = lw * .42;
    activeLetters().forEach((l, i) => { ctx.strokeStyle = LETTER_COLORS[i % LETTER_COLORS.length]; l.own.forEach(p => strokePrim(ctx, p)); });
    ctx.restore();
  }
  if (hl) {
    const l = state.letters.find(x => x.ch === hl && !x.twin);
    if (l) { ctx.save(); ctx.strokeStyle = th.ui; ctx.lineWidth = lw * 1.15; l.own.forEach(p => strokePrim(ctx, p)); ctx.restore(); }
  }
  if (state.termPick) {
    // en modo uno a uno se marcan los extremos libres que se pueden tocar
    ctx.save(); ctx.strokeStyle = th.ui; ctx.lineWidth = 2; ctx.setLineDash([4, 4]);
    for (const e of freeEnds(state.prims.filter(p => !p.hidden))) { const q = toCanvas(e); ctx.beginPath(); ctx.arc(q.x, q.y, 14, 0, Math.PI * 2); ctx.stroke(); }
    ctx.restore();
  }
  paintLayerSelection(ctx, th, 'letters'); paintGuides(ctx, th);
}

const canvas = $('canvas'), ctx = canvas.getContext('2d');
const previewCtx = $('previewCanvas').getContext('2d');
function render() {
  // el encuadre se deriva siempre del estado (borde, estrella, trazos): nunca
  // queda uno viejo. Solo se congela mientras se arrastra una letra.
  if (state.family === 'letters' && state.prims.length && !state.dragging) state.view = fitView();
  paint(ctx, { size: SIZE, theme: state.theme, interactive: true });
  paint(previewCtx, { size: 80, theme: state.theme });
  renderChips();
  syncCtxBar();
  histSchedule();
}
function snapshot(size, theme = state.theme, transparent = false) {
  const off = document.createElement('canvas');
  off.width = off.height = size;
  paint(off.getContext('2d'), { size, theme, transparent });
  return off;
}

// ── SVG real ────────────────────────────────────────────────────
const f2 = v => v.toFixed(2);
function primPath(p) {
  if (p.t === 'L') { const a = toCanvas(p.a), b = toCanvas(p.b); return `M ${f2(a.x)} ${f2(a.y)} L ${f2(b.x)} ${f2(b.y)}`; }
  const c = toCanvas(p.c), r = p.r * state.view.k;
  const at = a => ({ x: c.x + Math.cos(rad(a)) * r, y: c.y + Math.sin(rad(a)) * r });
  const s = at(p.a0), span = p.a1 - p.a0;
  if (span >= 359.5) { const m = at(p.a0 + 180); return `M ${f2(s.x)} ${f2(s.y)} A ${f2(r)} ${f2(r)} 0 0 1 ${f2(m.x)} ${f2(m.y)} A ${f2(r)} ${f2(r)} 0 0 1 ${f2(s.x)} ${f2(s.y)}`; }
  const e = at(p.a1);
  return `M ${f2(s.x)} ${f2(s.y)} A ${f2(r)} ${f2(r)} 0 ${span > 180 ? 1 : 0} 1 ${f2(e.x)} ${f2(e.y)}`;
}
function buildSVG() {
  const th = THEMES[state.theme];
  const out = [`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${SIZE} ${SIZE}" width="${SIZE}" height="${SIZE}">`];
  if (!state.transparent && state.family !== 'personal' && state.family !== 'compare') out.push(sceneSVG(bgScene(th)));
  if (state.family === 'rosa') { out.push(roseSVG(th)); out.push('</svg>'); return out.join(''); }
  if (state.family === 'kamea') { out.push(kameaSVG(th)); out.push('</svg>'); return out.join(''); }
  if (state.family === 'seal') { out.push(sealSVG(th)); out.push('</svg>'); return out.join(''); }
  if (state.family === 'personal') return personalSVG() || out.concat('</svg>').join('');
  if (state.family === 'compare') return compareSVG() || out.concat('</svg>').join('');
  if (state.prims.length && state.view) out.push(sceneSVG(lettersScene(th, true).fg));
  out.push('</svg>');
  return out.join('');
}
