// Referencias de la caligrafia (curva y pluma) para el puerto a Dart.
// Uso: CHROMIUM=<ruta> node _fixtures_calli.mjs
//   -> arcanum_app/test/features/sigilos/fixtures/caligrafia.json + png_calli/
// Aparte de _fixtures.mjs a proposito: no toca los fixtures ya validados.
import { chromium } from 'playwright';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const __dirname = path.dirname(fileURLToPath(import.meta.url));
const INDEX = 'file:///' + path.join(__dirname, 'index.html').replace(/\\/g, '/');
const DIR = path.join(__dirname, '..', 'arcanum_app', 'test', 'features', 'sigilos', 'fixtures');
const PNG_DIR = path.join(DIR, 'png_calli');
fs.mkdirSync(PNG_DIR, { recursive: true });
for (const f of fs.readdirSync(PNG_DIR)) fs.rmSync(path.join(PNG_DIR, f));

const b = await chromium.launch({ executablePath: process.env.CHROMIUM || undefined });
const page = await b.newPage();
await page.goto(INDEX); await page.waitForTimeout(300);
const cases = await page.evaluate(() => {
  const SIG = [['Mi practica mantiene enfoque sereno', 'cooper', 'fusion'], ['KAROLVS', 'unique', 'cross'], ['AMOR DIOS', 'unique', 'block']];
  const LAYERSETS = [[], [['circle']]];
  const STYLES = [presetStyle('pergamino'), presetStyle('oro'), { ...STYLE_BASE, ...metalStyle('mars') }, presetStyle('flash-saturn'),
    { ...presetStyle('papel'), preset: 'propio', line: 'double', cap: 'square', width: 150 }, { ...presetStyle('lacre'), preset: 'propio', relief: true, glow: true, width: 80 }];
  const out = []; let n = 0;
  for (const [text, method, mode] of SIG) for (const calli of ['curva', 'pluma']) for (const ls of LAYERSETS) for (const st of STYLES) {
    n++;
    if (ls.length && n % 2) continue; // muestra: no todo con marco
    const terminals = ['none', 'pattee', 'star', 'ring'][n % 4];
    Object.assign(state, { method, mode, absorb: true, compact: true, overlap: 0, intention: '', hidden: [], endStyles: {}, terminals, termScale: 100, transparent: false });
    state.layers = ls.map(([t, extra]) => newLayer(t, extra || {}));
    applyStyle({ ...st, calli }, true);
    document.getElementById('intention').value = text;
    generate();
    if (n % 5 === 0) { const e = freeEnds(state.prims.filter(p => !p.hidden))[0]; if (e) state.endStyles = { [e.key]: 'lance' }; }
    out.push({ text, method, mode, layers: state.layers, style: state.style, terminals, endStyles: state.endStyles, transparent: false, svg: buildSVG() });
  }
  return out;
});
// imagen de referencia: Chromium rasteriza el SVG exportado (sin texto: solo geometria)
let png = 0;
const p2 = await b.newPage();
for (const [i, c] of cases.entries()) {
  if (i % 3) continue;
  const url = await p2.evaluate(svg => new Promise(res => {
    const img = new Image();
    img.onload = () => { const cv = document.createElement('canvas'); cv.width = cv.height = 400; cv.getContext('2d').drawImage(img, 0, 0, 400, 400); res(cv.toDataURL('image/png')); };
    img.src = 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(svg);
  }), c.svg);
  fs.writeFileSync(path.join(PNG_DIR, `cal${i}.png`), Buffer.from(url.split(',')[1], 'base64'));
  png++;
}
fs.writeFileSync(path.join(DIR, 'caligrafia.json'), JSON.stringify({ svgs: cases }));
await b.close();
const curva = cases.filter(c => c.style.calli === 'curva').length, pluma = cases.filter(c => c.style.calli === 'pluma').length;
console.log(`${cases.length} SVG (${curva} curva, ${pluma} pluma) y ${png} imagenes -> ${path.relative(process.cwd(), DIR)}`);
