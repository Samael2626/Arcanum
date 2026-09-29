import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const workflow = JSON.parse(
  fs.readFileSync(new URL('../workflows/02_generar_borrador.json', import.meta.url), 'utf8'),
);
const validator = workflow.nodes.find((node) => node.name === 'Parsear y validar borrador');
assert.ok(validator, 'Falta el nodo validador');
const orthographyReviewer = workflow.nodes.find((node) => node.name === 'Revisar ortografia');
assert.ok(orthographyReviewer, 'Falta el nodo de ortografia');
const generator = workflow.nodes.find((node) => node.name === 'Generar pieza maestra');
assert.equal(generator.parameters.needsFallback, true, 'Falta activar el modelo de respaldo');
assert.equal(
  workflow.connections['Gemini editorial respaldo'].ai_languageModel[0][0].index,
  1,
  'El modelo de respaldo debe usar la entrada 1',
);

const brief = {
  external_key: 'demo-manifiesto-001',
  sources: [{ id: 'play-ficha' }],
  asset: null,
};

async function execute(raw) {
  const context = {
    $input: { first: () => ({ json: { text: raw } }) },
    $: (name) => {
      assert.equal(name, 'Preparar paquete factual');
      return { first: () => ({ json: brief }) };
    },
  };
  return new vm.Script(`(async () => { ${validator.parameters.jsCode} })()`).runInNewContext(context);
}

async function reviewOrthography(item) {
  const context = { $input: { first: () => ({ json: structuredClone(item) }) } };
  return new vm.Script(`(async () => { ${orthographyReviewer.parameters.jsCode} })()`).runInNewContext(context);
}

const validDraft = {
  hook: 'Tu práctica merece algo más que respuestas automáticas.',
  script: 'ARCANUM reúne herramientas para estudiar símbolos con intención. Consulta el Tarot, observa tu carta natal y conserva notas privadas dentro de un grimorio cifrado.',
  carousel: [
    'Tarot para formular mejores preguntas.',
    'Carta natal para estudiar tu propio cielo.',
    'Grimorio cifrado para guardar la práctica.',
  ],
  caption: 'Un espacio ordenado para quien prefiere estudiar, registrar y volver sobre sus hallazgos.',
  cta: 'Explora el Tarot en ARCANUM',
  alt_text: '',
  source_ids: ['play-ficha'],
  compliance: { claims_supported: true, warnings_applied: true },
};
const accepted = await execute(JSON.stringify(validDraft));
assert.equal(accepted[0].json.status, 'ready_for_review');
assert.equal(accepted[0].json.validation.valid, true);

const repetitiveDraft = {
  hook: 'El porvenir no es un mapa predeterminado, sino un espacio de contemplación.',
  script: 'ARCANUM no promete predecir el futuro. Se concibe como un instrumento de práctica y reflexión, diseñado para el estudio riguroso. En la aplicación encontrarás tres herramientas fundamentales: Tarot, carta natal y un grimorio cifrado.',
  carousel: [
    'Un instrumento de práctica y reflexión, no una máquina de predicciones.',
    'ARCANUM no promete predecir el futuro.',
    'Herramientas integradas: Tarot, carta natal y grimorio cifrado.',
  ],
  caption: 'ARCANUM es un instrumento de práctica y reflexión, no una máquina de predicciones. La aplicación no promete predecir el futuro, sino ofrecer un espacio estructurado para el trabajo personal a través del Tarot, la carta natal y un grimorio cifrado.',
  cta: 'Conoce las funciones de Tarot disponibles en la aplicación',
  alt_text: 'Texto sobrio sobre un fondo sobrio.',
  source_ids: ['play-ficha'],
  compliance: { claims_supported: true, warnings_applied: true },
};
const rejected = await execute(JSON.stringify(repetitiveDraft));
assert.equal(rejected[0].json.status, 'needs_revision');
assert.ok(rejected[0].json.validation.errors.includes('alt_text: debe quedar vacio hasta elegir un recurso visual'));
assert.ok(rejected[0].json.validation.errors.includes('cta: formula generica'));
assert.ok(rejected[0].json.validation.errors.some((error) => error.startsWith('repeticion alta:')));

const missingAccents = await reviewOrthography({
  draft: { hook: 'Una reflexion exige observacion metodica.' },
  validation: { score: 100, warnings: [] },
});
assert.equal(missingAccents[0].json.validation.score, 95);
assert.ok(missingAccents[0].json.validation.warnings.includes('ortografia: revisar tildes frecuentes'));

await assert.rejects(() => execute('{no es json}'), /JSON editorial invalido/);

console.log('Validador editorial: 4 casos verdes');
