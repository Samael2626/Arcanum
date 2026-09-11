---
tags: [arcanum, roadmap, retos, semana-4]
tipo: roadmap
area: arcanum
actualizado: 2026-09-10
---

# ARCANUM — Oportunidades de Mejora y Retos Futuros

Ver [[ARCANUM-Estado-Sesion]] · [[ARCANUM-Semana3-Flutter]]

## 1. Seguridad y tokens en Flutter ✅ HECHO (commit `529f9dd`)
Migrado a **Dio** con interceptor: adjunta `Bearer <access>`, y ante `401` refresca silenciosamente
(`/auth/refresh`, rota el refresh token, reintenta 1 vez; si falla, limpia sesión). Tokens en
**`flutter_secure_storage`**. `RegisterData` incluye datos natales.

## 2. Cifrado del Grimorio (client-side) ⏳ PENDIENTE (necesita pantallas Grimorio)
Backend ya guarda `encrypted_content` + `content_iv` (server nunca ve plaintext). Falta cliente:
- **AES-256-CBC** (`pointycastle`), IV aleatorio por entrada.
- **Derivación:** ⚠️ NO derivar la clave AES de la contraseña directamente (cambiar contraseña =
  perder todo). Patrón: `PBKDF2(password,salt)` → **KEK** que cifra una **DEK** aleatoria; guardar la
  DEK envuelta. Cambiar contraseña = re-envolver la DEK, no re-cifrar todo.
- DEK desbloqueada en `flutter_secure_storage` (biometría opcional).

## 3. Micro-animaciones ✅ HECHO (parcial)
`PulsingGlyph`: pulso/brillo dorado en el glifo planetario de "Hoy". Fade+slide-in al cargar.
Seguir: transiciones entre pestañas, animación de la fase lunar.

## 4. Gestión de estado ✅ HECHO (base)
**Riverpod** adoptado: `AuthNotifier` (sesión), `arcanumApiProvider`, providers de Dio/storage/repo.
Pantallas con `ConsumerWidget`/`ConsumerStatefulWidget`. Ampliar a futuros features (oráculo, grimorio).

---

## Pendiente para conectar las pestañas restantes (backend nuevo)
- **Grimorio:** endpoints CRUD de `grimoire_entries` + cifrado cliente (reto #2).
- **Arte (Materia Arcana):** endpoints de `materia_items` (hierbas/piedras/metales) + buscador.
- **Oráculo:** tarot (mazos/spreads) + IA ritual (Groq con contexto natal/luna/hora).
- **Onboarding** (5 pasos) pulido.

## Deuda: tres goldens de Hoy no se pueden regenerar ⏳ PENDIENTE (04/09/2026)

`flutter test test/capturas --update-goldens --run-skipped` deja **seis** capturas
al día y falla en tres:

- `04-sello-abierto`
- `04b-pliegue`
- `05-texto-abierto`

Las tres mueren con `Bad state: No element`, pero ya **no** donde decía esta
nota: el `ensureVisible` que se añadió después arregló el `find.text('Abrir el
sello del Sol')`. Ahora revientan más adelante, en
`tester.tap(find.byIcon(Icons.check_box_outline_blank).first)`
(`hoy_capturas_test.dart:367`): las casillas del diálogo de consentimiento no
aparecen. Las tres capturas que sí salen son las del sello **cerrado**, que no
pasan por ese diálogo.

Antes de llegar ahí, el fichero **no compilaba**: `_ApiDeMuestra.horoscope()` se
quedó sin el `{DateTime? day}` que la API ganó, y como el capturador lleva su
`@Tags(['capturas'])` la suite normal lo salta y nadie lo volvió a correr en
semanas. Sincronizada la firma el 08/09/2026; los tres fallos del diálogo siguen.

**No lo causó la banda del año** ni la lámina del zodíaco. Comprobado dos veces
con `git stash` sobre `lib/`: fallaban igual sin ninguno de los dos cambios. Es
deuda anterior.

Consecuencia práctica: las capturas del sello **abierto** que se suben a Play no
se pueden actualizar, así que envejecen cada vez que se toca esa pantalla.
Arreglarlo cuando alguien vuelva a `SkyTodayCard` — probablemente el `drag` fijo
de `-900` px ya no deja el botón donde estaba.

## Deuda: lo que quedó abierto tras el release del 10/09 ⏳ PENDIENTE (10/09/2026)

Tras el lote de 8 bugs de testers se barrieron por todo el árbol las mismas
clases de defecto que ya se habían probado. **La clase «dos nociones de
entorno» salió limpia y se cerró.** Esto es lo que sigue abierto, recontado el
10/09 con el release ya mergeado.

### Glifos sin `ArcanumGlifos` — 34 sitios, pero solo 1 con riesgo real

El respaldo `fontFamilyFallback: kGlyphFallback` solo lo llevan los
constructores de `ArcanumText`. Un `TextStyle(...)` crudo deja que el sistema
elija la fuente, y en varios Android eso es Noto Color Emoji.

El barrido parte del inventario real de la fuente
(`assets/fonts/glifos_manifest.txt`, 41 glifos) y busca todo literal Dart que
contenga uno, más los mapas que los sirven. **Separado por riesgo, que es lo
que importa:**

- **Riesgo real de emoji a color — 1 sitio.** `cielos_screen.dart:998` pinta
  `☽` a 60 px en el estado vacío «Aún no hay carta que trazar». La Luna es de
  los que Android resuelve como emoji. Es el único que queda de esa clase.
- **Ornamentos — 33 sitios.** `✶ ⛧ ✦ ❦ ✧` a 42-60 px en estados vacíos,
  cabeceras y separadores, repartidos por arte, cielos, grimorio, hoy,
  lecturas, onboarding, paywall y `arcanum_card.dart:111` (este último
  compartido por toda la app). No son glifos astrales, así que es improbable
  que salgan como emoji; lo que pierden es la forma garantizada de la fuente.

Ya cerrados en el release: el arte de la carta del Tarot —los 22 mayores, que
era el bug reportado—, los nueve del primer barrido, y `LoginPrompt`.
`ComingSoon` tiene la misma forma exacta que `LoginPrompt` (glifo a 64 px con
estilo propio) y **está en la lista de los 33**.

### Marcado de Gutenberg que el limpiador no cubre — 13 párrafos

`limpiarNotasEditoriales` exige que la nota vaya entre guiones bajos
(`_Descript._]`). Barridos los **5.014 párrafos** del inglés, tres formas se le
escapan y llegan crudas al lector:

  GOVERNMENT AND VIRTUES.]   encabezado en caja alta con ] y SIN cursiva
                             2 párrafos: lily-of-the-valley, polypody-of-the-oak
  * * * * *                  separador de sección de Gutenberg
                             10 párrafos en 5 capítulos
  [Illustration]             marcador de lámina
                             1 párrafo

Afecta también a quien lee en español: solo 82 de los 423 capítulos tienen
traducción y el resto cae al inglés por `textFor`.

Son 13 de 5.014. Tocar la regex arriesga los 1.912 párrafos que hoy limpia
bien, así que si se hace, con tests sobre los tres patrones antes de cambiar
nada.

### Catches que le echan la culpa a la conexión — 3 instancias y una parcial

El mismo antipatrón del sellado del grimorio: un `catch` que responde «revisa
tu conexión» sin mirar qué falló.

  grimorio_screen.dart:431     incondicional; cualquier fallo al abrir
  paywall_screen.dart:243      incondicional; cualquier fallo de precios.
                               Es el flujo de COMPRAS
  lector_screen.dart:185       `snapshot.hasError` -> «no hay conexión»,
                               también con un 500 o una caché corrupta
  grimorio_detail.dart:205     parcial: separa el fallo de descifrado y lo
                               demás lo achaca a la red

El patrón bueno ya existe en el repo y es el que hay que copiar:
`sky_today_state.dart` distingue cuatro casos, y `grimorio_error.dart` mira el
`DioExceptionType` en vez de adivinar. Ojo con `place_chooser.dart`, que
distingue por `contains('socket')` sobre el texto del error: la intención es
correcta pero el método es frágil.

## Deuda: la traducción canónica de Culpeper tiene 2 capítulos, la base 82 ⏳ PENDIENTE (09/09/2026)

`scripts/library_data/culpeper-complete-herbal.es.json` —el fichero del que
lee `seed_library.py`— contiene **2 capítulos**. Los respaldos de la misma
carpeta llegan a **82**, y la base de producción los tiene todos. En algún
momento una corrida del traductor sobrescribió el canónico con su último lote.

No rompe nada mientras nadie reingeste: `seed_library` solo toca los capítulos
que el fichero trae, y los ausentes conservan su `text_es` en la base. Pero
**bloquea las correcciones de datos**: la de la versalita partida (ver el
commit de la reingesta) no puede aplicarse a los 6 capítulos afectados porque
5 de ellos no están en el canónico.

Procedimiento para esa reingesta, cuando se haga:

```
cd arcanum-api/scripts/library_data
cp culpeper-complete-herbal.es.20260811-121513.bak.json    culpeper-complete-herbal.es.json          # el respaldo con los 82
cd ../.. && python scripts/seed_library.py culpeper-complete-herbal --dry-run
python scripts/seed_library.py culpeper-complete-herbal
```

Es seguro: las traducciones revisadas a mano (`translation_status = human`) no
se pisan, y el resto ya son las mismas que hay en la base. Lo que cambia son
los 6 párrafos de la versalita.

Lo que hay que arreglar de fondo es el pipeline: que escriba el corpus entero
o que el canónico no se sobrescriba con un lote parcial.

## Deuda: el ℞ pisando el signo en Cielos ⏳ NO REPRODUCIDO (09/09/2026)

Un tester reportó que en las filas con planeta retrógrado —Neptuno, Plutón,
Nodo Norte— el badge `℞` se superponía al nombre del signo y lo dejaba
ilegible («Cáncer» cortado).

**No se ha conseguido reproducir.** Lo investigado, para que nadie lo repita:

- **NO es falta de separación.** La primera hipótesis fue que el `Row` de
  signo/℞/casa iba sin `spacing`. Es falso: `_Tappable` envuelve cada zona con
  `EdgeInsets.symmetric(horizontal: 5)`, o sea **10 px** entre el nombre del
  signo y el badge. Se escribió el arreglo y un test, y el test **pasaba igual
  sin el arreglo** — que es como se vio el error. Revertido.
- **Tampoco se encoge el texto.** La segunda hipótesis fue el
  `FittedBox(fit: BoxFit.scaleDown)` que envuelve el grupo: al no caber, encoge
  el conjunto entero. Medido en un test a 360 px con las fuentes reales
  cargadas y Neptuno retrógrado en Cáncer, el signo se pinta a **21,2 px**, que
  es su alto nominal para 15 px de fuente. **No hay compresión.**

Falta una variable que no teníamos: qué planeta y qué signo salían exactamente,
o la **escala de fuente del sistema** del móvil del tester (en un teléfono real
casi nunca es 1, y con 1,3 el grupo sí podría dejar de caber). El `FittedBox`
sigue siendo la sospecha viva, porque encoge en silencio hasta tamaños
ilegibles en vez de recortar con elipsis.

Si vuelve a reportarse: pedir captura **con el nombre del planeta visible** y
el ajuste de tamaño de letra del dispositivo. Con eso el test de
`cielos_screen_test.dart` se cierra en una tarde.

## Deuda: el rótulo de sección no puede pasar AA sobre fondo oscuro ⏳ PENDIENTE (08/09/2026)

`SectionLabel` — el rótulo de las tarjetas, «TU CIELO DE HOY» y compañía — va en
`ArcanumColors.goldMuted`, **`#8A6E32`**. Su luminancia relativa es **0,168**, así
que su contraste contra **negro puro** topa en:

    (0,168 + 0,05) / 0,05 = **4,36**

AA pide 4,5. O sea que ese color **no puede pasar AA sobre ningún fondo oscuro**,
por mucho que se oscurezca el fondo: el techo está por debajo del umbral. No es
un problema de la lámina del zodíaco ni de una pantalla concreta — es de paleta y
sale en toda la app, en cada tarjeta que usa el rótulo.

Medido sobre las capturas de `test/capturas/salida/zodiaco-*.png`, con la lámina
detrás el rótulo va de **3,44 a 4,08** según lo clara que sea la plancha (el peor,
Sagitario, que tiene papel crema arriba). Sin lámina se queda igualmente por
debajo del 4,36 teórico. La lámina se come parte del margen que quedaba, no lo
crea.

Arreglo: subir el color del rótulo. `ArcanumColors.gold` (`#C9A84C`) da 0,409 de
luminancia, o sea techo 9,19 — pasa de sobra. Es un cambio de paleta que toca
todas las pantallas, así que hay que mirarlo entero de una vez y no por parches.

El resto del texto de la tarjeta sí pasa con la lámina puesta: titular 4,98 a
17,31, separación 4,56 a 9,18 y acción 7,18 a 8,64, con el mínimo en Escorpio.
Ese 4,56 va justo, y el método de medida (percentil 75 de la fila, sobre la
captura) es aproximado: si algún día se afina, empezar por ahí.

## Deuda: el botón de "tu siguiente paso" se desborda a 360 px ⏳ PENDIENTE (04/09/2026)

`hoy_screen.dart:340` — el `Row` del botón de acción no envuelve ni recorta:
con una etiqueta larga se desborda **26 px** a la derecha en un ancho lógico de
360 (el teléfono de referencia del capturador). Apareció al montar la app entera
por el router en `test/features/navegacion/boton_horoscopo_test.dart`, que
produce un "siguiente paso" distinto al de las capturas.

No es del botón del horóscopo: el FAB es una capa superpuesta y no participa en
ese `Row`. Ese test corre a 411 px para no fallar por algo que no prueba.

Arreglo probable: `Flexible` + `softWrap` sobre el `Text`, o `FittedBox`. Cuando
alguien toque esa tarjeta.

## Deuda: el horóscopo llama "casa" a un planeta ⏳ PENDIENTE (10/09/2026)

Salida real de `openai/gpt-oss-120b`, corrida del 10/09 con el prompt de la
frontera nueva:

> «tu **Mercurio natal** en Piscis, **la casa** que habla de la escritura y el
> comercio»

Mercurio es un planeta, no una casa. Son dos cosas distintas de la doctrina y
el texto las confunde delante del usuario, que es justo a quien la app dice que
enseña por uso.

**No es de la vuelta del 10-sep.** Se vio en esa ronda porque se estaban
leyendo salidas con lupa, pero nada de lo que se cambió ahí toca la
nomenclatura: es un fallo anterior, del mismo tipo que los que se cazan con
guarda determinista en vez de pidiéndolo por enésima vez en el prompt.

Arreglo probable, en la línea de `horoscope_guard`: una comprobación que
detecte un nombre de planeta seguido de «la casa» / «el sector» / «la zona» en
la misma frase. La lista de planetas ya existe en `correspondences.PLANET_DOMAINS`
y el bloque de datos dice cuál es cuál, así que se puede mirar con una función
pura. Cuidado con el falso positivo legítimo: «tu Venus en la casa 7» sí es
correcto, y ahí «casa» va con número.

Revisarlo por separado, no mezclado con un ajuste de voz.

## Operativo
- `C:` se llenó (0 GB) → Dart falla al compilar. `TEMP`/`TMP` del usuario ya
  apuntan a `D:\tmp` de forma permanente, así que no hay que pasarlos en cada
  build. Sigue pendiente liberar `C:`, que va al 93 %.
- **La caché de pub NO va dentro de `D:\tmp`.** Estuvo ahí y el 11/09/2026 se
  movió a `D:\Softwares\PubCache` (variable de usuario `PUB_CACHE`, persistente).
  `D:\tmp` es el directorio temporal del usuario y lo barren: el 10/09 se
  encontró con 153 de 185 paquetes reducidos a su `pubspec.yaml`, y eso tiró
  un build de release entero. El síntoma y el arreglo (`dart pub cache repair`)
  están en `ARCANUM-Play-Console-Progreso.md`.
