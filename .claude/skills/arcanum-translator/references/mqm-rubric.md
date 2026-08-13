# Rúbrica MQM

## Muestra

Usar 100 párrafos fijos:

- 20 de preliminares, catálogo y apéndice.
- 30 de hierbas, nombres y alias.
- 25 de medicina, dosis, embarazo y enfermedades.
- 15 de astrología y humores.
- 10 narrativos o editoriales.
- Incluir al menos 20 casos adversariales.

Para experimento inicial aceptar 60. No declarar ganador definitivo con menos de 50 por modelo.

## Procedimiento

1. Congelar corpus, prompts, glosario, SDK, modelos y parámetros.
2. Traducir los mismos bloques con cada candidato.
3. Ocultar modelo y aleatorizar orden.
4. Usar dos revisores bilingües; un tercero resuelve desacuerdos.
5. Registrar coste, tokens, latencia p50/p95, errores JSON y reparaciones.
6. Comparar por segmento y por 1.000 palabras.
7. Calcular intervalo bootstrap del 95 % sobre diferencias pareadas.

## Pesos

| Criterio | Peso |
|---|---:|
| Exactitud semántica | 35 % |
| Terminología histórica | 20 % |
| Registro y legibilidad | 15 % |
| Seguridad botánica | 15 % |
| Completitud | 10 % |
| Formato | 5 % |

Penalización: `critical=25`, `major=5`, `minor=1`.

## Gate

Elegir menor MQM ponderado solo si además cumple:

- cero `critical` médico o botánico;
- nombres protegidos exactos al 100 %;
- números y unidades exactos al 100 %;
- JSON válido en al menos 99,5 %;
- intervalo del 95 % favorable frente a `legacy_machine`;
- coste dentro del presupuesto confirmado de la cuenta.

Una victoria estilística no compensa un error crítico.
