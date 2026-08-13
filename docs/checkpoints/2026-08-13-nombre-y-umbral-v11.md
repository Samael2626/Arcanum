# Checkpoint 2026-08-13 — Nombre y Umbral V1.1: catálogo editorial

Rama: `feat/nombre-y-umbral-foundation`
Base: `79dae23 fix(perfil): estabilizar nombre y umbral`

## Veredicto

El catálogo pasa de **25 a 128 fichas verificadas** (**103 nuevas**, meta era 75).
Los apellidos **no se publican**: entran como cola editorial tipada con evidencia,
licencia y nivel de certeza. Ninguna entrada de la cola es publicable en V1.1, y
el tipo lo impide por construcción, no por convención.

## Fuentes verificadas contra la fuente real (2026-08-13)

| Tradición | Fuente | Licencia | Fichas |
|---|---|---|---:|
| Hebrea | Open Scriptures Hebrew Bible (morphhb) | CC BY 4.0 (lema/morfología); WLC dominio público | 50 |
| Griega | Liddell-Scott-Jones, *A Greek-English Lexicon* (Perseus) | CC BY-SA 3.0 US | 26 |
| Latina | Lewis y Short, *A Latin Dictionary* (Perseus, 1879) | CC BY-SA 3.0 US | 33 |
| Germánica | Förstemann, *Altdeutsches Namenbuch* I: Personennamen (1900) | Dominio público (PDM 1.0) | 13 |
| Árabe | Lane, *An Arabic-English Lexicon* (1863-1893) | Dominio público | 6 |

**Descartada: tradición indígena colombiana.** La gramática de fray Bernardo de
Lugo (1619) es dominio público pero es una gramática, no un onomástico de nombres
de pila. La transcripción del *Diccionario y gramática chibcha* de González de
Pérez (1987) está bajo copyright. Sin fuente reutilizable no entra nada.

## Decisiones editoriales

1. **Gematría histórica solo con escritura hebrea documentada.** Es ahora un
   invariante tipado: `NameTradition.allowsHistoricalGematria`. Griego, latín,
   germánico y árabe muestran su propia escritura documentada y nunca abren el
   cálculo 1-400. Un test lo verifica ficha por ficha.
2. **La evidencia se parte en dos ejes.** `formEvidence` y `meaningEvidence` son
   independientes: María tiene forma atestiguada (`מרים`) y significado discutido.
   Antes eso no se podía expresar sin mentir en una de las dos mitades.
3. **Entran los nombres con etimología rota.** María, Antonio, Rebeca, Catalina,
   Elena, Aarón, Ester, Lea, Jeremías, Rubén y Julio se publican declarando que su
   significado no está resuelto. Antonio es el caso ejemplar: la glosa popular
   «inestimable» es una invención renacentista y la ficha lo dice.
4. **Las raíces tradicionales solo existen en fichas hebreas** y siempre con su
   `traditionalRootsLimit`. Verificado por test.
5. **Las fuentes viven en la nota de archivo.** La prosa visible no contiene URLs,
   dominios ni nombres de licencia. Verificado por test.

## Apellidos: estado real

27 entradas en cola, ninguna publicable.

- **5 en cola con evidencia parcial** (Rodríguez, Hernández, Pérez, Enríquez,
  Estévez): la base del nombre de pila ya está verificada en el catálogo. Falta
  una fuente con licencia reutilizable para el sufijo patronímico `-ez`.
- **20 sin evidencia suficiente**: González, Martínez, Ramírez, Sánchez, Gómez,
  Gutiérrez, Jiménez, Domínguez, Suárez, Díaz, López, Velásquez, Álvarez, Torres,
  Castro, Valencia, Restrepo, Salazar, Moreno, Rojas.
- **2 descartados**: García y Muñoz. Origen no resuelto y demasiado frecuentes
  para arriesgar una conjetura.

Moreno lleva una nota explícita: su historia en Colombia toca la clasificación
colonial por color y exige tratamiento editorial antes de escribir nada.

## Cambios de código

- `data/name_sources.dart` (nuevo): `NameTradition`, `EvidenceLevel`, `NameSource`
  y las cinco fuentes verificadas. Elimina la duplicación de url/atribución que
  antes vivía en cada ficha.
- `data/name_catalog.dart`: tipo reescrito con fuente compartida, tradición,
  evidencia en dos ejes y `entryUrl` opcional para conservar los enlaces de lema
  de las cinco fichas griegas de la fundación. 128 fichas.
- `data/surname_queue.dart` (nuevo): cola editorial sin campos de significado ni
  de origen publicables.
- `presentation/name_part_screen.dart`: el desplegable de origen ahora se cierra
  con `tradition.allowsHistoricalGematria`, no solo con la presencia de escritura
  hebrea. La nota de archivo pasa a mostrar tradición, certeza, fuente, licencia,
  atribución y límite editorial en bloques separados.

## Pruebas

- `flutter analyze lib` — sin problemas.
- `flutter test` — **246 verdes** (antes 217; +29).
- `flutter build apk --debug` — correcto.
- `git diff --check` — limpio.
- CJK y mojibake — limpios en fuentes.
- **Físico: no ejecutado.** El OnePlus no estaba conectado (`flutter devices`
  solo reporta Windows, Chrome y Edge). Queda pendiente para la próxima sesión.

Tests nuevos que fijan las invariantes pedidas: procedencia completa por ficha,
gematría solo hebrea, ninguna ficha no hebrea presentándose como hebrea, etiqueta
de forma coherente con la tradición, prosa visible sin URLs, prosa sin
afirmaciones sobre la persona, apellidos sin origen ni significado, base de
apellido resolviendo a ficha real, y las 25 fichas de la fundación intactas.

## Siguiente

**Puentes del Umbral**: integración opt-in del nombre con Tarot, Oráculo y Cielos.
El test de aislamiento de red ya fija la frontera actual: Tarot y Cielos no
importan `name_threshold` ni `readingIdentityProvider`. Cualquier puente tendrá
que cambiar ese test de forma explícita y consciente.
