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

## Letras reconocibles (v3, decisión del 26-sep-2026)

Las letras reducidas son el material, no una semilla de azar. Frater U∴D∴,
*Practical Sigil Magic*, cap. 2 (método de la palabra) [OM]: *"as simple as
possible with the various letters recognizable (even with slight difficulty)"*.
Los sigilos salen de la *fusión y estilización* de letras (Spare).

- Cada letra se dibuja con su forma real (capital de trazo único sobre caja común).
- Los trazos que coinciden se comparten y guardan todas sus letras.
- Letra gemela (giro/reflejo de otra ya presente, p. ej. W = M invertida): no se
  repite; se declara en la procedencia.
- Tres composiciones, de menos a más legible: **Fusión** (Spare/U∴D∴, misma caja),
  **Bloque** (una celda por letra, bordes compartidos) y **Cruz** (monograma
  KAROLVS, 769 [HP]: vocales al centro, consonantes en los brazos).
- Cada letra muestra su % visible; ocultar trazos lo baja y el usuario lo ve.
- Rechazado: bandas, tótems o motivos derivados por hash de la letra. Si no se
  puede leer la letra, no es este motor.

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
- Frater U∴D∴, *Practical Sigil Magic*, cap. 2: método de la palabra, letras reconocibles, M/W/E [OM].
- Monograma KAROLVS de Carlomagno (desde 769): K izquierda, R arriba, L abajo, S derecha; vocales al centro [HP]. Diploma: Commons `Karldergrossesignatur.svg`.
- Casos de prueba fijos (gate): U∴D∴ `THISMYWOBANERGF`; Cooper `IDANP` con la I en el asta de la D; láminas de Mathers (Metatron, Elohim, Netzach ×6).
- Agrippa, *Three Books of Occult Philosophy*, II.22: kameas [HP]. Motor implementado (26-27 sep 2026):
  - Tablas transcritas de las láminas (ed. 1651, Peterson) y verificadas mágicas por código. Erratas de esa edición: Luna f1c8 «45» → 54; Kedemel «157» → 175; Bne Seraphim בסי → בני.
  - Agrippa cuenta las finales de 500 a 900 (Bne Seraphim 1252, Schedbarschemoth 3321 solo cuadran así).
  - Agrippa NO explica el trazado («el buscador sabio lo descubrirá»): el recorrido es [RC]. Sus caracteres llevan círculo en ambos extremos y horquilla al repasar.
  - Reducción calibrada con sus 15 figuras [AR]: Aiq Bekar hasta 6×6 (Barzabel, Sorath), quitar ceros desde 7×7 (Kedemel, Tiriel, Taftartarat, Hasmodai). 8 figuras coinciden, 6 en estructura, Grafiel no sale con ningún método: se avisa, no se fuerza. Malkah be-Tarshishim excluido: ninguna grafía probada da su 3321.
- Golden Dawn, documentos de Rosa-Cruz: coordenadas de letras [OM].
  - Mathers, manuscrito F *Sigils from the Rose*: círculo inicial; quiebro u onda en letras iguales seguidas; lazo donde la línea pasa por una letra del nombre (Resh en Metatron). El texto no habla de marca final, pero **sus figuras (Metatron, Elohim) acaban en barra corta**: va activada. Mirar las láminas, no solo el texto. Figuras: tarrdaniel.com `images/Manuscripts/Sigil_Metatron_Elohim.gif` y `Rose_Cross_22_Letters.gif`.
  - Lámina *Tracing for Netzach* (`images/Manuscripts/Sigil_Netzach.gif`): **una palabra = un sigilo**; Nogah es נגה. El lazo también marca una letra del nombre **aún no visitada** por la que pasa un trazo (Haniel), pero no la primera ni la última ni una ya visitada (Hagiel, Tzabaoth). Regla calibrada con 8 láminas: hipótesis, no ley.
  - Documento 5=6 *The Rose Cross Lamen* + SVG de Commons: madres א arriba, ש abajo-der, מ abajo-izq; dobles פ ר ב ד ג ת כ con פ arriba-izq; zodiaco ה arriba, antihorario. Prueba: en Metatron, Teth-Resh-Vav quedan en línea (giro ~1°).
- Claves de Salomón, *Lemegeton* y diarios de Dee: repertorios prescritos [HP].
- **Catálogo «Sello histórico» (27-sep-2026):** reproducir, nunca generar. Primera colección: 7 sellos y 16 caracteres de Agrippa II.22, pp. 244–252 de la ed. de Londres, 1651, escaneo de la Wellcome Collection (Internet Archive `b30335231`, marca de dominio público). Proceso en `arcanum-sigil-prototype/sellos/extract.py` y `build_data.py`: recorte, tinta separada del papel (fuera manchas, rótulos y transparencia del reverso) y calco con vtracer. Sin retoques a mano: los defectos van anotados en la ficha. El SVG exportado lleva la atribución (obra ajena). La errata «45» de la Luna está en la impresión de 1651.
- **Goetia (27-sep-2026):** 80 sellos de los 72 espíritus de las láminas de L. W. de Laurence (Chicago, 1916), que reimprime sin citarla la ed. Mathers-Crowley (1904); el escaneo es de la Harold B. Lee Library (BYU), en Internet Archive (`lesserkeyofsolom00dela`), anterior a 1929. Las láminas numeran FIGURAS, no espíritus: Paimon, Beleth, Leraje, Bathin, Bune, Vepar, Vual y Seere tienen dos sellos. Cada figura se identifica por el nombre grabado en su borde. Rangos y metales, de la lista clasificada del libro (pp. 47–48). Scripts en `sellos/goetia/`. Repertorio histórico: se estudia, no se genera ni se edita.
- Runología académica e investigación del Instituto Árni Magnússon: runas y galdrastafir [HP/investigación].

Consulta la guía de producto del vault antes de implementar cambios doctrinales.
