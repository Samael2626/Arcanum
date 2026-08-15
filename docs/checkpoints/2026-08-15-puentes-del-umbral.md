# Checkpoint — Puentes del Umbral

- **Fecha:** 2026-08-15
- **Rama:** `feat/nombre-y-umbral-foundation`
- **SHA:** `7017892 feat(umbral): construir los tres puentes opt-in del nombre`
- **Worktree:** `D:/tmp/nombre-y-umbral-foundation`

## Que se construyo

La integracion opt-in del perfil privado de lectura con Tarot, Cielos y
Oraculo. Sin pestanas nuevas, sin pantallas nuevas, sin tocar backend,
migraciones ni `release/p0a-beta`. El catalogo de 128 fichas no se amplio.

## Que cruza cada puente

| Puente | Dato exacto | Tipo | Sale del dispositivo |
|---|---|---|---|
| Tarot | `NameResonance` en memoria: `givenName`, `sourceMeaning`, `traditionLabel`, `editorialLimit`, `gematriaValue`, `gematriaOriginLabel` | objeto | no |
| Cielos | el mismo objeto | objeto | no |
| Oraculo | **solo** `NameCatalogEntry.meaning`, dentro de una clausula fija anexada al `question` que la persona ya envia | `String` en `data['question']` | **si** |

Se quedo fuera, en todos los casos: el apellido, la grafia hebrea, el
dialecto, `pointedHebrew`, `resultId`, las fechas, y hacia el Oraculo tambien
el nombre y el valor de gematria. Si el nombre no tiene ficha en el catalogo,
hacia el Oraculo **no cruza nada**: el texto libre que escribio la persona
jamas se publica.

### Por que el Oraculo va por `question`

`/oracle/ia` acepta hoy `{question, divination_session_id}`. Un campo nuevo lo
descartaria Pydantic en silencio: el puente seria una fuga sin beneficio. Y en
esta fase no se toca backend. Anexar al `question` funciona hoy y se audita
sobre el cuerpo real de la peticion.

### La decision incomoda, dicha en claro

Con 128 fichas, la frase de significado permite deducir el nombre casi de
forma biyectiva ("Humano, hombre." es Adan). Enviar la lectura **es**, en la
practica, enviar el nombre a quien tenga el catalogo. Se decidio construir el
puente igualmente, pero con el interruptor diciendo esa verdad literal en vez
de la formula comoda "no viaja nada tuyo". La politica de privacidad no
necesita cambio: el nombre en si sigue sin salir, y ningun campo nuevo viaja.

## Consentimiento

- Vive dentro del perfil cifrado: `ReadingIdentityProfile.bridges`, schema
  1 -> 2 con migracion que deja todos los puentes apagados.
- Tres interruptores independientes en la pantalla que ya existia. Nunca uno
  agrupado: el remoto y los locales no son la misma concesion.
- Apagados por defecto. Un puente apagado no se distingue de un perfil vacio:
  ausencia total, ni tarjeta ni invitacion.
- El del Oraculo pide confirmacion al encenderse. Apagarlo nunca pregunta.
- Revocar reescribe el perfil sin el flag. No hay residuo porque la resonancia
  se calcula al vuelo y nunca se persiste. Borrar el perfil se lleva el
  consentimiento por construccion.
- El Oraculo ademas muestra, justo encima del boton de envio, la linea exacta
  que va a salir del telefono.

## Que cambio en el test de aislamiento, y por que

`network_isolation_test.dart` prohibia a Tarot y Cielos nombrar
`name_threshold`. Ahora exige que la **unica** ruta importable sea
`name_threshold/bridge.dart`, y anade a Oraculo a la lista de vigilados. Sigue
prohibiendo por nombre `readingIdentityProvider`, `ReadingIdentityProfile`,
`ReadingIdentityRepository`, `ReadingNamePart`, `ConfirmedHebrewForm`,
`NameCatalog`, `HebrewGematria` y `SpanishHebrewConverter`.

Es correcto porque la frontera no se borra: pasa de "no hay contacto" a "hay
una sola puerta y el test la fija". La prohibicion por ausencia era imposible
de mantener con puentes; la prohibicion por ruta es mas estrecha que la
anterior en lo que importa, porque ahora tambien cubre Oraculo.

## Limite editorial

El sujeto gramatical de toda prosa de puente es el nombre o la fuente, jamas
la persona ni la carta: "Las fuentes de tradicion hebrea recogen ese nombre
asi: ...". Un test barre `indica que`, `te corresponde`, `te hace`,
`significa para ti`, `tu destino`, `estas destinad`, `vas a tener`, `predice`,
`revela que eres` y `por tu nombre` sobre toda la prosa generada y sobre los
textos de consentimiento y pie.

La gematria historica sigue cerrada: si una forma se declara historica pero la
tradicion de la ficha no la habilita, el puente **no muestra valor alguno**,
en vez de degradar la etiqueta (que seria mentir en la otra direccion).

## Pruebas

- `flutter analyze lib`: 0 issues.
- `flutter test`: **263 verdes** (246 antes, +17 nuevos).
- `flutter build apk --debug`: OK.
- `git diff --check`: limpio. CJK y mojibake: limpios.
- Golden `02-nombre-y-umbral.png` regenerado: cambia a proposito, la pantalla
  gana la tarjeta PUENTES.

Tests nuevos: `threshold_bridge_test.dart` (12) y
`oracle_bridge_payload_test.dart` (4), que verifica el cuerpo real de la
peticion con un `HttpClientAdapter` capturador: claves exactas
`{question, divination_session_id}`, texto compuesto exacto, y ausencia del
nombre, del apellido, de la grafia hebrea y del valor de gematria.

## Pendiente

- **Verificacion fisica en el OnePlus: sigue sin ejecutarse.** `flutter
  devices` solo lista Windows, Chrome y Edge. Pendiente heredado de la fase
  anterior, ahora con guion concreto: crear identidad, encender un puente,
  tirar una carta, revocar, confirmar que desaparece; logcat sin
  `FATAL EXCEPTION`, `_dependents`, Assertion ni Zone mismatch.

## Listo para Horoscopo

- `ThresholdBridge` es un enum: anadir `horoscope` es una entrada mas, con su
  interruptor y su pie, sin tocar el gate ni el almacenamiento.
- La migracion de schema ya descarta puentes desconocidos sin conceder
  permisos, asi que un binario viejo abre un perfil nuevo sin riesgo.
- `NameResonance` es el unico contrato que Horoscopo tendria que consumir, y
  ya esta recortado y auditado.
