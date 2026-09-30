import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const testDirectory = path.dirname(fileURLToPath(import.meta.url));

const assets = JSON.parse(
  fs.readFileSync(new URL('../assets/manifest.json', import.meta.url), 'utf8'),
);
const template = fs.readFileSync(
  new URL('../visuals/templates/carousel.html', import.meta.url),
  'utf8',
);
const cases = [
  {
    content: '../visuals/carousels/carta-natal-001/content.json',
    output: '../output/carta-natal-001',
    mode: 'final',
    status: 'approved',
  },
  {
    content: '../visuals/carousels/tarot-78-arcanos-001/content.json',
    output: '../output/previews/tarot-78-arcanos-001',
    mode: 'preview',
    status: 'ready_for_review',
  },
  {
    content: '../visuals/carousels/grimorio-cifrado-local-001/content.json',
    output: '../output/previews/grimorio-cifrado-local-001',
    mode: 'preview',
    status: 'ready_for_review',
  },
];

function pngDimensions(buffer) {
  assert.equal(buffer.subarray(1, 4).toString('ascii'), 'PNG');
  return {
    width: buffer.readUInt32BE(16),
    height: buffer.readUInt32BE(20),
  };
}

assert.match(template, /window\.renderCarousel/);
assert.match(template, /textContent = value/);
assert.match(template, /style\.backgroundImage/);
assert.match(template, /content\._preview/);
assert.doesNotMatch(template, /innerHTML\s*=/);
assert.doesNotMatch(template, /border-radius:\s*50%/);

for (const currentCase of cases) {
  const contentPath = path.resolve(testDirectory, currentCase.content);
  const caseOutputDirectory = path.resolve(testDirectory, currentCase.output);
  const content = JSON.parse(fs.readFileSync(contentPath, 'utf8'));
  const renderManifest = JSON.parse(
    fs.readFileSync(path.join(caseOutputDirectory, 'manifest.json'), 'utf8'),
  );

  assert.equal(content.status, currentCase.status);
  assert.deepEqual(content.canvas, { width: 1080, height: 1350 });
  assert.ok(content.slides.length >= 3 && content.slides.length <= 6);
  assert.ok(content.slides.every((slide) => slide.alt_text?.trim()));
  assert.equal(new Set(content.slides.map((slide) => slide.layout)).size, content.slides.length);
  assert.ok(assets.assets.some((asset) => asset.id === content.asset_id));
  assert.equal(renderManifest.external_key, content.external_key);
  assert.equal(renderManifest.content_status, currentCase.status);
  assert.equal(renderManifest.render_mode, currentCase.mode);
  assert.equal(renderManifest.files.length, content.slides.length);
  assert.equal(renderManifest.template, 'marketing-automation/visuals/templates/carousel.html');

  for (const rendered of renderManifest.files) {
    const file = fs.readFileSync(path.join(caseOutputDirectory, rendered.file));
    assert.deepEqual(pngDimensions(file), { width: 1080, height: 1350 });
    assert.equal(crypto.createHash('sha256').update(file).digest('hex'), rendered.sha256);
    assert.ok(rendered.alt_text?.trim());
  }
}

console.log('Carruseles: 1 final y 2 previews con archivos, dimensiones y hashes verificados');
