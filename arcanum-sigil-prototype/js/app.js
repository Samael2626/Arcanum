'use strict';
// Generar, edicion, puntero, procedencia, galeria, carga, exportar, historial, controles e inicio
// ── Generar ─────────────────────────────────────────────────────
function generate() {
  const text = $('intention').value.trim();
  if (!text) { showToast('Escribe una intención'); return; }
  const r = reduce(text, state.method);
  const units = r.units.filter(ch => GLYPHS[ch]);
  if (units.length < 1) {
    // sin letras no hay sigilo: nunca se deja el anterior en pantalla como si fuera este
    Object.assign(state, { intention: text, reduction: r, letters: [], extra: [], prims: [], hidden: [], decisions: [], sel: null });
    const why = r.cleaned ? 'La regla elegida no deja ninguna letra. Prueba otra reducción.' : 'La intención no tiene letras latinas.';
    $('reductionBox').innerHTML = `<div class="line"><b>Intención</b><span>${esc(text)}</span></div><div class="line"><b>Resultado</b><span>${why}</span></div>`;
    render();
    showToast(why);
    return;
  }
  const prev = state.intention === text ? Object.fromEntries(state.letters.map(l => [l.ch, l.user])) : {};
  if (state.intention !== text) { state.hidden = []; state.decisions = []; state.endStyles = {}; }
  state.intention = text;
  state.reduction = r;
  state.letters = units.map(ch => ({ ch, user: prev[ch] || newUser() }));
  state.sel = null;
  applyLayout();
  renderReduction();
}

function renderReduction() {
  const r = state.reduction;
  if (!r) return;
  const twins = state.letters.filter(l => l.twin);
  $('reductionBox').innerHTML =
    `<div class="line"><b>Intención</b><span>${esc(r.original)}</span></div>` +
    `<div class="line"><b>Letras</b><span>${esc(r.cleaned)}</span></div>` +
    `<div class="line"><b>Regla</b><span>${withBadges(r.rule)}</span></div>` +
    `<div class="line"><b>Quedan</b><span>${r.units.join(' ')}</span></div>` +
    (twins.length ? `<div class="line"><b>Gemelas</b><span>${twins.map(l => `${l.ch} está en ${l.twin.by} (${l.twin.how})`).join('; ')}</span></div>` : '');
}

function renderChips() {
  const box = $('letterChips');
  if (state.family !== 'letters') return;
  box.innerHTML = '';
  for (const l of state.letters) {
    const b = document.createElement('button');
    const pct = l.twin ? '⊂ ' + l.twin.by : Math.round(l.legible * 100) + '%';
    b.className = 'chip' + (state.sel === l.ch ? ' sel' : '') + (l.twin ? ' absorbed' : '') + (!l.twin && l.legible < .75 ? ' weak' : '');
    b.dataset.ch = l.ch;
    b.title = l.twin ? `${l.ch} ya está dentro de ${l.twin.by} (${l.twin.how})` : `${l.ch}: ${pct} visible` + (l.shares.length ? `, comparte trazos con ${l.shares.join(', ')}` : '');
    b.innerHTML = `<b>${l.ch}</b><small>${pct}</small>`;
    b.addEventListener('click', () => selectLetter(l.twin ? l.twin.by : l.ch));
    box.append(b);
  }
}

// ── Edicion por letra ───────────────────────────────────────────
function selectLetter(ch) {
  state.sel = state.sel === ch ? null : ch;
  render();
}
function editSelected(fn, type) {
  const l = state.letters.find(x => x.ch === state.sel && !x.twin);
  if (!l) { showToast('Toca primero una letra'); return; }
  fn(l.user);
  state.decisions.push({ type, ch: l.ch });
  rebuild();
}
function toggleHidden(key) {
  const i = state.hidden.indexOf(key);
  if (i >= 0) state.hidden.splice(i, 1); else state.hidden.push(key);
  state.decisions.push({ type: i >= 0 ? 'recuperar trazo' : 'ocultar trazo', key });
  rebuild();
}

function canvasPoint(e) {
  const r = canvas.getBoundingClientRect();
  return { x: (e.clientX - r.left) / r.width * SIZE, y: (e.clientY - r.top) / r.height * SIZE };
}
function primAt(pt, pool) {
  const w = toWorld(pt.x, pt.y), tol = 16 / state.view.k;
  let best = null, bd = tol;
  for (const p of pool) { const d = distToPrim(w, p); if (d < bd) { bd = d; best = p; } }
  return best;
}
let layerDrag = null;
const scopeNow = () => state.family === 'personal' ? 'personal' : 'letters';
function startLayerDrag(scope, L, pt, e) {
  state.layerSel[scope] = L.id;
  if (scope === 'letters') state.sel = null;
  ui.tap = pt; ui.tapFor = L.id;
  const c = L.type === 'symbol' ? [L.x, L.y] : [C + L.dx, C + L.dy];
  layerDrag = { scope, L, ox: pt.x - c[0], oy: pt.y - c[1], moved: false };
  canvas.setPointerCapture(e.pointerId);
  renderLayerPanel(scope); render();
}
canvas.addEventListener('pointerdown', e => {
  const fam = state.family;
  if (fam !== 'letters' && fam !== 'personal') return;
  if (fam === 'letters' && !state.prims.length) return;
  const scope = scopeNow(), pt = canvasPoint(e);
  if (fam === 'letters' && state.termPick) {
    const w = toWorld(pt.x, pt.y), tol = 22 / state.view.k;
    const ends = freeEnds(state.prims.filter(p => !p.hidden));
    const en = ends.reduce((b, x) => { const d = Math.hypot(x.x - w.x, x.y - w.y); return d < tol && (!b || d < b.d) ? { ...x, d } : b; }, null);
    if (en) {
      const cur = state.endStyles[en.key] || state.terminals;
      state.endStyles[en.key] = cur === state.termBrush ? 'none' : state.termBrush;
      state.decisions.push({ type: 'remate: ' + TERMINALS.find(t => t.id === state.endStyles[en.key]).name.toLowerCase() });
      render();
    }
    return;
  }
  if (fam === 'letters' && state.hideMode) { const p = primAt(pt, state.prims); if (p) toggleHidden(p.key); return; }
  // un simbolo ya puesto se toca antes que nada: se selecciona y se arrastra,
  // aunque «Colocar» este activo (si no, cada intento de moverlo crea otro)
  const hit = layerAt(pt, scope);
  if (hit && hit.type === 'symbol') { state.stampMode = false; syncControls(); startLayerDrag(scope, hit, pt, e); return; }
  if (state.stampMode) {
    const q = snapPoint(pt, scope, null, e);
    addLayer(scope, 'symbol', { sym: state.stampSym, x: q.x, y: q.y });
    // un toque, un simbolo: para poner otro se vuelve a elegir en el catalogo
    state.stampMode = false; syncControls();
    state.guides = []; render(); return;
  }
  if (fam === 'letters') {
    const p = primAt(pt, state.prims.filter(q => !q.hidden));
    if (p && p.units.length) {
      if (!p.units.includes(state.sel)) {
        const i = p.units.indexOf(state.sel);
        state.sel = p.units[(i + 1) % p.units.length];
      }
      const l = state.letters.find(x => x.ch === state.sel);
      state.layerSel.letters = null;
      ui.tap = pt; ui.tapFor = 'L:' + state.sel;
      const c0 = toCanvas({ x: l.base.tx + l.user.dx, y: l.base.ty + l.user.dy });
      state.dragging = { l, px: pt.x, py: pt.y, c0, dx: l.user.dx, dy: l.user.dy, moved: false };
      canvas.setPointerCapture(e.pointerId);
      renderLayerPanel('letters'); render();
      return;
    }
  }
  if (hit) { startLayerDrag(scope, hit, pt, e); return; }
  state.sel = null; state.layerSel[scope] = null;
  renderLayerPanel(scope); render();
});
canvas.addEventListener('pointermove', e => {
  const pt = canvasPoint(e);
  if (layerDrag) {
    const { L, scope } = layerDrag;
    const q = snapPoint({ x: pt.x - layerDrag.ox, y: pt.y - layerDrag.oy }, scope, L.id, e);
    if (L.type === 'symbol') { L.x = q.x; L.y = q.y; } else { L.dx = q.x - C; L.dy = q.y - C; }
    layerDrag.moved = true;
    render(); return;
  }
  const d = state.dragging;
  if (!d) return;
  // se mueve el centro de la letra y se alinea con guias
  const want = { x: d.c0.x + pt.x - d.px, y: d.c0.y + pt.y - d.py };
  const q = snapPoint(want, 'letters', 'letter:' + d.l.ch, e);
  d.l.user.dx = d.dx + (q.x - d.c0.x) / state.view.k;
  d.l.user.dy = d.dy + (q.y - d.c0.y) / state.view.k;
  d.moved = true;
  rebuild();
});
canvas.addEventListener('pointerup', () => {
  state.guides = [];
  if (layerDrag) {
    if (layerDrag.moved) { state.decisions.push({ type: 'mover capa' }); ui.tap = null; }
    const sc = layerDrag.scope; layerDrag = null;
    renderLayerPanel(sc); render(); return;
  }
  const d = state.dragging;
  if (!d) { render(); return; }
  state.dragging = null;
  if (d.moved) { state.decisions.push({ type: 'mover', ch: d.l.ch }); ui.tap = null; }
  rebuild();
});

// ── Procedencia ─────────────────────────────────────────────────
function showProvenance() {
  const body = $('provBody');
  if (state.family === 'rosa') { body.innerHTML = rosaProvenance(); $('provModal').classList.add('open'); return; }
  if (state.family === 'kamea') { body.innerHTML = kameaProvenance(); $('provModal').classList.add('open'); return; }
  if (state.family === 'seal') { body.innerHTML = sealProvenance(); $('provModal').classList.add('open'); return; }
  if (state.family === 'personal') { body.innerHTML = personalProvenance(); $('provModal').classList.add('open'); return; }
  if (state.family === 'compare') { body.innerHTML = compareProvenance(); $('provModal').classList.add('open'); return; }
  const r = state.reduction;
  if (!r) { body.innerHTML = '<p>Forja primero un sigilo.</p>'; $('provModal').classList.add('open'); return; }
  const m = MODES[state.mode];
  let html = `<h3>Reducción</h3><p><b>${esc(r.label)}</b> ${badge(r.tag)}: ${withBadges(r.rule)}</p><p>${esc(r.original)} → ${r.units.join(' ')}</p>`;
  html += `<h3>Letras</h3><ul>`;
  for (const l of state.letters) {
    if (l.twin) { html += `<li><b>${l.ch}</b>: no se dibuja; es ${l.twin.by} con ${l.twin.how} (Frater U∴D∴, M como W invertida).</li>`; continue; }
    const u = l.user, edits = [u.drot && `giro ${u.drot}°`, u.fx && 'reflejo H', u.fy && 'reflejo V', u.ds !== 1 && `escala ×${u.ds.toFixed(2)}`, (u.dx || u.dy) && 'movida'].filter(Boolean);
    html += `<li><b>${l.ch}</b>: ${Math.round(l.legible * 100)}% visible` + (l.shares.length ? `; comparte trazos con ${l.shares.join(', ')}` : '; sin trazos compartidos') + (edits.length ? `; ${edits.join(', ')}` : '') + '.</li>';
  }
  html += '</ul>';
  const shared = state.prims.filter(p => p.units.length > 1).length, struct = state.prims.filter(p => !p.units.length).length;
  html += `<h3>Trazos</h3><p>${state.prims.length} trazos: ${shared} compartidos entre letras` + (struct ? `, ${struct} de la cruz (composición)` : '') + `, ${state.prims.filter(p => p.hidden).length} ocultos por decisión tuya.</p>`;
  html += `<h3>Composición: ${m.label}</h3><p>${m.help} ${badge(m.tag)}</p><h3>Cómo trazarlo a mano</h3><ol>${m.hand.map(s => `<li>${s}</li>`).join('')}</ol>`;
  if (state.decisions.length) html += `<h3>Decisiones tuyas</h3><p>${state.decisions.map(d => d.type + (d.ch ? ' ' + d.ch : '')).join(' · ')}</p>`;
  html += '<h3>Fuentes</h3><ul>' +
    `<li>Austin Osman Spare, <i title="Título original: The Book of Pleasure">El libro del placer</i> (1913): el sigilo nace de fundir letras. ${badge('OM')}</li>` +
    `<li>Frater U∴D∴, <i title="Título original: Practical Sigil Magic">Magia práctica de sigilos</i>, cap. 2, método de la palabra: se tachan las letras repetidas y las que quedan se funden y estilizan, ${cita('tan simple como sea posible, con las distintas letras reconocibles (aunque cueste un poco)', 'as simple as possible with the various letters recognizable (even with slight difficulty)')}. ${badge('OM')}</li>` +
    `<li>Phillip Cooper, <i>Magia básica de sigilos</i>: iniciales únicas, superposición y borde opcional. ${badge('OM')}</li>` +
    `<li>Monograma KAROLVS de Carlomagno (desde 769): consonantes en la cruz y vocales en el centro. Es el modelo de la composición en cruz. ${badge('HP')}</li></ul>` +
    '<p class="note">Títulos y citas traducidos del inglés: pasa el ratón por encima para ver el original. La procedencia nunca se exporta al SVG.</p>';
  body.innerHTML = html;
  $('provModal').classList.add('open');
}

// ── Galeria (localStorage, solo comodidad local) ────────────────
const STORAGE_KEY = 'arcanum_sigils_v3';
function readGallery() { try { const d = JSON.parse(localStorage.getItem(STORAGE_KEY) || '[]'); return Array.isArray(d) ? d : []; } catch { return []; } }
function writeGallery(items) { try { localStorage.setItem(STORAGE_KEY, JSON.stringify(items)); return true; } catch { showToast('No se pudo guardar'); return false; } }
function captureState() {
  return JSON.parse(JSON.stringify({
    intention: state.intention, method: state.method, mode: state.mode, overlap: state.overlap, absorb: state.absorb,
    users: Object.fromEntries(state.letters.map(l => [l.ch, l.user])), hidden: state.hidden, decisions: state.decisions,
    theme: state.theme, style: state.style, terminals: state.terminals, layers: state.layers,
    termScale: state.termScale, endStyles: state.endStyles,
  }));
}
function restoreState(s) {
  Object.assign(state, { method: s.method, mode: s.mode, overlap: s.overlap, absorb: s.absorb, terminals: s.terminals, termScale: s.termScale || 100, endStyles: { ...(s.endStyles || {}) } });
  // guardados antiguos: construccion = pergamino liso, presentacion = oro y negro
  applyStyle(s.style || presetStyle(s.theme === 'present' ? 'oro' : 'papel'), true);
  // capas (o, si es un guardado antiguo, su borde, estrella, inscripcion y estampas)
  state.layers = s.layers ? JSON.parse(JSON.stringify(s.layers)) : legacyLayers(s);
  layerSeq = Math.max(layerSeq, ...state.layers.map(L => Number(String(L.id).replace(/\D/g, '')) || 0));
  state.layerSel.letters = null;
  renderLayerPanel('letters');
  $('intention').value = s.intention;
  state.intention = '';
  syncControls();
  if (!s.intention) {
    Object.assign(state, { reduction: null, letters: [], extra: [], prims: [], hidden: [], decisions: [], sel: null });
    $('reductionBox').textContent = '—';
    render();
    return;
  }
  generate();
  state.letters.forEach(l => { if (s.users[l.ch]) l.user = s.users[l.ch]; });
  state.hidden = [...s.hidden]; state.decisions = [...s.decisions];
  state.endStyles = { ...(s.endStyles || {}) };
  rebuild();
}
const svgURL = svg => 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(svg);
const CALLI_NAMES = { curva: 'Curva', pluma: 'Pluma' };
const FAMILY_NAMES = { letters: 'Letras', rosa: 'Rosa-Cruz', kamea: 'Kamea', personal: 'Sello', compare: 'Comparar' };
function galleryLabel() {
  const f = state.family;
  if (f === 'letters') return state.letters.map(l => l.ch).join('');
  if (f === 'rosa') return state.rosa.name || state.rosa.hebrew;
  if (f === 'kamea') return `${KAMEA_BY_ID[state.kamea.planet].name} · ${state.kamea.hebrew}`;
  if (f === 'personal') return personalName();
  return state.compare.name;
}
function saveSigil() {
  // la consulta de sellos historicos no es obra del usuario: no se guarda
  if (state.family === 'seal' || !exportReady()) { showToast(state.family === 'seal' ? 'Los sellos históricos se consultan, no se guardan' : 'Forja primero un sigilo'); return; }
  const now = new Date(), f = state.family;
  const items = readGallery();
  items.unshift({
    id: 'sigil-' + now.getTime(), family: f,
    name: now.toLocaleDateString('es-CO') + ' · ' + FAMILY_NAMES[f] + ' · ' + galleryLabel() + (f === 'letters' && CALLI_NAMES[state.style.calli] ? ' · ' + CALLI_NAMES[state.style.calli] : ''),
    thumb: f === 'letters' ? snapshot(120).toDataURL('image/png') : svgURL(buildSVG()),
    state: captureState(), doc: docSnapshot()
  });
  if (writeGallery(items)) { renderGallery(); showToast('Guardado en la galería'); }
}
function renderGallery() {
  const grid = $('galleryGrid');
  grid.innerHTML = '';
  const items = readGallery();
  if (!items.length) { grid.innerHTML = '<div class="helper">Aún no hay sigilos guardados.</div>'; return; }
  for (const it of items) {
    const card = document.createElement('div'); card.className = 'g-item';
    const img = document.createElement('img'); img.src = it.thumb; img.alt = it.name;
    img.addEventListener('click', () => { setFamily(it.family || 'letters'); if (it.doc) docRestore(it.doc); else restoreState(it.state); toggleGallery(false); });
    const name = document.createElement('div'); name.textContent = it.name;
    const del = document.createElement('button'); del.textContent = 'X'; del.title = 'Eliminar';
    del.addEventListener('click', () => { writeGallery(readGallery().filter(x => x.id !== it.id)); renderGallery(); });
    card.append(img, name, del); grid.append(card);
  }
}
function toggleGallery(force) {
  const p = $('galleryPanel'), open = typeof force === 'boolean' ? force : !p.classList.contains('open');
  p.classList.toggle('open', open); p.setAttribute('aria-hidden', String(!open));
  if (open) renderGallery();
}

// ── Carga (gnosis de bajo riesgo) ───────────────────────────────
let gnosisTimer = null;
function setGnosisTime(s) { $('gnosisTimer').textContent = String(Math.floor(s / 60)).padStart(2, '0') + ':' + String(Math.ceil(s % 60)).padStart(2, '0'); }
function stopGnosis() { clearInterval(gnosisTimer); gnosisTimer = null; $('gnosisOverlay').classList.remove('running'); $('btnStartCharge').disabled = false; }
function openGnosis() {
  if (state.family === 'seal' || !exportReady()) { showToast('Forja primero un sigilo'); return; }
  stopGnosis();
  $('gnosisSigil').src = state.family === 'letters' ? snapshot(600, 'present', true).toDataURL('image/png') : svgURL(buildSVG());
  setGnosisTime(Number($('gnosisDuration').value));
  $('btnForget').classList.remove('ready');
  $('gnosisOverlay').classList.add('open');
}
function closeGnosis() { stopGnosis(); $('gnosisOverlay').classList.remove('open'); }
function startGnosis() {
  const dur = Number($('gnosisDuration').value), end = performance.now() + dur * 1000;
  $('gnosisOverlay').classList.add('running'); $('btnStartCharge').disabled = true;
  const tick = () => {
    const left = Math.max(0, (end - performance.now()) / 1000);
    setGnosisTime(left);
    $('breathLabel').textContent = ['Inhala', 'Sostén', 'Exhala', 'Sostén'][Math.floor(((dur - left) % 16) / 4)];
    if (left <= 0) { stopGnosis(); $('btnForget').classList.add('ready'); }
  };
  tick(); gnosisTimer = setInterval(tick, 200);
}
function forgetSigil() {
  closeGnosis();
  Object.assign(state, { intention: '', reduction: null, letters: [], extra: [], prims: [], hidden: [], decisions: [], sel: null });
  state.layers = state.layers.filter(L => L.type !== 'symbol'); renderLayerPanel('letters');
  $('intention').value = ''; $('reductionBox').textContent = '—';
  render();
  showToast('Soltado. No lo busques.');
}

// ── Exportar ────────────────────────────────────────────────────
function download(blob, name) { const a = document.createElement('a'); a.href = URL.createObjectURL(blob); a.download = name; a.click(); }
const exportReady = () => state.family === 'rosa' ? state.rosa.trace.length : state.family === 'kamea' ? state.kamea.words.length : state.family === 'seal' ? !!SEAL_BY_ID[state.seal.id] : state.family === 'personal' ? personalReady(state.personal.source) : state.family === 'compare' ? compareReady() : state.prims.length;
const exportName = () => state.family === 'rosa' ? 'rosa-cruz' : state.family === 'kamea' ? `kamea-${state.kamea.planet}` : state.family === 'seal' ? `sello-${state.seal.id}` : state.family === 'personal' ? 'sello-personal' : state.family === 'compare' ? 'comparar' : 'sigilo';
function exportSVG() {
  if (!exportReady()) { showToast('Forja primero un sigilo'); return; }
  download(new Blob([buildSVG()], { type: 'image/svg+xml' }), exportName() + '.svg');
}
function exportPNG() {
  if (!exportReady()) { showToast('Forja primero un sigilo'); return; }
  if (state.family === 'letters') { snapshot(SIZE, state.theme, state.transparent).toBlob(b => download(b, 'sigilo.png')); return; }
  // el resto de familias: se rasteriza su SVG
  const img = new Image(), c = document.createElement('canvas');
  c.width = c.height = SIZE;
  img.onload = () => { c.getContext('2d').drawImage(img, 0, 0); c.toBlob(b => download(b, exportName() + '.png')); };
  img.src = 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(buildSVG());
}

// ── Historial: deshacer y rehacer ───────────────────────────────
// Se fotografia el documento (lo que decide el usuario, no lo derivado)
// cuando la pantalla queda quieta un instante: cualquier cambio entra en
// el historial sin tocar cada boton. Arrastrar cuenta como un solo paso.
const HIST_MAX = 100;
const hist = { past: [], future: [], timer: null, restoring: false };
function docSnapshot() {
  const p = state.personal, ro = state.rosa, km = state.kamea;
  return JSON.stringify({
    letters: captureState(),
    personal: { source: p.source, template: p.template, layers: p.layers, name: p.name, planet: p.planet, view: p.view },
    rosa: { name: ro.name, method: ro.method, hebrew: ro.hebrew, tokens: ro.tokens, tokensFor: ro.tokensFor, colors: ro.colors, diagram: ro.diagram, endBar: ro.endBar },
    kamea: { planet: km.planet, reduce: km.reduce, ends: km.ends, grid: km.grid, hebrew: km.hebrew, name: $('kameaName').value },
    style: state.style || null
  });
}
function docRestore(json) {
  const d = JSON.parse(json);
  hist.restoring = true;
  try {
    const bump = list => { layerSeq = Math.max(layerSeq, ...list.map(L => Number(String(L.id).replace(/\D/g, '')) || 0)); };
    Object.assign(state.personal, JSON.parse(JSON.stringify(d.personal)));
    bump(state.personal.layers);
    state.layerSel.personal = null;
    $('personalName').value = d.personal.name; $('selPersonalSource').value = d.personal.source;
    $('selPersonalPlanet').value = d.personal.planet; $('selPersonalView').value = d.personal.view;
    renderLayerPanel('personal');
    Object.assign(state.rosa, JSON.parse(JSON.stringify(d.rosa)));
    $('rosaName').value = d.rosa.name; $('rosaHebrew').value = d.rosa.hebrew; $('selTranslit').value = d.rosa.method;
    $('chkRosaColors').checked = d.rosa.colors; $('chkRosaDiagram').checked = d.rosa.diagram; $('chkRosaEndBar').checked = d.rosa.endBar;
    rosaTraceFromHebrew();
    Object.assign(state.kamea, { planet: d.kamea.planet, reduce: d.kamea.reduce, ends: d.kamea.ends, grid: d.kamea.grid });
    $('selKameaPlanet').value = d.kamea.planet; $('selKameaReduce').value = d.kamea.reduce; $('selKameaEnds').value = d.kamea.ends; $('chkKameaGrid').checked = d.kamea.grid;
    $('kameaHebrew').value = d.kamea.hebrew; $('kameaName').value = d.kamea.name || '';
    renderKameaPresets(); kameaTraceFromHebrew();
    if (d.style && typeof applyStyle === 'function') applyStyle(d.style, true);
    restoreState(d.letters);
    if (state.family === 'personal') renderPersonalInfo();
  } finally { hist.restoring = false; }
  render();
}
function histSchedule() {
  if (hist.restoring) return;
  clearTimeout(hist.timer);
  hist.timer = setTimeout(histCommit, 400);
}
function histCommit() {
  clearTimeout(hist.timer);
  if (hist.restoring || state.dragging || layerDrag) return;
  const snap = docSnapshot();
  if (hist.past[hist.past.length - 1] === snap) return;
  hist.past.push(snap);
  if (hist.past.length > HIST_MAX) hist.past.shift();
  hist.future = [];
  syncHistButtons();
}
function undo() {
  histCommit();
  if (hist.past.length < 2) { showToast('Nada que deshacer'); return; }
  hist.future.push(hist.past.pop());
  docRestore(hist.past[hist.past.length - 1]);
  syncHistButtons();
}
function redo() {
  if (!hist.future.length) { showToast('Nada que rehacer'); return; }
  const snap = hist.future.pop();
  hist.past.push(snap);
  docRestore(snap);
  syncHistButtons();
}
function syncHistButtons() {
  $('btnUndo').disabled = hist.past.length < 2;
  $('btnRedo').disabled = !hist.future.length;
}

// ── UI ──────────────────────────────────────────────────────────
function setFamily(f) {
  state.family = f;
  $('famLetters').classList.toggle('active', f === 'letters');
  $('famRosa').classList.toggle('active', f === 'rosa');
  $('famKamea').classList.toggle('active', f === 'kamea');
  $('famSeal').classList.toggle('active', f === 'seal');
  $('famPersonal').classList.toggle('active', f === 'personal');
  $('famCompare').classList.toggle('active', f === 'compare');
  $('comparePanel').hidden = f !== 'compare';
  $('stylePanel').hidden = f === 'personal' || f === 'compare';
  $('btnGrid').hidden = $('btnFab').hidden = f !== 'letters' && f !== 'personal';
  $('famCurrent').textContent = FAMILY_TITLES[f] + ' ▾';
  openFab(false); $('quickSymbols').hidden = true;
  setTab(ui.tab, false);
  closePalettes();
  $('personalPanel').hidden = f !== 'personal';
  if (f === 'personal') { $('selPersonalPlanet').disabled = state.personal.source === 'kamea'; renderPersonalInfo(); }
  $('sealPanel').hidden = f !== 'seal';
  if (f === 'seal' && !$('sealGrid').children.length) { renderSealFilters(); renderSealGrid(); selectSeal(state.seal.id); }
  updateSealView();
  $('lettersPanel').hidden = f !== 'letters';
  $('rosaPanel').hidden = f !== 'rosa';
  $('kameaPanel').hidden = f !== 'kamea';
  if (f === 'kamea' && !state.kamea.words.length) { renderKameaPresets(); kameaTraceFromHebrew(); }
  if (f === 'rosa' && $('rosaName').value.trim() && !state.rosa.trace.length) rosaGenerate();
  render();
}
function syncControls() {
  $('selReduction').value = state.method;
  $('chkAbsorb').checked = state.absorb;
  document.querySelectorAll('.mode-btn').forEach(b => b.classList.toggle('active', b.dataset.mode === state.mode));
  $('modeHelp').textContent = MODES[state.mode].help;
  $('overlapRow').style.display = state.mode === 'block' ? 'flex' : 'none';
  $('compactRow').style.display = state.mode === 'fusion' ? 'flex' : 'none';
  $('chkCompact').checked = state.compact;
  $('rngOverlap').value = Math.round(state.overlap * 100); $('overlapVal').textContent = Math.round(state.overlap * 100) + '%';
  // en uno a uno se resalta el pincel; si no, el remate general
  const termOn = state.termPick ? state.termBrush : state.terminals;
  document.querySelectorAll('.term-btn').forEach(b => b.classList.toggle('active', b.dataset.t === termOn));
  $('btnTermPalette').textContent = (state.termPick ? 'Pincel: ' : 'Remate: ') + TERMINALS.find(t => t.id === termOn).name + ' ▾';
  $('btnTermPick').classList.toggle('on', state.termPick);
  $('rngTermScale').value = state.termScale; $('termScaleVal').textContent = state.termScale + '%';
  $('chkColors').checked = state.colors; $('chkTransparent').checked = state.transparent;
  $('btnHideMode').classList.toggle('on', state.hideMode);
  document.querySelectorAll('[id^=btnAddLayer_]').forEach(b => { b.textContent = state.stampMode ? `Toca el lienzo: ${state.stampSym}` : '+ Añadir ▾'; });
  document.querySelectorAll('.stamp-btn').forEach(b => b.classList.toggle('active', b.dataset.s === state.stampSym));
}
const regenerate = () => { if (state.reduction) { applyLayout(); renderReduction(); } };

$('btnGenerate').addEventListener('click', generate);
$('selReduction').addEventListener('change', e => { state.method = e.target.value; if ($('intention').value.trim()) { state.intention = ''; generate(); } });
$('chkAbsorb').addEventListener('change', e => { state.absorb = e.target.checked; regenerate(); });
$('chkCompact').addEventListener('change', e => { state.compact = e.target.checked; regenerate(); });
document.querySelectorAll('.mode-btn').forEach(b => b.addEventListener('click', () => {
  state.mode = b.dataset.mode;
  state.letters.forEach(l => { l.user = newUser(); });
  state.hidden = [];
  syncControls(); regenerate();
}));
$('rngOverlap').addEventListener('input', e => { state.overlap = Number(e.target.value) / 100; syncControls(); regenerate(); });
$('btnRotL').addEventListener('click', () => editSelected(u => { u.drot -= 15; }, 'girar'));
$('btnRotR').addEventListener('click', () => editSelected(u => { u.drot += 15; }, 'girar'));
$('btnFlipH').addEventListener('click', () => editSelected(u => { u.fx = !u.fx; }, 'reflejar'));
$('btnFlipV').addEventListener('click', () => editSelected(u => { u.fy = !u.fy; }, 'reflejar'));
$('btnSmaller').addEventListener('click', () => editSelected(u => { u.ds = Math.max(.4, u.ds / 1.15); }, 'escalar'));
$('btnBigger').addEventListener('click', () => editSelected(u => { u.ds = Math.min(2, u.ds * 1.15); }, 'escalar'));
$('btnLetterReset').addEventListener('click', () => editSelected(u => Object.assign(u, newUser()), 'restaurar'));
$('btnHideMode').addEventListener('click', () => { state.hideMode = !state.hideMode; state.stampMode = false; state.termPick = false; syncControls(); render(); showToast(state.hideMode ? 'Toca un trazo para ocultarlo o recuperarlo' : 'Modo ocultar desactivado'); });
// Terminales: cada boton muestra su remate dibujado con la misma geometria
for (const t of TERMINALS) {
  const b = document.createElement('button');
  b.className = 'term-btn'; b.dataset.t = t.id; b.title = t.name + (t.tag ? ' · ' + tagText(t.tag) : '');
  const shapes = terminalShapes({ x: 8, y: 20 }, { x: 1, y: 0 }, t.id, 7.5)
    .map(sh => sh.fill ? `<path d="${sh.d}" fill="currentColor"/>` : `<path d="${sh.d}" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"/>`).join('');
  b.innerHTML = `<svg viewBox="0 0 40 40" style="color:var(--gold)"><path d="M 1 20 L 8 20" stroke="currentColor" stroke-width="3" stroke-linecap="round"/>${shapes}</svg><span>${t.name}</span>`;
  b.addEventListener('click', () => {
    if (state.termPick) { state.termBrush = t.id; showToast(t.name + ': toca las puntas'); }
    else state.terminals = t.id;
    closePalettes(); syncControls(); render();
  });
  $('termGrid').append(b);
}
$('rngTermScale').addEventListener('input', e => { state.termScale = Number(e.target.value); syncControls(); render(); });
$('btnTermPick').addEventListener('click', () => {
  state.termPick = !state.termPick; state.stampMode = false; state.hideMode = false;
  if (state.termPick && state.termBrush === 'none') state.termBrush = 'pattee';
  syncControls(); render();
  showToast(state.termPick ? 'Elige un remate y toca las puntas marcadas' : 'Uno a uno desactivado');
});
$('btnTermClear').addEventListener('click', () => { state.terminals = 'none'; state.endStyles = {}; syncControls(); render(); });
$('chkColors').addEventListener('change', e => { state.colors = e.target.checked; render(); });
$('chkTransparent').addEventListener('change', e => { state.transparent = e.target.checked; });
$('btnCharge').addEventListener('click', openGnosis);
$('btnStartCharge').addEventListener('click', startGnosis);
$('btnForget').addEventListener('click', forgetSigil);
$('btnGnosisClose').addEventListener('click', closeGnosis);
$('gnosisDuration').addEventListener('change', e => setGnosisTime(Number(e.target.value)));
$('btnSave').addEventListener('click', saveSigil);
$('btnGallery').addEventListener('click', () => toggleGallery());
$('btnUndo').addEventListener('click', undo);
$('btnRedo').addEventListener('click', redo);
$('btnGalleryClose').addEventListener('click', () => toggleGallery(false));
$('btnProvenance').addEventListener('click', showProvenance);
$('btnProvClose').addEventListener('click', () => $('provModal').classList.remove('open'));
$('btnSVG').addEventListener('click', exportSVG);
$('btnPNG').addEventListener('click', exportPNG);
$('famLetters').addEventListener('click', () => setFamily('letters'));
$('famRosa').addEventListener('click', () => setFamily('rosa'));
$('famKamea').addEventListener('click', () => setFamily('kamea'));
$('famSeal').addEventListener('click', () => setFamily('seal'));
$('famPersonal').addEventListener('click', () => setFamily('personal'));
$('famCompare').addEventListener('click', () => setFamily('compare'));
KAMEAS.forEach(k => { const o = document.createElement('option'); o.value = k.id; o.textContent = `${k.sym}\uFE0E ${k.name}`; $('selComparePlanet').append(o); });
$('selComparePlanet').options[0].textContent = `Regente de hoy (${KAMEA_BY_ID[DAY_RULER[state.personal.day]].name})`;
$('btnCompare').addEventListener('click', compareGenerate);
$('compareName').addEventListener('keydown', e => { if (e.key === 'Enter') compareGenerate(); });
// Sello personal
KAMEAS.forEach(k => { const o = document.createElement('option'); o.value = k.id; o.textContent = `${k.sym}\uFE0E ${k.name} (${PLANET_METAL[k.id]})`; $('selPersonalPlanet').append(o); });
$('selPersonalPlanet').options[0].textContent = `Regente de hoy (${KAMEA_BY_ID[DAY_RULER[state.personal.day]].name})`;
['selPersonalSource', 'selPersonalPlanet', 'selPersonalView'].forEach(id => $(id).addEventListener('change', personalRefresh));
$('personalName').addEventListener('input', personalRefresh);
// Sello historico
$('selSealCollection').addEventListener('change', e => setSealCollection(e.target.value));
$('selSealView').addEventListener('change', e => { state.seal.view = e.target.value; updateSealView(); });
$('btnSealKamea').addEventListener('click', sealToKamea);
// Kamea
KAMEAS.forEach(k => { const o = document.createElement('option'); o.value = k.id; o.textContent = `${k.sym}\uFE0E ${k.name} (${k.rows.length}×${k.rows.length})`; $('selKameaPlanet').append(o); });
$('selKameaPlanet').addEventListener('change', e => { state.kamea.planet = e.target.value; renderKameaPresets(); kameaTraceFromHebrew(); });
$('btnKameaGenerate').addEventListener('click', kameaGenerate);
$('kameaName').addEventListener('keydown', e => { if (e.key === 'Enter') kameaGenerate(); });
$('kameaHebrew').addEventListener('input', kameaTraceFromHebrew);
$('selKameaReduce').addEventListener('change', e => { state.kamea.reduce = e.target.value; kameaTraceFromHebrew(); });
$('selKameaEnds').addEventListener('change', e => { state.kamea.ends = e.target.value; render(); });
$('chkKameaGrid').addEventListener('change', e => { state.kamea.grid = e.target.checked; render(); });
document.querySelectorAll('.fam-btn.locked').forEach(b => b.addEventListener('click', () => showToast('Sello histórico: catálogo con fuente, en preparación')));
$('btnRosaGenerate').addEventListener('click', rosaGenerate);
$('chkRosaDiagram').addEventListener('change', e => { state.rosa.diagram = e.target.checked; render(); });
$('chkRosaEndBar').addEventListener('change', e => { state.rosa.endBar = e.target.checked; render(); });
$('chkRosaColors').addEventListener('change', e => { state.rosa.colors = e.target.checked; rosaTraceFromHebrew(); });
$('rosaHebrew').addEventListener('input', rosaTraceFromHebrew);
$('selTranslit').addEventListener('change', () => { if ($('rosaName').value.trim()) rosaGenerate(); });
$('rosaName').addEventListener('keydown', e => { if (e.key === 'Enter') rosaGenerate(); });
window.addEventListener('resize', () => { syncCtxBar(); if (!isMobile()) setSheet('half'); });
document.addEventListener('keydown', e => {
  if ((e.ctrlKey || e.metaKey) && e.key === 'Enter') generate();
  const typing = ['TEXTAREA', 'INPUT', 'SELECT'].includes(document.activeElement.tagName);
  if ((e.ctrlKey || e.metaKey) && !typing && (e.key === 'z' || e.key === 'Z')) { e.preventDefault(); if (e.shiftKey) redo(); else undo(); return; }
  if ((e.ctrlKey || e.metaKey) && !typing && (e.key === 'y' || e.key === 'Y')) { e.preventDefault(); redo(); return; }
  if ((e.key === 'Delete' || e.key === 'Backspace') && !typing && state.layerSel[scopeNow()]) removeLayer(scopeNow(), state.layerSel[scopeNow()]);
  if (e.key === 'Escape') { openMenu(false); openFab(false); $('quickSymbols').hidden = true; }
  if (e.key === 'Escape') { closeGnosis(); toggleGallery(false); $('provModal').classList.remove('open'); state.hideMode = false; state.stampMode = false; state.termPick = false; syncControls(); render(); }
});

// Marco ritual
const refit = () => { if (state.prims.length) state.view = fitView(); render(); };
const bindRange = (id, obj, key) => $(id).addEventListener('input', e => { obj[key] = Number(e.target.value); syncControls(); render(); });
// Barra contextual de capas y simbolos
$('btnLayerSmaller').addEventListener('click', () => editLayer(L => {
  if (L.type === 'symbol') L.size = Math.max(18, Math.round(L.size / 1.2));
  else if (isNested(L)) L.scale = Math.max(40, L.scale - 10);
  else L.size = Math.max(12, L.size - 3);
}));
$('btnLayerBigger').addEventListener('click', () => editLayer(L => {
  if (L.type === 'symbol') L.size = Math.min(160, Math.round(L.size * 1.2));
  else if (isNested(L)) L.scale = Math.min(160, L.scale + 10);
  else L.size = Math.min(40, L.size + 3);
}));
$('btnLayerRotL').addEventListener('click', () => editLayer(L => { L.rot = (L.rot + 345) % 360; }));
$('btnLayerRotR').addEventListener('click', () => editLayer(L => { L.rot = (L.rot + 15) % 360; }));
$('btnLayerDelete').addEventListener('click', () => { const sc = scopeNow(); if (state.layerSel[sc]) removeLayer(sc, state.layerSel[sc]); });
$('btnClearStamps').addEventListener('click', () => { state.layers = state.layers.filter(L => L.type !== 'symbol'); state.layerSel.letters = null; state.stampMode = false; syncControls(); layersChanged('letters'); });
$('btnGrid').addEventListener('click', () => { state.grid = { none: 'polar', polar: 'square', square: 'none' }[state.grid]; syncLayerTools(); render(); });
// Nivel: basico por defecto; avanzado muestra los ajustes finos
function setLevel(adv) {
  document.body.classList.toggle('adv', adv);
  $('btnBasic').classList.toggle('active', !adv); $('btnAdvanced').classList.toggle('active', adv);
  try { localStorage.setItem('arcanum_taller_nivel', adv ? 'adv' : 'basic'); } catch { /* sin almacenamiento: solo esta sesion */ }
}
$('btnBasic').addEventListener('click', () => setLevel(false));
$('btnAdvanced').addEventListener('click', () => setLevel(true));
// Ayuda: cada paso con texto de ayuda lleva su boton i
document.querySelectorAll('.step').forEach(step => {
  if (!step.querySelector('p.helper')) return;
  const b = document.createElement('button');
  b.className = 'info-btn'; b.textContent = 'i'; b.title = 'Ayuda'; b.setAttribute('aria-label', 'Ayuda');
  b.addEventListener('click', e => { e.preventDefault(); e.stopPropagation(); const on = step.classList.toggle('help-on'); b.classList.toggle('on', on); if (on) step.open = true; });
  step.querySelector('summary').append(b);
});

let toastTimer;
function showToast(m) { const t = $('toast'); t.textContent = m; t.classList.add('show'); clearTimeout(toastTimer); toastTimer = setTimeout(() => t.classList.remove('show'), 1900); }

initShell();
buildStylePanel();
applyStyle(presetStyle('pergamino'), true);
state.personal.layers = LAYER_PRESETS.goetia.make('personal');
mountLayerPanel('letters', $('layersHost_letters'));
mountLayerPanel('personal', $('layersHost_personal'));
syncLayerTools();
syncControls();
setLevel((() => { try { return localStorage.getItem('arcanum_taller_nivel') === 'adv'; } catch { return false; } })());
$('intention').value = 'Mi práctica mantiene enfoque sereno';
generate();
histCommit();
