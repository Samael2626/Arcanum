// Gate del Taller de Sigilos v3 - sigilo de letras.
// Uso: node _gate.mjs [--shots]   (requiere: npm install)
// --shots guarda capturas _shot-*.png para revisar a ojo.
import { chromium } from 'playwright';
import path from 'path';
import { fileURLToPath } from 'url';
const __dirname = path.dirname(fileURLToPath(import.meta.url));
const INDEX = 'file:///' + __dirname.split('\\').join('/') + '/index.html';
const SHOTS = process.argv.includes('--shots');

const results = [];
function check(name, ok, detail = '') {
  results.push({ name, ok });
  console.log((ok ? 'PASS' : 'FAIL') + '  ' + name + (detail ? '  - ' + detail : ''));
}

// Sin chromium de playwright descargado, cae a Edge del sistema
const browser = await chromium.launch().catch(() => chromium.launch({ channel: 'msedge' }));
const page = await browser.newPage({ viewport: { width: 1400, height: 1000 } });
const errors = [];
page.on('pageerror', e => errors.push(String(e)));
page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
await page.goto(INDEX);
await page.waitForTimeout(400);

async function forge(text, mode = 'fusion', method = 'cooper') {
  await page.selectOption('#selReduction', method);
  await page.click(`.mode-btn[data-mode="${mode}"]`);
  await page.fill('#intention', text);
  await page.click('#btnGenerate');
  await page.waitForTimeout(120);
}
const snap = () => page.evaluate(() => ({
  svg: buildSVG(), svg2: buildSVG(),
  letters: state.letters.map(l => ({ ch: l.ch, twin: l.twin, legible: l.legible, shares: l.shares })),
  prims: state.prims.map(p => ({ units: p.units, kind: p.kind || null, hidden: p.hidden }))
}));
async function shot(name) { if (SHOTS) await page.locator('#canvas').screenshot({ path: path.join(__dirname, `_shot-${name}.png`) }); }

// 1) Trazabilidad, determinismo, SVG real y letras completas en los 3 modos
const intents = ['AMOR DIOS', 'MI PRACTICA MANTIENE ENFOQUE SERENO', 'SABIDURIA', 'FUERZA'];
for (const mode of ['fusion', 'block', 'cross']) {
  for (const t of intents) {
    await forge(t, mode);
    const r = await snap();
    const traced = r.prims.every(p => p.units.length || p.kind === 'cross');
    const full = r.letters.every(l => l.twin || l.legible === 1);
    const real = r.svg.includes('<path') && !r.svg.includes('<image') && !/data-units|data-ch/.test(r.svg);
    check(`${mode} [${t}]`, traced && full && real && r.svg === r.svg2,
      `letras=${r.letters.map(l => l.ch).join('')} trazos=${r.prims.length} compartidos=${r.prims.filter(p => p.units.length > 1).length}`);
    await shot(`${mode}-${t.split(' ')[0].toLowerCase()}`);
  }
}

// 2) Tres intenciones -> estructuras distintas; tres modos -> estructuras distintas
const svgs = [];
for (const t of ['AMOR', 'FUERZA', 'LUNA']) { await forge(t); svgs.push((await snap()).svg); }
check('tres intenciones distintas', new Set(svgs).size === 3);
const modes = [];
for (const m of ['fusion', 'block', 'cross']) { await forge('LUZ DE MANANA', m); modes.push((await snap()).svg); }
check('tres composiciones distintas', new Set(modes).size === 3);

// 3) Trazos compartidos: H y E comparten el asta izquierda en fusion
await forge('HACIA EL HORIZONTE', 'fusion');
let r = await snap();
check('trazo compartido H+E', r.prims.some(p => p.units.includes('H') && p.units.includes('E')));
// L cabe entera dentro de E: todos sus trazos son compartidos
check('L contenida en E', r.letters.find(l => l.ch === 'L').shares.includes('E'));

// 4) Gemelas: W es M invertida (U.D.), Z es N girada
await forge('MUNDO WEB', 'fusion', 'unique');
r = await snap();
const w = r.letters.find(l => l.ch === 'W');
check('W absorbida por M', w && w.twin && w.twin.by === 'M', w && w.twin ? w.twin.how : 'no');
await forge('NADA ZOZOBRA', 'fusion', 'unique');
r = await snap();
const z = r.letters.find(l => l.ch === 'Z');
check('Z absorbida por N', z && z.twin && z.twin.by === 'N', z && z.twin ? z.twin.how : 'no');
await page.click('#chkAbsorb');
await page.waitForTimeout(80);
r = await snap();
check('absorcion desactivable', r.letters.every(l => !l.twin));
await page.click('#chkAbsorb');

// 4b) Ejemplos reales publicados: la reduccion debe dar lo mismo que la fuente
// Frater U.D., cap. 2: "the letters which appear more than once are deleted"
await forge('THIS MY WISH TO OBTAIN THE STRENGTH OF A TIGER', 'fusion', 'unique');
const ud = await page.evaluate(() => ({ units: state.reduction.units.join(''), w: (state.letters.find(l => l.ch === 'W') || {}).twin }));
check('U.D.: ejemplo de Spare deja THISMYWOBANERGF', ud.units === 'THISMYWOBANERGF', ud.units);
check('U.D.: la W se lee en la M (su propio ejemplo)', ud.w && ud.w.by === 'M');
// Cooper, p. 44: "I DESIRE A NEW PARTNER" -> I D A N P
await forge('I DESIRE A NEW PARTNER', 'fusion', 'cooper');
const coop = await page.evaluate(() => ({
  units: state.reduction.units.join(''),
  stem: state.prims.some(p => ['I', 'D'].every(u => p.units.includes(u))),
  centerI: state.prims.some(p => p.units.length === 1 && p.units[0] === 'I'),
  area: (() => { const v = fitView(); return v.k; })()
}));
check('Cooper: I DESIRE A NEW PARTNER deja IDANP', coop.units === 'IDANP', coop.units);
check('Cooper fig. 4: la I es el asta de la D (encaje compacto)', coop.stem && !coop.centerI);
await page.uncheck('#chkCompact');
const loose = await page.evaluate(() => state.prims.some(p => p.units.length === 1 && p.units[0] === 'I'));
check('sin encaje compacto la I va aparte', loose);
await page.check('#chkCompact');
// el encaje nunca ensancha el signo: todos los ejemplos siguen cabiendo en una caja
for (const t of ['I DESIRE A NEW PARTNER', 'THIS MY WISH TO OBTAIN THE STRENGTH OF A TIGER', 'MI PRACTICA MANTIENE ENFOQUE SERENO']) {
  await forge(t, 'fusion', t.startsWith('THIS') ? 'unique' : 'cooper');
  const box = await page.evaluate(() => {
    let x0 = Infinity, x1 = -Infinity;
    for (const p of state.prims) for (const q of primPoints(p)) { x0 = Math.min(x0, q.x); x1 = Math.max(x1, q.x); }
    return x1 - x0;
  });
  check(`encaje compacto no ensancha [${t.split(' ').slice(0, 3).join(' ')}]`, box <= 1.001, box.toFixed(2) + ' cajas');
}


// 5) Bloque: cada letra en su celda (sin dos letras en el mismo sitio)
await forge('SABIDURIA', 'block');
const cells = await page.evaluate(() => activeLetters().map(l => l.base.tx.toFixed(2) + ',' + l.base.ty.toFixed(2)));
check('bloque: una celda por letra', new Set(cells).size === cells.length, cells.join(' '));

// 6) Cruz: vocales al centro, consonantes en brazos, brazos marcados
await forge('KAROLUS', 'cross', 'unique');
const cross = await page.evaluate(() => ({
  center: activeLetters().filter(l => l.base.tx === 0 && l.base.ty === 0).map(l => l.ch).join(''),
  arms: state.prims.filter(p => p.kind === 'cross').length
}));
check('cruz KAROLVS: vocales al centro', cross.center === 'AOU', cross.center);
check('cruz: brazos como trazos de composicion', cross.arms === 4, cross.arms + '');
const kpos = await page.evaluate(() => Object.fromEntries(activeLetters().map(l => [l.ch, [Math.sign(Math.round(l.base.tx * 10)), Math.sign(Math.round(l.base.ty * 10))]])));
check('cruz como el diploma: K izq, R arriba, L abajo, S der', JSON.stringify([kpos.K, kpos.R, kpos.L, kpos.S]) === JSON.stringify([[-1, 0], [0, -1], [0, 1], [1, 0]]), JSON.stringify(kpos));
await shot('cross-karolus');

// 7) Edicion por letra: girar cambia el SVG y restaurar lo devuelve
await forge('AMOR DIOS', 'fusion');
const base = (await snap()).svg;
await page.click('.chip[data-ch="D"]');
await page.click('#btnRotR');
await page.waitForTimeout(80);
const rotated = (await snap()).svg;
await page.click('#btnLetterReset');
await page.waitForTimeout(80);
const restored = (await snap()).svg;
check('girar letra cambia el signo', rotated !== base);
check('restaurar letra lo devuelve', restored === base);
const dec = await page.evaluate(() => state.decisions.map(d => d.type));
check('decisiones registradas', dec.includes('girar') && dec.includes('restaurar'), dec.join(','));

// 8) Ocultar un trazo baja la legibilidad de su letra
const hid = await page.evaluate(() => {
  const p = state.prims.find(q => q.units.length === 1);
  toggleHidden(p.key);
  const l = state.letters.find(x => x.ch === p.units[0]);
  const out = { legible: l.legible, inSvg: buildSVG().split('<path').length };
  toggleHidden(p.key);
  return { ...out, after: buildSVG().split('<path').length };
});
check('ocultar trazo baja legibilidad', hid.legible < 1 && hid.inSvg < hid.after, `legible=${hid.legible.toFixed(2)}`);

// 9) Borde (Cooper): capa independiente, solo por decision
const noBorder = (await snap()).svg;
await page.selectOption('#selBorder', 'circle');
const withBorder = (await snap()).svg;
check('borde capa on/off', !noBorder.includes('data-layer="border"') && withBorder.includes('data-layer="border"'));
await page.selectOption('#selBorder', 'none');

// 9b) Marco ritual: estrella 5-9 puntas, inscripcion y estampas (capas a mano)
await page.click('#subStar summary');
await page.check('#chkStar');
for (const n of [5, 6, 7, 8, 9]) {
  await page.selectOption('#selStarPoints', String(n));
  const st = await page.evaluate(() => {
    const s = buildSVG(), g = s.match(/<g data-layer="star"[\s\S]*?<\/g>/);
    return { det: s === buildSVG(), paths: g ? (g[0].match(/<path/g) || []).length : 0 };
  });
  check(`estrella ${n} puntas`, st.det && st.paths === n + 1, `${st.paths - 1} acordes`);
  if ([5, 7, 9].includes(n)) await shot(`star-${n}`);
}
await page.uncheck('#chkStarChords');
check('estrella sin acordes', (await page.evaluate(() => (buildSVG().match(/<g data-layer="star"[\s\S]*?<\/g>/)[0].match(/<path/g) || []).length)) === 1);
await page.check('#chkStarChords');
await page.click('#subIns summary');
await page.check('#chkInscription');
await page.fill('#insText', 'VOLUNTAS');
const insN = await page.evaluate(() => (buildSVG().match(/<g data-layer="inscription"[\s\S]*?<\/g>/)[0].match(/<text/g) || []).length);
check('inscripcion 8 letras', insN === 8, insN + '');
// Simbolos arcanos: catalogo, colocar, arrastrar, escalar, quitar
const cat = await page.evaluate(() => ({
  groups: document.querySelectorAll('#stampCatalog .stamp-group').length,
  btns: document.querySelectorAll('#stampCatalog .stamp-btn').length,
  named: [...document.querySelectorAll('#stampCatalog .stamp-btn')].every(b => b.title),
  modern: /[♅♆♇]/.test(document.getElementById('stampCatalog').textContent)
}));
check('catalogo de simbolos por grupos con nombre', cat.groups === 6 && cat.btns >= 39 && cat.named, `${cat.groups} grupos, ${cat.btns} simbolos`);
check('solo planetas clasicos', !cat.modern);
await page.click('.stamp-btn[title="Júpiter"]');
const box = await page.locator('#canvas').boundingBox();
const at = (fx, fy) => [box.x + box.width * fx, box.y + box.height * fy];
await page.mouse.click(...at(.15, .15));
await page.click('#btnStamp');
let st1 = await page.evaluate(() => ({ n: state.stamps.length, sym: state.stamps[0] && state.stamps[0].sym, svg: buildSVG().includes('data-layer="stamps"'), info: document.getElementById('stampInfo').textContent }));
check('jupiter colocado', st1.n === 1 && st1.sym.startsWith('♃') && st1.svg && /Júpiter/.test(st1.info), st1.info);
await page.mouse.move(...at(.15, .15)); await page.mouse.down(); await page.mouse.move(...at(.85, .2), { steps: 5 }); await page.mouse.up();
const moved = await page.evaluate(() => ({ x: state.stamps[0].x, n: state.stamps.length }));
check('arrastrar simbolo lo mueve', moved.x > 600 && moved.n === 1, `x=${moved.x.toFixed(0)}`);
await page.click('#btnStampBigger');
check('ampliar simbolo', await page.evaluate(() => state.stamps[0].size > STAMP_SIZE && buildSVG().includes(`font-size="${state.stamps[0].size}"`)));
await page.click('#btnStampDelete');
check('quitar simbolo', await page.evaluate(() => state.stamps.length === 0 && !buildSVG().includes('data-layer="stamps"')));
await page.click('.stamp-btn[title="Saturno"]');
await page.mouse.click(...at(.15, .15));
await page.click('#btnStamp');
const stamps = await page.evaluate(() => ({ n: state.stamps.length, svg: buildSVG().includes('data-layer="stamps"') }));
check('estampa colocada sin tocar letras', stamps.n === 1 && stamps.svg, `n=${stamps.n}`);
await shot('marco-completo');
await page.evaluate(() => localStorage.clear());
await page.click('#btnSave');
await page.uncheck('#chkStar'); await page.uncheck('#chkInscription'); await page.click('#btnClearStamps');
await page.evaluate(() => restoreState(readGallery()[0].state));
const back = await page.evaluate(() => ({ star: state.star.enabled && state.star.points === 9, ins: state.inscription.text, stamps: state.stamps.length, ui: document.getElementById('chkStar').checked }));
check('galeria recupera estrella, inscripcion y estampas', back.star && back.ins === 'VOLUNTAS' && back.stamps === 1 && back.ui);
await page.uncheck('#chkStar'); await page.uncheck('#chkInscription'); await page.click('#btnClearStamps');

// 9c) Terminales: catalogo, remate general y uno a uno
await forge('MI PRACTICA MANTIENE ENFOQUE SERENO', 'fusion');
const termIds = await page.evaluate(() => TERMINALS.map(t => t.id).filter(id => id !== 'none'));
check('catalogo de remates', termIds.length >= 13, termIds.join(','));
const freeN = await page.evaluate(() => freeEnds(state.prims.filter(p => !p.hidden)).length);
for (const id of termIds) {
  await page.click(`.term-btn[data-t="${id}"]`);
  const t = await page.evaluate(() => {
    const s = buildSVG(), g = s.match(/<g data-layer="terminals"[\s\S]*?<\/g>/);
    return { det: s === buildSVG(), groups: terminalList(state.prims.filter(p => !p.hidden)).length, paths: g ? (g[0].match(/<path/g) || []).length : 0, nan: /NaN/.test(s) };
  });
  check(`remate ${id}`, t.det && !t.nan && t.groups === freeN && t.paths >= freeN, `${t.groups} puntas, ${t.paths} paths`);
  if (['pattee', 'ring', 'trident', 'star'].includes(id)) await shot(`term-${id}`);
}
const pat = await page.evaluate(() => {
  state.terminals = 'pattee'; render();
  const t = terminalList(state.prims.filter(p => !p.hidden))[0];
  return { arms: t.shapes.length, filled: t.shapes.every(s => s.fill) };
});
check('cruz patada: 4 brazos rellenos', pat.arms === 4 && pat.filled);
await page.click('#btnTermClear');
check('quitar todos los remates', await page.evaluate(() => !buildSVG().includes('data-layer="terminals"')));
// uno a uno: una sola punta con cruz patada, como el ejemplo
await page.click('#btnTermPick');
await page.click('.term-btn[data-t="pattee"]');
const endPx = await page.evaluate(() => {
  const e = freeEnds(state.prims.filter(p => !p.hidden))[0], q = toCanvas(e), r = canvas.getBoundingClientRect();
  return { x: r.left + q.x / SIZE * r.width, y: r.top + q.y / SIZE * r.height };
});
await page.mouse.click(endPx.x, endPx.y);
let one = await page.evaluate(() => terminalList(state.prims.filter(p => !p.hidden)).map(t => t.style));
check('uno a uno: una sola punta', one.length === 1 && one[0] === 'pattee', one.join(','));
await shot('term-uno');
await page.mouse.click(endPx.x, endPx.y);
one = await page.evaluate(() => terminalList(state.prims.filter(p => !p.hidden)).length);
check('uno a uno: segundo toque lo quita', one === 0);
await page.mouse.click(endPx.x, endPx.y);
await page.click('#btnTermPick');
await page.evaluate(() => localStorage.clear());
await page.click('#btnSave');
await page.click('#btnTermClear');
await page.evaluate(() => restoreState(readGallery()[0].state));
check('galeria recupera remates por punta', await page.evaluate(() => terminalList(state.prims.filter(p => !p.hidden)).length === 1));
await page.click('#btnTermClear');

// 10) Miniatura 80x80 con tinta suficiente
const ink = await page.evaluate(() => {
  const d = document.getElementById('previewCanvas').getContext('2d').getImageData(0, 0, 80, 80).data;
  let n = 0;
  for (let i = 0; i < d.length; i += 4) if (d[i] + d[i + 1] + d[i + 2] < 300) n++;
  return n;
});
check('miniatura 80x80', ink > 120, ink + ' px de tinta');

// 11) Sin hebreo en el sigilo de letras
check('sin hebreo en sigilo de letras', !(await snap()).svg.match(/[\u0590-\u05FF]/));

// 12) Rosa-Cruz: motor separado
await page.click('#famRosa');
// Disposicion del Lamen (documento 5=6 + SVG de Commons)
const lay = await page.evaluate(() => {
  const q = he => { const p = PETALS[he]; return { x: Math.round(p.x - C), y: Math.round(p.y - C) }; };
  return { aleph: q('א'), shin: q('ש'), mem: q('מ'), peh: q('פ'), kaph: q('כ'), daleth: q('ד'), heh: q('ה'), vav: q('ו'), lamed: q('ל'), qoph: q('ק'), n: Object.keys(PETALS).length };
});
check('rosa: 22 petalos', lay.n === 22);
check('rosa: madres (Aleph arriba, Shin abajo-der, Mem abajo-izq)', lay.aleph.x === 0 && lay.aleph.y < 0 && lay.shin.x > 0 && lay.shin.y > 0 && lay.mem.x < 0 && lay.mem.y > 0);
check('rosa: dobles (Peh arriba-izq, Kaph arriba-der, Daleth abajo)', lay.peh.x < 0 && lay.peh.y < 0 && lay.kaph.x > 0 && lay.kaph.y < 0 && lay.peh.x === -lay.kaph.x && lay.daleth.x === 0 && lay.daleth.y > 0);
check('rosa: zodiaco antihorario (Heh arriba, Vav a su izq, Qoph a su der, Lamed abajo)', lay.heh.x === 0 && lay.heh.y < 0 && lay.vav.x < 0 && lay.qoph.x > 0 && lay.lamed.x === 0 && lay.lamed.y > 0);

// Metatron: el ejemplo del propio manuscrito F
await page.selectOption('#selTranslit', 'consonantal');
await page.fill('#rosaName', 'Metatron');
await page.click('#btnRosaGenerate');
const met = await page.evaluate(() => {
  const s = buildSVG();
  return {
    heb: document.getElementById('rosaHebrew').value, g: gematria(state.rosa.hebrew),
    crooks: state.rosa.trace.filter(v => v.crook).map(v => v.he).join(''), nooses: state.rosa.trace.filter(v => v.noose).map(v => v.he + ':' + v.turn.toFixed(1)).join(','),
    det: s === buildSVG(), start: (s.match(/data-mark="start"/g) || []).length, end: s.includes('data-mark="end"'),
    line: s.includes('data-mark="line"'), noosePath: (s.match(/data-mark="noose"/g) || []).length, core: s.includes('data-layer="core"'),
    heb22: (s.match(/[א-ת]/g) || []).length
  };
});
check('metatron: transliteracion consonantica = מטטרון', met.heb === 'מטטרון', met.heb);
check('metatron: gematria 314', met.g.std === 314, met.g.std + ' / gadol ' + met.g.gadol);
check('metatron: quiebro en Teth (dos seguidas)', met.crooks === 'ט', met.crooks);
check('metatron: lazo en Resh, giro < 3 grados', /^ר:[0-2]\.\d$/.test(met.nooses), met.nooses);
check('metatron: circulo inicial y barra final por defecto (figura del manuscrito)', met.start === 1 && met.end && met.line && met.noosePath === 1);
check('rosa: determinista, diagrama con 22 letras, sin mezcla', met.det && met.heb22 >= 22 && !met.core);
await shot('rosa-metatron');
check('metatron: ningun trazo apartado', await page.evaluate(() => !state.rosa.trace.some(v => v.shifted)));
await page.uncheck('#chkRosaEndBar');
check('barra final desactivable', await page.evaluate(() => !buildSVG().includes('data-mark="end"')));
await page.check('#chkRosaEndBar');
// Elohim, segunda figura del manuscrito: Alef, Lamed y He comparten eje;
// el original lo dibuja en zigzag, asi que ningun trazo puede quedar tapado
await page.fill('#rosaHebrew', 'אלהים');
const elo = await page.evaluate(() => {
  const t = state.rosa.trace;
  let hidden = 0;
  for (let k = 1; k < t.length - 1; k++) for (let j = 0; j < k; j++) if (segmentsOverlap(t[j], t[j + 1], t[k], t[k + 1])) hidden++;
  return { path: t.map(v => v.he).join(''), shifted: t.filter(v => v.shifted).map(v => v.he).join(''), hidden };
});
check('elohim: recorrido א ל ה י מ como en la figura (la final ם usa el petalo de מ)', elo.path === 'אלהימ', elo.path);
check('elohim: ningun trazo tapado (zigzag)', elo.hidden === 0 && elo.shifted === 'ה', `apartado: ${elo.shifted}`);
await shot('rosa-elohim');

// Lamina "Tracing for Netzach" del manuscrito F: seis sigilos reales.
// Cada caso fija lo que se ve en la figura original.
async function traceOf(heb) {
  await page.fill('#rosaHebrew', heb);
  return page.evaluate(() => {
    const s = buildSVG();
    return {
      words: state.rosa.words.map(w => w.map(v => v.he).join('')),
      nooses: state.rosa.trace.filter(v => v.noose).map(v => v.he).join(''),
      passes: state.rosa.trace.filter(v => v.pass).map(v => v.pass.he).join(''),
      crooks: state.rosa.trace.filter(v => v.crook).map(v => v.he).join(''),
      starts: (s.match(/data-mark="start"/g) || []).length, ends: (s.match(/data-mark="end"/g) || []).length,
      noosePaths: (s.match(/data-mark="noose"/g) || []).length
    };
  });
}
const NETZACH = [
  // nombre, hebreo, palabras, lazos de paso, lazos de vertice
  ['NETZACH', 'נצח', ['נצח'], '', ''],
  ['YHVH TZABAOTH', 'יהוה צבאות', ['יהוה', 'צבאות'], '', ''],
  ['HANIEL', 'הניאל', ['הניאל'], 'א', ''],
  ['ELOHIM', 'אלהים', ['אלהימ'], '', ''],
  ['NOGAH', 'נגה', ['נגה'], '', ''],
  ['HAGIEL', 'הגיאל', ['הגיאל'], '', '']
];
for (const [name, heb, words, passes, nooses] of NETZACH) {
  const t = await traceOf(heb);
  const ok = JSON.stringify(t.words) === JSON.stringify(words) && t.passes === passes && t.nooses === nooses
    && t.starts === words.length && t.ends === words.length && t.noosePaths === passes.length + nooses.length;
  check(`lamina Netzach: ${name}`, ok, `palabras=${t.words.join('|')} paso=${t.passes || '-'} lazos=${t.nooses || '-'} circulos=${t.starts} barras=${t.ends}`);
}
// Nogah: la lamina tiene 2 trazos (נגה, sin Vav); con Vav serian 3
check('lamina Netzach: NOGAH con Vav daria otra figura', (await traceOf('נוגה')).words[0].length === 4);

// Hebreo directo y editable
await page.fill('#rosaName', 'שדי');
await page.click('#btnRosaGenerate');
check('hebreo directo: שדי = 314', await page.evaluate(() => gematria(state.rosa.hebrew).std === 314 && state.rosa.trace.length === 3));
await page.fill('#rosaHebrew', 'שד');
check('hebreo editable retraza', await page.evaluate(() => state.rosa.trace.length === 2));

// ARCANUM: finales y dos gematrias
await page.fill('#rosaName', 'Arcanum');
await page.click('#btnRosaGenerate');
const arc = await page.evaluate(() => ({ heb: state.rosa.hebrew, g: gematria(state.rosa.hebrew) }));
check('arcanum consonantico = ארכנום, 317 / gadol 877', arc.heb === 'ארכנום' && arc.g.std === 317 && arc.g.gadol === 877, `${arc.heb} ${arc.g.std}/${arc.g.gadol}`);
await shot('rosa-arcanum');

// Letra a letra conserva el comportamiento anterior
await page.selectOption('#selTranslit', 'full');
await page.fill('#rosaName', 'VOLUNTAS');
await page.click('#btnRosaGenerate');
const vol = await page.evaluate(() => ({ n: [...state.rosa.hebrew].length, g: gematria(state.rosa.hebrew).std }));
check('letra a letra: VOLUNTAS 8 letras, 232', vol.n === 8 && vol.g === 232, `${vol.n} ${vol.g}`);
await page.selectOption('#selTranslit', 'consonantal');
await page.click('#famLetters');
await page.waitForTimeout(80);
check('vuelta a letras', (await snap()).svg.includes('data-layer="core"'));

// 13) Galeria: guardar y restaurar produce el mismo SVG
await page.evaluate(() => localStorage.clear());
await forge('AMOR DIOS', 'block');
await page.click('.chip[data-ch="A"]');
await page.click('#btnFlipV');
const saved = (await snap()).svg;
await page.click('#btnSave');
await forge('OTRA COSA', 'fusion');
await page.evaluate(() => restoreState(readGallery()[0].state));
await page.waitForTimeout(80);
check('galeria restaura el mismo signo', (await snap()).svg === saved);

// 13b) Kamea: tablas y nombres de Agrippa (lib. II, cap. 22)
await page.click('#famKamea');
const km = await page.evaluate(() => {
  const magic = KAMEAS.map(k => {
    const t = k.rows, n = t.length, m = n * (n * n + 1) / 2;
    const ok = t.every(r => r.reduce((a, b) => a + b) === m)
      && t[0].every((_, j) => t.reduce((a, r) => a + r[j], 0) === m)
      && t.reduce((a, r, i) => a + r[i], 0) === m && t.reduce((a, r, i) => a + r[n - 1 - i], 0) === m
      && JSON.stringify(t.flat().sort((a, b) => a - b)) === JSON.stringify([...Array(n * n)].map((_, i) => i + 1));
    return k.id + ':' + (ok ? 'ok' : 'FALLA');
  });
  const sums = KAMEAS.flatMap(k => k.names.map(n => [n[1], [...n[2]].reduce((a, ch) => a + kameaValue(ch), 0), n[3]]));
  return { magic, bad: sums.filter(([, got, want]) => got !== want), moon: KAMEA_BY_ID.moon.rows[0][7], n: sums.length };
});
check('kamea: las 7 tablas son cuadrados magicos', km.magic.every(x => x.endsWith(':ok')), km.magic.join(' '));
check('kamea: Luna fila 1 col 8 = 54 (errata "45" corregida)', km.moon === 54);
check(`kamea: los ${km.n} nombres suman lo que imprime Agrippa (finales 500-900)`, km.bad.length === 0, km.bad.map(b => b.join('=')).join(' '));

// Reduccion "Como Agrippa": reproduce sus figuras (Aiq Bekar hasta 6x6, ceros desde 7x7)
async function kcells(planet, he) {
  await page.selectOption('#selKameaPlanet', planet);
  await page.fill('#kameaHebrew', he);
  return page.evaluate(() => state.kamea.words.map(w => w.map(s => s.cell).join(',')).join(' | '));
}
const KCASES = [
  ['mars', 'Barzabel', 'ברצבאל', '2,2,9,2,1,3'],
  ['sun', 'Sorath', 'סורת', '6,6,2,4'],
  ['venus', 'Kedemel', 'קדמאל', '10,4,40,1,30'],
  ['mercury', 'Tiriel', 'טיריאל', '9,10,20,10,1,30'],
  ['mercury', 'Taftartarat', 'תפתרתרת', '40,8,40,20,40,20,40'],
  ['moon', 'Hasmodai', 'חשמודאי', '8,30,40,6,4,1,10']
];
for (const [pl, la, he, want] of KCASES) {
  const got = await kcells(pl, he);
  check(`kamea como Agrippa: ${la}`, got === want, got);
}
// Trazo al estilo de sus caracteres
const kshape = async (pl, he) => { await kcells(pl, he); return page.evaluate(() => { const s = buildSVG(); return { det: s === buildSVG(), starts: (s.match(/data-mark="start"/g) || []).length, endCircle: /data-mark="end" d="M [^"]* A /.test(s), repeat: (s.match(/data-mark="repeat"/g) || []).length, hairpin: / C /.test((s.match(/data-mark="line" d="([^"]+)"/) || [])[1] || ''), core: s.includes('data-layer="core"') }; }); };
const agiel = await kshape('saturn', 'אגיאל');
check('kamea Agiel: horquilla, circulo en ambos extremos, determinista', agiel.hairpin && agiel.starts === 1 && agiel.endCircle && agiel.det && !agiel.core);
const sor = await kshape('sun', 'סורת');
check('kamea Sorath: gancho de la casilla 6 repetida al inicio', sor.repeat === 1);
await page.selectOption('#selKameaEnds', 'gd');
check('kamea: extremos al estilo Aurora Dorada (barra)', await page.evaluate(() => !/data-mark="end" d="M [^"]* A /.test(buildSVG())));
await page.selectOption('#selKameaEnds', 'agrippa');
const presets = await page.evaluate(() => { const out = {}; for (const k of KAMEAS) { document.getElementById('selKameaPlanet').value = k.id; document.getElementById('selKameaPlanet').dispatchEvent(new Event('change')); out[k.id] = document.querySelectorAll('#kameaPresets button').length; } return out; });
check('kamea: botones con los nombres de Agrippa por planeta', Object.values(presets).every(n => n >= 2), JSON.stringify(presets));
await page.selectOption('#selKameaPlanet', 'mars');
await page.click('#kameaPresets button >> nth=0');
check('kamea Grafiel: la app avisa de que su figura no se reproduce', await page.evaluate(() => /no sale de esta tabla/.test(document.getElementById('kameaBox').innerText)));
await page.click('#btnKameaProv');
const kprov = await page.evaluate(() => document.getElementById('provBody').innerText + '\n' + document.getElementById('kameaBox').innerText);
await page.click('#btnProvClose');
const mk = kprov.match(/\[(HP|OM|RC|AR)\]|\b(the|with|of the|shall|wise searcher)\b/i);
check('kamea: procedencia en espanol', !mk, mk ? 'encontrado: ' + mk[0] : '');
await page.click('#famLetters');


// 14) Todo el texto visible en espanol: sin codigos internos ni citas en ingles
// (el original en ingles solo puede vivir en tooltips)
const ENGLISH = /\[(HP|OM|RC|AR)\]|\b(the|with|of the|from the|Sigils|Pleasure|Practical|Basic Sigil|Lamen\.svg|Mispar|noose|crook|recognizable|pattee|botonnee)\b/i;
async function visibleText() {
  await page.click('#btnProvenance').catch(() => {});
  await page.waitForTimeout(80);
  const t = await page.evaluate(() => [document.getElementById('provBody'), document.getElementById('reductionBox'), document.getElementById('rosaBox'), document.getElementById('controlPanel')].map(e => e.innerText).join('\n'));
  await page.click('#btnProvClose').catch(() => {});
  return t;
}
await forge('HACIA EL HORIZONTE', 'cross');
await page.click('#btnTermPick');
await page.click('.term-btn[data-t="pattee"]');
const endPx2 = await page.evaluate(() => {
  const e = freeEnds(state.prims.filter(p => !p.hidden))[0], q = toCanvas(e), r = canvas.getBoundingClientRect();
  return { x: r.left + q.x / SIZE * r.width, y: r.top + q.y / SIZE * r.height };
});
await page.mouse.click(endPx2.x, endPx2.y);
await page.click('#btnTermPick');
const tLetters = await visibleText();
const m1 = tLetters.match(ENGLISH);
check('procedencia de letras en espanol', !m1, m1 ? 'encontrado: ' + m1[0] : '');
await page.click('#famRosa');
await page.fill('#rosaName', 'Metatron');
await page.click('#btnRosaGenerate');
await page.click('#btnRosaProv');
await page.waitForTimeout(80);
const tRosa = await page.evaluate(() => document.getElementById('provBody').innerText + '\n' + document.getElementById('rosaBox').innerText);
await shot('prov-rosa');
await page.click('#btnProvClose');
const m2 = tRosa.match(ENGLISH);
check('procedencia de la Rosa en espanol', !m2, m2 ? 'encontrado: ' + m2[0] : '');
const origs = await page.evaluate(() => [...document.querySelectorAll('#provBody q')].every(q => q.title.startsWith('Original en inglés')));
check('citas con original en tooltip', origs);
const termTitles = await page.evaluate(() => [...document.querySelectorAll('.term-btn')].map(b => b.title).join(' | '));
check('tooltips de remates sin codigos', !/\[/.test(termTitles), termTitles.slice(0, 60));
await page.click('#famLetters');

check('sin errores de pagina', errors.length === 0, errors.slice(0, 2).join(' | '));
await browser.close();
const fails = results.filter(x => !x.ok).length;
console.log(`\n==== ${results.length} checks, ${fails} FAIL ====`);
process.exit(fails ? 1 : 0);
