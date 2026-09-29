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
// la interfaz arranca en basico: se comprueba y se pasa a avanzado para los tests
const basic = await page.evaluate(() => ({ adv: document.body.classList.contains('adv'), reduc: !!document.getElementById('selReduction').offsetParent, intent: !!document.getElementById('intention').offsetParent }));
await page.evaluate(() => setLevel(true));
// paletas: el catalogo se abre con su boton
const addL = async (t, scope = 'letters') => { await page.click(`#btnAddLayer_${scope}`); await page.click(`#addPalette_${scope} [data-add="${t}"]`); };
const stamp = async name => { await page.click('#btnAddLayer_letters'); await page.click(`#stampCatalog .stamp-btn[title="${name}"]`); };
const term = async id => { await page.click('#btnTermPalette'); await page.click(`.term-btn[data-t="${id}"]`); };
const preset = async (fmt, scope = 'personal') => { await page.click(`#btnAddLayer_${scope}`); await page.click(`#layersHost_${scope} [data-preset="${fmt}"]`); };

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

// 9) Capas: marcos anidados, estrellas, inscripcion y simbolos
const layerSvg = type => page.evaluate(t => (buildSVG().match(new RegExp(`<g data-layer="${t}">[\\s\\S]*?</g>`)) || [''])[0], type);
const noBorder = (await snap()).svg;
await addL('circle');
const withBorder = (await snap()).svg;
check('capa circulo on/off', !noBorder.includes('data-layer="circle"') && withBorder.includes('data-layer="circle"'));
// varias capas a la vez, cada una dentro de la anterior
for (const t of ['square', 'triangle', 'ringLatin', 'ringHebrew', 'star', 'inscription']) await addL(t);
const nest = await page.evaluate(() => {
  const lay = layoutLayers(state.layers, layerCtx('letters'));
  const Rs = lay.parts.filter(p => p.R).map(p => p.R);
  return { n: lay.parts.length, down: Rs.every((r, i) => !i || r < Rs[i - 1]), contentR: lay.contentR, last: Rs[Rs.length - 1], det: buildSVG() === buildSVG() };
});
check('capas: 7 marcos apilados, cada uno dentro del anterior', nest.n === 7 && nest.down && nest.det, JSON.stringify(nest));
check('capas: el sigilo cabe en el hueco final', await page.evaluate(() => { const r = layoutLayers(state.layers, layerCtx('letters')).contentR; return state.view.k * Math.SQRT2 * Math.max(...state.prims.flatMap(p => primPoints(p).map(q => Math.max(Math.abs(q.x - state.view.cx), Math.abs(q.y - state.view.cy))))) <= r + 1; }));
await shot('capas-apiladas');
// tamano y giro: una capa puede cruzarse con las demas
const crossL = await page.evaluate(() => { const L = state.layers.find(q => q.type === 'square'); const before = buildSVG(); L.scale = 150; L.rot = 45; render(); return before !== buildSVG(); });
check('capas: tamano y giro cambian la capa', crossL);
// orden: subir y bajar
const order = await page.evaluate(() => { const ids = state.layers.map(L => L.id); moveLayer('letters', ids[1], -1); const ok = state.layers[0].id === ids[1]; moveLayer('letters', ids[1], 1); return ok && state.layers[1].id === ids[1]; });
check('capas: reordenar sube y baja', order);
// estrellas de 5 a 9 puntas, angulosa exacta y ancha
await page.evaluate(() => { state.layers = []; layersChanged('letters'); });
const starL = await page.evaluate(() => addLayer('letters', 'star').id);
for (const n of [5, 6, 7, 8, 9]) {
  const st = await page.evaluate(([id, n]) => { const L = layerById('letters', id); L.points = n; render(); const g = (buildSVG().match(/<g data-layer="star">[\s\S]*?<\/g>/) || [''])[0]; const geo = layerGeom(L, 300, layerCtx('letters')); const tips = geo.vertices; return { paths: (g.match(/<path/g) || []).length, ratio: Math.hypot(tips[1][0] - C, tips[1][1] - C) / Math.hypot(tips[0][0] - C, tips[0][1] - C), want: starRatio(n, STAR_STEP[n]) }; }, [starL, n]);
  check(`estrella ${n} puntas angulosa exacta`, st.paths === n + 1 && Math.abs(st.ratio - st.want) < .002, `${st.paths - 1} acordes, ${st.ratio.toFixed(3)}`);
  if ([5, 7, 9].includes(n)) await shot(`star-${n}`);
}
check('estrella de 5 = pentagrama (0,382)', await page.evaluate(id => { const L = layerById('letters', id); L.points = 5; const v = layerGeom(L, 300, layerCtx('letters')).vertices; return Math.abs(Math.hypot(v[1][0] - C, v[1][1] - C) / 300 - .382) < .002; }, starL));
check('estrella ancha disponible', await page.evaluate(id => { const L = layerById('letters', id); L.shape = 'wide'; const v = layerGeom(L, 300, layerCtx('letters')).vertices; L.shape = 'sharp'; return Math.hypot(v[1][0] - C, v[1][1] - C) / 300 > .45; }, starL));
check('estrella sin acordes', await page.evaluate(id => { const L = layerById('letters', id); L.chords = false; render(); const n = ((buildSVG().match(/<g data-layer="star">[\s\S]*?<\/g>/) || [''])[0].match(/<path/g) || []).length; L.chords = true; render(); return n === 1; }, starL));
check('estrella que contiene: el sigilo se encoge a su centro', await page.evaluate(id => { const a = layoutLayers(state.layers, layerCtx('letters')).contentR; const L = layerById('letters', id); L.contain = true; const b = layoutLayers(state.layers, layerCtx('letters')).contentR; L.contain = false; return b < a; }, starL));
// dos estrellas a la vez (5 y 7)
await page.evaluate(() => { addLayer('letters', 'star', { points: 7 }); });
check('capas: dos estrellas superpuestas', await page.evaluate(() => (buildSVG().match(/<g data-layer="star">/g) || []).length === 2));
// inscripcion y anillos con su propio texto
await page.evaluate(() => { state.layers = []; addLayer('letters', 'inscription', { text: 'VOLUNTAS' }); });
const insN = (await layerSvg('inscription')).split('<text').length - 1;
check('inscripcion 8 letras', insN === 8, insN + '');
await page.evaluate(() => { state.layers = []; addLayer('letters', 'ringLatin', { text: 'LUZ' }); addLayer('letters', 'ringHebrew', { text: 'אור' }); });
const rings = await page.evaluate(() => { const s = buildSVG(); const g = t => (s.match(new RegExp(`<g data-layer="${t}">[\\s\\S]*?</g>`)) || [''])[0]; return { lat: g('ringLatin').split('<text').length - 1, heb: /[א-ת]/.test(g('ringHebrew')) && !/[A-Z]</.test(g('ringHebrew')) }; });
check('dos anillos a la vez, cada uno con su texto', rings.lat === 3 && rings.heb, JSON.stringify(rings));
await page.evaluate(() => { state.layers = []; layersChanged('letters'); });
// Simbolos arcanos: catalogo, colocar (con iman), arrastrar, escalar, quitar
const cat = await page.evaluate(() => ({
  groups: document.querySelectorAll('#stampCatalog .stamp-group').length,
  btns: document.querySelectorAll('#stampCatalog .stamp-btn').length,
  named: [...document.querySelectorAll('#stampCatalog .stamp-btn')].every(b => b.title),
  modern: /[♅♆♇]/.test(document.getElementById('stampCatalog').textContent)
}));
check('catalogo de simbolos por grupos con nombre', cat.groups === 6 && cat.btns >= 39 && cat.named, `${cat.groups} grupos, ${cat.btns} simbolos`);
check('solo planetas clasicos', !cat.modern);
const syms = () => page.evaluate(() => state.layers.filter(L => L.type === 'symbol').map(L => ({ sym: L.sym, x: L.x, y: L.y, size: L.size })));
await stamp('Júpiter');
const box = await page.locator('#canvas').boundingBox();
const at = (fx, fy) => [box.x + box.width * fx, box.y + box.height * fy];
await page.mouse.click(...at(.15, .15));
let st1 = await syms();
const info1 = await page.evaluate(() => document.getElementById('ctxBar').hidden ? '' : document.getElementById('ctxName').textContent);
check('jupiter colocado como capa', st1.length === 1 && st1[0].sym.startsWith('♃') && (await page.evaluate(() => buildSVG().includes('data-layer="symbol"'))) && /Júpiter/.test(info1), info1);
await page.mouse.move(...at(.15, .15)); await page.mouse.down(); await page.mouse.move(...at(.85, .2), { steps: 5 }); await page.mouse.up();
st1 = await syms();
check('arrastrar simbolo lo mueve', st1[0].x > 600 && st1.length === 1, `x=${st1[0].x.toFixed(0)}`);
await page.click('#btnLayerBigger');
check('ampliar simbolo', await page.evaluate(() => { const L = state.layers.find(q => q.type === 'symbol'); return L.size > STAMP_SIZE && buildSVG().includes(`scale(${(L.size / 100).toFixed(4)})`); }));
await page.click('#btnLayerDelete');
check('quitar simbolo', (await syms()).length === 0 && !(await page.evaluate(() => buildSVG().includes('data-layer="symbol"'))));
// regresion: con «Colocar» activo, tocar un simbolo existente lo mueve, no crea otro
await stamp('Marte');
await page.mouse.click(...at(.2, .8));
const mars = (await syms()).find(q => q.sym.startsWith('♂'));
check('colocar se apaga solo tras poner un simbolo', await page.evaluate(() => !state.stampMode));
await stamp('Marte');
const nBefore = (await syms()).length;
const mx = box.x + box.width * mars.x / 800, my = box.y + box.height * mars.y / 800;
await page.mouse.move(mx, my); await page.mouse.down(); await page.mouse.move(mx + 60, my - 40, { steps: 4 }); await page.mouse.up();
const aft = await syms();
check('con colocar activo, arrastrar un simbolo lo mueve sin duplicarlo', aft.length === nBefore && aft.some(q => q.sym.startsWith('♂') && Math.abs(q.x - mars.x) > 20), `${nBefore} -> ${aft.length}`);
await page.keyboard.press('Delete');
check('Supr borra el simbolo seleccionado', (await syms()).length === nBefore - 1);

// guias: arrastrado cerca de la vertical del centro, se pega a x = 400
await stamp('Saturno');
await page.mouse.click(...at(.3, .1));
const s0 = (await syms())[0];
const cx0 = box.x + box.width * s0.x / 800, cy0 = box.y + box.height * s0.y / 800;
await page.mouse.move(cx0, cy0); await page.mouse.down();
await page.mouse.move(box.x + box.width * .493, cy0 + 12, { steps: 4 });
const gd = await page.evaluate(() => state.guides.map(g => g.k).join(','));
await page.mouse.up();
const s1 = (await syms())[0];
check('guias: el simbolo se pega a la vertical del centro', Math.abs(s1.x - 400) < .01 && /v|point/.test(gd), `x=${s1.x.toFixed(2)} guias=${gd}`);
check('guias: pocas a la vez (no satura)', gd.split(',').filter(Boolean).length <= 2, gd);
check('guias: desaparecen al soltar', await page.evaluate(() => state.guides.length === 0));
// con Alt se mueve libre
await page.mouse.move(box.x + box.width * .5, box.y + box.height * s1.y / 800); await page.mouse.down();
await page.keyboard.down('Alt');
await page.mouse.move(box.x + box.width * .507, box.y + box.height * s1.y / 800 + 5, { steps: 3 });
await page.keyboard.up('Alt');
await page.mouse.up();
check('guias: Alt mueve libre (sin pegarse)', await page.evaluate(() => Math.abs(state.layers.find(q => q.type === 'symbol').x - 400) > 2));
// giro con iman a multiplos de 15
check('giro con iman: 43 grados se pega a 45', await page.evaluate(() => snapAngle(43) === 45 && snapAngle(37) === 37));
// rejilla: solo en pantalla, nunca en el SVG
await page.click('#btnGrid');
check('rejilla polar visible y fuera del SVG', await page.evaluate(() => state.grid === 'polar' && !/data-layer="grid"/.test(buildSVG())));
await page.click('#btnGrid'); await page.click('#btnGrid');
check('rejilla: el icono del lienzo recorre polar, cuadrada y ninguna', await page.evaluate(() => state.grid === 'none'));
await shot('marco-completo');
// galeria: guarda y recupera las capas
await page.evaluate(() => { addLayer('letters', 'star', { points: 9 }); addLayer('letters', 'inscription', { text: 'VOLUNTAS' }); });
await page.evaluate(() => localStorage.clear());
await page.click('#btnSave');
await page.evaluate(() => { state.layers = []; layersChanged('letters'); });
await page.evaluate(() => restoreState(readGallery()[0].state));
const back = await page.evaluate(() => ({ star: state.layers.some(L => L.type === 'star' && L.points === 9), ins: (state.layers.find(L => L.type === 'inscription') || {}).text, syms: state.layers.filter(L => L.type === 'symbol').length, ui: document.querySelectorAll('#layerList_letters .layer-row').length }));
check('galeria recupera estrella, inscripcion y simbolos (capas)', back.star && back.ins === 'VOLUNTAS' && back.syms === 1 && back.ui === 3, JSON.stringify(back));
// guardados antiguos (borde, estrella, estampas) se convierten en capas
check('galeria antigua se migra a capas', await page.evaluate(() => { const l = legacyLayers({ border: 'circle', star: { enabled: true, points: 7, shape: 'sharp', inner: 50, chords: true }, inscription: { enabled: false }, stamps: [{ sym: '♄︎', x: 100, y: 100, size: 40 }] }); return l.map(L => L.type).join() === 'circle,star,symbol'; }));
await page.evaluate(() => { state.layers = []; layersChanged('letters'); });

// 9c) Terminales: catalogo, remate general y uno a uno
await forge('MI PRACTICA MANTIENE ENFOQUE SERENO', 'fusion');
const termIds = await page.evaluate(() => TERMINALS.map(t => t.id).filter(id => id !== 'none'));
check('catalogo de remates', termIds.length >= 13, termIds.join(','));
const freeN = await page.evaluate(() => freeEnds(state.prims.filter(p => !p.hidden)).length);
for (const id of termIds) {
  await term(id);
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
await term('pattee');
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

// Colores del Lamen (manuscrito F): los de Metatron son los que da Mathers
await page.check('#chkRosaColors');
await page.fill('#rosaHebrew', 'מטטרון');
const col = await page.evaluate(() => {
  const s = buildSVG();
  return { names: [...new Set(state.rosa.trace.map(v => v.he))].map(he => ROSE_COLORS[he][0]).join(', '),
    segs: (s.match(/data-mark="segment"/g) || []).length, grads: (s.match(/<linearGradient/g) || []).length, det: s === buildSVG(),
    synth: /cidra rojiza/.test(document.getElementById('rosaBox').innerText) };
});
check('rosa colores: Metatron = azul profundo, amarillo verdoso, naranja, rojo anaranjado, verde azulado (manuscrito F)',
  col.names === 'azul profundo, amarillo verdoso, naranja, rojo anaranjado, verde azulado', col.names);
check('rosa colores: un tramo degradado por paso, determinista, sintesis de Mathers', col.segs === 4 && col.grads === 4 && col.det && col.synth, JSON.stringify(col));
await page.uncheck('#chkRosaColors');

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
// Nombres biblicos con su grafia original y vista de lamina
await page.selectOption('#selKameaPlanet', 'saturn');
await page.fill('#kameaName', 'Samuel');
await page.click('#btnKameaGenerate');
const sam = await page.evaluate(() => ({ he: state.kamea.hebrew, cells: state.kamea.words[0].map(s => s.cell).join(','), svg: buildSVG() }));
check('kamea: Samuel se escribe שמואל (1 S 1:20), no סמול', sam.he === 'שמואל' && sam.cells === '3,4,6,1,3', `${sam.he} ${sam.cells}`);
check('kamea: vista de lamina por defecto (sin tabla, con rotulo)', !sam.svg.includes('data-layer="kamea-grid"') && sam.svg.includes('data-layer="caption"'));
await page.selectOption('#selKameaPlanet', 'moon');
await page.click('#kameaPresets button >> nth=1');
const rtl = await page.evaluate(() => { const w = kameaFit(state.kamea.words).map(ws => ws.reduce((a, q) => a + q.x, 0) / ws.length); return w; });
check('kamea: varias palabras de derecha a izquierda (Schedbarschemoth a la derecha)', rtl.length === 2 && rtl[0] > rtl[1], rtl.map(x => x.toFixed(0)).join(' > '));
await page.click('#btnProvenance');
const kprov = await page.evaluate(() => document.getElementById('provBody').innerText + '\n' + document.getElementById('kameaBox').innerText);
await page.click('#btnProvClose');
const mk = kprov.match(/\[(HP|OM|RC|AR)\]|\b(the|with|of the|shall|wise searcher)\b/i);
check('kamea: procedencia en espanol', !mk, mk ? 'encontrado: ' + mk[0] : '');
await page.click('#famLetters');


// 13c) Sello historico: catalogo reproducido, no generado
await page.click('#famSeal');
const scat = await page.evaluate(() => {
  const ag = SEALS_DATA.filter(s => s.src === 'agrippa1651');
  return {
    n: ag.length, pages: [...new Set(ag.map(s => s.page))].sort().join(','),
    paths: SEALS_DATA.every(s => s.paths.length && s.w > 0 && s.h > 0),
    sellos: ag.filter(s => s.kind === 'sello').length,
    roles: ag.filter(s => s.role).every(s => sealKameaName(s) && sealKameaName(s)[0] === s.role)
  };
});
check('sello: 23 piezas de Agrippa (7 sellos y 16 caracteres), pp. 244-252', scat.n === 23 && scat.sellos === 7 && scat.pages === '244,245,246,247,248,249,250,251,252', `${scat.n} piezas, paginas ${scat.pages}`);
check('sello: cada pieza tiene calco y cada caracter con nombre enlaza con la Kamea', scat.paths && scat.roles);
let sealErr = '';
for (const id of await page.evaluate(() => SEALS_DATA.map(s => s.id))) {
  const r = await page.evaluate(id => { selectSeal(id); const s = buildSVG(), s2 = buildSVG(); const g = SEAL_BY_ID[id].src === 'goetia1916'; return { det: s === s2, bad: /NaN|undefined/.test(s), desc: /<desc>[^<]*(Wellcome|Harold B\. Lee)/.test(s) && (g ? /<desc>[^<]*figura \d+/.test(s) : /<desc>[^<]*p\. 2\d\d/.test(s)), ok: !new DOMParser().parseFromString(s, 'image/svg+xml').querySelector('parsererror') }; }, id);
  if (!r.det || r.bad || !r.desc || !r.ok) sealErr += id + ' ';
}
check('sello: las 103 piezas pintan, SVG valido con atribucion de fuente y pagina o figura', !sealErr, sealErr);
// Goetia: 72 espiritus, 80 figuras, rangos de la lista clasificada (pp. 47-48)
const go = await page.evaluate(() => {
  const G = SEALS_DATA.filter(s => s.src === 'goetia1916');
  const spirits = new Set(G.map(s => s.spirit));
  const doubles = G.filter(s => s.second).map(s => s.name).join(',');
  const byS = {}; G.forEach(s => { byS[s.spirit] = s; });
  const two = Object.values(byS).filter(s => s.ranks.length === 2).length;
  const noRank = Object.values(byS).filter(s => !s.ranks.length).length;
  const pages = G.every(s => s.page >= 22 && s.page <= 45);
  const b = G.find(s => s.fig === 1);
  return { n: G.length, spirits: spirits.size, doubles, two, noRank, pages, bael: `${b.name}|${b.ranks}|${b.metals}|${b.page}`, figs: G.map(s => s.fig).join(',') === [...Array(80)].map((_, i) => i + 1).join(',') };
});
check('goetia: 80 figuras para 72 espiritus', go.n === 80 && go.spirits === 72 && go.figs, `${go.n}/${go.spirits}`);
check('goetia: los 8 sellos dobles del libro', go.doubles === 'Paimon,Beleth,Leraje,Bathin,Bune,Vepar,Uvall,Seere', go.doubles);
check('goetia: rangos de la lista clasificada (7 con doble titulo, ninguno sin rango)', go.two === 7 && go.noRank === 0, `dobles ${go.two}, sin rango ${go.noRank}`);
check('goetia: Bael rey, sello en oro, p. 22; paginas del texto entre 22 y 45', go.bael === 'Bael|Rey|oro|22' && go.pages, go.bael);
await page.selectOption('#selSealCollection', 'goetia1916');
await page.click('.seal-filter[data-p="Caballero"]');
check('goetia: filtro por rango (Caballero = Furcas)', await page.evaluate(() => [...document.querySelectorAll('.seal-card')].map(b => SEAL_BY_ID[b.dataset.id].name).join() === 'Furcas'));
await page.click('.seal-filter[data-p="all"]');
await page.click('.seal-card[data-id="goetia-09"]');
await page.click('#sealBox a[onclick*="goetia-10"]');
check('goetia: el sello doble enlaza con su pareja (Paimon 9 -> 10)', await page.evaluate(() => state.seal.id === 'goetia-10' && /figura 9/.test(document.getElementById('sealBox').innerText)));
await page.selectOption('#selSealCollection', 'agrippa1651');
await page.selectOption('#selSealView', 'facsimile');
await page.waitForFunction(() => { const i = document.getElementById('sealFacsimile'); return i.complete && i.naturalWidth > 0; }, null, { timeout: 5000 }).catch(() => {});
check('sello: facsimil del escaneo visible', await page.evaluate(() => { const i = document.getElementById('sealFacsimile'); return !i.hidden && i.complete && i.naturalWidth > 100; }));
await page.selectOption('#selSealView', 'trace');
await page.click('.seal-card[data-id="saturno-inteligencia"]');
await page.click('#btnSealKamea');
check('sello -> kamea: Agiel sobre Saturno', await page.evaluate(() => state.family === 'kamea' && state.kamea.planet === 'saturn' && state.kamea.hebrew === 'אגיאל'));
await page.click('#kameaBox button');
check('kamea -> sello: vuelve al caracter original de Agrippa', await page.evaluate(() => state.family === 'seal' && state.seal.id === 'saturno-inteligencia'));
await page.click('#btnProvenance');
const stext = await page.evaluate(() => document.getElementById('provBody').innerText + document.getElementById('sealBox').innerText);
await page.click('#btnProvClose');
const ms = stext.match(/\[(HP|OM|RC|AR)\]|(the|of the|with)/i);
check('sello: ficha y procedencia en espanol', !ms, ms ? 'encontrado: ' + ms[0] : '');
await page.click('#famLetters');

// 13d) Sello personal: sigilo propio en formato historico, declarado como nuevo
await forge('Samuel', 'fusion', 'cooper');
await page.click('#famPersonal');
const pers = {};
for (const fmt of ['goetia', 'pentaculo', 'agrippa']) {
  await preset(fmt);
  pers[fmt] = await page.evaluate(() => { const s = buildSVG(); return { s, det: s === buildSVG(), ok: !new DOMParser().parseFromString(s, 'image/svg+xml').querySelector('parsererror'), nan: /NaN|undefined/.test(s), texts: (() => { const g = new DOMParser().parseFromString(s, 'image/svg+xml').querySelector('[data-layer="personal-name"]'); return g ? g.querySelectorAll('text, [data-glyph]').length : 0; })(), sigil: /data-layer="personal-sigil"[\s\S]*<path/.test(s), honest: /No es un sello histórico/.test(s) }; });
}
check('sello personal: 3 plantillas distintas, deterministas y validas', new Set(Object.values(pers).map(x => x.s)).size === 3 && Object.values(pers).every(x => x.det && x.ok && !x.nan && x.sigil));
check('sello personal: Goetia con SAMUEL (6 letras) y el simbolo del planeta en el anillo', pers.goetia.texts === 7, pers.goetia.texts + '');
check('sello personal: pentaculo con el nombre en hebreo (שמואל) y el simbolo', pers.pentaculo.texts === 6 && /[א-ת]/.test(pers.pentaculo.s));
check('sello personal: el SVG declara que es un sello nuevo, no historico', Object.values(pers).every(x => x.honest));
const auto = await page.evaluate(() => personalPlanet() === DAY_RULER[new Date().getDay()]);
check('sello personal: planeta por defecto = regente del dia', auto);
await page.click('#famKamea');
await page.selectOption('#selKameaPlanet', 'mars');
await page.fill('#kameaName', 'Samuel'); await page.click('#btnKameaGenerate');
await page.click('#famPersonal');
await page.selectOption('#selPersonalSource', 'kamea');
const kp = await page.evaluate(() => ({ planet: personalPlanet(), locked: document.getElementById('selPersonalPlanet').disabled, metal: /metal: hierro/.test(buildSVG()) }));
check('sello personal: con Kamea el planeta es el de la tabla (Marte, hierro)', kp.planet === 'mars' && kp.locked && kp.metal, JSON.stringify(kp));
await page.selectOption('#selPersonalSource', 'letters');
// capas en el sello: plantilla Goetia + cruces + estrella de 7 + anillo hebreo por dentro
await preset('goetia');
const po = await page.evaluate(() => {
  state.personal.layers[0].sep = 'cross';
  addLayer('personal', 'star', { points: 7 });
  addLayer('personal', 'ringHebrew');
  const s = buildSVG();
  return { cross: (s.match(/data-glyph="✠"/g) || []).length, star: ((s.match(/<g data-layer="star">[\s\S]*?<\/g>/) || [''])[0].match(/<path/g) || []).length, heb: /[א-ת]/.test(s), layers: state.personal.layers.map(L => L.type).join() };
});
check('sello personal: capas combinadas (anillo con cruces, estrella de 7, anillo hebreo)', po.cross === 5 && po.star === 8 && po.heb, JSON.stringify(po));
check('sello personal: la descripcion nombra sus capas', await page.evaluate(() => /capas: Anillo latino, Estrella 7, Anillo hebreo/.test(buildSVG())));
await preset('goetia');
await page.click('#famLetters');
// Sigilo de letras: anillos con nombre
await forge('Amor', 'fusion', 'cooper');
await page.evaluate(() => { state.layers = []; addLayer('letters', 'ringLatin'); });
const lr = await page.evaluate(() => { const s = buildSVG(); return { n: (s.match(/<g data-layer="ringLatin">[\s\S]*?<\/g>/) || [''])[0].split('<text').length - 1 }; });
check('letras: anillo con la intencion (AMOR, 4 letras)', lr.n === 4, JSON.stringify(lr));
await page.evaluate(() => { state.layers = []; addLayer('letters', 'ringHebrew'); });
check('letras: anillo en hebreo', await page.evaluate(() => /[א-ת]/.test(buildSVG())));
await page.evaluate(() => { state.layers = []; layersChanged('letters'); });

// 13e) Comparar: el mismo nombre en los tres sistemas
await page.click('#famCompare');
await page.fill('#compareName', 'Samuel');
await page.selectOption('#selComparePlanet', 'saturn');
await page.click('#btnCompare');
const cmpR = await page.evaluate(() => { const s = buildSVG(); return { det: s === buildSVG(), ok: !new DOMParser().parseFromString(s, 'image/svg+xml').querySelector('parsererror'), nan: /NaN|undefined/.test(s), cells: ['letters', 'rosa', 'kamea'].every(c => { const k = s.indexOf(`data-layer="compare-${c}"`); return k >= 0 && s.indexOf('<path', k) > k; }), heb: state.rosa.hebrew === state.kamea.hebrew && state.rosa.hebrew === 'שמואל', letters: state.letters.map(l => l.ch).join(''), planet: state.kamea.planet }; });
check('comparar: tres sigilos del mismo nombre en una lamina', cmpR.det && cmpR.ok && !cmpR.nan && cmpR.cells, JSON.stringify(cmpR));
check('comparar: Samuel = SAMUEL en letras y שמואל en Rosa y Kamea (Saturno)', cmpR.heb && cmpR.letters === 'SAMUEL' && cmpR.planet === 'saturn');
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
await term('pattee');
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
await page.click('#btnProvenance');
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

// 15) Interfaz simplificada: basico, paletas, barra contextual, ayuda
check('arranca en basico: intencion visible, reduccion oculta', !basic.adv && basic.intent && !basic.reduc, JSON.stringify(basic));
await page.evaluate(() => setLevel(false));
const nBasic = await page.evaluate(() => [...document.querySelectorAll('#controlPanel button, #controlPanel select, #controlPanel input')].filter(e => e.offsetParent).length);
await page.evaluate(() => setLevel(true));
const nAdv = await page.evaluate(() => [...document.querySelectorAll('#controlPanel button, #controlPanel select, #controlPanel input')].filter(e => e.offsetParent).length);
check('basico muestra muchos menos controles que avanzado', nBasic <= 22 && nBasic < nAdv / 2, `basico ${nBasic}, avanzado ${nAdv}`);
check('sin numeros de paso ni boton de iman', await page.evaluate(() => !document.querySelector('.step-num') && !document.querySelector('.magnet-btn') && state.magnet === true));
check('paletas cerradas por defecto', await page.evaluate(() => [...document.querySelectorAll('.palette')].every(p => p.hidden)));
await page.click('#btnAddLayer_letters');
check('Añadir abre su paleta', await page.evaluate(() => !document.getElementById('addPalette_letters').hidden));
await page.mouse.click(5, 5);
check('tocar fuera cierra la paleta', await page.evaluate(() => document.getElementById('addPalette_letters').hidden));
const helpStep = page.locator('#lettersPanel .step').first();
const helpBefore = await helpStep.locator('p.helper').first().isVisible();
await helpStep.locator('.info-btn').click();
const helpAfter = await helpStep.locator('p.helper').first().isVisible();
check('ayuda oculta tras el boton i y visible al tocarlo', !helpBefore && helpAfter);
await helpStep.locator('.info-btn').click();
await forge('AMOR DIOS', 'fusion');
await page.evaluate(() => { state.sel = null; state.layerSel.letters = null; render(); });
check('sin seleccion no hay barra contextual', await page.evaluate(() => document.getElementById('ctxBar').hidden));
const dpt = await page.evaluate(() => { const p = state.prims.find(q => q.units.length === 1 && q.units[0] === 'D' && q.t === 'L'); const a = toCanvas(p.a), b = toCanvas(p.b), r = canvas.getBoundingClientRect(); return { x: r.left + (a.x + b.x) / 2 / SIZE * r.width, y: r.top + (a.y + b.y) / 2 / SIZE * r.height }; });
await page.mouse.click(dpt.x, dpt.y);
const cb = await page.evaluate(() => { const b = document.getElementById('ctxBar'), w = b.parentElement.getBoundingClientRect(), r = b.getBoundingClientRect(); return { shown: !b.hidden, name: document.getElementById('ctxName').textContent, letter: !document.getElementById('ctxLetter').hidden, inside: r.left >= w.left && r.right <= w.right && r.top >= w.top && r.bottom <= w.bottom }; });
check('tocar una letra en el lienzo muestra su barra, dentro del lienzo', cb.shown && cb.name === 'D' && cb.letter && cb.inside, JSON.stringify(cb));
const beforeRot = (await snap()).svg;
await page.click('#btnRotL');
check('la barra gira la letra', (await snap()).svg !== beforeRot);
await page.click('#btnLetterReset');
check('y la restaura', (await snap()).svg === beforeRot);
await page.evaluate(() => { state.sel = null; state.layers = []; layersChanged('letters'); });
await addL('star');
const lb = await page.evaluate(() => ({ shown: !document.getElementById('ctxBar').hidden, layer: !document.getElementById('ctxLayer').hidden, scale: state.layers[0].scale }));
await page.click('#btnLayerSmaller'); await page.click('#btnLayerRotR');
const la = await page.evaluate(() => ({ scale: state.layers[0].scale, rot: state.layers[0].rot }));
check('capa nueva seleccionada: su barra escala y gira', lb.shown && lb.layer && la.scale === lb.scale - 10 && la.rot === 15, JSON.stringify([lb, la]));
await page.click('#btnLayerDelete');
check('la barra quita la capa', await page.evaluate(() => state.layers.length === 0 && document.getElementById('ctxBar').hidden));
check('botones de la barra y del lienzo de 48 px o mas', await page.evaluate(() => { document.getElementById('ctxBar').hidden = false; document.getElementById('ctxLetter').hidden = false; document.getElementById('ctxLayer').hidden = false; const ok = [...document.querySelectorAll('.canvas-tools .tool:not([hidden]), #ctxBar .tool')].every(b => { const r = b.getBoundingClientRect(); return r.width >= 48 && r.height >= 48; }); render(); return ok; }));
for (const f of ['famRosa', 'famKamea', 'famSeal', 'famPersonal', 'famCompare']) {
  await page.click('#' + f);
  const ok = await page.evaluate(() => !!document.getElementById('btnProvenance').offsetParent && !!document.getElementById('btnSVG').offsetParent && !!document.getElementById('btnPNG').offsetParent);
  check(`${f}: fuentes y descargas en la esquina del lienzo`, ok);
}
await page.click('#famLetters');

// 16) Deshacer y rehacer, cache de capas, galeria de todas las familias
await forge('LUZ Y SOMBRA', 'fusion');
await page.evaluate(() => { state.layers = []; layersChanged('letters'); histCommit(); });
const h0 = (await snap()).svg;
await addL('star');
await page.evaluate(() => histCommit());
const h1 = (await snap()).svg;
await page.click('#btnUndo');
const hu = (await snap()).svg;
await page.click('#btnRedo');
const hr = (await snap()).svg;
check('deshacer quita la estrella y rehacer la devuelve', h1 !== h0 && hu === h0 && hr === h1);
await page.keyboard.press('Control+z');
check('Ctrl+Z deshace', (await snap()).svg === h0);
const stable = await page.evaluate(() => { const n = hist.past.length; histCommit(); return hist.past.length === n && hist.future.length === 1; });
check('restaurar no ensucia el historial (rehacer sigue disponible)', stable);
await page.keyboard.press('Control+y');
check('Ctrl+Y rehace', (await snap()).svg === h1);
// arrastrar una letra es un solo paso
const nPast = await page.evaluate(() => hist.past.length);
const lp = await page.evaluate(() => { const l = activeLetters()[0], q = toCanvas({ x: l.base.tx, y: l.base.ty }), p = state.prims.find(x => x.units.length === 1 && x.units[0] === l.ch && x.t === 'L'); const a = toCanvas(p.a), b = toCanvas(p.b), r = canvas.getBoundingClientRect(); return { x: r.left + (a.x + b.x) / 2 / SIZE * r.width, y: r.top + (a.y + b.y) / 2 / SIZE * r.height }; });
await page.mouse.move(lp.x, lp.y); await page.mouse.down(); await page.mouse.move(lp.x + 40, lp.y + 20, { steps: 8 }); await page.mouse.up();
await page.waitForTimeout(500);
check('arrastrar una letra entra como un solo paso', await page.evaluate(n => hist.past.length === n + 1, nPast));
await page.click('#btnUndo');
check('y se deshace de una vez', (await snap()).svg === h1);
// rosa: el historial cubre las otras familias
await page.click('#famRosa'); await page.fill('#rosaName', 'Rafael'); await page.click('#btnRosaGenerate');
await page.evaluate(() => histCommit());
const r1 = await page.evaluate(() => state.rosa.hebrew);
await page.fill('#rosaName', 'Gabriel'); await page.click('#btnRosaGenerate');
await page.evaluate(() => histCommit());
await page.click('#btnUndo');
check('deshacer en Rosa-Cruz vuelve al nombre anterior', await page.evaluate(r => state.rosa.hebrew === r && document.getElementById('rosaHebrew').value === r, r1), r1);
// galeria de Kamea: guarda y vuelve con planeta y hebreo
await page.evaluate(() => localStorage.clear());
await page.click('#famKamea'); await page.selectOption('#selKameaPlanet', 'jupiter'); await page.fill('#kameaName', 'Samuel'); await page.click('#btnKameaGenerate');
const kSvg = (await snap()).svg;
await page.evaluate(() => saveSigil());
await page.selectOption('#selKameaPlanet', 'moon'); await page.fill('#kameaName', 'Otro'); await page.click('#btnKameaGenerate');
await page.click('#famLetters');
await page.evaluate(() => { toggleGallery(true); document.querySelector('#galleryGrid img').click(); });
const kBack = await page.evaluate(() => ({ fam: state.family, planet: state.kamea.planet, svg: buildSVG(), fam0: readGallery()[0].family }));
check('galeria guarda y restaura una Kamea (familia, planeta, trazo)', kBack.fam === 'kamea' && kBack.planet === 'jupiter' && kBack.svg === kSvg && kBack.fam0 === 'kamea', JSON.stringify({ fam: kBack.fam, planet: kBack.planet }));
check('los sellos historicos no se guardan', await page.evaluate(() => { setFamily('seal'); const n = readGallery().length; saveSigil(); const ok = readGallery().length === n; setFamily('letters'); return ok; }));
check('cache de capas: misma entrada, mismo objeto', await page.evaluate(() => { const c = layerCtx('letters'), L = [newLayer('star')]; return layoutLayers(L, c) === layoutLayers(JSON.parse(JSON.stringify(L)), c); }));
await page.evaluate(() => localStorage.clear());

// 17) Simbolos vectoriales: no dependen de la fuente del sistema
check('los 39 simbolos del catalogo tienen dibujo propio', await page.evaluate(() => STAMP_CATALOG.every(([, items]) => items.every(i => hasGlyph(i.sym))) && ['☉', '☽', '☿', '♀', '♂', '♃', '♄', '✠'].every(hasGlyph)));
const gsvg = await page.evaluate(() => { state.layers = []; addLayer('letters', 'symbol', { sym: '♃︎' }); addLayer('letters', 'ringLatin', { symbol: 'mars', sep: 'cross' }); const s = buildSVG(); state.layers = []; layersChanged('letters'); return s; });
check('el SVG exportado no usa ninguna fuente de simbolos', !/Segoe UI Symbol/.test(gsvg) && /data-glyph="♃"/.test(gsvg) && /data-glyph="♂"/.test(gsvg) && /data-glyph="✠"/.test(gsvg));
check('los glifos son SVG valido', await page.evaluate(() => Object.keys(GLYPHS_ARCANE).every(k => !new DOMParser().parseFromString(`<svg xmlns="http://www.w3.org/2000/svg">${glyphSVG(k, 50, 50, 60, 0, '#000')}</svg>`, 'image/svg+xml').querySelector('parsererror'))));
check('la Rosa rotula planetas y signos con glifos', await page.evaluate(() => { setFamily('rosa'); const s = buildSVG(); setFamily('letters'); return (s.match(/data-glyph=/g) || []).length >= 19 && !/Segoe UI Symbol/.test(s); }));

check('sin errores de pagina', errors.length === 0, errors.slice(0, 2).join(' | '));
await browser.close();
const fails = results.filter(x => !x.ok).length;
console.log(`\n==== ${results.length} checks, ${fails} FAIL ====`);
process.exit(fails ? 1 : 0);
