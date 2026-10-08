import assert from 'node:assert/strict';
import fs from 'node:fs';

const briefs = JSON.parse(
  fs.readFileSync(new URL('../seeds/content-briefs.json', import.meta.url), 'utf8'),
);
const schema = JSON.parse(
  fs.readFileSync(new URL('../schemas/content-brief.schema.json', import.meta.url), 'utf8'),
);
const workflow = JSON.parse(
  fs.readFileSync(new URL('../workflows/02_generar_borrador.json', import.meta.url), 'utf8'),
);

assert.equal(briefs.length, 10, 'La primera cola debe contener diez briefs');
assert.equal(new Set(briefs.map((brief) => brief.external_key)).size, 10, 'external_key debe ser unico');

const required = new Set(schema.required);
for (const brief of briefs) {
  for (const field of required) {
    assert.ok(Object.hasOwn(brief, field), `${brief.external_key}: falta ${field}`);
  }
  assert.ok(brief.facts.length > 0, `${brief.external_key}: faltan hechos`);
  assert.ok(brief.sources.length > 0, `${brief.external_key}: faltan fuentes`);
  assert.ok(brief.derived_formats.length > 0, `${brief.external_key}: faltan derivados`);
  const sourceIds = new Set(brief.sources.map((source) => source.id));
  for (const fact of brief.facts) {
    assert.ok(sourceIds.has(fact.source_id), `${brief.external_key}: source_id huerfano`);
  }
  for (const source of brief.sources) {
    assert.match(source.reference, /^docs\/play-ficha\.md:\d+(?:-\d+)?$/);
  }
}

const expectedGroups = [
  ['tarot', 2],
  ['astrologia', 1],
  ['cielo', 1],
  ['practica', 2],
  ['materia', 2],
  ['manifiesto', 1],
  ['producto', 1],
];
for (const [pillar, count] of expectedGroups) {
  assert.equal(briefs.filter((brief) => brief.pillar === pillar).length, count, `Pilar ${pillar}`);
}

const claimNode = workflow.nodes.find((node) => node.name === 'Reclamar siguiente brief');
const saveNode = workflow.nodes.find((node) => node.name === 'Guardar resultado editorial');
const failureNode = workflow.nodes.find((node) => node.name === 'Registrar fallo editorial');
const generatorNode = workflow.nodes.find((node) => node.name === 'Generar pieza maestra');
assert.ok(claimNode, 'Falta reclamar el siguiente brief');
assert.ok(saveNode, 'Falta guardar el resultado editorial');
assert.ok(failureNode, 'Falta persistir el fallo editorial');
assert.equal(claimNode.type, 'n8n-nodes-base.postgres');
assert.equal(saveNode.type, 'n8n-nodes-base.postgres');
assert.match(claimNode.parameters.query, /FOR UPDATE SKIP LOCKED/);
assert.match(claimNode.parameters.query, /generation_attempts = item\.generation_attempts \+ 1/);
assert.match(saveNode.parameters.query, /generated_content = \$2::jsonb/);
assert.match(saveNode.parameters.query, /status = \$3::marketing\.content_status/);
assert.match(failureNode.parameters.query, /status = 'failed'/);
assert.equal(generatorNode.onError, 'continueErrorOutput');
assert.equal(
  workflow.connections['Generar pieza maestra'].main[1][0].node,
  'Registrar fallo editorial',
);
assert.equal(
  workflow.connections['Ejecutar manualmente'].main[0][0].node,
  'Reclamar siguiente brief',
);
assert.equal(
  workflow.connections['Validar voz editorial'].main[0][0].node,
  'Validar claims sensibles',
);
assert.equal(
  workflow.connections['Revisar ortografia'].main[0][0].node,
  'Registrar modelo usado',
);
assert.equal(
  workflow.connections['Registrar modelo usado'].main[0][0].node,
  'Guardar resultado editorial',
);

console.log('Cola editorial: 10 briefs y persistencia verificadas');
