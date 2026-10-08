// Exporta a la app solo los sellos de Agrippa 1651.
// Una sola fuente de verdad: lee sellos/sellos.js y SEAL_SOURCES de js/catalogo.js.
// Uso: node _export_catalogo.mjs   ->  export/catalogo-sellos.json
import fs from 'fs';
import vm from 'vm';
import path from 'path';
import { fileURLToPath } from 'url';
const dir = path.dirname(fileURLToPath(import.meta.url));
const read = f => fs.readFileSync(path.join(dir, f), 'utf8');
const ctx = vm.createContext({ window: {} });
vm.runInContext(read('sellos/sellos.js'), ctx);
const SOURCES = new vm.Script(read('js/catalogo.js') + '\n;SEAL_SOURCES').runInContext(ctx);

// 1 decimal: el escaneo mide ~600 px, una decima es imperceptible y quita ~35 %
const r1 = d => d.replace(/-?\d+\.\d+/g, n => String(+(+n).toFixed(1)));
const scanUrl = (src, leaf) => `https://archive.org/details/${SOURCES[src].item}/page/n${leaf}/mode/1up`;
const pick = (o, ks) => Object.fromEntries(ks.filter(k => o[k] != null && !(Array.isArray(o[k]) && !o[k].length)).map(k => [k, o[k]]));

const items = [
  ...ctx.window.SEALS.map(s => ({ source: 'agrippa1651', ...pick(s, ['id', 'title', 'planet', 'planetName', 'kind', 'role', 'engraved', 'note']), page: s.page, leaf: s.leaf, scanUrl: scanUrl('agrippa1651', s.leaf), w: s.w, h: s.h, paths: s.paths.map(([d, x, y]) => [r1(d), x, y]) }))
];
const out = {
  version: 1,
  note: 'Catalogo de Agrippa 1651. Figuras de la Goetia excluidas por situacion juridica NO COMPROBADA en Colombia. Generado por _export_catalogo.mjs: no editar a mano.',
  sources: Object.fromEntries(Object.entries(SOURCES).filter(([k]) => k === 'agrippa1651').map(([k, v]) => [k, { name: v.name, short: v.short, work: v.work, edition: v.edition, scan: v.scan, license: v.license, item: v.item }])),
  goetiaRanks: [],
  items
};
fs.mkdirSync(path.join(dir, 'export'), { recursive: true });
const file = path.join(dir, 'export/catalogo-sellos.json');
fs.writeFileSync(file, JSON.stringify(out));
console.log(`${items.length} piezas -> export/catalogo-sellos.json (${(fs.statSync(file).size / 1024).toFixed(0)} KB)`);
