'use strict';
// Kamea: tablas planetarias de Agrippa
// ── Kamea: tablas planetarias de Agrippa ────────────────────────
// Fuente: Agrippa, De occulta philosophia (1533), lib. II, cap. 22 [HP].
// Tablas transcritas de las laminas de la ed. inglesa de 1651 (ed. digital
// de J. H. Peterson, esotericarchives.com) y comprobadas por codigo.
// Erratas de esa edicion, resueltas por aritmetica y declaradas en pantalla:
//  - Luna, fila 1, col. 8: impreso "45" (ya esta en la fila 9 y la fila
//    sumaria 360). El unico numero que falta es 54.
//  - Kedemel: impreso "157"; su hebreo suma 175 (la linea de Venus).
//  - Bne Seraphim: transcrito בסי; solo בני da el 1252 impreso.
// Agrippa usa valores mayores para las finales (Bne Seraphim y
// Schedbarschemoth solo cuadran asi). Y NO explica como se trazan los
// sellos: "el buscador sabio lo descubrira". El trazado es reconstruccion.
const KAMEAS = [
  { id: 'saturn', name: 'Saturno', sym: '♄', rows: [[4, 9, 2], [3, 5, 7], [8, 1, 6]],
    names: [['Inteligencia', 'Agiel', 'אגיאל', 45, 'op2_30.gif', 'si'], ['Espíritu', 'Zazel', 'זאזל', 45, 'op2_31.gif', 'parcial']] },
  { id: 'jupiter', name: 'Júpiter', sym: '♃', rows: [[4, 14, 15, 1], [9, 7, 6, 12], [5, 11, 10, 8], [16, 2, 3, 13]],
    names: [['Inteligencia', 'Iofiel', 'יהפיאל', 136, 'op2_35.jpeg', 'parcial'], ['Espíritu', 'Hismael', 'הסמאל', 136, 'op2_36.gif', 'si']] },
  { id: 'mars', name: 'Marte', sym: '♂', rows: [[11, 24, 7, 20, 3], [4, 12, 25, 8, 16], [17, 5, 13, 21, 9], [10, 18, 1, 14, 22], [23, 6, 19, 2, 15]],
    names: [['Inteligencia', 'Grafiel', 'גראפיאל', 325, 'op2_40.gif', 'no'], ['Espíritu', 'Barzabel', 'ברצבאל', 325, 'op2_41.gif', 'si']] },
  { id: 'sun', name: 'Sol', sym: '☉', rows: [[6, 32, 3, 34, 35, 1], [7, 11, 27, 28, 8, 30], [19, 14, 16, 15, 23, 24], [18, 20, 22, 21, 17, 13], [25, 29, 10, 9, 26, 12], [36, 5, 33, 4, 2, 31]],
    names: [['Inteligencia', 'Najiel', 'נכיאל', 111, 'op2_45.gif', 'si'], ['Espíritu', 'Sorath', 'סורת', 666, 'op2_46.gif', 'si']] },
  { id: 'venus', name: 'Venus', sym: '♀', rows: [[22, 47, 16, 41, 10, 35, 4], [5, 23, 48, 17, 42, 11, 29], [30, 6, 24, 49, 18, 36, 12], [13, 31, 7, 25, 43, 19, 37], [38, 14, 32, 1, 26, 44, 20], [21, 39, 8, 33, 2, 27, 45], [46, 15, 40, 9, 34, 3, 28]],
    names: [['Inteligencia', 'Haguiel', 'הגיאל', 49, 'op2_50.gif', 'parcial'], ['Espíritu', 'Kedemel', 'קדמאל', 175, 'op2_51.gif', 'si'], ['Inteligencias', 'Bne Serafim', 'בני שרפים', 1252, 'op2_52.gif', 'parcial']] },
  { id: 'mercury', name: 'Mercurio', sym: '☿', rows: [[8, 58, 59, 5, 4, 62, 63, 1], [49, 15, 14, 52, 53, 11, 10, 56], [41, 23, 22, 44, 45, 19, 18, 48], [32, 34, 35, 29, 28, 38, 39, 25], [40, 26, 27, 37, 36, 30, 31, 33], [17, 47, 46, 20, 21, 43, 42, 24], [9, 55, 54, 12, 13, 51, 50, 16], [64, 2, 3, 61, 60, 6, 7, 57]],
    names: [['Inteligencia', 'Tiriel', 'טיריאל', 260, 'op2_56.gif', 'parcial'], ['Espíritu', 'Taftartarat', 'תפתרתרת', 2080, 'op2_57.gif', 'si']] },
  { id: 'moon', name: 'Luna', sym: '☽', rows: [[37, 78, 29, 70, 21, 62, 13, 54, 5], [6, 38, 79, 30, 71, 22, 63, 14, 46], [47, 7, 39, 80, 31, 72, 23, 55, 15], [16, 48, 8, 40, 81, 32, 64, 24, 56], [57, 17, 49, 9, 41, 73, 33, 65, 25], [26, 58, 18, 50, 1, 42, 74, 34, 66], [67, 27, 59, 10, 51, 2, 43, 75, 35], [36, 68, 19, 60, 11, 52, 3, 44, 76], [77, 28, 69, 20, 61, 12, 53, 4, 45]],
    names: [['Espíritu', 'Hasmodai', 'חשמודאי', 369, 'op2_61.gif', 'si'], ['Espíritu de los espíritus', 'Shedbarshemot Shartatán', 'שדברשהמעת שרתתן', 3321, 'op2_62.gif', 'parcial']] }
];
const VERDICT_TEXT = {
  si: 'El trazo coincide con el carácter que dibuja Agrippa.',
  parcial: 'Coincide la estructura (tramos, horquillas y extremos), pero no del todo la orientación del dibujo de Agrippa.',
  no: 'El carácter de Agrippa no sale de esta tabla con ningún método conocido; se muestra el trazo, no su figura.'
};
const KAMEA_BY_ID = Object.fromEntries(KAMEAS.map(k => [k.id, k]));
const AGRIPPA_URL = 'http://www.esotericarchives.com/agrippa/agripp2b.htm';

// Valor de letra como lo cuenta Agrippa: finales de 500 a 900
const kameaValue = ch => GADOL_FINAL[ch] || HEB_VALUE[baseLetter(ch)] || 0;

// Numero mayor que la ultima casilla: dos reducciones en uso [RC]
const KAMEA_REDUCE = {
  agrippa: { label: 'Como Agrippa', rule: 'Hasta la tabla del Sol (6×6) se reduce a la cámara (200 → 2); desde Venus (7×7), se quitan ceros (200 → 20). Es la regla que reproduce sus figuras: Barzabel y Sorath por un lado; Kedemel, Tiriel, Taftartarat y Hasmodai por otro. Ningún texto la enuncia.' },
  zeros: { label: 'Quitar ceros', rule: 'Se divide entre 10 hasta que cabe en la tabla (200 → 20 → 2 según el tamaño).' },
  aiq: { label: 'Aiq Bekar (nueve cámaras)', rule: 'Se reduce a su cámara: unidades, decenas y centenas de la misma cifra comparten casilla (200 → 2, 30 → 3).' }
};
function kameaCell(v, max, method) {
  if (v <= max) return { cell: v, reduced: false };
  if (method === 'agrippa') method = max <= 36 ? 'aiq' : 'zeros';
  if (method === 'aiq') { let c = v; while (c >= 10) c = Math.floor(c / 10); return { cell: c, reduced: true }; }
  let c = v;
  while (c > max && c % 10 === 0) c /= 10;
  while (c > max) c = Math.floor(c / 10);
  return { cell: c, reduced: true };
}

// Geometria de la tabla en el lienzo
const KAMEA_SIZE = 560;
function kameaGeom(k) {
  const n = k.rows.length, cell = KAMEA_SIZE / n, x0 = C - KAMEA_SIZE / 2, y0 = C - KAMEA_SIZE / 2;
  const pos = {};
  k.rows.forEach((row, r) => row.forEach((v, c) => { pos[v] = { x: x0 + (c + .5) * cell, y: y0 + (r + .5) * cell, r, c }; }));
  return { n, cell, x0, y0, pos };
}

// Recorrido: una palabra, un sigilo (como en la Rosa)
function kameaTrace(heb, k, method) {
  const g = kameaGeom(k), max = g.n * g.n;
  return heb.split(' ').filter(Boolean).map(word => {
    const steps = [];
    for (const ch of word) {
      const v = kameaValue(ch);
      if (!v) continue;
      const { cell, reduced } = kameaCell(v, max, method);
      steps.push({ ch, v, cell, reduced, ...g.pos[cell] });
    }
    return steps;
  });
}

// Trazo al estilo de los caracteres de Agrippa: circulo en ambos extremos;
// si el trazo vuelve por una linea ya dibujada, va en paralelo y el giro
// se redondea en horquilla (Inteligencias de Saturno y Jupiter).
// Medidas: finas sobre la tabla (construccion); en lamina, tinta gruesa y
// circulos marcados, como los caracteres grabados de Agrippa
const kameaLook = grid => grid ? { line: 3.2, mark: 2.4, lane: 14, endR: 9 } : { line: 10, mark: 7, lane: 22, endR: 16 };
// En lamina el caracter llena el cuadro, como en el libro: misma forma,
// escalada y centrada (la tabla sigue siendo la referencia exacta)
function kameaFit(words) {
  // varias palabras: una columna por palabra, de derecha a izquierda como
  // se lee el hebreo (lamina de la Luna: Schedbarschemoth a la derecha)
  const n = words.filter(w => w.length).length || 1, colW = 470 / n;
  let col = 0;
  return words.map(ws => {
    if (!ws.length) return ws;
    const xs = ws.map(q => q.x), ys = ws.map(q => q.y);
    const x0 = Math.min(...xs), x1 = Math.max(...xs), y0 = Math.min(...ys), y1 = Math.max(...ys);
    const w = x1 - x0, h = y1 - y0;
    const k = Math.min(w ? (colW - (n > 1 ? 40 : 0)) / w : Infinity, h ? 430 / h : Infinity, 3);
    const cx = (x0 + x1) / 2, cy = (y0 + y1) / 2, ox = C + 235 - colW * (col++ + .5);
    return ws.map(q => ({ ...q, x: ox + (q.x - cx) * k, y: C + 8 + (q.y - cy) * k }));
  });
}
function kameaShapes(steps, ends, look) {
  // letras seguidas en la misma casilla: un solo vertice con repeticion
  const verts = [];
  for (const s of steps) {
    const last = verts[verts.length - 1];
    if (last && last.cell === s.cell) { last.repeat++; continue; }
    verts.push({ ...s, repeat: 1 });
  }
  const shapes = [];
  const circle = (x, y, r) => `M ${f2(x + r)} ${f2(y)} A ${r} ${r} 0 1 0 ${f2(x - r)} ${f2(y)} A ${r} ${r} 0 1 0 ${f2(x + r)} ${f2(y)} Z`;
  if (!verts.length) return shapes;
  if (verts.length === 1) { shapes.push({ mark: 'start', d: circle(verts[0].x, verts[0].y, look.endR) }); return shapes; }
  // cada segmento va en su carril: tantos carriles como veces se repasa la misma linea
  const segs = [];
  for (let i = 0; i < verts.length - 1; i++) {
    const a = verts[i], b = verts[i + 1];
    const lane = segs.filter(s => segmentsOverlap(s.a, s.b, a, b)).length;
    const dx = b.x - a.x, dy = b.y - a.y, l = Math.hypot(dx, dy) || 1, ux = dx / l, uy = dy / l;
    // carril a la izquierda del sentido de avance
    const ox = -uy * lane * look.lane, oy = ux * lane * look.lane;
    segs.push({ a, b, ux, uy, A: { x: a.x + ox, y: a.y + oy }, B: { x: b.x + ox, y: b.y + oy } });
  }
  const pt = p => f2(p.x) + ' ' + f2(p.y);
  const first = segs[0], last = segs[segs.length - 1];
  // la linea sale del borde del circulo inicial
  const S = { x: first.A.x + first.ux * look.endR, y: first.A.y + first.uy * look.endR };
  let d = `M ${pt(S)}`;
  segs.forEach((s, i) => {
    const next = segs[i + 1];
    const isLast = !next;
    const E = isLast && ends === 'agrippa' ? { x: s.B.x - s.ux * look.endR, y: s.B.y - s.uy * look.endR } : s.B;
    if (!next) { d += ` L ${pt(E)}`; return; }
    const reverse = s.ux * next.ux + s.uy * next.uy < -0.97;
    if (reverse) {
      // horquilla: se frena antes del vertice y gira en curva al carril de vuelta
      const k = look.lane * .9;
      const P = { x: s.B.x - s.ux * k, y: s.B.y - s.uy * k };
      const Q = { x: next.A.x + next.ux * k, y: next.A.y + next.uy * k };
      d += ` L ${pt(P)} C ${pt({ x: P.x + s.ux * k * 1.4, y: P.y + s.uy * k * 1.4 })} ${pt({ x: Q.x - next.ux * k * 1.4, y: Q.y - next.uy * k * 1.4 })} ${pt(Q)}`;
    } else {
      d += ` L ${pt(s.B)}`;
    }
  });
  shapes.push({ mark: 'line', d });
  shapes.push({ mark: 'start', d: circle(first.A.x, first.A.y, look.endR) });
  if (ends === 'agrippa') shapes.push({ mark: 'end', d: circle(last.B.x, last.B.y, look.endR) });
  else {
    const n = { x: -last.uy * 11, y: last.ux * 11 };
    shapes.push({ mark: 'end', d: `M ${pt({ x: last.B.x + n.x, y: last.B.y + n.y })} L ${pt({ x: last.B.x - n.x, y: last.B.y - n.y })}` });
  }
  // letras repetidas en la misma casilla: pequeno lazo sobre el vertice
  // tambien en los extremos: el gancho inicial de Sorath son dos letras en la casilla 6
  verts.filter(v => v.repeat > 1).forEach(v => shapes.push({ mark: 'repeat', d: circle(v.x, v.y - 16, 5) }));
  return shapes;
}

function kameaSVG(th) {
  const km = state.kamea, k = KAMEA_BY_ID[km.planet], g = kameaGeom(k), out = [];
  const used = new Set(km.words.flat().map(s => s.cell));
  if (km.grid) {
    out.push(`<g data-layer="kamea-grid" stroke="${th.faint}" stroke-width="1.2">`);
    for (const [v, p] of Object.entries(g.pos)) {
      out.push(`<rect x="${f2(p.x - g.cell / 2)}" y="${f2(p.y - g.cell / 2)}" width="${f2(g.cell)}" height="${f2(g.cell)}" fill="${used.has(Number(v)) ? th.faint : 'none'}"/>`);
      out.push(`<text x="${f2(p.x)}" y="${f2(p.y)}" stroke="none" fill="${th.frame}" text-anchor="middle" dominant-baseline="middle" font-family="Georgia, serif" font-size="${Math.round(g.cell * .32)}">${v}</text>`);
    }
    out.push('</g>');
  }
  const wd = kameaLook(km.grid), words = km.grid ? km.words : kameaFit(km.words);
  out.push(`<g data-layer="kamea" fill="none" stroke="${km.grid ? th.accent : th.ink}" stroke-linecap="round" stroke-linejoin="round">`);
  words.forEach((w, i) => {
    out.push(`<g data-word="${i + 1}">`);
    for (const s of kameaShapes(w, km.ends, wd)) out.push(`<path data-mark="${s.mark}" d="${s.d}" stroke-width="${s.mark === 'line' ? wd.line : wd.mark}"/>`);
    out.push('</g>');
  });
  out.push('</g>');
  const cap = kameaCaption();
  if (cap && !km.grid) out.push(`<g data-layer="caption" fill="${th.ink}" text-anchor="middle" font-family="Georgia, serif"><text x="${C}" y="72" font-size="26" font-style="italic">${esc(cap.title)}</text><text x="${C}" y="${SIZE - 44}" font-size="17" fill="${th.frame}">${esc(cap.sub)}</text></g>`);
  return out.join('');
}
// Rotulo de lamina, como en Agrippa ("Of the Spirit of Saturn")
function kameaCaption() {
  const km = state.kamea, k = KAMEA_BY_ID[km.planet];
  if (!km.hebrew) return null;
  const preset = k.names.find(n => n[2] === km.hebrew);
  const name = preset ? preset[1] : ($('kameaName').value.trim() || km.hebrew);
  return { title: name, sub: preset ? `${preset[0]} de ${k.name}` : `Sobre la tabla de ${k.name}` };
}

function kameaTraceFromHebrew() {
  const km = state.kamea, k = KAMEA_BY_ID[km.planet];
  km.hebrew = cleanHebrew($('kameaHebrew').value);
  km.words = kameaTrace(km.hebrew, k, km.reduce);
  const g = kameaGeom(k), max = g.n * g.n, total = max * (max + 1) / 2, line = g.n * (max + 1) / 2;
  const sum = [...km.hebrew].reduce((acc, ch) => acc + kameaValue(ch), 0);
  const echo = sum === total ? `igual al total de la tabla de ${k.name} (${total})` : sum === line ? `igual a una línea de la tabla (${line})` : '';
  // cada letra aislada con <bdi>: sin eso el hebreo reordena la linea entera
  const steps = km.words.map(w => w.map(s => `<bdi lang="he">${s.ch}</bdi>&nbsp;${s.v}${s.reduced ? '&nbsp;→&nbsp;' + s.cell : ''}`).join(' · ')).join(' <b>|</b> ');
  const preset = k.names.find(n => n[2] === km.hebrew);
  $('kameaBox').innerHTML =
    (preset ? `<div class="line"><b>Nombre</b><span>${esc(preset[1])}, ${preset[0].toLowerCase()} de ${k.name} según Agrippa ${badge('HP')}</span></div>` +
      `<div class="line"><b>Figura</b><span>${VERDICT_TEXT[preset[5]]}${km.reduce === 'agrippa' ? '' : ' (con la reducción «Como Agrippa»)'} <button class="btn-dim" style="min-height:28px;padding:2px 8px" onclick="kameaToSeal('${k.id}', '${preset[0]}')">Ver el original de Agrippa</button></span></div>` : '') +
    `<div class="line"><b>Tabla</b><span>${k.sym}︎ ${k.name}: ${g.n}×${g.n}, cada línea suma ${line}, en total ${total}.</span></div>` +
    `<div class="line"><b>Hebreo</b><span dir="rtl" lang="he">${esc(km.hebrew) || '—'}</span></div>` +
    `<div class="line"><b>Casillas</b><span dir="ltr">${steps || '—'}</span></div>` +
    `<div class="line"><b>Reducción</b><span>${esc(KAMEA_REDUCE[km.reduce].label)} ${badge(km.reduce === 'agrippa' ? 'AR' : 'RC')}: ${esc(KAMEA_REDUCE[km.reduce].rule)}</span></div>` +
    `<div class="line"><b>Suma</b><span>${sum}${echo ? ' · ' + echo : ''}</span></div>`;
  render();
}
function kameaGenerate() {
  const km = state.kamea, name = $('kameaName').value.trim();
  if (!name) { showToast('Escribe un nombre'); return; }
  $('kameaHebrew').value = hasHebrew(name) ? cleanHebrew(name) : transliterate(name, $('selKameaTranslit').value).hebrew;
  kameaTraceFromHebrew();
}
function renderKameaPresets() {
  const k = KAMEA_BY_ID[state.kamea.planet], box = $('kameaPresets');
  box.innerHTML = '';
  k.names.forEach(([role, la, he]) => {
    const b = document.createElement('button');
    b.className = 'btn-dim'; b.textContent = `${role}: ${la}`; b.title = `Nombre que da Agrippa para ${k.name}: ${he}`;
    b.addEventListener('click', () => { $('kameaName').value = la; $('kameaHebrew').value = he; kameaTraceFromHebrew(); });
    box.append(b);
  });
}
function kameaProvenance() {
  const km = state.kamea, k = KAMEA_BY_ID[km.planet];
  return `<h3>Kamea de ${k.name}</h3><p>Tabla de ${k.rows.length}×${k.rows.length}, tal como la imprime Agrippa. ${badge('HP')}</p>` +
    '<h3>Qué es histórico y qué no</h3><ul>' +
    `<li>Las siete tablas, los nombres de inteligencias y espíritus y sus números: Agrippa, <i title="Título original: De occulta philosophia">Filosofía oculta</i> (1533), libro II, cap. 22. ${badge('HP')}</li>` +
    `<li>Cada nombre suma el número que Agrippa le da, contando las letras finales de 500 a 900, como hace él (Bne Serafim 1252). ${badge('HP')}</li>` +
    `<li>Cómo se traza el sello sobre la tabla: Agrippa no lo explica; dice que ${cita('el buscador sabio […] lo descubrirá fácilmente', 'the wise searcher, and he which shall understand the verifying of these tables, shall easily find out')}. El recorrido de casilla en casilla es una reconstrucción. ${badge('RC')}</li>` +
    `<li>Círculo en los dos extremos y horquilla cuando el trazo vuelve sobre sí mismo: así están dibujados los caracteres de Agrippa. ${badge('HP')}</li>` +
    `<li>Números mayores que la tabla: se reducen quitando ceros o por Aiq Bekar. Comparando con sus 15 figuras, Agrippa usa Aiq Bekar hasta 6×6 y quita ceros desde 7×7: así coinciden 8 figuras con claridad y 6 en su estructura. Grafiel no sale con ningún método. ${badge('AR')}</li></ul>` +
    '<h3>Erratas de la edición inglesa de 1651</h3><ul>' +
    '<li>Luna, fila 1, columna 8: pone «45», que ya está en la fila 9 y deja la fila en 360. El único número que falta es 54.</li>' +
    '<li>Kedemel: pone «157», pero קדמאל suma 175, que es la línea de Venus.</li>' +
    '<li>Bne Serafim: la transcripción trae בסי; solo בני da el 1252 impreso.</li></ul>' +
    '<h3>Grafiel, sin reproducir</h3><p>Su figura en Agrippa es un circuito cerrado de cinco vértices. גראפיאל pasa dos veces por el Álef y no puede dibujar eso; un Grafiel sin el segundo Álef (ג ר א פ י ל) sí daría cinco vértices cerrados, pero ninguna orientación de la tabla reproduce la forma. Queda como indicio, no como regla.</p>' +
    '<h3>Nombre que no se incluye</h3><p>La inteligencia de las inteligencias de la Luna, <i>Malkah be-Tarshishim…</i>, llega corrupta en Agrippa (Donald Tyson propuso una restauración en su edición anotada). Cinco grafías hebreas distintas suman su 3321; sin la fuente que decide entre ellas, el taller no elige ninguna.</p>' +
    `<p class="note">Láminas originales: <a href="${AGRIPPA_URL}" target="_blank" rel="noopener" style="color:var(--gold)">Agrippa, libro II, cap. 22 (Esoteric Archives)</a>.</p>`;
}
