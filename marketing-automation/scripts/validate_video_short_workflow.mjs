import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const workflowPath = new URL('../workflows/05_preparar_video_short.json', import.meta.url);
const workflowText = await readFile(workflowPath, 'utf8');
const workflow = JSON.parse(workflowText);
const serialized = JSON.stringify(workflow);

assert.equal(workflow.active, false, 'El workflow debe importarse inactivo');
assert.equal(workflow.id, 'ArcanumShort05V1');
assert.equal(workflow.name, 'ARCANUM 05 - Preparar video short');
assert.ok(workflow.nodes.some((node) => node.type === 'n8n-nodes-base.manualTrigger'));
assert.ok(!workflow.nodes.some((node) => node.type === 'n8n-nodes-base.scheduleTrigger'));
assert.ok(!workflow.nodes.some((node) => node.type === 'n8n-nodes-base.youTube'));
assert.ok(serialized.includes("status IN ('approved', 'rendered')"));
assert.ok(serialized.includes("approved_at IS NOT NULL"));
assert.ok(serialized.includes("derived_formats ? 'short_video'"));
assert.ok(serialized.includes('/healthz'));
assert.ok(serialized.includes('/api/visuals/generate'));
assert.ok(!serialized.includes('/tts'));
assert.ok(!serialized.includes('/merge-audio'));
assert.ok(!serialized.includes('/create-video'));
assert.ok(!/(gsk_|sk-proj-|sk-[A-Za-z0-9]{20,})/.test(serialized), 'No se permiten secretos');

const names = new Set(workflow.nodes.map((node) => node.name));
for (const [source, outputs] of Object.entries(workflow.connections)) {
  assert.ok(names.has(source), `Nodo origen inexistente: ${source}`);
  for (const branch of outputs.main) {
    for (const connection of branch) {
      assert.ok(names.has(connection.node), `Nodo destino inexistente: ${connection.node}`);
    }
  }
}

console.log('Workflow 05 valido: seguro, manual e independiente.');
