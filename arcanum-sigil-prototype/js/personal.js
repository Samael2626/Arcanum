'use strict';
// Sello personal y Comparar
// ── Sello personal: tu sigilo en formato de sello historico ─────
// Toma el sigilo de un motor del taller y lo monta con la forma de un
// sello clasico. Es un sello NUEVO: el formato imita modelos reales
// (Goetia 1904, pentaculos de la Clave de Salomon, laminas de Agrippa),
// pero el resultado no es ninguno de ellos y la ficha lo dice [RC].
const PERSONAL_FORMATS = {
  goetia: { label: 'Goetia', model: 'los 72 sellos de la Goetia (ed. 1904): doble anillo con el nombre en letras latinas repartidas por el borde' },
  pentaculo: { label: 'Pentáculo salomónico', model: 'los pentáculos de la Clave de Salomón: banda con el nombre en hebreo entre dos círculos' },
  agrippa: { label: 'Lámina de Agrippa', model: 'los caracteres planetarios de Agrippa (1651): la figura sola, con su rótulo' }
};
// Metales de los siete planetas, como los enumera la Goetia (p. 48)
const PLANET_METAL = { saturn: 'plomo', jupiter: 'estaño', mars: 'hierro', sun: 'oro', venus: 'cobre', mercury: 'mercurio', moon: 'plata' };
const METAL_TONE = { plomo: ['#8d9096', '#5c6066'], estaño: ['#c3c8cc', '#8f969c'], hierro: ['#9a9da0', '#5e6264'], oro: ['#e7c35a', '#a8801f'], cobre: ['#d99365', '#8f4f2a'], mercurio: ['#dfe5ea', '#98a4ad'], plata: ['#e4e6ea', '#a3a8b0'] };
// Regente del dia (orden de los dias de la semana: domingo = Sol)
const DAY_RULER = ['sun', 'moon', 'mars', 'mercury', 'jupiter', 'venus', 'saturn'];
const DAY_NAMES = ['domingo', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado'];
const PERSONAL_SOURCES = { letters: 'Sigilo de letras', rosa: 'Rosa-Cruz', kamea: 'Kamea' };

// Un sigilo de Kamea ya pertenece a un planeta: el sello no puede decir otro
function personalPlanet() {
  const p = state.personal;
  if (p.source === 'kamea') return state.kamea.planet;
  return p.planet === 'auto' ? DAY_RULER[p.day] : p.planet;
}
function personalName() {
  const p = state.personal;
  if (p.name.trim()) return p.name.trim();
  if (p.source === 'letters') return state.intention;
  if (p.source === 'rosa') return state.rosa.name;
  return $('kameaName') ? $('kameaName').value.trim() : '';
}
// Sigilo de un motor como marcado SVG monocromo, sin fondo ni rotulos
function personalSourceMarkup(src) {
  const keep = { family: state.family, diagram: state.rosa.diagram, grid: state.kamea.grid };
  state.family = src; state.rosa.diagram = false; state.kamea.grid = false;
  let svg;
  try { svg = buildSVG(); } finally { state.family = keep.family; state.rosa.diagram = keep.diagram; state.kamea.grid = keep.grid; }
  const doc = new DOMParser().parseFromString(svg, 'image/svg+xml');
  const layers = { letters: ['core', 'terminals'], rosa: ['rose'], kamea: ['kamea'] }[src];
  const ser = new XMLSerializer();
  const parts = [];
  for (const name of layers) {
    const g = doc.querySelector(`g[data-layer="${name}"]`);
    if (!g) continue;
    g.querySelectorAll('linearGradient').forEach(n => n.remove());
    for (const el of [g, ...g.querySelectorAll('*')]) {
      for (const a of ['stroke', 'fill']) {
        const v = el.getAttribute(a);
        if (v && v !== 'none') el.setAttribute(a, 'currentColor');
      }
    }
    parts.push(ser.serializeToString(g).replace(/ xmlns="[^"]*"/g, ''));
  }
  return parts.join('');
}
function personalReady(src) {
  return src === 'letters' ? state.prims.length > 0 : src === 'rosa' ? state.rosa.trace.length > 0 : state.kamea.words.length > 0;
}
// Caja del sigilo medida en el propio navegador
let personalProbe = null;
function measureMarkup(markup) {
  if (!personalProbe) {
    personalProbe = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
    personalProbe.setAttribute('width', SIZE); personalProbe.setAttribute('height', SIZE);
    personalProbe.style.cssText = 'position:absolute;left:-9999px;top:0;visibility:hidden';
    document.body.append(personalProbe);
  }
  personalProbe.innerHTML = `<g>${markup}</g>`;
  const b = personalProbe.firstChild.getBBox();
  return { x: b.x, y: b.y, w: b.width || 1, h: b.height || 1 };
}
function personalSVG() {
  const p = state.personal, src = p.source;
  if (!personalReady(src)) return null;
  const planet = personalPlanet(), metal = PLANET_METAL[planet], k = KAMEA_BY_ID[planet];
  const metalView = p.view === 'metal';
  const ink = metalView ? '#2b2116' : '#1b1612';
  const name = personalName() || 'SIN NOMBRE';
  const lay = layoutLayers(p.layers, layerCtx('personal'));
  const out = [`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${SIZE} ${SIZE}" width="${SIZE}" height="${SIZE}">`];
  out.push(`<title>${esc(`Sello personal de ${name}`)}</title>`);
  out.push(`<desc>${esc(`Sello nuevo creado en ARCANUM ${personalFormatText()}. No es un sello histórico. Sigilo: ${PERSONAL_SOURCES[src]}. Planeta: ${k.name}; metal: ${metal} (tabla de metales de la Goetia, p. 48).`)}</desc>`);
  if (!state.transparent) out.push(`<rect width="${SIZE}" height="${SIZE}" fill="${metalView ? '#1a1612' : '#efe6d2'}"/>`);
  if (metalView) {
    const [light, dark] = METAL_TONE[metal];
    // la placa sigue al marco exterior: disco si es redondo, lamina si no
    const outer = lay.parts.find(q => q.R);
    out.push(`<defs><radialGradient id="metal" cx="38%" cy="32%" r="80%"><stop offset="0" stop-color="${light}"/><stop offset="1" stop-color="${dark}"/></radialGradient></defs>`);
    out.push(outer && ['circle', 'ringLatin', 'ringHebrew'].includes(outer.L.type)
      ? `<circle cx="${f2(outer.g.center[0])}" cy="${f2(outer.g.center[1])}" r="${f2(outer.R + 18)}" fill="url(#metal)"/>`
      : `<rect x="48" y="48" width="704" height="704" rx="18" fill="url(#metal)"/>`);
  }
  out.push(layersSVG(lay.parts, ink, q => q.L.type !== 'symbol').replace(/data-layer="(ringLatin|ringHebrew|caption)"/g, 'data-layer="personal-name"'));
  // el sigilo, encajado en el hueco central
  const markup = personalSourceMarkup(src);
  const b = measureMarkup(markup);
  const s = Math.min((2 * lay.contentR) / Math.hypot(b.w, b.h), 2.2);
  out.push(`<g data-layer="personal-sigil" color="${ink}" transform="translate(${f2(C - (b.x + b.w / 2) * s)} ${f2(C - (b.y + b.h / 2) * s)}) scale(${s.toFixed(4)})">${markup}</g>`);
  out.push(layersSVG(lay.parts, ink, q => q.L.type === 'symbol'));
  out.push('</svg>');
  return out.join('');
}
// Descripcion del formato: la plantilla de partida y las capas que quedan
function personalFormatText() {
  const p = state.personal, f = PERSONAL_FORMATS[p.template];
  const names = p.layers.filter(L => L.visible).map(layerName).join(', ') || 'sin capas';
  return f ? `en formato de ${f.model} (capas: ${names})` : `con capas elegidas por ti (${names})`;
}
// En el lienzo se pinta el mismo SVG (una sola geometria para las dos salidas)
const personalImg = { key: '', img: null };
function paintPersonal(ctx) {
  const svg = personalSVG();
  if (!svg) {
    ctx.fillStyle = '#8a7f72'; ctx.textAlign = 'center'; ctx.font = 'italic 22px Georgia, serif';
    ctx.fillText(`Primero crea un sigilo en «${PERSONAL_SOURCES[state.personal.source]}».`, C, C);
    return;
  }
  if (personalImg.key !== svg) {
    const img = new Image();
    img.onload = () => { personalImg.img = img; render(); };
    img.src = 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(svg);
    personalImg.key = svg;
  }
  // mientras carga la nueva, se ve la anterior: arrastrar no parpadea
  if (personalImg.img && personalImg.img.complete) ctx.drawImage(personalImg.img, 0, 0, SIZE, SIZE);
  const th = THEMES.build;
  if (ctx.canvas === canvas) { paintGrid(ctx, th); paintLayerSelection(ctx, th, 'personal'); paintGuides(ctx, th); }
}
function renderPersonalInfo() {
  const p = state.personal, planet = personalPlanet(), k = KAMEA_BY_ID[planet];
  const ready = personalReady(p.source);
  $('personalBox').innerHTML =
    `<div class="line"><b>Sigilo</b><span>${ready ? `El último que hiciste en ${PERSONAL_SOURCES[p.source]}.` : `Aún no hay sigilo en ${PERSONAL_SOURCES[p.source]}: créalo primero en su pestaña.`}</span></div>` +
    `<div class="line"><b>Formato</b><span>${esc(personalFormatText().replace(/^en formato de /, 'Imita '))}. ${badge('RC')}</span></div>` +
    `<div class="line"><b>Planeta</b><span>${k.sym}\uFE0E ${k.name}${p.source === 'kamea' ? ', el de la tabla sobre la que se trazó el sigilo' : p.planet === 'auto' ? `, regente del ${DAY_NAMES[p.day]} (el día en que lo creas)` : ', elegido por ti'}.</span></div>` +
    `<div class="line"><b>Metal</b><span>${PLANET_METAL[planet]}, según la tabla de metales de los planetas de la Goetia (p. 48). ${badge('HP')}</span></div>` +
    `<div class="line"><b>Qué es</b><span>Un sello nuevo, tuyo, en formato histórico. No es un sello de Salomón ni de Agrippa: esos están en el catálogo de consulta.</span></div>`;
}
function personalRefresh() {
  const p = state.personal;
  p.name = $('personalName').value; p.source = $('selPersonalSource').value;
  p.planet = $('selPersonalPlanet').value; p.view = $('selPersonalView').value;
  $('selPersonalPlanet').disabled = p.source === 'kamea';
  renderPersonalInfo();
  render();
}
function personalProvenance() {
  const p = state.personal;
  return `<h3>Sello personal</h3><p>Sello nuevo creado en el taller a partir de tu sigilo de ${PERSONAL_SOURCES[p.source]}. ${badge('RC')}</p>` +
    '<h3>De dónde sale cada parte</h3><ul>' +
    `<li>La figura central: tu sigilo, tal como lo trazó su motor (con sus propias fuentes, en la procedencia de ese motor).</li>` +
    `<li>El formato: ${esc(personalFormatText())}. Es una reconstrucción del aspecto, no una regla del libro.</li>` +
    `<li>El metal: la Goetia asigna a cada planeta un metal (Saturno plomo, Júpiter estaño, Marte hierro, Sol oro, Venus cobre, Mercurio mercurio, Luna plata; p. 48). ${badge('HP')}</li>` +
    `<li>El planeta por defecto es el regente del día de la semana en que lo creas (domingo Sol, lunes Luna… sábado Saturno). ${badge('HP')}</li></ul>` +
    '<p class="note">El SVG exportado lo declara en su descripción: sello nuevo, no histórico.</p>';
}

// ── Comparar: el mismo nombre en los tres sistemas ──────────────
// Ejercicio 6 de la Guia Maestra: trazar un nombre con letras, Rosa-Cruz
// y Kamea y ver por que son artefactos distintos. Usa los motores tal cual
// (rellena sus pestanas con el nombre) y compone una lamina.
function compareGenerate() {
  const name = $('compareName').value.trim();
  if (!name) { showToast('Escribe un nombre'); return; }
  const c = state.compare;
  c.name = name;
  c.planet = $('selComparePlanet').value === 'auto' ? DAY_RULER[state.personal.day] : $('selComparePlanet').value;
  // letras: el nombre entero, letras unicas, en fusion (el metodo de Spare)
  state.method = 'unique'; state.mode = 'fusion'; state.intention = '';
  $('intention').value = name; generate();
  $('rosaName').value = name; rosaGenerate();
  state.kamea.planet = c.planet; $('selKameaPlanet').value = c.planet; renderKameaPresets();
  $('kameaName').value = name; kameaGenerate();
  syncControls();
  renderCompareInfo();
  render();
}
function compareReady() { return state.prims.length > 0 && state.rosa.trace.length > 0 && state.kamea.words.length > 0; }
// Cada sigilo en su recuadro, con el mismo trazo de tinta
function compareSVG() {
  if (!compareReady()) return null;
  const c = state.compare, ink = '#1b1612', k = KAMEA_BY_ID[c.planet];
  const out = [`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${SIZE} ${SIZE}" width="${SIZE}" height="${SIZE}">`];
  out.push(`<title>${esc(`${c.name} en tres sistemas`)}</title><desc>${esc(`El nombre «${c.name}» trazado con el método de la palabra (letras únicas, fusión), sobre la Rosa-Cruz de la Golden Dawn y sobre la kamea de ${k.name} de Agrippa.`)}</desc>`);
  // mismo grosor de tinta en los tres, se escale como se escale cada uno
  out.push('<style>.cmp *{vector-effect:non-scaling-stroke;stroke-width:4px}</style>');
  if (!state.transparent) out.push(`<rect width="${SIZE}" height="${SIZE}" fill="#efe6d2"/>`);
  const cells = [
    { src: 'letters', x: 20, y: 60, title: 'Letras (Spare)', sub: state.letters.map(l => l.ch).join(' ') },
    { src: 'rosa', x: 410, y: 60, title: 'Rosa-Cruz', sub: state.rosa.hebrew },
    { src: 'kamea', x: 20, y: 440, title: `Kamea de ${k.name}`, sub: state.kamea.words.map(w => w.map(st => st.cell).join('·')).join(' | ') }
  ];
  out.push(`<text x="${C}" y="38" text-anchor="middle" font-family="Georgia, serif" font-style="italic" font-size="26" fill="${ink}">${esc(c.name)}</text>`);
  for (const cell of cells) {
    const markup = personalSourceMarkup(cell.src), b = measureMarkup(markup);
    const box = 262, sc = Math.min(box / b.w, box / b.h, 1.6);
    const cx = cell.x + 185, cy = cell.y + 184;
    out.push(`<g data-layer="compare-${cell.src}">`);
    out.push(`<rect x="${cell.x}" y="${cell.y}" width="370" height="370" rx="6" fill="none" stroke="${ink}" stroke-opacity=".18"/>`);
    out.push(`<g class="cmp" color="${ink}" transform="translate(${f2(cx - (b.x + b.w / 2) * sc)} ${f2(cy - (b.y + b.h / 2) * sc)}) scale(${sc.toFixed(4)})">${markup}</g>`);
    out.push(`<text x="${cell.x + 185}" y="${cell.y + 350}" text-anchor="middle" font-family="Georgia, serif" font-size="17" fill="${ink}">${esc(cell.title)}</text>`);
    out.push(`<text x="${cell.x + 185}" y="${cell.y + 22}" text-anchor="middle" font-family="Georgia, Arial Hebrew, serif" font-size="15" fill="${ink}" fill-opacity=".7"${cell.src === 'rosa' ? ' direction="rtl"' : ''}>${esc(cell.sub)}</text>`);
    out.push('</g>');
  }
  // cuarto recuadro: lo que cambia entre sistemas
  const g = gematria(state.rosa.hebrew);
  const notes = [
    `Letras: ${state.letters.length} letras únicas del nombre latino.`,
    `Hebreo: ${state.rosa.hebrew} (gematría ${g.std}).`,
    `Rosa-Cruz: ${state.rosa.trace.length} pétalos recorridos.`,
    `Kamea: ${state.kamea.words.flat().length} casillas de ${k.rows.length}×${k.rows.length}.`,
    'Mismo nombre, tres artefactos:',
    'cada sistema cifra otra cosa.'
  ];
  out.push(`<g data-layer="compare-notes" font-family="Georgia, serif" font-size="16" fill="${ink}">`);
  notes.forEach((t, i) => out.push(`<text x="430" y="${490 + i * 34}"${i >= 4 ? ' font-style="italic"' : ''}>${esc(t)}</text>`));
  out.push('</g></svg>');
  return out.join('');
}
const compareImg = { key: '', img: null };
function paintCompare(ctx) {
  const svg = compareSVG();
  if (!svg) {
    ctx.fillStyle = '#8a7f72'; ctx.textAlign = 'center'; ctx.font = 'italic 22px Georgia, serif';
    ctx.fillText('Escribe un nombre y pulsa «Comparar».', C, C);
    return;
  }
  if (compareImg.key !== svg) {
    const img = new Image();
    img.onload = () => { compareImg.img = img; render(); };
    img.src = 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(svg);
    compareImg.key = svg;
  }
  if (compareImg.img && compareImg.img.complete) ctx.drawImage(compareImg.img, 0, 0, SIZE, SIZE);
}
function renderCompareInfo() {
  const c = state.compare;
  if (!compareReady()) { $('compareBox').textContent = '—'; return; }
  const k = KAMEA_BY_ID[c.planet];
  $('compareBox').innerHTML =
    `<div class="line"><b>Letras</b><span>Método de la palabra: letras únicas en fusión (${state.letters.map(l => l.ch).join('')}). ${badge('OM')}</span></div>` +
    `<div class="line"><b>Rosa-Cruz</b><span><bdi lang="he">${esc(state.rosa.hebrew)}</bdi> sobre los 22 pétalos del Lamen. ${badge('OM')}</span></div>` +
    `<div class="line"><b>Kamea</b><span>La misma grafía hebrea sobre la tabla de ${k.name} de Agrippa. ${badge('HP')}</span></div>` +
    `<div class="line"><b>Por qué</b><span>Spare trabaja con las letras latinas de tu intención; la Rosa-Cruz y la Kamea, con el nombre en hebreo. Las tres pestañas quedan con este nombre por si quieres seguir en una.</span></div>`;
}
function compareProvenance() {
  return '<h3>El mismo nombre en tres sistemas</h3><p>Ejercicio 6 de la Guía Maestra de sigilos: trazar un nombre con los tres métodos y explicar por qué son artefactos distintos.</p><ul>' +
    `<li>Letras: método de la palabra, letras únicas y fusión (Spare; Frater U∴D∴). ${badge('OM')}</li>` +
    `<li>Rosa-Cruz: manuscrito F de Mathers sobre el Lamen de la Golden Dawn. ${badge('OM')}</li>` +
    `<li>Kamea: tablas planetarias de Agrippa, libro II, cap. 22; el trazado sobre la tabla es reconstrucción. ${badge('HP')} ${badge('RC')}</li>` +
    `<li>El paso del latín al hebreo es del taller (con grafía bíblica para los nombres que la tienen). ${badge('RC')}</li></ul>` +
    '<p class="note">Cada motor tiene su propia procedencia en su pestaña.</p>';
}
