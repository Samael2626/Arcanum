'use strict';
// Sellos historicos: catalogo de consulta (ira a Materia)
// ── Sello historico: catalogo, no generador ─────────────────────
// Cada pieza se reproduce de su fuente, con edicion, pagina y escaneo. El
// trazo es un calco del escaneo (sellos/*.py): no se dibuja ni se edita.
const SEAL_SOURCES = {
  agrippa1651: {
    name: 'Agrippa · planetas', short: 'Agrippa, Londres, 1651 · libro II, cap. 22',
    work: 'Agrippa, Tres libros de filosofía oculta, libro II, cap. 22',
    edition: 'Londres: R.W. para Gregory Moule, 1651 (primera edición inglesa)',
    scan: 'Wellcome Collection, en Internet Archive (b30335231)',
    license: 'Marca de dominio público de Creative Commons', item: 'b30335231',
    img: s => `sellos/${s.id}.jpg`
  },
  goetia1916: {
    name: 'Goetia · 72 espíritus', short: 'Goetia, ed. Mathers-Crowley 1904 (reimpr. Chicago, 1916)',
    work: 'La Llave menor de Salomón, Goetia (Lemegeton, libro I), traducción de S. L. MacGregor Mathers, edición de Aleister Crowley (1904)',
    edition: 'Reimpresión de L. W. de Laurence, Chicago, 1916, que reproduce la edición de 1904 con su prefacio de 1903',
    scan: 'Harold B. Lee Library (Brigham Young University), en Internet Archive (lesserkeyofsolom00dela)',
    license: 'Dominio público en EE. UU. (edición de 1916). Situación de las figuras en Colombia: NO COMPROBADA', item: 'lesserkeyofsolom00dela',
    img: s => `sellos/goetia/g${String(s.fig).padStart(2, '0')}.jpg`
  }
};
const GOETIA_RANKS = ['Rey', 'Duque', 'Príncipe o prelado', 'Marqués', 'Presidente', 'Conde', 'Caballero'];
const SEALS_DATA = (window.SEALS || []).map(s => ({ ...s, src: 'agrippa1651' }));
const SEAL_BY_ID = Object.fromEntries(SEALS_DATA.map(s => [s.id, s]));
const sealSrc = s => SEAL_SOURCES[s.src];
const scanUrl = s => `https://archive.org/details/${sealSrc(s).item}/page/n${s.leaf}/mode/1up`;
// Nombre de la tabla de Agrippa (p. 243) para los caracteres con nombre
function sealKameaName(s) {
  if (s.src !== 'agrippa1651' || !s.role) return null;
  const k = KAMEA_BY_ID[s.planet];
  return k && k.names.find(n => n[0] === s.role) || null;
}
const sealRef = s => s.src === 'goetia1916' ? `${sealSrc(s).short} · figura ${s.fig}` : `${sealSrc(s).short} · p. ${s.page}`;
function sealFit(s, box = 600, top = 70) {
  const k = Math.min(box / s.w, (box - 40) / s.h);
  return { k, x: C - s.w * k / 2, y: top + (box - 40 - s.h * k) / 2 + 20 };
}
function sealSVG(th) {
  const s = SEAL_BY_ID[state.seal.id];
  if (!s) return '';
  const f = sealFit(s), src = sealSrc(s);
  // obra ajena reproducida: la atribucion viaja con el archivo
  const where = s.src === 'goetia1916' ? `figura ${s.fig} de las láminas` : `p. ${s.page}`;
  const out = [`<title>${esc(s.title)}</title><desc>${esc(`${src.work}. ${src.edition}, ${where}. Calco del escaneo de la ${src.scan}, hoja ${s.leaf}. ${src.license}.`)}</desc>`];
  out.push(`<g data-layer="seal" fill="${th.ink}" transform="translate(${f2(f.x)} ${f2(f.y)}) scale(${f.k.toFixed(5)})">`);
  for (const [d, tx, ty] of s.paths) out.push(`<path transform="translate(${tx} ${ty})" d="${d}"/>`);
  out.push('</g>');
  out.push(`<g data-layer="caption" text-anchor="middle" font-family="Georgia, serif"><text x="${C}" y="52" font-size="24" font-style="italic" fill="${th.ink}">${esc(s.title)}</text><text x="${C}" y="${SIZE - 28}" font-size="14" fill="${th.frame}">${esc(sealRef(s))}</text></g>`);
  return out.join('');
}
function sealThumb(s) {
  return `<svg viewBox="0 0 ${s.w} ${s.h}" aria-hidden="true"><g fill="currentColor">${s.paths.map(([d, tx, ty]) => `<path transform="translate(${tx} ${ty})" d="${d}"/>`).join('')}</g></svg>`;
}
const sealCardLabel = s => s.src === 'goetia1916' ? `${s.spirit} · ${esc(s.name)}${s.second ? ' (2.º)' : ''}` : `${s.sym}︎ ${esc(s.kind === 'sello' ? 'Sello' : s.role || 'Inteligencia de las inteligencias')}`;
function sealVisible() {
  const { collection: c, filter: f } = state.seal;
  return SEALS_DATA.filter(s => s.src === c && (f === 'all' || (c === 'goetia1916' ? s.ranks.includes(f) : s.planet === f)));
}
// La cuadricula se construye una vez por coleccion y filtro; elegir solo
// cambia la marca (80 miniaturas vectoriales por clic serian lentas)
function renderSealGrid() {
  const grid = $('sealGrid');
  grid.innerHTML = '';
  for (const s of sealVisible()) {
    const b = document.createElement('button');
    b.className = 'seal-card'; b.dataset.id = s.id; b.title = s.src === 'goetia1916' ? `${s.title} · figura ${s.fig}` : `${s.title} · p. ${s.page}`;
    b.innerHTML = sealThumb(s) + `<span>${sealCardLabel(s)}</span>`;
    b.addEventListener('click', () => selectSeal(s.id));
    grid.append(b);
  }
  markSealCard();
}
function markSealCard() {
  document.querySelectorAll('.seal-card').forEach(b => b.classList.toggle('active', b.dataset.id === state.seal.id));
}
function renderSealFilters() {
  const box = $('sealFilters'), c = state.seal.collection;
  box.innerHTML = '';
  const opts = c === 'goetia1916' ? [['all', 'Todos'], ...GOETIA_RANKS.map(r => [r, r.split(' ')[0]])] : [['all', 'Todos'], ...KAMEAS.map(k => [k.id, k.sym + '︎'])];
  opts.forEach(([id, label]) => {
    const b = document.createElement('button');
    b.className = 'btn-dim seal-filter' + (id === state.seal.filter ? ' active' : ''); b.dataset.p = id; b.textContent = label;
    b.title = id === 'all' ? 'Todas las piezas' : c === 'goetia1916' ? `Espíritus con rango de ${id.toLowerCase()}` : KAMEA_BY_ID[id].name;
    b.addEventListener('click', () => { state.seal.filter = id; syncSealFilter(); renderSealGrid(); });
    box.append(b);
  });
}
function syncSealFilter() {
  document.querySelectorAll('.seal-filter').forEach(b => b.classList.toggle('active', b.dataset.p === state.seal.filter));
}
function setSealCollection(c) {
  state.seal.collection = c; state.seal.filter = 'all';
  $('selSealCollection').value = c;
  renderSealFilters(); renderSealGrid();
  const first = SEALS_DATA.find(s => s.src === c);
  if (!SEAL_BY_ID[state.seal.id] || SEAL_BY_ID[state.seal.id].src !== c) selectSeal(first.id);
}
function sealInfo(s) {
  const src = sealSrc(s), lines = [];
  lines.push(`<div class="line"><b>Pieza</b><span>${esc(s.title)} ${badge('HP')}</span></div>`);
  if (s.src === 'goetia1916') {
    const twins = SEALS_DATA.filter(x => x.src === s.src && x.spirit === s.spirit);
    lines.push(`<div class="line"><b>Espíritu</b><span>n.º ${s.spirit}, ${esc(s.name)}${s.alt.length ? ` (también ${s.alt.map(esc).join(', ')})` : ''}; descrito en la p. ${s.page}.</span></div>`);
    lines.push(`<div class="line"><b>Rango</b><span>${s.ranks.map((r, i) => `${r}: su sello va en ${s.metals[i]}`).join('; ')}, según la lista clasificada del libro (pp. 47–48).</span></div>`);
    lines.push(`<div class="line"><b>Lámina</b><span>Figura ${s.fig}, hoja ${s.leaf} del escaneo (láminas sin paginar). El nombre grabado en el borde identifica al espíritu.</span></div>`);
    if (twins.length > 1) lines.push(`<div class="line"><b>Doble</b><span>Este espíritu tiene dos sellos: ${twins.map(t => t.id === s.id ? `figura ${t.fig} (este)` : `<a href="#" style="color:var(--gold)" onclick="selectSeal('${t.id}');return false">figura ${t.fig}</a>`).join(' y ')}.</span></div>`);
  } else {
    const kn = sealKameaName(s);
    lines.push(`<div class="line"><b>Grabado</b><span>El rótulo dice ${cita(esc(s.title.replace('Carácter d', 'D').replace('Sello d', 'D')), s.engraved)}.</span></div>`);
    if (kn) lines.push(`<div class="line"><b>Nombre</b><span>${esc(kn[1])} (<bdi lang="he">${kn[2]}</bdi>), según la tabla de nombres de la p. 243; suma ${kn[3]}.</span></div>`);
  }
  lines.push(`<div class="line"><b>Fuente</b><span>${esc(src.work)}. ${esc(src.edition)}${s.src === 'agrippa1651' ? `, <b>p. ${s.page}</b>` : ''}.</span></div>`);
  lines.push(`<div class="line"><b>Escaneo</b><span><a href="${scanUrl(s)}" target="_blank" rel="noopener" style="color:var(--gold)">${esc(src.scan)}, hoja ${s.leaf}</a>. ${esc(src.license)}.</span></div>`);
  lines.push('<div class="line"><b>Trazo</b><span>Calcado del escaneo, no dibujado: la tinta se separa del papel y se vectoriza.</span></div>');
  if (s.note) lines.push(`<div class="line"><b>Nota</b><span>${esc(s.note)}</span></div>`);
  return lines.join('');
}
function selectSeal(id) {
  const s = SEAL_BY_ID[id];
  if (!s) return;
  if (s.src !== state.seal.collection) { state.seal.collection = s.src; state.seal.filter = 'all'; $('selSealCollection').value = s.src; renderSealFilters(); renderSealGrid(); }
  state.seal.id = id;
  if (!document.querySelector(`.seal-card[data-id="${id}"]`)) { state.seal.filter = 'all'; syncSealFilter(); renderSealGrid(); }
  markSealCard();
  $('sealBox').innerHTML = sealInfo(s);
  $('btnSealKamea').hidden = !sealKameaName(s);
  updateSealView();
  render();
}
function updateSealView() {
  const s = SEAL_BY_ID[state.seal.id], fac = state.family === 'seal' && state.seal.view === 'facsimile' && s;
  const img = $('sealFacsimile');
  img.hidden = !fac;
  if (fac) { img.src = sealSrc(s).img(s); img.alt = `Facsímil: ${s.title}, ${sealRef(s)}`; }
}
function sealToKamea() {
  const s = SEAL_BY_ID[state.seal.id], kn = sealKameaName(s);
  if (!kn) return;
  setFamily('kamea');
  state.kamea.planet = s.planet; $('selKameaPlanet').value = s.planet; renderKameaPresets();
  $('kameaName').value = kn[1]; $('kameaHebrew').value = kn[2]; kameaTraceFromHebrew();
}
// Desde la Kamea: el caracter original de Agrippa en el catalogo
function kameaToSeal(planet, role) {
  const s = SEALS_DATA.find(x => x.src === 'agrippa1651' && x.planet === planet && x.role === role);
  if (!s) return;
  setFamily('seal');
  selectSeal(s.id);
}
function sealProvenance() {
  const s = SEAL_BY_ID[state.seal.id];
  if (!s) return '<p>Elige una pieza del catálogo.</p>';
  const src = sealSrc(s);
  let html = `<h3>${esc(s.title)}</h3><p>${esc(src.work)}. ${esc(src.edition)}. ${badge('HP')}</p>` +
    '<h3>Cómo se ha reproducido</h3><ol>' +
    `<li>Escaneo de la ${esc(src.scan)}, hoja ${s.leaf} (${esc(src.license)}).</li>` +
    '<li>Recorte de la pieza a resolución completa.</li>' +
    '<li>Se separa la tinta del papel: se descartan manchas, restos de rótulos o de la rejilla de la lámina y la tinta que se transparenta del reverso.</li>' +
    '<li>La tinta se calca a vectores. No se redibuja ni se corrige nada a mano.</li></ol>';
  if (s.src === 'goetia1916') {
    html += '<h3>Sobre esta edición</h3><ul>' +
      '<li>De Laurence reimprimió en Chicago (1916) la edición de Mathers y Crowley (1904) sin citarla. Se comprueba en el propio escaneo: reproduce el prefacio de Crowley, fechado en 1903 (' + cita('este día de CC. 1903 e.v.', 'this day of CC. 1903 e.v.') + ').</li>' +
      '<li>Las láminas numeran figuras, no espíritus: son 80 figuras para 72 espíritus, porque Paimon, Beleth, Leraje, Bathin, Bune, Vepar, Vual y Seere tienen dos sellos. Cada figura se identifica por el nombre grabado en su borde.</li>' +
      '<li>Nombres, variantes y páginas salen del texto del libro; rangos y metales, de su lista clasificada (pp. 47–48). Los errores del reconocimiento de texto se corrigieron contra el escaneo (por ejemplo, «Shan» es Shax).</li>' +
      '<li>Es un repertorio histórico que se estudia: el taller no genera ni edita sellos de la Goetia ni los mezcla con otros sistemas.</li></ul>';
  } else {
    html += '<h3>Qué es y qué no es</h3><ul>' +
      '<li>Es una reproducción de una pieza impresa, con su página. No se genera ni se edita, y no se mezcla con los motores del taller.</li>' +
      '<li>Los caracteres de inteligencias y espíritus se pueden comparar con su trazado en la Kamea; los sellos de los planetas no salen de un nombre.</li></ul>';
  }
  if (s.note) html += `<p>${esc(s.note)}</p>`;
  return html + `<p class="note"><a href="${scanUrl(s)}" target="_blank" rel="noopener" style="color:var(--gold)">Ver la página en el escaneo</a></p>`;
}
