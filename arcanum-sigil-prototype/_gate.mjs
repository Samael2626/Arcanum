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
await page.fill('#rosaName', 'VOLUNTAS');
await page.click('#btnRosaGenerate');
await page.waitForTimeout(120);
const rosa = await page.evaluate(() => {
  const s = buildSVG();
  return {
    n: state.rosa.resolved.length, det: s === buildSVG(), rose: s.includes('data-layer="rose"'), core: s.includes('data-layer="core"'),
    marks: s.includes('data-mark="start"') && s.includes('data-mark="end"'), heb: (s.match(/[\u0590-\u05FF]/g) || []).length,
    gem: /Gematría\s*232/.test(document.getElementById('rosaBox').textContent)
  };
});
check('rosa-cruz: 8 letras de VOLUNTAS', rosa.n === 8, rosa.n + '');
check('rosa-cruz: gematria 232', rosa.gem);
check('rosa-cruz: determinista, marcas inicio/fin', rosa.det && rosa.rose && rosa.marks);
check('rosa-cruz: sin mezcla con sigilo de letras', !rosa.core);
check('rosa-cruz: diagrama de 22 letras', rosa.heb >= 22, rosa.heb + '');
await shot('rosa');
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

check('sin errores de pagina', errors.length === 0, errors.slice(0, 2).join(' | '));
await browser.close();
const fails = results.filter(x => !x.ok).length;
console.log(`\n==== ${results.length} checks, ${fails} FAIL ====`);
process.exit(fails ? 1 : 0);
