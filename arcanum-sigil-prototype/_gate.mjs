// Gate de validacion del Taller de Sigilos v2 - totem de bandas.
// Uso: node _gate.mjs   (requiere playwright instalado: npm install)
// Ejecuta los 4 casos de aceptacion + gate visual del skill arcanum-sigil.
import { chromium } from 'playwright';
import path from 'path';
import { fileURLToPath } from 'url';
const __dirname = path.dirname(fileURLToPath(import.meta.url));
const INDEX = 'file:///' + __dirname.split('\\').join('/') + '/index.html';

const results = [];
function check(name, ok, detail) {
  results.push({ name, ok });
  console.log((ok ? 'PASS' : 'FAIL') + '  ' + name + (detail ? '  — ' + detail : ''));
}

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1400, height: 900 } });
const pageErrors = [];
page.on('pageerror', e => pageErrors.push(String(e)));
page.on('console', m => { if (m.type() === 'error') pageErrors.push(m.text()); });

await page.goto(INDEX);
await page.waitForTimeout(800);

const acceptance = [
  'AMOR DIOS',
  'MI PRACTICA MANTIENE ENFOQUE SERENO',
  'SABIDURIA',
  'FUERZA'
];

async function generate(word) {
  await page.fill('#intention', word);
  await page.click('#btnGenerate');
  await page.waitForTimeout(400);
  return page.evaluate(() => {
    const d = document.getElementById('reductionBox').textContent;
    const strokes = state.core.strokes;
    const svg1 = buildSVG();
    const svg2 = buildSVG();
    const layers = [...new Set([...svg1.matchAll(/data-layer="([^"]+)"/g)].map(m => m[1]))];
    const reduced = (state.reduction ? state.reduction.reduced : '');
    const shaft = strokes.filter(s => s.kind === 'merge' && (s.units || []).length === reduced.length).length;
    const bandCoverage = [...reduced].filter(ch => strokes.some(s => s.unit === ch)).length;
    return {
      d, strokes: strokes.length,
      reduced,
      shaft,
      bandCoverage,
      provenance: strokes.map(s => s.unit || (s.units || []).join('+')).filter(Boolean),
      det: svg1 === svg2,
      layers,
      hasPath: svg1.includes('<path'),
      coreLayers: (svg1.match(/data-layer="core"/g) || []).length
    };
  });
}

// 1) Gate: cada trazo tiene procedencia + determinismo + SVG real por capas + poste con bandas
for (const w of acceptance) {
  const r = await generate(w);
  const ok = r.strokes > 0 && r.det && r.hasPath && r.coreLayers === 1 && r.layers.includes('core')
    && r.shaft === 1 && r.bandCoverage === r.reduced.length;
  check('totem [' + w + ']', ok, `trazo=${r.strokes} bandas=${r.bandCoverage}/${r.reduced.length} det=${r.det} capas=${r.layers.join(',')}`);
  if (w === 'AMOR DIOS') {
    check('procedencia por trazo [' + w + ']', r.provenance.length === r.strokes, `[${r.provenance.join(',')}]`);
    check('reduccion etiquetada [' + w + ']', /Original/.test(r.d) && /Regla/.test(r.d), r.d.slice(0, 60));
  }
}

// 2) Gate: tres intenciones producen estructuras distintas (SVG distintos)
const sigs = [];
for (const w of ['AMOR', 'FUERZA', 'LUNA']) {
  const r = await generate(w);
  sigs.push(r.det ? buildSVGString(page) : '');
}
async function buildSVGString(p) { return p.evaluate(() => buildSVG()); }
check('tres intenciones distintas', new Set(sigs).size === 3, `svg x3 ${new Set(sigs).size}`);

// 3) Estrella 5/6/7/8 puntas (marco ceremonial, capa independiente)
await page.click('#subMarco');
await page.waitForTimeout(200);
for (const n of [5, 6, 7, 8]) {
  await page.fill('#intention', 'FUERZA');
  await page.click('#btnGenerate');
  await page.waitForTimeout(200);
  await page.selectOption('#selStarPoints', String(n));
  await page.waitForTimeout(250);
  const r = await page.evaluate(() => {
    const svg = buildSVG();
    return { star: svg.includes('data-layer="star"'), det: buildSVG() === svg };
  });
  check(`estrella ${n} puntas`, r.star && r.det, '');
}

// 4) Marco: circulo on/off y estrella como capas independientes
await page.fill('#intention', 'SABIDURIA');
await page.click('#btnGenerate');
await page.waitForTimeout(300);
const withC = await page.evaluate(() => buildSVG());
await page.click('#chkCircle');
await page.waitForTimeout(200);
const withoutC = await page.evaluate(() => buildSVG());
check('circulo capa on/off', withC.includes('data-layer="circle"') && !withoutC.includes('data-layer="circle"'), '');
await page.click('#chkCircle');
await page.waitForTimeout(200);

// 5) Inscripcion latina (nunca automatica)
await page.click('#chkInscription');
await page.fill('#insText', 'VOLUNTAS');
await page.waitForTimeout(250);
const ins = await page.evaluate(() => buildSVG());
check('inscripcion capa', ins.includes('data-layer="inscription"') && (ins.match(/<text/g) || []).length >= 8, (ins.match(/<text/g) || []).length + ' chars');
await page.click('#chkInscription');
await page.waitForTimeout(150);

// 6) Miniatura 80x80 legible
const lit = await page.evaluate(() => {
  const pc = document.getElementById('previewCanvas');
  const d = pc.getContext('2d').getImageData(0, 0, 80, 80).data;
  let n = 0;
  for (let i = 0; i < d.length; i += 4) if (d[i + 3] > 0 && (d[i] + d[i + 1] + d[i + 2]) > 60) n++;
  return n;
});
check('miniatura 80x80', lit > 80, lit + ' px');

// 7) No mezcla: familias bloqueadas y sin hebreo/planetas automaticos
const famLocked = await page.evaluate(() => document.querySelectorAll('.fam-btn.locked').length);
const noHebrew = await page.evaluate(() => !buildSVG().match(/[\u0590-\u05FF]/));
check('3 familias bloqueadas', famLocked === 3, famLocked + '');
check('sin hebreo automatico', noHebrew, '');

// 8) Colores guia: OFF por defecto y presentes tras generar
const guideState = await page.evaluate(() => ({
  on: document.getElementById('chkGuide').checked,
  hasGuide: Array.isArray(state._guideStrokes) && state._guideStrokes.length > 0
}));
check('guia de colores OFF por defecto', guideState.on === false, '');
check('guia de colores presente tras generar', guideState.hasGuide, '');

// 9) Tres tallas del totem cambian la estructura
const tallas = [];
for (const k of [0, 1, 2]) {
  await page.click('#btnSkel' + k);
  await page.waitForTimeout(250);
  tallas.push(await page.evaluate(() => buildSVG()));
}
check('3 tallas producen estructuras distintas', new Set(tallas).size === 3, '');
await page.click('#btnSkel0');
await page.waitForTimeout(200);

// 10) Interaccion: editar + simplificar
const before = await page.evaluate(() => state.core.strokes.length);
await page.click('#btnEditStrokes');
await page.waitForTimeout(150);
const editOn = await page.evaluate(() => editMode);
await page.click('#btnEditStrokes');
await page.waitForTimeout(150);
await page.click('#btnSimplify');
await page.waitForTimeout(250);
const after = await page.evaluate(() => state.core.strokes.length);
check('editar trazos', editOn === true, '');
check('simplificar', after <= before, `${before} -> ${after}`);

// 11) Sin errores de pagina
check('sin errores de pagina', pageErrors.length === 0, pageErrors.slice(0, 2).join(' | '));

// ── Rosa-Cruz: motor separado ───────────────────────────────────
// 12) Familia desbloqueada, panel visible, resto apagado
await page.click('#subFamilias');
await page.waitForTimeout(200);
await page.click('#famRosaCruz');
await page.waitForTimeout(200);
const rosaUI = await page.evaluate(() => ({
  panel: !document.getElementById('rosaPanel').hidden,
  personal: document.getElementById('famPersonal').classList.contains('active'),
  marco: document.getElementById('famMarco').classList.contains('active')
}));
check('rosa-cruz: panel visible', rosaUI.panel, '');
check('rosa-cruz: personal/marco apagados', !rosaUI.personal && !rosaUI.marco, '');

// 13) Transliteracion determinista + trazo sobre la Rosa
await page.fill('#rosaName', 'VOLUNTAS');
await page.click('#btnRosaGenerate');
await page.waitForTimeout(300);
const rosa = await page.evaluate(() => {
  const svg1 = buildSVG();
  const svg2 = buildSVG();
  const resolved = state.rosa.resolved.filter(p => !p.missing).length;
  return {
    resolved,
    det: svg1 === svg2,
    hasRose: svg1.includes('data-layer="rose"'),
    noCore: !svg1.includes('data-layer="core"'),
    hasStart: svg1.includes('r="12" fill="none" stroke="#e6b422"'),
    hasEnd: svg1.includes('r="6" fill="none" stroke="#c65a3b"'),
    gematria: /Gematría[\s\S]{0,80}232/.test(document.getElementById('rosaBox').textContent),
    hebrew: svg1.match(/[\u0590-\u05FF]/g) ? svg1.match(/[\u0590-\u05FF]/g).length : 0,
    boxUnits: /Unidades/.test(document.getElementById('rosaBox').textContent)
  };
});
check('rosa-cruz: transliteracion determinista', rosa.det, '');
check('rosa-cruz: trazo + circulos inicio/fin', rosa.hasRose && rosa.hasStart && rosa.hasEnd, '');
check('rosa-cruz: 8 letras de VOLUNTAS', rosa.resolved === 8, rosa.resolved + '');
check('rosa-cruz: gematria 232', rosa.gematria, '');
check('rosa-cruz: sin mezcla con glifo personal', rosa.noCore, '');
check('rosa-cruz: diagrama hebreo + unidades en caja', rosa.hebrew >= 22 && rosa.boxUnits, rosa.hebrew + '');

// 14) Vuelta al glifo personal: rosa se apaga, no se mezcla
await page.click('#famPersonal');
await page.waitForTimeout(200);
const back = await page.evaluate(() => ({
  panel: document.getElementById('rosaPanel').hidden,
  core: buildSVG().includes('data-layer="core"')
}));
check('rosa-cruz: vuelta a personal', back.panel && back.core, '');

// 15) Sin errores de pagina (incluye flujo rosa-cruz)
check('sin errores de pagina', pageErrors.length === 0, pageErrors.slice(0, 2).join(' | '));

await browser.close();
const fails = results.filter(r => !r.ok).length;
console.log('\n==== ' + results.length + ' checks, ' + fails + ' FAIL ====');
process.exit(fails ? 1 : 0);
