// Referencias de Comparar. Uso: CHROMIUM=<chrome> node _fixtures_compare.mjs
import { chromium } from 'playwright';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.dirname(fileURLToPath(import.meta.url));
const dir = path.join(root, '..', 'arcanum_app', 'test', 'features', 'sigilos', 'fixtures');
const pngDir = path.join(dir, 'png_compare');
fs.mkdirSync(pngDir, { recursive: true });
const browser = await chromium.launch({ executablePath: process.env.CHROMIUM || (process.platform === 'win32' ? 'C:/Program Files/Google/Chrome/Application/chrome.exe' : undefined) });
const page = await browser.newPage();
await page.goto('file:///' + path.join(root, 'index.html').replace(/\\/g, '/'));
await page.waitForTimeout(300);
const cases = await page.evaluate(() => {
  const out = [];
  const run = c => {
    state.personal.day = c.day ?? 6;
    state.transparent = !!c.transparent;
    applyStyle({ ...presetStyle(c.preset ?? 'pergamino') }, true);
    document.getElementById('compareName').value = c.name;
    document.getElementById('selComparePlanet').value = c.planetChoice ?? 'auto';
    compareGenerate();
    const cells = ['letters', 'rosa', 'kamea'].map(src => {
      const markup = personalSourceMarkup(src);
      return { src, markup, bounds: measureMarkup(markup) };
    });
    out.push({ ...c, day: state.personal.day, planetChoice: c.planetChoice ?? 'auto',
      planet: state.compare.planet, style: state.style, hebrew: state.rosa.hebrew,
      letters: state.letters.map(l => l.ch).join(''),
      cells, svg: compareSVG() });
  };
  for (const [name, planetChoice] of [
    ['Samuel', 'saturn'], ['Ana Maria', 'venus'], ['Gabriel', 'jupiter'],
    ['Metatron', 'mars'], ['Karolvs', 'mercury'], ['Elohim', 'moon'],
  ]) run({ name, planetChoice });
  run({ name: 'Samuel', day: 0, transparent: true, preset: 'oro' });
  let seed = 20261005;
  const rnd = () => (seed = (seed * 1664525 + 1013904223) >>> 0) / 4294967296;
  const names = ['Samuel', 'Gabriel', 'Haniel', 'Luz y sombra', 'VOLUNTAS'];
  const planets = ['auto', 'sun', 'moon', 'mars', 'mercury', 'jupiter', 'venus', 'saturn'];
  for (let i = 0; i < 12; i++) run({ name: names[Math.floor(rnd() * names.length)],
    planetChoice: planets[Math.floor(rnd() * planets.length)], day: Math.floor(rnd() * 7),
    transparent: rnd() < .25, preset: ['pergamino', 'oro', 'lacre'][Math.floor(rnd() * 3)] });
  return out;
});
const stripPaper = svg => svg.replace(/<rect width="800" height="800" fill="#efe6d2"\/>/, '');
fs.writeFileSync(path.join(dir, 'compare.json'), JSON.stringify(cases.map(c => ({ ...c, svg: stripPaper(c.svg) }))));
const raster = await browser.newPage();
for (const [i, c] of cases.entries()) {
  if (i % 2) continue;
  const svg = stripPaper(c.svg).replace(/<text[^>]*>.*?<\/text>/g, '');
  const url = await raster.evaluate(svg => new Promise(resolve => {
    const image = new Image();
    image.onload = () => {
      const canvas = document.createElement('canvas');
      canvas.width = canvas.height = 400;
      canvas.getContext('2d').drawImage(image, 0, 0, 400, 400);
      resolve(canvas.toDataURL('image/png'));
    };
    image.onerror = () => resolve(null);
    image.src = 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(svg);
  }), svg);
  if (!url) throw Error(`No rasteriza el caso ${i}`);
  fs.writeFileSync(path.join(pngDir, `cmp${i}.png`), Buffer.from(url.split(',')[1], 'base64'));
}
console.log(`${cases.length} casos, ${Math.ceil(cases.length / 2)} imagenes`);
await browser.close();
