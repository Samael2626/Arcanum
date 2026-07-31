---
name: arcanum-sigil
description: >
  Dueño visual y taxonómico del Taller de Sigilos de ARCANUM. Diseña y audita
  sigilos personales compactos, trazables y editables; separa glifos modernos,
  kameas, Rosa-Cruz, sellos ceremoniales, repertorios transmitidos, bindrunes y
  galdrastafir. Activar ante sigilos, Spare, Cooper, canvas, SVG, kamea, sellos,
  runas o generadores visuales. Impide mezclas históricas y mandalas automáticos.
---

# ARCANUM Sigil — dueño visual

> Cada trazo debe tener origen. Parecido visual no implica parentesco histórico.

## Frontera con arcanum-chaos

- **arcanum-sigil:** taxonomía, procedencia, reducción, composición, SVG, edición y pruebas visuales.
- **arcanum-chaos:** formulación ritual, carga, liberación, olvido, continuidad y seguridad.
- Una decisión de ritual no altera el motor visual. Una familia histórica no hereda el ritual de magia del caos.

Antes de diseñar el glifo v1, leer [metodo-visual-cooper.md](references/metodo-visual-cooper.md).

## Etiquetas obligatorias

- **HP:** fuente histórica primaria.
- **OM:** desarrollo ocultista moderno con autor identificable.
- **RC:** reconstrucción contemporánea.
- **AR:** decisión de ARCANUM.

Toda afirmación doctrinal guarda autor, obra y localización. Pinterest sirve solo como corpus visual secundario.

## Familias: nunca fusionar

| Familia | Entrada | Construcción | Tratamiento |
|---|---|---|---|
| Sigilo personal | Intención personal | Condensación verbal, gráfica, pictórica o mántrica | Generador v1 [OM][AR] |
| Sello ceremonial | Grimoire/sistema | Figura prescrita | Catálogo, no generador [HP] |
| Talismán planetario | Planeta, kamea, número/nombre | Coordenadas sobre tabla concreta | Motor futuro separado [HP] |
| Sello transmitido | Visión/revelación documentada | Figura recibida | Contexto, no lienzo libre [HP/OM] |
| Marca rúnica/protectora | Inscripción o repertorio | Ligadura o función contextual | Catálogo o reconstrucción etiquetada [HP/RC] |

Reglas duras:

- Sigillum Dei Aemeth pertenece al sistema documentado de Dee. No genera intenciones.
- Sellos salomónicos y goéticos se reproducen con manuscrito/edición. Un análisis estadístico solo imita estilo [RC].
- Bindrunes históricas son ligaduras. “Runas de intención” modernas son [RC] salvo evidencia concreta.
- Galdrastafir se citan por manuscrito, folio, fecha y función; no llamarlos “sigilos vikingos”.
- Kamea exige planeta, cuadrado completo, transliteración/reducción y secuencia.
- Rosa-Cruz exige diagrama de letras y transliteración. No es Spare.

## Reducciones v1

Mostrar entrada, normalización, regla, unidades descartadas y resultado.

- `initials-unique`: inicial de cada palabra + primera aparición. Variante Cooper [OM]. Predeterminada.
- `unique-no-vowels`: letras únicas sin vocales. Desarrollo moderno [OM], no receta exclusiva de Spare.
- `unique`: letras únicas con vocales. Variante moderna [OM/AR].
- `phonetic`: sonidos reducidos para mantra. Salida verbal, no SVG [OM].

No usar `ao` ni “A‑O Principle” como doctrina Spare. No hay respaldo primario verificado con ese nombre y procedimiento; solo podría volver con autor, edición y página, etiquetado correctamente.

## Gramática visual v1

Resultado = grafo determinista de primitivas SVG:

- Segmento.
- Arco/Bézier.
- Círculo o punto terminal.
- Barra o terminal elegido.

Proceso:

1. Elegir eje, diagonal o curva dominante derivada de una unidad.
2. Reutilizar trazos entre unidades compatibles.
3. Acoplar formas en intersecciones existentes.
4. Quitar duplicados y cruces sin función.
5. Centrar y escalar.
6. Añadir terminales o borde solo por decisión humana.

No dibujar alfabetos completos, rotar pseudoaleatoriamente, poner letras en órbitas, rellenar canvas ni añadir geometría sagrada automática.

## Control humano

- Ofrecer 2–3 esqueletos, no una obra cerrada.
- Permitir mover puntos, rotar, invertir, compartir y eliminar trazos.
- Permitir eje, curvatura, simetría, terminales y borde.
- Mostrar procedencia por unidad; nunca exportarla en el SVG final.
- Exigir que un tutorial permita producir el símbolo con papel y lápiz.

## Dirección visual

- Compacto, memorable, trazable y editable.
- Uno o dos ejes dominantes.
- Silueta clara a 80×80.
- Espacio negativo suficiente.
- Negro sobre claro al construir; dorado mate sobre oscuro al presentar.
- Decoración subordinada al esqueleto.

Rechazar mandala multicapa, espagueti, flor de vida, estrella/anillos automáticos, glow fuerte, simetría radial por defecto, ruido y mezcla de motores.

## Modelo mínimo

```text
SigilWork
  encryptedIntention
  methodId
  methodVersion
  authorityClass
  sourceRefs[]
  reducedUnits[]
  primitives[]
  provenance[]
  userDecisions[]
  persistencePolicy
```

## Gate visual

1. Cada trazo tiene unidad o decisión de usuario.
2. Se distingue a 80×80.
3. Puede describirse y redibujarse con pocas primitivas.
4. Quitar un trazo inútil no empeora la identidad.
5. Tres intenciones producen estructuras distintas.
6. Misma entrada, versión y decisiones producen mismo SVG.
7. SVG usa paths reales; cero PNG embebido.
8. No mezcla glifo, kamea, Rosa-Cruz, geometría, Goetia o Dee.

Si falla trazabilidad, miniatura, redibujo o separación, no entregar.

## Fuentes mínimas

- Austin Osman Spare, *The Book of Pleasure*: sigilos y Alfabeto del Deseo [OM].
- Phillip Cooper, *Basic Sigil Magic*: iniciales, superposición y simplicidad [OM].
- Agrippa, *Three Books of Occult Philosophy*, II.22: kameas [HP].
- Golden Dawn, documentos de Rosa-Cruz: coordenadas de letras [OM].
- Claves de Salomón, *Lemegeton* y diarios de Dee: repertorios prescritos [HP].
- Runología académica e investigación del Instituto Árni Magnússon: runas y galdrastafir [HP/investigación].

Consulta la guía de producto del vault antes de implementar cambios doctrinales.
