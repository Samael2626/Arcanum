'use strict';
// ════════════════════════════════════════════════════════════════
//  Estilo: tinta, soporte, trazo y efectos
//  Todo sale en el lienzo y en el SVG/PNG por igual (una sola escena).
//  Procedencia:
//   - Colores planetarios: escala del Rey de la Aurora Dorada, los mismos
//     de la Rosa-Cruz (letra del planeta). [OM]
//   - Relampagueantes: Flying Roll XIV: "A flashing tablet is one made in
//     the complementary colours" (rojo-verde, azul-naranja, amarillo-violeta).
//     Campo en el color del planeta y signo en su complementario. [OM]
//     El indigo de Saturno no esta en esos tres pares: su complementario
//     (ambar) es reconstruccion. [RC]
//   - Metales de los planetas: Goetia, p. 48 (PLANET_METAL). [HP]
//   - Lo demas (tintas, soportes, efectos): decisiones del taller. [AR]
// ════════════════════════════════════════════════════════════════
const PLANET_LETTER = { saturn: 'ת', jupiter: 'כ', mars: 'פ', sun: 'ר', venus: 'ד', mercury: 'ב', moon: 'ג' };
const planetColor = id => ROSE_COLORS[PLANET_LETTER[id]];
// complementario segun los pares de Flying Roll XIV
const FLASH = { mars: 'ד', venus: 'פ', sun: 'ג', moon: 'ר', mercury: 'כ', jupiter: 'ב' };
const flashColor = id => id === 'saturn' ? ['ámbar', '#f0aa1a'] : ROSE_COLORS[FLASH[id]];
const shade = (hex, k) => '#' + hexRGB(hex).map(v => Math.round(v * k).toString(16).padStart(2, '0')).join('');
const PLANET_ORDER = ['saturn', 'jupiter', 'mars', 'sun', 'venus', 'mercury', 'moon'];

const INKS = [
  ['Tinta de hollín', '#1b1612'], ['Sepia', '#5b3a1e'], ['Lacre', '#7a1020'], ['Oro', '#c99a1a'],
  ['Plata', '#cfd4db'], ['Azul noche', '#1c2a4a'], ['Hueso', '#f4efe4']
];
const GROUNDS = [
  ['Pergamino', '#efe6d2'], ['Papel', '#f7f3ea'], ['Negro', '#0a080d'], ['Burdeos', '#2a0b12'], ['Azul noche', '#0f1626']
];
const STYLE_BASE = { preset: 'pergamino', ink: '#1b1612', bg: '#efe6d2', metal: null, texture: 'pergamino', width: 100, line: 'single', cap: 'round', calli: 'none', relief: false, glow: false };
const STYLE_PRESETS = {
  pergamino: { label: 'Pergamino', ink: '#1b1612', bg: '#efe6d2', texture: 'pergamino' },
  papel: { label: 'Papel limpio', ink: '#1b1612', bg: '#f7f3ea', texture: 'none' },
  lacre: { label: 'Lacre', ink: '#7a1020', bg: '#efe6d2', texture: 'pergamino' },
  oro: { label: 'Oro y negro', ink: '#c99a1a', bg: '#0a080d', texture: 'none', glow: true },
  burdeos: { label: 'Oro y burdeos', ink: '#c99a1a', bg: '#2a0b12', texture: 'none' },
  plata: { label: 'Plata lunar', ink: '#cfd4db', bg: '#0f1626', texture: 'none', glow: true },
  metal: { label: 'Grabado en metal', metalOf: 'today', texture: 'none', relief: true }
};
// Preset relampagueante de un planeta
const flashStyle = id => ({ preset: 'flash-' + id, ink: flashColor(id)[1], bg: planetColor(id)[1], texture: 'none', metal: null });
function metalStyle(planet) {
  const m = PLANET_METAL[planet], [hi, lo] = METAL_TONE[m];
  // la tinta es el mismo metal, mas hondo: un grabado se lee por sombra
  return { preset: 'metal', metal: m, metalPlanet: planet, bg: hi, ink: shade(lo, .42), texture: 'none', relief: true };
}
function presetStyle(key) {
  if (key.startsWith('flash-')) return { ...STYLE_BASE, ...flashStyle(key.slice(6)) };
  const p = STYLE_PRESETS[key];
  const extra = p.metalOf ? metalStyle(DAY_RULER[new Date().getDay()]) : {};
  const { label, metalOf, ...rest } = p;
  return { ...STYLE_BASE, ...rest, ...extra, preset: key };
}
function themeFor(st) {
  const dark = luminance(st.bg) < .45;
  return {
    bg: st.bg, ink: st.ink, faint: hexA(st.ink, .16), frame: hexA(st.ink, .55),
    // acento de la obra: la tinta, salvo el rojo de construccion sobre papel claro
    accent: st.ink === '#1b1612' && !dark ? '#9b1c2e' : st.ink,
    // marcas de edicion (solo pantalla): siempre contrastan con el fondo
    ui: dark ? '#f3d27a' : '#9b1c2e'
  };
}

// ── Soporte ─────────────────────────────────────────────────────
const bgCache = new Map();
function bgScene(th) {
  const st = state.style, key = JSON.stringify([st.bg, st.ink, st.metal, st.texture]);
  if (bgCache.has(key)) return bgCache.get(key);
  const full = `M 0 0 H ${SIZE} V ${SIZE} H 0 Z`, g = [];
  if (st.metal) {
    const [hi, lo] = METAL_TONE[st.metal];
    g.push({ layer: 'bg', color: lo, items: [{ d: full, grad: { id: 'soporteMetal', type: 'linear', x1: 0, y1: 0, x2: SIZE, y2: SIZE, stops: [[0, hi], [.5, lo], [1, hi]] } }] });
    // cepillado del metal
    const lines = [];
    for (let y = 5; y < SIZE; y += 6) lines.push(`M 0 ${y} H ${SIZE}`);
    g.push({ layer: 'bg-cepillado', color: '#ffffff', w: 1, items: [{ d: lines.join(' '), op: .07 }] });
  } else {
    g.push({ layer: 'bg', color: th.bg, items: [{ d: full, fill: true }] });
    if (st.texture === 'pergamino') {
      // fibras y viñeta con semilla fija: el mismo pergamino siempre
      let seed = 7;
      const rnd = () => (seed = seed * 16807 % 2147483647) / 2147483647;
      const fib = [];
      for (let i = 0; i < 110; i++) {
        const x = rnd() * SIZE, y = rnd() * SIZE, a = rnd() * Math.PI, l = 12 + rnd() * 46;
        fib.push(`M ${f2(x)} ${f2(y)} q ${f2(Math.cos(a) * l / 2 + (rnd() - .5) * 8)} ${f2(Math.sin(a) * l / 2 + (rnd() - .5) * 8)} ${f2(Math.cos(a) * l)} ${f2(Math.sin(a) * l)}`);
      }
      g.push({ layer: 'bg-fibras', color: th.ink, w: .8, items: [{ d: fib.join(' '), op: .07 }] });
      g.push({ layer: 'bg-vineta', color: th.ink, items: [{ d: full, grad: { id: 'soporteVineta', type: 'radial', cx: C, cy: C, r: SIZE * .72, stops: [[.55, st.ink, 0], [1, st.ink, .2]] } }] });
    }
  }
  bgCache.set(key, g);
  return g;
}

// ── Efectos: se resuelven en grupos normales antes de emitir ─────
function applyFx(groups, th) {
  const st = state.style, out = [];
  for (const g of groups) {
    let seq = [g];
    if (st.line === 'double' && g.layer === 'core') seq = [{ ...g, w: g.w * 1.9 }, { ...g, layer: 'core-hueco', color: th.bg, w: g.w * .7 }];
    if (st.glow && g.sigil) seq = [{ ...g, layer: g.layer + '-halo', w: (g.hw || g.w) * 3.4, op: .12 }, { ...g, layer: g.layer + '-halo2', w: (g.hw || g.w) * 2, op: .2 }, ...seq];
    if (st.relief) seq = [
      ...seq.map(q => ({ ...q, layer: q.layer + '-sombra', color: '#000000', op: (q.op == null ? 1 : q.op) * .35, dx: 1.6, dy: 1.6 })),
      ...seq.map(q => ({ ...q, layer: q.layer + '-luz', color: '#ffffff', op: (q.op == null ? 1 : q.op) * .45, dx: -1.1, dy: -1.1 })),
      ...seq
    ];
    out.push(...seq);
  }
  return out;
}

// ── Aplicar ─────────────────────────────────────────────────────
function applyStyle(st, silent = false) {
  state.style = { ...STYLE_BASE, ...st };
  THEMES.custom = themeFor(state.style);
  state.theme = 'custom';
  syncStyleUI();
  if (!silent) render();
}
const setStyle = patch => applyStyle({ ...state.style, ...patch, preset: patch.preset || 'propio' });

function styleInfoHTML() {
  const st = state.style;
  if (st.preset.startsWith('flash-')) {
    const id = st.preset.slice(6), k = KAMEA_BY_ID[id];
    return `<div class="line"><b>Colores</b><span>Relampagueantes de ${k.name}: campo ${planetColor(id)[0]} (su color en la escala del Rey) y signo ${flashColor(id)[0]}, su complementario. ${badge('OM')}</span></div>` +
      `<div class="line"><b>Fuente</b><span>Flying Roll XIV: ${cita('una tabla relampagueante es la que se hace en los colores complementarios', 'A flashing tablet is one made in the complementary colours')} (rojo y verde, azul y naranja, amarillo y violeta).${id === 'saturn' ? ` El índigo de Saturno no está en esos pares: el ámbar es reconstrucción. ${badge('RC')}` : ''}</span></div>`;
  }
  if (st.metal) {
    const planet = st.metalPlanet || Object.keys(PLANET_METAL).find(k => PLANET_METAL[k] === st.metal);
    return `<div class="line"><b>Soporte</b><span>${st.metal[0].toUpperCase() + st.metal.slice(1)}, el metal de ${KAMEA_BY_ID[planet].name} en la Goetia (p. 48). ${badge('HP')} El brillo y el relieve son del taller. ${badge('AR')}</span></div>`;
  }
  return `<div class="line"><b>Estilo</b><span>${esc(STYLE_PRESETS[st.preset] ? STYLE_PRESETS[st.preset].label : 'Propio')}: tinta, soporte y efectos del taller. ${badge('AR')}</span></div>`;
}
// muestra de un estilo: circulo del soporte con un signo en su tinta
function swatchHTML(st, sym = '✦') {
  const bg = st.metal ? `linear-gradient(135deg, ${METAL_TONE[st.metal][0]}, ${METAL_TONE[st.metal][1]})` : st.bg;
  return `<span class="sw-disc" style="background:${bg};color:${st.ink}">${glyphIcon(sym, 22)}</span>`;
}
function buildStylePanel() {
  const cards = Object.keys(STYLE_PRESETS).map(k => { const st = presetStyle(k); return `<button class="sw-card" data-preset-style="${k}" title="${STYLE_PRESETS[k].label}">${swatchHTML(st)}<span>${STYLE_PRESETS[k].label}</span></button>`; });
  $('stylePresets').innerHTML = cards.join('');
  $('flashPresets').innerHTML = PLANET_ORDER.map(id => { const st = flashStyle(id); return `<button class="sw-card" data-preset-style="flash-${id}" title="Relampagueante de ${KAMEA_BY_ID[id].name}">${swatchHTML(st, PLANET_GLYPH[id])}<span>${KAMEA_BY_ID[id].name}</span></button>`; }).join('');
  const inks = [...INKS, ...PLANET_ORDER.map(id => [`${KAMEA_BY_ID[id].name} (${planetColor(id)[0]})`, planetColor(id)[1]])];
  $('inkSwatches').innerHTML = inks.map(([n, c]) => `<button class="sw" data-ink="${c}" title="${n}" aria-label="${n}" style="background:${c}"></button>`).join('');
  const grounds = [...GROUNDS.map(([n, c]) => [n, c, '']), ...PLANET_ORDER.map(id => [`${PLANET_METAL[id][0].toUpperCase() + PLANET_METAL[id].slice(1)} (${KAMEA_BY_ID[id].name})`, `linear-gradient(135deg, ${METAL_TONE[PLANET_METAL[id]][0]}, ${METAL_TONE[PLANET_METAL[id]][1]})`, id])];
  $('bgSwatches').innerHTML = grounds.map(([n, c, metal]) => `<button class="sw" ${metal ? `data-metal="${metal}"` : `data-bg="${c}"`} title="${n}" aria-label="${n}" style="background:${c}"></button>`).join('');
  document.querySelectorAll('[data-preset-style]').forEach(b => b.addEventListener('click', () => applyStyle({ ...presetStyle(b.dataset.presetStyle), calli: state.style.calli })));
  document.querySelectorAll('[data-ink]').forEach(b => b.addEventListener('click', () => setStyle({ ink: b.dataset.ink })));
  document.querySelectorAll('[data-bg]').forEach(b => b.addEventListener('click', () => setStyle({ bg: b.dataset.bg, metal: null, metalPlanet: null })));
  document.querySelectorAll('[data-metal]').forEach(b => b.addEventListener('click', () => { const m = metalStyle(b.dataset.metal); setStyle({ bg: m.bg, metal: m.metal, metalPlanet: m.metalPlanet, texture: 'none' }); }));
  document.querySelectorAll('[data-texture]').forEach(b => b.addEventListener('click', () => setStyle({ texture: b.dataset.texture })));
  document.querySelectorAll('[data-line]').forEach(b => b.addEventListener('click', () => setStyle({ line: b.dataset.line })));
  document.querySelectorAll('[data-cap]').forEach(b => b.addEventListener('click', () => setStyle({ cap: b.dataset.cap })));
  document.querySelectorAll('[data-calli]').forEach(b => b.addEventListener('click', () => setStyle({ calli: b.dataset.calli })));
  $('chkRelief').addEventListener('change', e => setStyle({ relief: e.target.checked }));
  $('chkGlow').addEventListener('change', e => setStyle({ glow: e.target.checked }));
  $('rngStrokeW').addEventListener('input', e => setStyle({ width: Number(e.target.value) }));
}
function syncStyleUI() {
  const st = state.style;
  if (!$('stylePresets')) return;
  document.querySelectorAll('[data-preset-style]').forEach(b => b.classList.toggle('active', b.dataset.presetStyle === st.preset));
  document.querySelectorAll('[data-ink]').forEach(b => b.classList.toggle('active', b.dataset.ink === st.ink));
  document.querySelectorAll('[data-bg]').forEach(b => b.classList.toggle('active', !st.metal && b.dataset.bg === st.bg));
  document.querySelectorAll('[data-metal]').forEach(b => b.classList.toggle('active', !!st.metal && PLANET_METAL[b.dataset.metal] === st.metal));
  document.querySelectorAll('[data-texture]').forEach(b => { b.classList.toggle('active', b.dataset.texture === st.texture); b.disabled = !!st.metal; });
  document.querySelectorAll('[data-line]').forEach(b => b.classList.toggle('active', b.dataset.line === st.line));
  document.querySelectorAll('[data-cap]').forEach(b => b.classList.toggle('active', b.dataset.cap === st.cap));
  document.querySelectorAll('[data-calli]').forEach(b => b.classList.toggle('active', b.dataset.calli === st.calli));
  $('chkRelief').checked = st.relief; $('chkGlow').checked = st.glow;
  $('rngStrokeW').value = st.width; $('strokeWVal').textContent = st.width + '%';
  $('styleInfo').innerHTML = styleInfoHTML();
}
