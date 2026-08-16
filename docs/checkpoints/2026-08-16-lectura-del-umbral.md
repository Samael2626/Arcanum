# Checkpoint — Lectura del Umbral

- **Fecha:** 2026-08-16
- **Rama:** `feat/nombre-y-umbral-foundation`
- **SHA:** `8247325 feat(umbral): construir la Lectura del Umbral y matar los dos P0`
- **Worktree:** `D:/tmp/nombre-y-umbral-foundation`
- **Alcance:** solo el nucleo gratuito. Sin creditos, sin RevenueCat, sin
  suscripcion Mistico. Sin pestanas ni pantallas nuevas.

## Los dos P0

### 1. Zona local explicita

`app/services/local_window.py`. El dia natural de una persona se resuelve en su
zona, no en la del servidor. Con `datetime.now(timezone.utc).date()`, alguien en
Bogota recibia la lectura del dia siguiente durante las ultimas cinco horas de
cada jornada, y alguien en Tokio la del anterior durante las primeras nueve. No
es un redondeo: es un dia equivocado.

Decision de fondo: **el instante de referencia es el mediodia local, no "ahora"**.
Asi la lectura es la misma a las 00:05 y a las 23:55 — una tesis diaria que
cambia cada hora no es una tesis — y ademas esquiva el hueco de los cambios de
horario de verano, donde la medianoche local puede no existir.

`/astral/today` gana `tz` opcional y devuelve `local_date`, `timezone`,
`day_window` y `degraded_reason`. Sin `tz`, `local_date` es `null` y la
respuesta dice por que. Una zona rota da 422; nunca se cae a UTC en silencio.

Fixtures: mismo instante en cuatro zonas (Bogota, UTC, Tokio, Kiritimati), los
dos lados de la medianoche local, dia de 23 horas (2026-03-08, Nueva York) y
dia de 25 (2026-11-01).

### 2. Fuera el fallback de Bogota

Estaba en dos sitios, no en uno:

- `app/services/oracle_context.py`: `_FALLBACK_LAT/_FALLBACK_LON` borrados.
  `_coords()` devuelve `None` y el contexto declara la ausencia con una
  instruccion explicita al modelo: *"No la inventes ni la sustituyas por otra
  ciudad."*
- `arcanum_app/lib/core/api/arcanum_api.dart`: **`today()` traia
  `lat = 4.71, lon = -74.07` como valores por defecto.** Toda la app mostraba la
  hora planetaria de un meridiano ajeno sin que nada en la pantalla lo
  insinuara. Ahora son obligatorios. Sin lugar confirmado, Hoy muestra una
  tarjeta que lo dice y ofrece confirmarlo; el editor del Grimorio sella la
  entrada sin anotacion astral en vez de con una falsa.

Un test barre `lib/` entero buscando esas coordenadas y verifica por regex que
`today()` no tenga ningun parametro con valor por defecto.

## El selector — contrato `horoscope_daily/1`

Tres decisiones gobiernan todo:

1. **La lectura de un dia es funcion de (carta, fecha local)**, no del instante.
2. **Se ordena por dias a exacto, no por grados de orbe.** Pluton a 3 grados
   lleva meses ahi; Pluton exacto hoy es la noticia de hoy. Filtro de entrada:
   `|dias_a_exacto| <= 1`.
3. **La Luna en transito no entra al pool.** Hace cinco aspectos exactos al dia:
   si entrara, ningun otro factor pasaria nunca y el ritmo se disfrazaria de
   titular. Aparece como ritmo de fondo, con `is_headline: false`.

```
exactitud = max(0, 100 - round(|dias_a_exacto| * 100))
score = exactitud*10 + rareza*60 + personal*40 + aspecto*12 + aplicativo*25
```

- rareza (transitante): pluton/neptuno/urano/saturno 5, jupiter 4, marte/sol 3,
  venus/mercurio/nodo 2.
- personal (receptor natal): sol/luna 5, ASC/MC 5 (solo con hora),
  mercurio/venus/marte 3, jupiter/saturno 2, exteriores 1.
- aspecto: conjuncion 5, oposicion/cuadratura 4, trigono 3, sextil 2.

**Desempate** (orden total, cero azar): menor `|dias_a_exacto|` -> mayor rareza
-> mayor personal -> alfabetico de `(transitante, natal, aspecto)`. El tramo
alfabetico existe para que dos empatados no queden a merced del orden del dict.

**Cuantos:** el segundo entra solo si su score llega al 60% del primero y no
repite ni transitante ni receptor. Nunca tres. Repetir planeta no da un segundo
hecho: da el mismo hecho dicho dos veces.

Se anadio `speed` a `current_positions()` en `natal_chart_engine.py`. Sin
velocidad no hay "aplicativo" ni "dias a exacto". Es aditivo; no se reescribio
ni una efemeride.

## El texto no lo escribe un modelo

`app/services/umbral_editorial.py` compone la lectura desde un corpus finito y
versionado. Es una decision, no una limitacion: "cero afirmaciones prohibidas"
solo puede ser una propiedad verificable si el conjunto de frases posibles esta
escrito en el repositorio. Con generacion libre seria una esperanza con tests de
muestreo. El modelo entra despues, si la persona lo pide, por la via de
profundizar — que en esta fase esta apagada.

El vocabulario de dominios es deliberadamente abstracto ("el limite, el tiempo y
lo que sostiene" para Saturno). No es pudor: el dominio de un planeta escrito en
terminos concretos convierte cualquier frase condicional en un consejo
encubierto.

## Casos dificiles

| Caso | Que se muestra |
|---|---|
| Sin transito destacado | Ritmo lunar (fase, iluminacion, signo), `is_headline: false`. Si hay transito colectivo exacto, entra etiquetado "lo comparte todo el mundo y no describe tu carta" |
| Sin hora natal | `precision: no_time`. Ni casas, ni Ascendente, ni Medio Cielo. **La Luna natal se excluye del pool**: sin hora puede desviarse hasta 6,5 grados y cualquier aspecto suyo seria inventado. Se declara en los limites |
| Sin carta natal | `precision: general`, `is_personalized: false`, y lo dice |
| Sin zona horaria | `precision: unavailable`. Contrato completo, `reading: null`, razon explicita. Nunca un 422 mudo: la pantalla de Hoy se quedaria sin nada que decir |
| Factores contradictorios | `tension: true`, dos titulares separados y una linea explicita: *"el cielo del dia no trae una moraleja, y fabricarle una seria escribir por encima de lo que se calculo"* |
| Sin internet | Ultima lectura cacheada y cifrada, con su fecha y su zona originales, marcada "No actualizada". **No se regenera** |

Frase para el caso comun, que es el aburrido: *"Hoy ningun transito perfecciona
sobre tu carta. Eso no es un fallo ni una carencia: la mayoria de los dias el
cielo no tiene un titular, y decirlo es mas honesto que ascender el ritmo de
fondo a noticia."*

## Flutter

- `lib/features/umbral/` — dominio, cache cifrado, controlador, dos vistas.
- **Hoy**: `UmbralBlock`. Hecho del dia, etiquetas de estado (precision, no
  personalizada, no actualizada, tension) y una sola puerta. No repite la
  lectura entera: si Hoy la cuenta toda, abrir el Oraculo deja de tener sentido.
- **Oraculo**: `UmbralReadingView` con los cinco bloques en orden fijo, la
  reflexion cifrada, la CTA inerte y la trazabilidad al pie.
- El cache va cifrado con `GrimoireCrypto` en `FlutterSecureStorage`: la lectura
  lleva dentro signos y casas natales, y guardarla en claro seria la copia sin
  candado de lo que el Grimorio si protege.
- La reflexion esta **cerrada por defecto**. Una caja de texto siempre abierta
  bajo una lectura diaria es una invitacion permanente a dejar rastro, y el
  rastro se pide.

## Analitica

Estado real, comprobado: **la app no tiene ni un emisor de analitica**.
`firebase_analytics` esta en `pubspec.yaml` pero no se importa ni se instancia en
ningun sitio de `lib/`. No hay eventos que auditar.

El test no simula uno para tener algo verde: fija la ausencia. El dia que alguien
conecte un emisor, falla y obliga a decidir a mano que puede llevar un evento —
que segun la direccion editorial nunca es texto, ni ciphertext, ni fecha, hora o
lugar natal exactos.

## Pruebas

- **Backend: 273 verdes** (214 antes, +59). 3 skipped preexistentes.
- **Flutter: 288 verdes** (263 antes, +25).
- `flutter analyze lib`: 0 issues. `flutter build apk --debug`: OK.
- `git diff --check`: limpio. CJK y codificacion: limpios.

Adversariales (`tests_unit/test_umbral_editorial.py`): 360 lecturas generadas
(120 fechas x 3 niveles de precision) y **mas de 3.000 cadenas barridas** contra
73 formulas prohibidas en siete familias — prediccion determinista, consejo
imperativo, medico, legal, financiero, de vinculo y de miedo/urgencia. El
barrido cubre tambien el corpus fijo completo, para que anadir una constante sin
tocar el test no abra un agujero.

Dos invariantes duros:
- **La lectura simbolica y la practica no contienen ni un digito.** Si el texto
  interpretativo no puede llevar cifras, no puede colar un hecho fabricado.
- Cada cifra del bloque de cielo observado se verifica contra el factor que
  produjo el motor.

## Pendiente

- **Verificacion fisica en el OnePlus: sigue sin ejecutarse.** `flutter devices`
  lista Windows, Chrome y Edge. Guion cuando aparezca: abrir Hoy con lugar
  confirmado y sin el, abrir la lectura en Oraculo, guardar una reflexion,
  cortar la red y confirmar que aparece "No actualizada" con la fecha vieja;
  logcat sin `FATAL EXCEPTION`, `_dependents`, Assertion ni Zone mismatch.

## Hallazgo de infraestructura

`arcanum-test-db` no publicaba puerto, y **el 5433 que el hook usaba por defecto
lo ocupa `botlaw-pg`**. El hook llevaba tiempo apuntando a la base de otro
proyecto: fallaba con "password authentication failed" y parecia un problema de
credenciales. Contenedor recreado en 5434 y default del hook corregido.

## Que queda para la fase de monetizacion

- La CTA "Profundizar con el Oraculo" esta construida y visible, con opacidad
  reducida y el texto "Todavia no disponible". Encenderla es cablear un
  `onPressed`; un test verifica hoy que no lo tiene.
- El contrato ya viaja versionado, asi que el endpoint de profundizacion puede
  recibir el factor exacto que la persona vio sin volver a calcularlo.
- Sigue condicionada a RevenueCat sandbox verde. Mezclarla con esta fase habria
  atado un gate editorial ya resuelto a uno de cobro que no lo esta.
