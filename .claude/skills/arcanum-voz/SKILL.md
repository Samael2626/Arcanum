---
name: arcanum-voz
description: >
  Pulir la VOZ de los dos textos que ARCANUM genera con IA: el horoscopo diario
  (`horoscope_prompt.py`) y el Oraculo de tarot (prompt en Arcanum-datos). Cubre
  el bucle entero: generar un intento REAL contra Groq, leerlo, decidir si el
  fallo es del prompt o del sistema, arreglarlo, y convertir en guarda
  determinista lo que el prompt pide y el modelo incumple igual. Activar SIEMPRE
  que Samuel diga que un texto "suena tecnico", "no se entiende", "le falta
  magia", "suena a revista", "no responde la pregunta", "mis testers no lo
  entienden", o cuando pida comparar versiones de la voz, tocar cualquiera de los
  dos prompts, o anadir una comprobacion a `horoscope_guard` / `oracle_guard`.
  Activar tambien antes de editar esos prompts por cualquier motivo: se han roto
  tres veces por editarlos sin medir.
---

# ARCANUM — la voz del horoscopo y del Oraculo

> Un prompt es una instruccion, no una garantia. Lo que no se mide, no se sabe;
> y lo que el prompt pide tres veces sin conseguirlo, se comprueba en codigo.

---

## LA REGLA CERO: NO SE TOCA UN PROMPT SIN UN INTENTO REAL DELANTE

Prohibido razonar sobre el texto imaginado. Antes de editar y despues de editar,
se genera contra **Groq de verdad** con un cielo real o una carta falsa. Tres
veces se ha "arreglado" la voz a ciegas y tres veces salio peor.

```bash
cd arcanum-api && set -a; . ./.env; set +a
python scripts/comparar_voz_horoscopo.py     # antes/despues con el mismo cielo
```

Para una muestra rapida, `scripts/muestra_voz.py` de esta skill (ver abajo).

---

## LOS DOS TEXTOS, Y DONDE VIVE CADA UNO

| | Horoscopo | Oraculo (tarot) |
|---|---|---|
| Prompt | `arcanum-api/app/services/horoscope_prompt.py` | **otro repo**: `Arcanum-datos/prompts/oracle_system.txt` |
| En produccion sale de | el codigo (default de `config.py`) | la variable **`ORACLE_SYSTEM_PROMPT` de Railway** |
| Guarda | `horoscope_guard.defectos()` | `oracle_guard.defectos()` |
| Datos que recibe | `horoscope.describe(sky)` | `oracle_context.build_oracle_context` + `build_tarot_context` |
| Quien lo paga | gratis para todos | es la ruta que se **cobra** |

> **EL FICHERO DEL CATALOGO NO ES PRODUCCION.** Comprobado el 25-sep-2026 con
> `railway variables --service Arcanum-Code`: la voz viva del Oraculo sale de
> `ORACLE_SYSTEM_PROMPT`. Commitear en Arcanum-datos **no cambia la app**. Y el
> guard si viaja en el codigo, asi que mezclar uno sin el otro hace que la
> guarda pida reintentos por reglas que el prompt viejo no conoce: llamadas del
> cupo gastadas para nada. **Van juntos o no van.**

---

### MEDIDO EL 26-SEP: EL PROMPT VIVO DEL ORACULO NO ES EL DEL CATALOGO

No es que commitear en Arcanum-datos no cambie la app -- eso ya estaba escrito.
Es que los dos textos **ya se han separado**, y el vivo es el viejo:

| | catalogo `prompts/oracle_system.txt` | Railway (produccion) |
|---|---|---|
| tamano | 10.061 chars | **6.242 chars** |
| "energia" vetada | 1 | **0** |
| "vibracion" vetada | 2 | **0** |
| "conseguiras" vetada | 1 | **0** |
| el cierre como "gesto" | 3 | **0** |

`oracle_guard` castiga vocabulario vetado, promesas de resultado y tercera
persona. **El prompt vivo no contiene ninguna de esas reglas**, y ademas usa
"consultante" dos veces, que es justo lo que `tercera_persona` marca. Cada
lectura de produccion que dice "energia" paga un reintento por una regla que al
modelo nunca se le dijo.

> **No se ensancha el guard hasta reconciliar los dos prompts.** Ensancharlo hoy
> solo sube el gasto de cupo en produccion. Esta pendiente anadir "alcanzaras" y
> "vas a alcanzar" a `PROMESAS_DE_RESULTADO` -- salieron sin marcar en la Cruz
> Celta medida --, y espera por esto.

Para leerlo hace falta `railway variables --service Arcanum-Code --json`. Con
`--kv` **no vale**: corta el valor en el primer salto de linea y parece que el
prompt son 80 caracteres.

Y la trampa de medicion que se lleva media hora: en local `.env` no define
`ORACLE_SYSTEM_PROMPT`, asi que `muestra_voz.py oraculo` mide el **catalogo**.
Lo que sale en esa pantalla no es lo que sirve la app.

### RESUELTO EL 29-SEP: NO ERAN LOS TRAMOS, ERA LA SINTESIS

El diagnostico del 26-sep --"salen diez fichas"-- dejo de ser cierto en cuanto
entraron la poda del contexto y la regla de la geometria. Medido el 29 con el
prompt vivo: **los tramos YA salen de una oracion**. Acortarlos no habria
arreglado nada.

Lo que fallaba era el parrafo de cierre, que se habia convertido en el
vertedero del cielo justo donde tenia que responder:

> "En la danza de los astros, el Sol que confronta a tu Venus natal ilumina...
> Mercurio frente a su propio espejo... la hora de Venus y el dia regido por
> Mercurio invitan a meditar."

Arreglado diciendole lo que es: **la respuesta, no un resumen**, y que ahi no
entra ni un nombre de cuerpo, ni de signo, ni de figura, ni de hora planetaria.

**Y HIZO FALTA UNA SEGUNDA PASADA, por un efecto que conviene conocer: al
pedirle que RESPONDA, empieza a DECIDIR.** La primera version salio con "el
momento llama a soltar la comodidad y aceptar la oferta" --- la decision que la
persona vino a consultar, dicha como invitacion en vez de como orden. El
prompt ya lo prohibia; lo que faltaba era decirlo EN el sitio donde tienta.

**Y el guard no lo caza:** `_DECIDE_POR_TI` exige un modal delante (`debes`,
`tienes que`, `la decision correcta es`), asi que "llama a ... aceptar la
oferta" pasa limpio. Queda anotado como limite conocido y NO se ensancha el
guard todavia: el prompt lo arreglo en la corrida siguiente, y la regla de la
casa es que se comprueba en codigo lo que el prompt pide tres veces y no
consigue. Si vuelve a salir, ya tiene su sitio.

Medido, tres corridas:

| | llamadas | defectos entregados | responde | decide |
|---|---|---|---|---|
| base | 2 | 3 (energia, "el logro sera", "te llevara a") | no | no |
| con la regla de la sintesis | 1 | 0 | si | **si** |
| + el aviso de no decidir | 2 | 0 | si | no |

### MEDIDO EL 26-SEP: LA CRUZ CELTA PIERDE LA PREGUNTA

Primera medida de las diez posiciones (`muestra_voz.py oraculo --cruz`), contra
el prompt del catalogo, que es el bueno de los dos. Una corrida, no tres:

- Salieron **diez fichas con el nombre de la posicion por delante**, una por
  carta. No es una respuesta, es un catalogo. La forma que funciona en tres
  cartas no sobrevive al cambio de formato.
- **No responde la pregunta.** La roza ("recorte de ingresos", "mas alla del
  salario") y nunca aterriza en lo que se vino a consultar.
- Se colo la doctrina en crudo: "tierra fria y seca", "aire calido y humedo",
  "la hora de Saturno". El horoscopo lo tiene prohibido; el Oraculo no.
- `retry=True` y **"energia" seguia dentro despues del reintento**.
- Dos promesas sin marcar: "**alcanzaras** una conclusion" y "**el logro sera**
  la sintesis". `alcanzaras` no esta en `PROMESAS_DE_RESULTADO`.
- Lo unico que aguanto el cambio de formato fue el cierre: un gesto, una frase.

### MEDIDO EL 06-OCT: LAS CARTAS SE NOMBRAN POR SU NOMBRE COMUN

Desde `b51f90a` el contexto nombra cada carta como la conoce cualquiera («Ocho de
Oros», no «Señor de la Prudencia») y el guarda la exige con ese mismo nombre
(`oracle_context.card_display_name`, que usan los dos). `muestra_voz.py` armaba la
tirada con el titulo Book T: media un contexto que ya no se manda. Corregido.

Cruz Celta, una corrida por lado, prompt vivo contra el ejemplo corregido: el
modelo toma los nombres DEL CONTEXTO en los dos casos; el ejemplo no los cambia.
Antes `retry=True` (por `decide_por_ti`, no por nombres); despues sin reintento y
sin defectos. El catálogo ya lleva el ejemplo con nombres comunes. Tras entrar
`b51f90a` en `main`, se actualizó `ORACLE_SYSTEM_PROMPT` en Railway; el valor
vivo coincide con el catálogo completo salvo el salto final (06-oct).

### MEDIDO EL 06-OCT: LA SINTESIS COPIA EL CIELO

Con el prompt corregido y los nombres comunes, dos Cruces Celtas sin reintento
nombraron cuerpos en la respuesta final (**2/2**). Una empujó hacia aceptar la
oferta consultada; la otra ofreció dos caminos, pero cerró con «permite que la
decisión fluya». `decide_por_ti` dejó pasar ambas. Esas muestras reproducen el
fallo; no estiman su frecuencia.

Piloto de una guarda **solo en `banco_voz.py`**, nunca en producción: dos
lecturas nuevas, presupuesto máximo de cuatro llamadas reales, 75 segundos
entre inicios de petición. Se gastaron las cuatro. En la primera, la guarda
experimental detectó cinco nombres de cuerpos y forzó un reintento que los
quitó. En la segunda, reintentó la guarda existente por `asesoria_real`; la
respuesta entregada tampoco nombró cuerpos. Las dos salidas finales tuvieron
las diez cartas por nombre común. La primera pide «romper la inercia»; la
segunda deja «que la esperanza guíe tu paso». No son órdenes de aceptar la
oferta, pero sigue haciendo falta juicio humano sobre cuánto orientan.

**No pasar esta guarda a producción aún:** dos respuestas limpias costaron
cuatro llamadas frente a las dos de la base; solo uno de los dos reintentos fue
causado por la nueva regla. El extractor del piloto depende de la etiqueta
`Resultado — El Mundo` y excluye «Luna», que también es carta en esa tirada.
No es un detector general seguro. El siguiente ensayo necesita presupuesto
previo, más preguntas y un extractor de respuesta que no confunda cartas con
cuerpos. El guarda de decisión tampoco se ensancha por una frase ambigua.

## EL BUCLE

1. **Reproducir.** Generar el texto real. Si Samuel dice que algo no se
   entiende, generarlo con **tres cartas natales distintas**: un fallo que sale
   en 1 de 3 no se arregla igual que uno que sale siempre.
2. **Leer y separar.** ¿El fallo es de VOZ (como lo dice) o de FORMA (que va
   primero)? Casi siempre que "no se entiende" es de forma, y apretar la voz no
   lo arregla.
3. **Buscar la contradiccion en el sistema antes de culpar al modelo.** Ver la
   seccion siguiente: cada vez que el modelo "desobedecia", el sistema le estaba
   pidiendo dos cosas opuestas.
4. **Editar el prompt.** Cambio minimo, y el porque va en el **docstring** del
   fichero (no se envia al modelo, no cuesta tokens), nunca en el prompt.
5. **Medir otra vez.** Si el defecto sale en 2 de 3 corridas, el prompt no lo va
   a arreglar: pasa a guarda determinista.
6. **Tests.** Los literales del prompt estan fijados por tests; si un test cae,
   leerlo antes de cambiarlo: suele estar defendiendo una decision anterior de
   Samuel, con su fecha escrita.
7. **Suite entera** (`python -m pytest tests_unit -q`), commit, y doc en vault.

---

## LO QUE YA SE APRENDIO, Y NO HAY QUE VOLVER A DESCUBRIR

### 1. El modelo no desobedece: obedece dos reglas opuestas

- **25-sep:** el texto sonaba a clase. El prompt exigia pagar CADA termino con su
  significado, permitia DOS por parrafo, **y mandaba usar el "porque" geometrico
  que el bloque de datos ya trae glosado en prosa**. El modelo lo copiaba. No era
  desobediencia: era el prompt.
- **26-sep:** el cuerpo no se entendia. `expected_terms` **reintenta si los
  cuerpos no aparecen**, asi que el modelo abria siempre por "Venus atraviesa
  Escorpio y tira de tu Jupiter natal en Acuario" — y al mismo tiempo se le
  prohibia explicarlo. Dato pelado por diseno.

**Antes de tocar la voz, buscar que le OBLIGA el sistema.** `expected_terms`,
`describe()` y el guard mandan mas que cualquier parrafo del prompt.

### 2. Esconder el nombre no da claridad: da acertijo

Medido el 26-sep. Prohibir los nombres en el cuerpo produjo *"la direccion que
sigue el norte se alinea con la belleza interior"* (= Nodo Norte y Venus) y
*"una corriente de luz que se extiende desde tu centro"*. Peor que el nombre:
no se entiende Y no se puede comprobar.

**Lo que se entendio en la prueba fue presentar cada cuerpo por su OFICIO:**
*"Venus, que lleva los pactos y lo que se disfruta, pasa por Escorpio y tira de
tu Jupiter natal; ninguno cede, asi que lo que hoy firmes sera a
reganadientes"*. Fue la unica variante que salio **sin reintento**.

### 3. Lo que el prompt pide tres veces y no consigue, se comprueba

`horoscope_guard` y `oracle_guard` solo hacen comprobaciones **puras y
deterministas**. Lo que exige juicio de estilo se queda en el prompt, y eso esta
escrito como limite conocido, no como olvido.

Y hay una trampa medida dos veces: **no marcar lo que el prompt PIDE.**
`formulas_de_gremio` marcaba la jerga explicada, que es justo lo que se pedia, y
castigaba al modelo por obedecer. `glosas_de_manual` no marca que explique:
marca **el largo** de la explicacion (`MAXIMA_GLOSA = 55`).

### 4. Cada guarda cuesta una llamada, y el cupo son 8.000 TPM

`_generate_with_coverage` hace **UN** reintento y despues entrega el mejor de los
dos con un `logger.warning`. Consecuencia que hay que tener presente: **anadir
guardas aumenta la superficie de reintento**, y con un solo reintento como techo,
mas reglas vigiladas = mas textos entregados con defecto. Medir el porcentaje
antes y despues, no solo si la regla es correcta.

Lo que es **formato y no voz** no merece reintento: se arregla en el borde. Las
negritas del modelo (`**cuadratura**`, que en la app se ven como asteriscos) se
quitan en `_limpia_espacios`.

### 5. El cierre es lo unico que sale de la pantalla

El prompt del 17-ago pedia un gesto y salia *"al anochecer enciende una vela
verde y coloca una esmeralda"*. Se degrado a constatacion y salia *"a la hora de
Venus se consagraba el cobre"* — un dato de museo que informa y no se hace.
**El cierre es UN gesto, hacible hoy, con lo que hay en una casa, en una frase.**
El Oraculo llego a cerrar con siete pasos, verso en latin y enterrar un juramento
bajo una raiz de roble.

### 6. Los dos ejes que no se confunden

```
"cierra ese pendiente hoy"   -> que hacer.   No se comprueba manana.  VALE
"vas a cerrar ese asunto"    -> como acaba.  Se comprueba manana.     NO
```

Aflojar el primero no dice nada del segundo. Confundirlos hizo que en agosto se
derogara una regla entera cuando solo sobraba su mitad. Y con el imperativo
abierto aparecio el limite nuevo: **no se decide la decision que vino a
consultar** (`oracle_guard.decide_por_ti`), ni se promete el final con una imagen
(`promesa_velada`: *"sera la llave que abre la puerta"* es *"conseguiras"* dicho
mas bonito).

### 7. Trampas de fontaneria que cuestan media hora

- **`test_voz_de_los_prompts`** prohibe que un prompt *ensene* el vocabulario que
  veta, y reconoce la cita por `"vocabulario psicologico"` **en la MISMA linea**.
  Si partes la lista de palabras vetadas en varias lineas, el guardia cree que
  las estas ensenando. Mantener la lista en **una linea larga**.
- **`oracle_guard` NO hereda `materia_prestada`**: el contexto astral nombra los
  planetas en **ingles** (`"sun en Tauro"`), asi que el romero del Sol —correcto—
  se marcaria como materia de un cuerpo ausente.
- **`defectos(..., forma=False)`** existe para juzgar FRAGMENTOS: las
  comprobaciones de forma (que la nota exista, que el cuerpo no nombre) solo
  tienen sentido sobre un texto completo. En produccion se llama con el default.
- Los fixtures de test envejecen con la voz. Si `JORNADA` o `REAL_MALO` empiezan
  a fallar, mirar si el fixture trae el estilo viejo **antes** de aflojar la
  regla nueva.

---

## RESUELTO EL 26-SEP: LA RED ERA EXIGIR EL NOMBRE, NO PROHIBIRLO

Cinco corridas contra Groq con las mismas tres cartas. El resumen, porque la
conclusion no era la que se esperaba:

| variante | que se cambio | resultado |
|---|---|---|
| actual (V3) | -- | 2 de 3 genericas, 1 copio definiciones |
| V2 con el guard viejo | solo el prompt | **prueba invalida**: el guard seguia vetando el nombre |
| V2 con el nombre permitido | prompt + guard | **acertijos en 3 de 3** |
| V2 + cobertura en el CUERPO | + `expected_terms` sobre el cuerpo | 3 de 3 nombran con oficio |
| lo mismo, sin vetar "natal" | -- | **1 de 3 limpia sin reintento** |

**El error de diagnostico, escrito para no repetirlo:** se probo V2 cambiando el
prompt y dejando `jerga_en_el_cuerpo` como estaba. Con el guard vetando el
nombre, el modelo elige entre obedecer al prompt y comerse un reintento, o
esquivar el nombre con una perifrasis. Elige la perifrasis, y la prueba mide el
guard, no la variante. **Prompt y guard se cambian a la vez o no se mide nada.**

**Y el hallazgo:** permitir el nombre no basta. Con los nombres permitidos el
modelo SIGUE sin usarlos --"el que corta, que obra con lo que se separa por
fuerza" por Marte, "consagra el cobre a la hora de la hermosura" por Venus--,
porque lee el oficio como SUSTITUTO del nombre. Lo que lo arregla es la otra
mitad: `expected_terms` medido contra el CUERPO en vez de contra el texto
entero. Entonces el nombre es obligatorio donde importa y deja de hacer falta
prohibirlo, que era lo que fabricaba el acertijo.

Texto de la corrida limpia, sin reintento:

> "El dia se siente como una hoja afilada que se arrima a la piel. Marte, que
> lleva la contienda y el corte, se funde con tu Sol natal en Cancer; al
> mezclarse no hay distancia que los separe y el impulso que nace es corto,
> trabaja con lo que le falta y no con su fuerza plena."

### DECIDIDO POR SAMUEL EL 26-SEP: EL CUERPO DEL HOROSCOPO SE QUEDA COMO ESTA

Vistos los seis textos enteros, Samuel eligio el ACTUAL "por mucho". La receta
de abajo queda MEDIDA Y NO APLICADA, a proposito. No se implementa.

Lo que gana el actual es el ritmo: dos parrafos cortos, imagen primero, y se lee
de un vistazo. Lo que la variante hacia mejor --precision, nada de acertijos--
no compensaba que el texto creciera entre 1,3 y 2,3 veces.

**Lo que NO queda resuelto, y hay que tenerlo presente al elegir esto:** el
actual es la forma que se queda sin red anti-generico, porque `expected_terms`
se satisface con la nota al pie. La carta B de esa corrida --"el tiron que hoy
se siente en tus decisiones aprieta con fuerza"-- vale para cualquiera y el
guard la aprobo sin un defecto. Elegir esta voz es elegir tambien eso, hasta
que se ponga otra red.

**Y NO, la cobertura contra el cuerpo NO se puede hacer sin cambiar la voz.**
Eso se escribio aqui como si fuera gratis y es falso; probado el 28-sep-2026 y
revertido en el acto. Con el cuerpo sin nombres --que es la voz elegida-- exigir
los cuerpos EN el cuerpo hace que TODOS los horoscopos fallen la cobertura,
reintenten y sigan fallando. No es un ajuste: es prompt y guard pidiendo lo
contrario, la trampa de siempre.

Lo pararon dos tests que ya estaban escritos, con su fecha dentro:
`test_un_texto_que_nombra_su_transito_en_la_nota_no_reintenta` y
`test_un_horoscopo_generico_dispara_el_reintento`. Defendian la decision del
26-sep y tenian razon.

**Y LA VIA DEL DOMINIO TAMPOCO SIRVE.** Estaba anotada aqui como la idea que
quedaba: exigir que el cuerpo toque el DOMINIO de los cuerpos en juego --"los
pactos", "el corte", "el limite", que `PLANET_DOMAINS` ya trae-- en vez de su
NOMBRE. Medida el 29-sep-2026 SIN gastar un token, pasando el detector por seis
salidas reales guardadas mas dos controles genericos.

Resultado: **deja pasar el generico**. "El tiron que hoy se siente en tus
decisiones aprieta con fuerza..." --la salida del 26-sep que el guard aprobo sin
un solo defecto-- pasa por la palabra **"fuerza"**, que sale del dominio de
Marte "lo que se separa por fuerza" y en el texto es uso corriente del
castellano.

No es un problema de umbral, y por eso no se arregla afinandolo: **las palabras
de dominio son palabras normales**. "fuerza", "camino", "corte", "trato",
"filo", "pueblo". Ningun detector de vocabulario distingue "el corte de Marte"
de "un corte de pelo". Seguir ajustando el umbral hasta que cuadre con los
ejemplos de uno es ajustarlo a la muestra, no construir una red.

**CONCLUSION, y es la que cierra el asunto:** lo generico es un juicio de
SENTIDO, no de vocabulario, y esta skill ya lo dice en su propia regla --- las
guardas son puras y deterministas, y lo que exige juicio de estilo se queda en
el prompt. `expected_terms` solo funcionaba porque un nombre SE PUEDE
comprobar. No hay red determinista que no rompa la voz (exigir el nombre) o
deje pasar lo que viene a cazar (buscar palabras).

**Y la red NO esta muerta, esta SOMERA**, que es una correccion a lo que yo
mismo escribi arriba: caza el texto que no nombra ningun cuerpo en NINGUN sitio
--lo prueba `test_un_horoscopo_generico_dispara_el_reintento`-- y deja pasar el
que nombra en la nota y no dice nada. Ese es el limite real, y es conocido.

### La receta medida, para cuando se implemente

1. `expected_terms` se comprueba contra el CUERPO (`_cuerpo_y_nota`), no contra
   el texto entero. Sin esto no funciona nada de lo demas.
2. `_NOMBRES_VETADOS_EN_EL_CUERPO` se queda SOLO con las figuras --cuadratura,
   trigono, sextil, oposicion, conjuncion, quincuncio-- mas orbe, decanato y
   efemeride. Fuera los planetas, fuera los signos, y **fuera "natal"**: "tu
   Luna natal" es castellano corriente y vetarlo costaba un reintento en las
   tres cartas.
3. El prompt presenta cada cuerpo por su oficio la primera vez que aparece, y
   dice que el nombre va EN EL CUERPO (esto ultimo falta: es por lo que 2 de 3
   aun reintentan, el primer intento lo omite).
4. La nota, por codigo. En estas corridas se degrado sola ("Luna Llena,
   Saturno, Marte", sin etiquetas), que es el argumento que faltaba.

Pendiente medido y NO resuelto: `materia_prestada` sigue colandose (salio
"cobre, que es de Venus, que hoy no sale" entregado en el texto final).

## LA DECISION ABIERTA (26-sep-2026)

Se probaron tres formas con el mismo cielo. Samuel eligio V3 y luego se midio que
no aguanta. Estado real:

- **V1 persona primero** — fallo: frase llana y detras el manual entero.
- **V2 cada cuerpo por su oficio** — la unica sin reintento y la que se entiende.
- **V3 cuerpo sin ningun nombre + nota al pie** — el cuerpo se vuelve vago o
  criptico en 2 de 3 corridas; el modelo **escribe su propia nota** aunque se le
  prohiba (hay que cortarla por `MARCA_NOTA`).
- **La nota compuesta por CODIGO** es claramente mejor que pedirsela al modelo:
  siempre existe, es exacta, cero tokens, cero reintentos. `POINTS_ES` y
  `ASPECTS_ES` de `natal_chart_engine` mas `sky["today"] / sky["chapter"]` bastan.

**Pendiente de decidir con Samuel:** V2 en el cuerpo + nota por codigo (plegada
en la UI, que se toca y abre), o insistir en el cuerpo sin nombres atacando la
vaguedad por otro lado. Si se quita `expected_terms`, **desaparece la red
anti-generico** y hay que poner otra en su sitio.

---

## COMO SE MIDE

`scripts/banco_voz.py` prueba VARIANTES sin tocar el repo: parchea el prompt,
el guard y los bloques de datos en memoria.

```bash
cd arcanum-api && set -a; . ./.env; set +a
python ../.claude/skills/arcanum-voz/scripts/banco_voz.py horoscopo --cartas ABC --prompt variante.txt --v2guard --cuerpo --pausa 75 --max-llamadas 6
python ../.claude/skills/arcanum-voz/scripts/banco_voz.py oraculo --cruz --pausa 75 --max-llamadas 4 --veces 2
python ../.claude/skills/arcanum-voz/scripts/banco_voz.py oraculo --cruz --guard-sintesis --pausa 75 --max-llamadas 4 --veces 2
```

`--pausa 75` no es capricho: una llamada de horoscopo pide 6.200 tokens y el
plan gratuito da 8.000 POR MINUTO, asi que dos seguidas rebotan por TPM aunque
sobre cupo diario. La pausa y `--max-llamadas` se aplican a cada petición real
del SDK, incluidos el reintento y el salto a otra clave por 429. El presupuesto
se fija ANTES de medir; `--guard-sintesis` es una variante de laboratorio.

`scripts/muestra_voz.py` genera el texto real con lo que hay vigente. Tres cartas
distintas para el horoscopo, o una tirada con carta falsa para el Oraculo:

```bash
cd arcanum-api && set -a; . ./.env; set +a
python ../.claude/skills/arcanum-voz/scripts/muestra_voz.py horoscopo
python ../.claude/skills/arcanum-voz/scripts/muestra_voz.py oraculo
python ../.claude/skills/arcanum-voz/scripts/muestra_voz.py horoscopo --veces 3
```

Y para oir una version vieja contra la de hoy, sin copiar nada a mano, el prompt
se saca del propio git:

```python
src = subprocess.run(["git", "show", f"{ref}:arcanum-api/app/services/horoscope_prompt.py"],
                     capture_output=True, text=True, encoding="utf-8").stdout
ns = {}; exec(compile(src, "viejo", "exec"), ns); prompt = ns["HOROSCOPE_SYSTEM_PROMPT"]
```

**Al leer la salida, mirar SIEMPRE `retry` y `flaws_first`.** Un texto limpio con
`retry=True` significa que el primer intento estaba mal y el cupo ya se pago dos
veces; un texto sucio con `retry=True` significa que el reintento tampoco lo
arreglo y se entrego con el defecto dentro.

---

## LO QUE SIGUE ROTO, ESCRITO PARA NO REDESCUBRIRLO

- **"energia" se cuela** cuando el unico reintento tampoco la quita. Sale en
  ~1 de 3 corridas del horoscopo. Es la decision de coste, no un bug.
- **`materia_prestada` no vigila el COLOR**: salio *"el color del dia se vuelve
  escarlata"* en un cielo de Venus y Luna.
- **La nota duplicada** si algun dia el codigo compone la nota y no se corta la
  del modelo.
- **`_GLOSABLES` no incluye** "al no haber distancia" ni "en fase aplicativa",
  que es por donde se escapa la explicacion tecnica ahora.

---

## REGLAS DE LA CASA QUE APLICAN AQUI

- Codigo e identificadores en **ingles**; comentarios en **espanol sin acentos**;
  el texto que lee el usuario final, **espanol con acentos**.
- El razonamiento largo va en el **docstring** del modulo, que no se envia al
  modelo. El prompt se queda corto a proposito.
- Una regla que se deroga **se escribe con su fecha y su motivo**, no se borra:
  una guarda que desaparece sin nota parece un descuido al mes siguiente.
- Nunca `ARCANUM_SKIP_HOOKS=1`. Si el hook bloquea, el bloqueo es el dato.
- Al acabar: commit + push + nota en el vault (`D:\Brain\10-Proyectos\ARCANUM`)
  y linea en `MOC-ARCANUM`.
