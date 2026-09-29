'use strict';
// ════════════════════════════════════════════════════════════════
//  Interfaz del taller: pensada para movil primero
//  - Escritorio: riel de pestañas a la izquierda y cajon con su contenido.
//  - Movil (<= 820 px): barra de pestañas abajo y el cajon como hoja que
//    se desliza desde abajo (cerrada, media, completa).
//  - Menu de hamburguesa: motor (familia) y nivel de detalle.
//  - Radiales: acciones del elemento tocado alrededor de el, y el boton +
//    del lienzo con los añadidos rapidos.
//  Solo declara funciones: initShell() lo llama el script principal.
// ════════════════════════════════════════════════════════════════
const ui = { tab: 'crear', sheet: 'half', tap: null, tapFor: null };
const isMobile = () => window.matchMedia('(max-width: 820px)').matches;

// ── Iconos propios (no dependen de la fuente del movil) ─────────
const ICON_PATHS = {
  rotL: 'M4.5 12a7.5 7.5 0 1 0 2.2-5.3 M4 4v5h5',
  rotR: 'M19.5 12a7.5 7.5 0 1 1-2.2-5.3 M20 4v5h-5',
  flipH: 'M12 3v18 M9 7 3 12l6 5z M15 7l6 5-6 5z',
  flipV: 'M3 12h18 M7 9l5-6 5 6z M7 15l5 6 5-6z',
  minus: 'M5 12h14',
  plus: 'M12 5v14 M5 12h14',
  reset: 'M4.5 12a7.5 7.5 0 1 0 2.2-5.3 M4 4v5h5 M12 11.2v1.6',
  trash: 'M5 7h14 M10 7V4.5h4V7 M7 7l1 13h8l1-13',
  undo: 'M9 14 4 9l5-5 M4 9h10a6 6 0 0 1 0 12h-3',
  redo: 'M15 14l5-5-5-5 M20 9H10a6 6 0 0 0 0 12h3',
  gridNone: 'M4 4h16v16H4z M4 9.3h16 M4 14.6h16 M9.3 4v16 M14.6 4v16',
  gridPolar: 'M12 4a8 8 0 1 0 0.01 0 M12 8a4 4 0 1 0 0.01 0 M12 2v20 M2 12h20',
  gridSquare: 'M3 3h18v18H3z M3 9h18 M3 15h18 M9 3v18 M15 3v18',
  menu: 'M4 7h16 M4 12h16 M4 17h16',
  crear: 'M4 20l4.5-1 11-11-3.5-3.5-11 11z M14 6.5l3.5 3.5',
  capas: 'M12 3 21 8l-9 5-9-5z M3 12l9 5 9-5 M3 16l9 5 9-5',
  estilo: 'M12 3s-7 8-7 12a7 7 0 0 0 14 0c0-4-7-12-7-12z M9 15.5a3 3 0 0 0 3 3',
  guardar: 'M12 3v12 M7 10l5 5 5-5 M4 20h16',
  circle: 'M12 4a8 8 0 1 0 0.01 0',
  square: 'M5 5h14v14H5z',
  ring: 'M12 3a9 9 0 1 0 0.01 0 M12 7a5 5 0 1 0 0.01 0',
  star: 'M12 3l2.6 7.6H21l-5.2 4.3 2 7.1L12 17.6 6.2 22l2-7.1L3 10.6h6.4z',
  text: 'M5 6h14 M12 6v13 M9 19h6'
};
const icon = (name, px = 22) => `<svg viewBox="0 0 24 24" width="${px}" height="${px}" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="${ICON_PATHS[name]}"/></svg>`;

// ── Pestañas y hoja ─────────────────────────────────────────────
const TAB_FAMILIES = { capas: ['letters', 'personal'], estilo: ['letters', 'rosa', 'kamea', 'seal'] };
const tabAvailable = t => !TAB_FAMILIES[t] || TAB_FAMILIES[t].includes(state.family);
function setTab(t, open = true) {
  if (!tabAvailable(t)) t = 'crear';
  ui.tab = t;
  document.querySelectorAll('.tab').forEach(b => {
    const on = b.dataset.tab === t;
    b.classList.toggle('active', on); b.setAttribute('aria-selected', String(on));
    b.hidden = !tabAvailable(b.dataset.tab);
  });
  document.querySelectorAll('.tab-page').forEach(p => { p.hidden = p.id !== 'page_' + t; });
  $('lettersLayersPage').hidden = state.family !== 'letters';
  $('personalLayersPage').hidden = state.family !== 'personal';
  closePalettes();
  if (open && isMobile() && ui.sheet === 'closed') setSheet('half');
  $('controlPanel').scrollTop = 0;
}
function setSheet(st) {
  ui.sheet = st;
  const p = $('controlPanel');
  p.dataset.sheet = st;
  // en movil el lienzo se encoge para no quedar debajo de la hoja
  document.body.dataset.sheet = isMobile() ? st : '';
  if (typeof syncCtxBar === 'function' && state.view) requestAnimationFrame(syncCtxBar);
  p.style.height = '';
}
// arrastrar el asa de la hoja: se suelta en cerrada, media o completa
function bindSheetHandle() {
  const h = $('sheetHandle'), p = $('controlPanel');
  let drag = null;
  h.addEventListener('pointerdown', e => { if (!isMobile()) return; drag = { y: e.clientY, h: p.getBoundingClientRect().height, moved: false }; h.setPointerCapture(e.pointerId); p.style.transition = 'none'; });
  h.addEventListener('pointermove', e => {
    if (!drag) return;
    const nh = Math.max(0, Math.min(window.innerHeight * .88, drag.h + drag.y - e.clientY));
    if (Math.abs(e.clientY - drag.y) > 4) drag.moved = true;
    p.style.height = nh + 'px';
  });
  h.addEventListener('pointerup', () => {
    if (!drag) return;
    const hNow = p.getBoundingClientRect().height, vh = window.innerHeight;
    p.style.transition = '';
    // un toque sin arrastre alterna media y completa
    if (!drag.moved) setSheet(ui.sheet === 'full' ? 'half' : 'full');
    else setSheet(hNow < vh * .2 ? 'closed' : hNow < vh * .64 ? 'half' : 'full');
    drag = null;
  });
}

// ── Menu de hamburguesa ─────────────────────────────────────────
const FAMILY_TITLES = { letters: 'Sigilo de letras', rosa: 'Rosa-Cruz', kamea: 'Kamea', personal: 'Sello personal', compare: 'Comparar', seal: 'Sellos históricos' };
function openMenu(open) {
  const m = $('famMenu'), on = typeof open === 'boolean' ? open : m.hidden;
  m.hidden = !on;
  $('btnMenu').setAttribute('aria-expanded', String(on));
}
// Para ir a un control: abre su pestaña, la hoja o el menu (lo usan la
// ayuda y los tests)
function revealFor(el) {
  if (!el) return;
  if (el.closest('#famMenu')) { openMenu(true); return; }
  const page = el.closest('.tab-page');
  if (page && page.hidden) setTab(page.id.replace('page_', ''));
  if (page && isMobile() && ui.sheet === 'closed') setSheet('half');
  let det = el.closest('details');
  while (det) { det.open = true; det = det.parentElement.closest('details'); }
}

// ── Radial de acciones del elemento tocado ──────────────────────
function syncCtxBar() {
  const bar = $('ctxBar'), t = ctxTarget();
  bar.hidden = !t;
  if (!t) return;
  $('ctxName').innerHTML = t.kind === 'layer' && t.L.type === 'symbol' && hasGlyph(t.L.sym) ? glyphIcon(t.L.sym, 16) + ' ' + esc(STAMP_NAMES[t.L.sym] || '') : esc(t.name);
  $('ctxLetter').hidden = t.kind !== 'letter';
  $('ctxLayer').hidden = t.kind !== 'layer';
  const resizable = t.kind === 'layer' && (t.L.type === 'symbol' || isNested(t.L) || t.L.type === 'inscription');
  $('btnLayerSmaller').hidden = $('btnLayerBigger').hidden = !resizable;
  const btns = [...bar.querySelectorAll('.ctx-group:not([hidden]) .tool:not([hidden])')];
  const n = btns.length, r = n >= 6 ? 68 : 58, B = 48, D = 2 * r + B + 8;
  const wrap = bar.parentElement, W = wrap.clientWidth, H = wrap.clientHeight, k = W / SIZE;
  // centro: donde se toco, si fue este elemento; si no, el centro del elemento
  const key = t.kind === 'letter' ? 'L:' + t.name : t.L.id;
  const c = ui.tap && ui.tapFor === key ? ui.tap : { x: t.x, y: (t.top + t.bottom) / 2 };
  const cx = Math.max(D / 2 + 2, Math.min(W - D / 2 - 2, c.x * k)), cy = Math.max(D / 2 + 2, Math.min(H - D / 2 - 26, c.y * k));
  Object.assign(bar.style, { left: cx - D / 2 + 'px', top: cy - D / 2 + 'px', width: D + 'px', height: D + 'px' });
  btns.forEach((b, i) => {
    const a = (-90 + i * 360 / n) * Math.PI / 180;
    b.style.left = D / 2 + Math.cos(a) * r - B / 2 + 'px';
    b.style.top = D / 2 + Math.sin(a) * r - B / 2 + 'px';
  });
}

// ── Boton + del lienzo: radial de añadidos rapidos ──────────────
const QUICK = [
  ['circle', 'Círculo', () => icon('circle')], ['square', 'Cuadrado', () => icon('square')], ['ringLatin', 'Anillo', () => icon('ring')],
  ['star', 'Estrella', () => icon('star')], ['inscription', 'Inscripción', () => icon('text')], ['symbol', 'Símbolo', () => glyphIcon('♃', 22)]
];
function openFab(open) {
  const r = $('fabRadial'), on = typeof open === 'boolean' ? open : r.hidden;
  r.hidden = !on;
  $('btnFab').setAttribute('aria-expanded', String(on));
  $('btnFab').classList.toggle('on', on);
  if (!on) return;
  // cuarto de circulo desde el boton hacia arriba y a la izquierda
  const items = [...r.querySelectorAll('.fab-item')], R = 190;
  items.forEach((b, i) => {
    const a = (180 + i * 90 / (items.length - 1)) * Math.PI / 180;
    b.style.right = 8 - Math.cos(a) * R + 'px';
    b.style.bottom = 8 - Math.sin(a) * R + 'px';
  });
}
function quickAdd(type) {
  openFab(false);
  const scope = scopeNow();
  if (type === 'symbol') { $('quickSymbols').hidden = false; return; }
  addLayer(scope, type);
}

function initShell() {
  document.querySelectorAll('[data-icon]').forEach(b => { b.insertAdjacentHTML('afterbegin', icon(b.dataset.icon, b.classList.contains('tab') ? 24 : 22)); });
  document.querySelectorAll('.tab').forEach(b => b.addEventListener('click', () => {
    if (isMobile() && b.dataset.tab === ui.tab && ui.sheet !== 'closed') { setSheet('closed'); return; }
    setTab(b.dataset.tab);
  }));
  $('btnMenu').addEventListener('click', e => { e.stopPropagation(); openMenu(); });
  $('famCurrent').addEventListener('click', e => { e.stopPropagation(); openMenu(); });
  document.querySelectorAll('#famMenu .fam-btn').forEach(b => b.addEventListener('click', () => openMenu(false)));
  document.addEventListener('click', e => {
    if (!$('famMenu').hidden && !e.target.closest('#famMenu')) openMenu(false);
    if (!$('fabRadial').hidden && !e.target.closest('#fabRadial, #btnFab')) openFab(false);
    if (!$('quickSymbols').hidden && !e.target.closest('#quickSymbols, #fabRadial')) $('quickSymbols').hidden = true;
  });
  // radial +
  $('fabRadial').innerHTML = QUICK.map(([t, name, ic]) => `<button class="tool fab-item" data-quick="${t}" title="${name}" aria-label="${name}">${ic()}<small>${name}</small></button>`).join('');
  $('btnFab').addEventListener('click', e => { e.stopPropagation(); openFab(); });
  $('fabRadial').querySelectorAll('[data-quick]').forEach(b => b.addEventListener('click', e => { e.stopPropagation(); quickAdd(b.dataset.quick); }));
  $('quickSymbolsGrid').innerHTML = stampCatalogHTML();
  $('quickSymbolsGrid').querySelectorAll('.stamp-btn').forEach(b => b.addEventListener('click', () => {
    $('quickSymbols').hidden = true;
    state.stampSym = b.dataset.s; state.stampMode = true; state.hideMode = false; state.termPick = false;
    syncControls(); showToast(b.title + ': toca el lienzo para colocarlo');
  }));
  $('btnQuickClose').addEventListener('click', () => { $('quickSymbols').hidden = true; });
  bindSheetHandle();
  setSheet(isMobile() ? 'half' : 'half');
  setTab('crear', false);
}
