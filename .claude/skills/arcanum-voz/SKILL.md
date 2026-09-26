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

Lo unico que sigue pendiente de decidir aqui es si la cobertura se mide contra
el cuerpo (punto 1 de la receta), que se puede hacer SIN cambiar la voz: no
obliga a nombrar con oficio, solo deja de dar por buena una nota al pie como
prueba de que el texto habla de algo.

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
python ../.claude/skills/arcanum-voz/scripts/banco_voz.py horoscopo --cartas ABC     --prompt variante.txt --v2guard --cuerpo --pausa 75
python ../.claude/skills/arcanum-voz/scripts/banco_voz.py oraculo --limpio --cruz
```

`--pausa 75` no es capricho: una llamada de horoscopo pide 6.200 tokens y el
plan gratuito da 8.000 POR MINUTO, asi que dos seguidas rebotan por TPM aunque
sobre cupo diario. Con 35 segundos rebota; con 75 no.

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
