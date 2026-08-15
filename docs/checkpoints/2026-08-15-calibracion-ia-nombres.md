# Checkpoint 2026-08-15 — Calibracion de IA para el catalogo de nombres

Rama: `feat/nombre-y-umbral-foundation`
Base: `81e79c1 feat(perfil): ampliar catalogo editorial de nombres`

## Veredicto

**Ningun modelo disponible sirve para decidir el significado de un nombre.**
Los cuatro evaluados inventan entre el 75% y el 92% de las veces sobre nombres
cuya etimologia la filologia no ha resuelto. No es falta de conocimiento: los
mismos modelos aciertan el 98% de los significados atestiguados y el 98% de las
tradiciones. Lo que no saben hacer es callarse.

El catalogo se queda en **128 fichas**. No se anadio ninguna, porque anadir
exige abrir la fuente con licencia por entrada y eso no se hizo en esta sesion.
Lo que si queda es la herramienta, la evidencia y la cola de trabajo.

## Como se midio

El propio catalogo es el banco de pruebas, y es honesto porque cada ficha se
verifico antes a mano contra fuente con licencia:

- **Set trampa (12 fichas `disputed`)**: el modelo debe declarar el significado
  no resuelto. Si lo resuelve, esta inventando y lo sabemos.
- **Set de cobertura (95 fichas `attested`)**: el modelo debe resolverlas. Uno
  que se abstiene de todo tiene invencion cero y es igual de inutil.
- **21 fichas `probable`**: excluidas, ambiguas por construccion.

Criterio fijado **antes** de correr, como en el harness de BinanceAgent:
invencion <= 25%, cobertura >= 80%, tradicion >= 85%.

## Resultados (2026-08-15, contra la API real)

| Modelo | Invencion | Cobertura | Tradicion | Veredicto |
|---|---:|---:|---:|---|
| `openai/gpt-oss-120b` | 83% (10/12) | 98% (93/95) | 97% | DESCARTADO |
| `openai/gpt-oss-20b` | 92% (11/12) | 99% (94/95) | 98% | DESCARTADO |
| `qwen/qwen3.6-27b` | — | — | — | NO EVALUABLE |
| `llama-3.3-70b-versatile` | 75% (9/12) | 98% (93/95) | 98% | REFERENCIA |

`qwen/qwen3.6-27b` acepta `response_format: json_object` y luego devuelve JSON
invalido (400 `json_validate_failed`). Inservible para un arnes automatico.

`llama-3.3-70b-versatile` se apaga el **16 de agosto de 2026**: entra como
referencia historica, nunca como candidato.

Coste: `gpt-oss-120b` tardo **4869s** contra 98s del `20b`, con peor invencion.
El modelo grande no compra nada en esta tarea.

## Lo que los modelos inventan, y por que importa

Los tres coinciden casi palabra por palabra en las mismas glosas populares que
la filologia descarto: "Catalina = pura", "Lea = cansada", "Ester = estrella",
"Ruben = he aqui un hijo", "Elena = luz", "Julio = joven".

Eso convierte la invencion en algo util si se invierte: el modelo es un buen
**detector de la glosa falsa que circula**, que es justo lo que la ficha tiene
que refutar. No sirve para escribir el significado; sirve para saber contra que
esta escribiendo uno. Asi nacio la nota de Antonio sobre la invencion
renacentista, solo que a mano.

## Division del trabajo que queda fijada

La IA **no decide significado ni forma**. Solo hace dos cosas donde no puede
mentir sin que se note:

1. **Proponer candidatos.** Una lista de nombres se verifica sola: si propone
   uno que nadie usa, no se verifica y no entra.
2. **Redactar prosa a partir de datos ya verificados.** No inventa porque no se
   le da margen.

La fuente de verdad sigue siendo OSHB, LSJ, Lewis y Short, Forstemann y Lane.

## Cola de candidatos

66 componentes de nombre sin cubrir, ordenados por consenso entre 9 angulos.
Cabeza de la cola: Carmen, Eduardo, Francisco, Gustavo, Javier, Raul, Teresa
(3/9); despues Abel, Alfredo, Cesar, Hector, Jesus, Marta, Oscar, Paola, Pilar,
Santiago, Sergio (2/9).

El ruido de la propia lista prueba por que la verificacion es obligatoria: colo
**Marquez** (un apellido), **Babel**, **Balaam** y **Judas**.

Los compuestos (`Maria del Carmen`, `Maria de los Angeles`) **no piden ficha
propia**: el modulo guarda el nombre por partes y cada parte resuelve la suya.
Lo que piden es que sus componentes tengan ficha.

### Dos casos que exigen decision editorial antes de entrar

- **Javier** es de origen vasco (Etxeberria). Ninguna de las cinco fuentes con
  licencia lo cubre. Entra solo si se anade una sexta fuente vasca verificada.
- **Carmen** es genuinamente ambiguo: el `carmen` latino ("canto") y el titulo
  mariano del Monte Carmelo (hebreo כרם) son dos historias distintas y la
  segunda es la que explica su uso en Colombia. No es una ficha de una sola raiz.

## Cambios de codigo

- `arcanum_app/tool/dump_name_catalog.dart` (nuevo): vuelca el catalogo a JSON
  para que el arnes mida contra la fuente de verdad y no contra una copia. Vive
  en `tool/` a proposito: `flutter test` sin argumentos solo barre `test/`, asi
  que no corre solo ni escribe archivos de sorpresa. Verificado: la suite sigue
  en 246.
- `tools/names/calibrate_name_model.py` (nuevo): el arnes.
- `tools/names/propose_name_candidates.py` (nuevo): candidatos sin
  significados, con descomposicion de compuestos y consenso por angulo.
- `tools/names/gold.json` (nuevo): el banco de pruebas.
- `docs/prompts/puentes-del-umbral.md` (nuevo): prompt de la fase siguiente.

Las herramientas viven en `tools/names/` y no bajo `arcanum-api/`: leen el
catalogo de Flutter y no tocan una linea de FastAPI. Ponerlas en el backend
implicaba una dependencia que no existe y arrastraba su gate de tests sin
motivo. El hook de pre-commit fue el que lo delato, exigiendo Postgres para un
cambio que no toca el backend.

Ambos scripts aislan el fallo por unidad (por modelo, por angulo): un modelo
roto no puede tirar los resultados de los otros, que costaron cuota real. Se
aprendio por las malas — la primera corrida completa perdio dos modelos ya
evaluados por una excepcion no capturada.

## Pruebas

- `flutter analyze` — sin problemas (216s, proyecto entero).
- `flutter test` — **246 verdes**, sin cambio: no se toco `lib/`.
- `git diff --check` — limpio. CJK y mojibake limpios.
- **Fisico: sigue sin ejecutar.** El OnePlus no aparece en `flutter devices`
  (solo Windows, Chrome, Edge). Es el mismo pendiente que dejo `81e79c1`.

## Siguiente

Sin cambios: **Puentes del Umbral**, con el prompt ya escrito en
`docs/prompts/puentes-del-umbral.md`. La cola de nombres se trabaja aparte,
fuente por fuente, cuando haya sesion para abrir diccionarios.
