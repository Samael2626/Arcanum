// Verifica export/catalogo-sellos.json: estructura, procedencia y que el trazo
// exportado se ve igual que el original (raster en Chromium, pieza a pieza).
// Uso: node _export_catalogo.mjs && node _verify_export.mjs
import fs from 'fs';
import vm from 'vm';
import path from 'path';
import { fileURLToPath } from 'url';
import { chromium } from 'playwright';
const dir = path.dirname(fileURLToPath(import.meta.url));
const exp = JSON.parse(fs.readFileSync(path.join(dir, 'export/catalogo-sellos.json'), 'utf8'));
const ctx = vm.createContext({ window: {} });
vm.runInContext(fs.readFileSync(path.join(dir, 'sellos/sellos.js'), 'utf8'), ctx);
vm.runInContext(fs.readFileSync(path.join(dir, 'sellos/goetia/goetia.js'), 'utf8'), ctx);
const orig = Object.fromEntries([...ctx.window.SEALS, ...ctx.window.GOETIA].map(s => [s.id, s]));

let fails = 0;
const check = (name, ok, detail = '') => { if (!ok) fails++; console.log((ok ? 'PASS' : 'FAIL') + '  ' + name + (detail ? '  - ' + detail : '')); };
const A = exp.items.filter(i => i.source === 'agrippa1651'), G = exp.items.filter(i => i.source === 'goetia1916');
const nums = s => (s.match(/-?\d+(?:\.\d+)?/g) || []).map(Number);

check('103 piezas: 23 de Agrippa y 80 de la Goetia', exp.items.length === 103 && A.length === 23 && G.length === 80, `${A.length}+${G.length}`);
check('ids unicos y todos los del original', new Set(exp.items.map(i => i.id)).size === 103 && exp.items.every(i => orig[i.id]));
check('cada pieza cita una fuente con licencia, edicion y escaneo', exp.items.every(i => { const s = exp.sources[i.source]; return s && s.license && s.edition && s.scan && s.work; }));
check('enlace al escaneo correcto en cada pieza', exp.items.every(i => i.scanUrl === `https://archive.org/details/${exp.sources[i.source].item}/page/n${i.leaf}/mode/1up`));
check('pagina, hoja y caja validas', exp.items.every(i => i.page > 0 && i.leaf > 0 && i.w > 0 && i.h > 0));
check('72 espiritus y 8 con sello doble', new Set(G.map(g => g.spirit)).size === 72 && G.length - 72 === 8, `${new Set(G.map(g => g.spirit)).size} espiritus`);
check('Goetia: nombre, rango y metal por pieza, rangos conocidos', G.every(g => g.name && g.ranks && g.metals && g.ranks.length === g.metals.length && g.ranks.every(r => exp.goetiaRanks.includes(r))));
check('Agrippa: planeta y tipo en cada pieza', A.every(a => a.planet && a.kind && a.title));
check('trazos y desplazamientos con numeros finitos', exp.items.every(i => i.paths.length && i.paths.every(([d, tx, ty]) => nums(d).every(Number.isFinite) && Number.isFinite(tx) && Number.isFinite(ty))));
check('mismo numero de trazos que el original', exp.items.every(i => i.paths.length === orig[i.id].paths.length && i.paths.every((p, k) => p[1] === orig[i.id].paths[k][1] && p[2] === orig[i.id].paths[k][2])));
check('mismo numero de comandos de trazo que el original (nada recortado)', exp.items.every(i => i.paths.every((p, k) => (p[0].match(/[A-Za-z]/g) || []).length === (orig[i.id].paths[k][0].match(/[A-Za-z]/g) || []).length)));

// raster: original y exportado, misma pieza, 240 px
const browser = await chromium.launch({ executablePath: process.env.CHROMIUM || undefined });
const page = await browser.newPage();
const worst = await page.evaluate(async ({ items, orig }) => {
  const draw = (s, paths) => {
    const c = document.createElement('canvas'); c.width = c.height = 240; const x = c.getContext('2d');
    x.fillStyle = '#fff'; x.fillRect(0, 0, 240, 240); const k = Math.min(228 / s.w, 228 / s.h);
    x.translate(6, 6); x.scale(k, k); x.fillStyle = '#000';
    for (const [d, tx, ty] of paths) { x.save(); x.translate(tx, ty); x.fill(new Path2D(d)); x.restore(); }
    return x.getImageData(0, 0, 240, 240).data;
  };
  let max = 0, id = '';
  for (const it of items) {
    const a = draw(it, orig[it.id].paths), b = draw(it, it.paths); let diff = 0, ink = 0;
    for (let i = 0; i < a.length; i += 4) { if (a[i] < 128) ink++; if (Math.abs(a[i] - b[i]) > 100) diff++; }
    const pct = 100 * diff / Math.max(ink, 1); if (pct > max) { max = pct; id = it.id; }
  }
  return { max, id };
}, { items: exp.items, orig });
check('raster: el trazo exportado se ve igual que el original (peor pieza < 0,5 % de la tinta)', worst.max < 0.5, `${worst.id} ${worst.max.toFixed(3)} %`);
await browser.close();
console.log(`\n==== ${fails} FAIL ====`);
process.exit(fails ? 1 : 0);
