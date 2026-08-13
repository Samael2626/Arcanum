# Política de traducción

## Prioridad

1. Fidelidad semántica.
2. Seguridad médica y botánica.
3. Completitud y estructura.
4. Terminología histórica consistente.
5. Legibilidad española.
6. Estilo editorial.

El estilo de Andrés Laguna puede orientar una segunda capa editorial. Nunca permitir que cambie agente, modalidad, negación, dosis, planta, diagnóstico o relación causal.

## Reglas

- Traducir todo. No resumir, explicar, moralizar ni completar.
- Conservar duda y modalidad: `may`, `suppose`, `thought`, `perhaps`.
- Conservar números, fracciones, unidades y comparaciones. No convertir medidas.
- Conservar marcas como `_Descript._]`, `_Place._]`, `_Time._]` y `_Government and virtues._]` según la política vigente de la obra.
- Conservar byte a byte cada término protegido: mayúsculas, espacios, apóstrofes, orden y guion ASCII `-`.
- No latinizar ni identificar científicamente una planta sin fuente curada y revisión humana.
- Aplicar traducciones obligatorias del glosario. Rechazar sus formas prohibidas.
- Registrar dudas fuera del texto traducido.
- No presentar la eficacia terapéutica histórica como recomendación médica actual.

## Riesgo

Marcar `high` cuando aparezca cualquiera:

- planta tóxica o identificación ambigua;
- embarazo, parto, infancia o lactancia;
- dosis, medida, frecuencia o vía de administración;
- veneno, antídoto, contraindicación o negación;
- tratamiento de enfermedad;
- correspondencia astrológica usada como regla terapéutica.

Todo riesgo alto necesita revisión humana antes de estado `human`.

## Validadores deterministas

Bloquear ante:

- JSON inválido, IDs faltantes, repetidos o desordenados;
- términos protegidos alterados;
- guiones Unicode donde el original exige `-`;
- números, fracciones, rangos o unidades cambiados;
- secciones omitidas;
- texto externo, Markdown, razonamiento o comentarios del modelo;
- falsos amigos prohibidos por el glosario;
- párrafos vacíos o duplicados.

Alertar, sin bloquear por sí solo, ante ratio de longitud anormal, inglés residual permitido por nombres propios o cambios fuertes de puntuación.

## Revisor LLM

Usar modelo distinto al traductor. Comparar original y traducción, no solo leer español. Clasificar:

- `critical`: planta, dosis, medida, embarazo, contraindicación, negación, omisión o falso amigo médico con riesgo.
- `major`: cambio de sentido, agente, tiempo, modalidad, término histórico o sección.
- `minor`: legibilidad, puntuación o registro sin cambio semántico.

El crítico produce defectos e instrucciones mínimas de reparación. No reescribe por gusto.

## Publicación

- `machine` significa aprobado automáticamente, no correcto por autoridad humana.
- `human` exige revisión real registrada.
- `blocked` nunca se siembra como traducción publicable.
- Mantener siempre disponible el original inglés.
