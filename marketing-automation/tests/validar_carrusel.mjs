import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const testDirectory = path.dirname(fileURLToPath(import.meta.url));
const outputDirectory = path.resolve(testDirectory, '../output/carta-natal-001');

const content = JSON.parse(
  fs.readFileSync(new URL('../visuals/carousels/carta-natal-001/content.json', import.meta.url), 'utf8'),
);
const assets = JSON.parse(
  fs.readFileSync(new URL('../assets/manifest.json', import.meta.url), 'utf8'),
);
const template = fs.readFileSync(
  new URL('../visuals/templates/carousel.html', import.meta.url),
  'utf8',
);
const renderManifest = JSON.parse(
  fs.readFileSync(path.join(outputDirectory, 'manifest.json'), 'utf8'),
);

function pngDimensions(buffer) {
  assert.equal(buffer.subarray(1, 4).toString('ascii'), 'PNG');
  return {
    width: buffer.readUInt32BE(16),
    height: buffer.readUInt32BE(20),
  };
}

assert.equal(content.status, 'approved');
assert.equal(content.canvas.width, 1080);
assert.equal(content.canvas.height, 1350);
assert.ok(content.slides.length >= 3 && content.slides.length <= 6);
assert.ok(content.slides.every((slide) => slide.alt_text?.trim()));
assert.equal(new Set(content.slides.map((slide) => slide.layout)).size, content.slides.length);
assert.ok(assets.assets.some((asset) => asset.id === content.asset_id));
assert.match(template, /window\.renderCarousel/);
assert.match(template, /textContent = value/);
assert.doesNotMatch(template, /innerHTML\s*=/);
assert.doesNotMatch(template, /border-radius:\s*50%/);
assert.equal(renderManifest.external_key, content.external_key);
assert.equal(renderManifest.files.length, content.slides.length);
assert.equal(renderManifest.source, 'marketing-automation/visuals/carousels/carta-natal-001/content.json');
assert.equal(renderManifest.template, 'marketing-automation/visuals/templates/carousel.html');

for (const rendered of renderManifest.files) {
  const file = fs.readFileSync(path.join(outputDirectory, rendered.file));
  assert.deepEqual(pngDimensions(file), { width: 1080, height: 1350 });
  assert.equal(crypto.createHash('sha256').update(file).digest('hex'), rendered.sha256);
  assert.ok(rendered.alt_text?.trim());
}

console.log('Carrusel: contrato, archivos, dimensiones y hashes verificados');
