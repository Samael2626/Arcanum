// Referencias de Sello personal. Uso: CHROMIUM=<chrome> node _fixtures_personal.mjs
import { chromium } from 'playwright';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.dirname(fileURLToPath(import.meta.url));
const dir = path.join(root, '..', 'arcanum_app', 'test', 'features', 'sigilos', 'fixtures');
const pngDir = path.join(dir, 'png_personal');
fs.mkdirSync(pngDir, { recursive: true });
const browser = await chromium.launch({ executablePath: process.env.CHROMIUM || (process.platform === 'win32' ? 'C:/Program Files/Google/Chrome/Application/chrome.exe' : undefined) });
const page = await browser.newPage();
await page.goto('file:///' + path.join(root, 'index.html').replace(/\\/g, '/'));
await page.waitForTimeout(300);
const cases = await page.evaluate(() => {
  const out = [];
  const run = c => {
    state.personal.day = c.day ?? 6;
    state.personal.name = c.label ?? '';
    state.personal.source = c.source;
    state.personal.template = c.template;
    state.personal.planet = c.planet ?? 'auto';
    state.personal.view = c.view ?? 'paper';
    state.personal.layers = LAYER_PRESETS[c.template].make('personal');
    if (c.extra) for (const type of c.extra) state.personal.layers.push(newLayer(type));
    state.transparent = !!c.transparent;
    applyStyle({ ...presetStyle(c.preset ?? 'pergamino') }, true);
    if (c.source === 'letters') {
      state.method = c.method ?? 'unique';
      state.mode = c.mode ?? 'fusion';
      document.getElementById('intention').value = c.name;
      generate();
    } else if (c.source === 'rosa') {
      document.getElementById('rosaName').value = c.name;
      rosaGenerate();
    } else {
      state.kamea.planet = c.sourcePlanet ?? 'saturn';
      document.getElementById('selKameaPlanet').value = state.kamea.planet;
      document.getElementById('kameaName').value = c.name;
      kameaGenerate();
    }
    state.family = 'personal';
    const markup = personalSourceMarkup(c.source);
    const bounds = measureMarkup(markup);
    const layout = layoutLayers(state.personal.layers, layerCtx('personal'));
    const svg = buildSVG();
    out.push({ ...c, planetChoice: state.personal.planet, planet: personalPlanet(), name: personalName(), style: state.style,
      layers: state.personal.layers, bounds, contentR: layout.contentR,
      source: c.source, sourceMarkup: markup, svg });
  };
  for (const source of ['letters', 'rosa', 'kamea'])
    for (const template of ['goetia', 'pentaculo', 'agrippa'])
      for (const view of ['paper', 'metal'])
        run({ source, template, view, name: 'Samuel', sourcePlanet: 'mars', day: 6 });
  run({ source: 'letters', template: 'goetia', name: 'Ana Maria', planet: 'venus', extra: ['star', 'ringHebrew'] });
  run({ source: 'letters', template: 'agrippa', name: 'Karolvs', planet: 'moon', transparent: true, preset: 'oro' });
  run({ source: 'rosa', template: 'pentaculo', name: 'Metatron', planet: 'mercury', preset: 'lacre' });
  let seed = 20261005;
  const rnd = () => (seed = (seed * 1664525 + 1013904223) >>> 0) / 4294967296;
  const names = ['Gabriel', 'Haniel', 'Luz y sombra', 'VOLUNTAS', 'Elohim'];
  for (let i = 0; i < 12; i++) run({ source: ['letters', 'rosa', 'kamea'][Math.floor(rnd() * 3)],
    template: ['goetia', 'pentaculo', 'agrippa'][Math.floor(rnd() * 3)],
    name: names[Math.floor(rnd() * names.length)], view: rnd() < .5 ? 'paper' : 'metal',
    sourcePlanet: 'jupiter', day: Math.floor(rnd() * 7) });
  return out;
});
fs.writeFileSync(path.join(dir, 'personal.json'), JSON.stringify(cases.map(c => ({
  ...c, svg: c.svg.replace(/<rect width="800" height="800" fill="(?:#1a1612|#efe6d2)"\/>/, ''),
}))));
const raster = await browser.newPage();
for (const [i, c] of cases.entries()) {
  if (i % 3) continue;
  const svg = c.svg.replace(/<text[^>]*>.*?<\/text>/g, '').replace(/<rect width="800" height="800" fill="(?:#1a1612|#efe6d2)"\/>/, '');
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
  fs.writeFileSync(path.join(pngDir, `per${i}.png`), Buffer.from(url.split(',')[1], 'base64'));
}
console.log(`${cases.length} casos, ${Math.ceil(cases.length / 3)} imagenes`);
await browser.close();
