---
name: arcanum-sigil
description: >
  Diseña y audita el Taller de Sigilos de ARCANUM con énfasis en sigilos gráficos
  simples, compactos y trazables. Activar ante sigilos, sigilización, Austin Osman
  Spare, Phillip Cooper, composición de letras, canvas, SVG, kamea, sellos
  ceremoniales, gnosis o generadores visuales. Impide mezclar familias simbólicas,
  producir mandalas automáticos, garabatos aleatorios o composiciones ilegibles.
---

# Taller de Sigilos — ARCANUM

> Un sigilo no es decoración generativa. Cada trazo nace de la intención.

## Fuente y criterio

Leer [metodo-visual-cooper.md](references/metodo-visual-cooper.md) antes de diseñar,
implementar o auditar el render principal.

Jerarquía:

1. Fuentes primarias suministradas por el usuario.
2. Obras originales de Austin Osman Spare.
3. Referencias visuales aprobadas por el usuario.
4. Pinterest como inspiración secundaria, nunca como autoridad doctrinal.

Si las fuentes discrepan, nombrar la variante. No presentar una reducción como la
única forma “Spare”.

## Familias separadas

### Glifo gráfico

Modo principal. Condensa letras en un emblema simple.

- Usar pocos trazos compartidos.
- Superponer, rotar, invertir o reutilizar formas compatibles.
- Mantener silueta compacta y centro visual claro.
- Permitir curvas, diagonales, barras, ganchos, puntos y terminales.
- Usar simetría solo cuando mejora la forma; nunca por defecto.

### Sello ceremonial

Modo independiente. Puede contener círculo, triángulo, nombres, caracteres,
correspondencias y borde ritual. No mezclar automáticamente con el glifo gráfico.

### Kamea

Modo independiente. El trazado deriva de posiciones numéricas sobre un cuadrado
mágico concreto. Mostrar planeta y kamea usados.

### Sigilo mántrico

Modo verbal, no gráfico. Reducir fonéticamente, reorganizar sonidos y producir una
frase eufónica. No convertirlo automáticamente en geometría.

## Reducciones explícitas

Ofrecer variantes nombradas:

- initials: primera letra de cada palabra y eliminación de repetidas. Variante
  gráfica descrita por Cooper.
- unique-no-vowels: eliminar vocales y letras repetidas.
- unique: conservar vocales y eliminar repetidas.
- ao: transformación A–O, identificada como método distinto.

Siempre mostrar entrada, normalización, regla aplicada y resultado. Nunca mezclar
reglas sin indicarlo.

## Gramática visual del glifo

Construir el resultado como grafo de primitivas SVG:

- Segmento
- Arco o Bézier
- Círculo o punto terminal
- Barra o flecha terminal

Proceso:

1. Elegir un trazo dominante derivado de una letra: eje, diagonal o curva.
2. Reutilizar ese trazo para representar otras letras compatibles.
3. Acoplar barras, arcos y diagonales en intersecciones existentes.
4. Eliminar segmentos duplicados y cruces sin función.
5. Normalizar, centrar y escalar la silueta.
6. Añadir terminales o borde solo por decisión del usuario.

No dibujar cada letra completa. No usar rotaciones pseudoaleatorias. No ubicar
letras en órbitas. No añadir geometría sagrada para “hacerlo mágico”.

## Dirección visual aprobada

- Negro sobre fondo claro durante construcción; dorado mate sobre oscuro al
  presentar.
- Trazo uniforme, orgánico o geométrico según la intención.
- Uno o dos ejes dominantes.
- Silueta reconocible a tamaño pequeño.
- Espacio negativo suficiente.
- Complejidad baja: debe poder recordarse y redibujarse.
- Decoración subordinada al núcleo.

Evitar:

- Mandala multicapa.
- Espagueti de líneas.
- Flor de vida, estrella o anillos automáticos.
- Glow fuerte.
- Simetría radial de cuatro u ocho brazos por defecto.
- Letras separadas dentro de círculos como resultado principal.
- Mezcla simultánea de motores.
- Ruido generado para llenar el canvas.

## Control del usuario

Dar control sin convertir el taller en fichas alfabéticas:

- Mostrar 2–3 propuestas estructurales limpias.
- Permitir elegir eje, curvatura, simetría, terminales y borde.
- Permitir mover puntos de control y eliminar trazos.
- Ofrecer una vista de procedencia que resalte qué letra originó cada trazo.
- Mantener esa procedencia fuera del resultado exportado.

El ordenador asiste. El usuario elige y corrige.

## Pruebas de aceptación

Un glifo pasa solo si cumple:

1. **Trazabilidad:** cada trazo corresponde a una letra reducida o adorno elegido.
2. **Miniatura:** se lee como una silueta a 80×80.
3. **Memoria:** puede describirse con pocas primitivas.
4. **Simplicidad:** quitar un trazo inútil mejora o conserva el símbolo.
5. **Identidad:** tres intenciones distintas producen estructuras distintas.
6. **Determinismo:** misma intención y configuración producen el mismo SVG.
7. **Exportación:** SVG usa paths reales; cero PNG embebido.
8. **Separación:** glifo, sello ceremonial y kamea nunca se fusionan por defecto.

Si falla trazabilidad, miniatura o simplicidad, no entregar.

## Flujo ARCANUM

    intención
      → reducción nombrada
      → 2–3 propuestas simples
      → edición de estructura
      → decoración opcional
      → exportación
      → carga
      → olvido

La carga y el olvido pertenecen al ritual, no al algoritmo visual. Consultar
arcanum-chaos para gnosis y estado del sigilo.

## Modelo de datos mínimo

    {
      intention,
      reductionMethod,
      reducedUnits,
      family,
      primitives,
      provenance,
      decorations,
      state
    }

primitives define el SVG. provenance explica el origen y no se exporta.

