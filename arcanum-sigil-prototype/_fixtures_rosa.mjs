// Referencias de la familia Rosa-Cruz para el puerto a Dart.
// Uso: CHROMIUM=<ruta> node _fixtures_rosa.mjs
//   -> arcanum_app/test/features/sigilos/fixtures/rosa.json + png_rosa/
// Aparte de _fixtures.mjs a proposito: no toca los fixtures ya validados.
import { chromium } from 'playwright';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const __dirname = path.dirname(fileURLToPath(import.meta.url));
const INDEX = 'file:///' + path.join(__dirname, 'index.html').replace(/\\/g, '/');
const DIR = path.join(__dirname, '..', 'arcanum_app', 'test', 'features', 'sigilos', 'fixtures');
const OUT = path.join(DIR, 'rosa.json');
const PNG_DIR = path.join(DIR, 'png_rosa');
fs.mkdirSync(PNG_DIR, { recursive: true });
for (const f of fs.readdirSync(PNG_DIR)) fs.rmSync(path.join(PNG_DIR, f));

const b = await chromium.launch({ executablePath: process.env.CHROMIUM || undefined });
const page = await b.newPage();
await page.goto(INDEX); await page.waitForTimeout(300);
const out = await page.evaluate(() => {
  const cases = [];
  const run = (c) => {
    const ro = state.rosa;
    Object.assign(ro, { colors: !!c.colors, diagram: c.diagram !== false, endBar: c.endBar !== false });
    applyStyle({ ...presetStyle(c.preset || 'pergamino') }, true);
    state.transparent = !!c.transparent;
    state.family = 'rosa';
    if (c.name) {
      document.getElementById('rosaName').value = c.name;
      document.getElementById('selTranslit').value = c.method || 'consonantal';
      rosaGenerate();
    } else {
      ro.name = ''; ro.tokens = null; ro.tokensFor = '';
      document.getElementById('rosaHebrew').value = c.hebrew;
      rosaTraceFromHebrew();
    }
    const vert = v => ({
      he: v.he, ch: v.ch, repeat: v.repeat, x: v.x, y: v.y, shifted: !!v.shifted, crook: v.crook, noose: v.noose, turn: v.turn,
      pass: v.pass ? { he: v.pass.he, d: v.pass.d, t: v.pass.t } : null,
      inDir: v.inDir, outDir: v.outDir
    });
    cases.push({
      ...c, hebrew: ro.hebrew, method: ro.method, style: state.style,
      words: ro.words.map(w => w.map(vert)), gematria: gematria(ro.hebrew),
      lines: [...document.querySelectorAll('#rosaBox .line')].map(l => [l.querySelector('b').innerText, l.querySelector('span').innerText]),
      svg: buildSVG()
    });
  };
  const NAMES = ['Metatron', 'Elohim', 'Samuel', 'Arcanum', 'VOLUNTAS', 'Marc', 'Haniel', 'Hagiel', 'Tzabaoth', 'Ana Maria', 'Luz y sombra', 'Karolvs', 'Gabriel', 'Rafael'];
  for (const name of NAMES) for (const method of ['consonantal', 'full']) {
    run({ name, method });
    run({ name, method, colors: true, preset: 'oro' });
  }
  // hebreo directo: nombres divinos, repeticiones, finales, varias palabras
  for (const hebrew of ['מטטרון', 'אלהים', 'יהוה', 'שדי', 'יהוה צבאות', 'צבאות', 'הניאל', 'הגיאל', 'אא', 'ממם', 'ששש', 'אמש', 'אבגדהוזחטיכלמנסעפצקרשת',
    'ך', 'מרך', 'שלום עולם', 'עשרה', 'א', 'תת', 'אתא', 'פרבדגתכ', 'שְׁמוּאֵל', 'נ', 'כככ ממ']) {
    run({ hebrew });
    run({ hebrew, colors: true, preset: 'burdeos' });
  }
  // opciones: sin diagrama, sin barra final, fondo transparente, otros estilos
  for (const [i, hebrew] of ['מטטרון', 'אלהים', 'שמואל', 'יהוה צבאות'].entries()) {
    run({ hebrew, diagram: false });
    run({ hebrew, endBar: false, preset: 'papel' });
    run({ hebrew, diagram: false, colors: true, transparent: true });
    run({ hebrew, colors: true, endBar: false, preset: ['lacre', 'plata', 'oro', 'papel'][i] });
  }
  run({ hebrew: '' });
  run({ hebrew: '', diagram: false });
  // muestra al azar con semilla fija: todas las letras, finales incluidas
  let seed = 20261004;
  const rnd = () => (seed = (seed * 1664525 + 1013904223) >>> 0) / 4294967296;
  const ALPHA = [...'אבגדהוזחטיכלמנסעפצקרשת', ...'ךםןףץ'];
  for (let n = 0; n < 70; n++) {
    const words = 1 + Math.floor(rnd() * 3);
    const hebrew = Array.from({ length: words }, () => Array.from({ length: 1 + Math.floor(rnd() * 8) }, () => ALPHA[Math.floor(rnd() * ALPHA.length)]).join('')).join(' ');
    run({ hebrew, colors: n % 3 === 0, diagram: n % 5 !== 0, endBar: n % 4 !== 0 });
  }
  return cases;
});
// el soporte (fibras del pergamino) ya tiene su paridad en los fixtures de letras: aqui solo la obra
const trimmed = out.map(c => ({ ...c, svg: c.svg.slice(c.svg.indexOf('<g data-layer="rose')) }));
fs.writeFileSync(OUT, JSON.stringify(trimmed));
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
  fs.writeFileSync(path.join(PNG_DIR, `ros${i}.png`), Buffer.from(url.split(',')[1], 'base64'));
  png++;
}
console.log(out.length, 'casos y', png, 'imagenes ->', DIR);
await b.close();
