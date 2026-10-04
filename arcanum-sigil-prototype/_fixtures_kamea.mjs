// Referencias de la familia Kamea para el puerto a Dart.
// Uso: CHROMIUM=<ruta> node _fixtures_kamea.mjs
//   -> arcanum_app/test/features/sigilos/fixtures/kamea.json
// Aparte de _fixtures.mjs a proposito: no toca los fixtures ya validados.
import { chromium } from 'playwright';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const __dirname = path.dirname(fileURLToPath(import.meta.url));
const INDEX = 'file:///' + path.join(__dirname, 'index.html').replace(/\\/g, '/');
const DIR = path.join(__dirname, '..', 'arcanum_app', 'test', 'features', 'sigilos', 'fixtures');
const OUT = path.join(DIR, 'kamea.json');
const PNG_DIR = path.join(DIR, 'png_kamea');
fs.mkdirSync(PNG_DIR, { recursive: true });
for (const f of fs.readdirSync(PNG_DIR)) fs.rmSync(path.join(PNG_DIR, f));

const b = await chromium.launch({ executablePath: process.env.CHROMIUM || undefined });
const page = await b.newPage();
await page.goto(INDEX); await page.waitForTimeout(300);
const out = await page.evaluate(() => {
  const cases = [];
  const run = (c) => {
    const km = state.kamea;
    Object.assign(km, { planet: c.planet, reduce: c.reduce, ends: c.ends, grid: c.grid });
    document.getElementById('selKameaPlanet').value = c.planet;
    document.getElementById('selKameaTranslit').value = c.translit || 'consonantal';
    document.getElementById('kameaName').value = c.name || '';
    if (c.name) { document.getElementById('kameaHebrew').value = hasHebrew(c.name) ? cleanHebrew(c.name) : transliterate(c.name, c.translit || 'consonantal').hebrew; }
    else document.getElementById('kameaHebrew').value = c.hebrew;
    applyStyle({ ...presetStyle(c.preset || 'pergamino') }, true);
    state.transparent = !!c.transparent;
    state.family = 'kamea';
    kameaTraceFromHebrew();
    const g = kameaGeom(KAMEA_BY_ID[c.planet]);
    cases.push({
      ...c, hebrew: km.hebrew, style: state.style, family: 'kamea',
      words: km.words.map(w => w.map(s => ({ ch: s.ch, v: s.v, cell: s.cell, reduced: s.reduced, x: s.x, y: s.y }))),
      fit: kameaFit(km.words).map(w => w.map(q => [q.x, q.y])),
      caption: kameaCaption(),
      svg: buildSVG()
    });
  };
  // cada nombre de Agrippa, con cada reduccion y los dos remates
  for (const k of KAMEAS) for (const n of k.names) for (const reduce of ['agrippa', 'zeros', 'aiq']) for (const ends of ['agrippa', 'gd']) {
    run({ planet: k.id, hebrew: n[2], reduce, ends, grid: false });
  }
  // vista sobre la tabla (cuadricula numerada)
  for (const k of KAMEAS) for (const n of k.names.slice(0, 1)) run({ planet: k.id, hebrew: n[2], reduce: 'agrippa', ends: 'agrippa', grid: true });
  // nombres propios por transliteracion, con los dos metodos y otros estilos
  for (const [name, planet, translit, preset] of [['Samuel', 'saturn', 'consonantal', 'pergamino'], ['Samuel', 'moon', 'full', 'oro'], ['Ana Maria', 'venus', 'consonantal', 'papel'],
    ['Karolvs', 'mars', 'full', 'lacre'], ['Luz y sombra', 'sun', 'consonantal', 'oro'], ['Marc', 'jupiter', 'consonantal', 'pergamino'], ['שמואל', 'mercury', 'consonantal', 'pergamino']]) {
    run({ planet, name, reduce: 'agrippa', ends: 'agrippa', grid: false, translit, preset });
    run({ planet, name, reduce: 'zeros', ends: 'gd', grid: true, translit, preset });
  }
  // casos limite: vacio, una letra, letras repetidas, finales, transparente
  run({ planet: 'saturn', hebrew: '', reduce: 'agrippa', ends: 'agrippa', grid: false });
  run({ planet: 'saturn', hebrew: 'א', reduce: 'agrippa', ends: 'agrippa', grid: false });
  run({ planet: 'saturn', hebrew: 'אא', reduce: 'agrippa', ends: 'agrippa', grid: false });
  run({ planet: 'moon', hebrew: 'ךםןףץ', reduce: 'zeros', ends: 'gd', grid: false });
  run({ planet: 'mars', hebrew: 'שלום עולם', reduce: 'aiq', ends: 'agrippa', grid: false, transparent: true });
  run({ planet: 'venus', hebrew: 'שְׁמוּאֵל', reduce: 'agrippa', ends: 'agrippa', grid: true });
  return cases;
});
fs.writeFileSync(OUT, JSON.stringify(out));
// imagen de referencia: Chromium rasteriza el SVG exportado sin texto (la
// fuente es de cada lado: Georgia en el SVG, Crimson Pro en la app)
let png = 0;
const p2 = await b.newPage();
for (const [i, c] of out.entries()) {
  if (i % 4) continue;
  const svg = c.svg.replace(/<text[^>]*>.*?<\/text>/g, '');
  const url = await p2.evaluate(svg => new Promise(res => {
    const img = new Image();
    img.onload = () => { const cv = document.createElement('canvas'); cv.width = cv.height = 400; cv.getContext('2d').drawImage(img, 0, 0, 400, 400); res(cv.toDataURL('image/png')); };
    img.src = 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(svg);
  }), svg);
  fs.writeFileSync(path.join(PNG_DIR, `kam${i}.png`), Buffer.from(url.split(',')[1], 'base64'));
  png++;
}
console.log(out.length, 'casos y', png, 'imagenes ->', DIR);
await b.close();
