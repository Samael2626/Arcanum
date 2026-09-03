# Ficha de Google Play — ARCANUM

Todo lo que hay que rellenar en Play Console, con la respuesta ya decidida y el
porque. Lo que dice "VERIFICAR" es lo unico que queda por decidir.

- **Paquete:** `com.arcanum.magick`
- **Bundle:** `.tmp/arcanum-1.0.0+5.aab` (versionCode 5)
- **Cuenta:** personal creada despues del 13/11/2023 -> **sujeta a prueba
  cerrada con 12 testers durante 14 dias continuos**

---

## 0. Las URLs legales, ya publicadas

No hizo falta montar hosting: **GitHub Pages ya estaba sirviendo** desde la rama
`gh-pages`, con HTTPS y repo publico.

```
Privacidad  https://samael2626.github.io/Arcanum/privacy-policy.html
Terminos    https://samael2626.github.io/Arcanum/terms-of-service.html
Borrado     https://samael2626.github.io/Arcanum/account-deletion.html
Indice      https://samael2626.github.io/Arcanum/
```

Se editan en la rama `gh-pages`, NO en `arcanum_app/web/`. Hubo un borrador
duplicado ahi y se quito: dos copias de una politica legal es una que miente.

### El sitio web del desarrollador NO puede ser GitHub Pages

Verificado en la ayuda de AdMob: el rastreador busca en
`https://<hostname>/app-ads.txt` y **solo mira el directorio raiz**. Una pagina
de PROYECTO de GitHub Pages vive en `samael2626.github.io/Arcanum/`, que es un
subdirectorio: no vale. Google nombra Firebase Hosting como la salida, y sus
subdominios `.web.app` si son raiz.

```
Sitio del desarrollador  https://arcanum-app-magick.web.app
app-ads.txt              https://arcanum-app-magick.web.app/app-ads.txt
```

Los documentos legales se quedan en GitHub Pages: son campos distintos de la
ficha y no tienen que compartir dominio.

> **El sitio ya estaba desplegado con una PWA vieja, y `/app-ads.txt` devolvia
> HTTP 200 con `text/html`** — el HTML de la app, servido por el rewrite
> `** -> /index.html`. Un 200 que parece correcto y no lo es: AdMob habria
> fallado la verificacion mientras cualquier comprobacion ingenua decia que todo
> bien. El rewrite se quito y `firebase.json` apunta ahora a `arcanum_app/sitio/`,
> una pagina de soporte pequena, en vez de al build de Flutter.
>
> Comprobado en un canal de vista previa antes de tocar nada:
> `app-ads.txt` sale `text/plain`, la raiz sirve la pagina, y una ruta inventada
> da 404 en vez de tragarsela el rewrite.

---

## 0 bis. El orden correcto

El reloj de los 14 dias es lo unico que no se puede acelerar. Todo lo demas cabe
dentro de esa ventana, asi que **primero se arranca el reloj**:

```
1. ~~Desplegar hosting~~      HECHO 26/08: legales en GitHub Pages, y
                              Firebase Hosting desplegado en vivo
                              (app-ads.txt ya sale text/plain)
2. Crear la app en Play Console
3. Declaraciones de contenido -> privacidad, Data Safety, clasificacion, anuncios
4. Ficha (textos + graficos)
5. Subir el AAB a PRUEBA CERRADA  <- aqui arranca el reloj
6. Meter a los 12 testers y que NO se salgan
7. Dia 14: pedir acceso a produccion
8. Revision (<= 7 dias habitualmente)
9. Produccion -> vincular en AdMob -> revision de AdMob
```

---

## 1. Textos de la ficha

**Nombre de la app** (max 30):

```
ARCANUM
```

**Descripcion breve** (max 80):

```
Tarot, carta natal y grimorio cifrado. Un instrumento, no un oráculo.
```

**Descripcion completa** (max 4000):

```
ARCANUM es un panel de trabajo para quien practica, no una app de predicciones.

No te dice lo que va a pasar. Te muestra el cielo que tienes encima ahora mismo,
calculado con efemérides reales a partir de tu hora y tu lugar de nacimiento, y
te enseña a leerlo por el uso.

QUÉ TRAE

· Tu cielo de hoy. Los tránsitos que tocan tu carta natal hoy, ordenados por
  peso real: cuál es el capítulo lento de fondo y cuál el clima del día. Cada
  aspecto se dibuja, no se enuncia.

· Carta natal. Cálculo con Swiss Ephemeris, casas Placidus y sistema
  configurable. Planetas clásicos, ángulos, aspectos y sus orbes.

· Tarot. Los 78 arcanos con varias tiradas, e interpretación que parte de tu
  pregunta y no de un texto enlatado.

· Materia arcana. Plantas, piedras, metales y perfumes con sus correspondencias,
  tomadas de fuentes históricas —Agrippa, Culpeper, Dioscórides— y no inventadas.

· Grimorio cifrado. Tus notas se cifran con AES-256 en tu propio teléfono. El
  servidor guarda texto cifrado y no tiene forma de leerlo.

· Hora planetaria y regente del día, calculados para tu ubicación.

CÓMO FUNCIONA EL PLAN GRATUITO

Hay un número de consultas al día. La suscripción quita ese límite. No
desbloquea contenido distinto: es el mismo material.

LO QUE ARCANUM NO HACE

No predice el futuro. No da consejo médico, legal ni financiero. No promete
resultados. Es un instrumento de estudio y de práctica, y está escrito como tal.
```

> El ultimo bloque no es humildad: Play tiene politica sobre apps que hacen
> afirmaciones enganosas, y el texto de la ficha es lo primero que se mira.

---

## 2. Data Safety (Seguridad de los datos)

Sacado de los modelos de `arcanum-api`, no de memoria.

### Preguntas de cabecera

| Pregunta | Respuesta |
|---|---|
| ¿Recoge o comparte datos de usuario? | **Sí** |
| ¿Se cifran en tránsito? | **Sí** — todo va por HTTPS |
| ¿Se puede pedir el borrado? | **Sí** — en la app y por web. `DELETE /users/me` (`routers/users.py:40`) borra la fila del usuario y **todo lo colgado en cascada** (`ondelete="CASCADE"` en grimorio, carta natal, tiradas, conversaciones del oráculo, créditos, tokens) y además pide a RevenueCat borrar el customer (`:50`). La única excepción es Groq: ver la nota al pie de la tabla |
| URL de borrado | `https://samael2626.github.io/Arcanum/account-deletion.html` |
| ¿Cumple la política de familias? | No aplica: publico objetivo 18+ |

### Tipos de datos

| # | Categoría de Play | Tipo | Recogido | Compartido con | Finalidad | Cifrado en tránsito | Oblig. | Borrable | Evidencia |
|---|---|---|---|---|---|---|---|---|---|
| 1 | Info personal | Dirección de correo | Sí | No | Cuenta y autenticación | Sí | **Sí** | Sí | `models/user.py:12` |
| 2 | Info personal | Nombre | Sí | **No** | Personalizar la App | Sí | No | Sí | `models/user.py:14`; ya **no** viaja a Groq: `services/oracle_context.py:116` |
| 3 | Info personal | Otra info (fecha y hora de nacimiento) | Sí | No en crudo | Cálculo de la carta natal | Sí | No | Sí | `models/user.py:15-16` |
| 4 | Ubicación | Ubicación aproximada | Sí | No | Hora planetaria y fecha local | Sí | No | Sí | `models/user.py:26-27` |
| 5 | Ubicación | Ubicación precisa | Sí | No | Coordenadas de nacimiento y actuales | Sí | No | Sí | `models/user.py:17-18, 24-25` |
| 6 | Info financiera | Historial de compras | Sí | **Sí — RevenueCat, Google Play Billing** | Gestionar la suscripción | Sí | No | Sí | `models/user.py:30`; `monetization_service.dart:65,70` |
| 7 | Mensajes | Otros mensajes en la app | Sí | **Sí — Groq** | Generar las lecturas | Sí | No | Sí | `models/oracle_conversation.py:13`; `claude_service.py:168-170` |
| 8 | Actividad en la app | Otro contenido generado por el usuario | Sí | No | Grimorio: **título y etiquetas en claro**, cuerpo cifrado | Sí | No | Sí | `schemas/grimoire_entry.py` (`title`, `tags` fuera del cifrado) |
| 9 | Info y rendimiento | Registros de fallos | Sí | Sí — Google/Crashlytics | Funcionalidad y diagnóstico | Sí | No | Sí | `main.dart:29,31` |
| 10 | Info y rendimiento | Diagnósticos | Sí | Sí — Google/Crashlytics | Diagnóstico | Sí | No | Sí | `main.dart:59,73` |
| 11 | ID de dispositivo | ID de dispositivo o de otro tipo | Sí | Sí — Google (AdMob, Firebase) | Publicidad e identificación de instalación | Sí | No | Parcial | manifiesto del AAB: `MobileAdsInitProvider`, `AD_ID`, `FirebaseInstallationsRegistrar` |

**Filas que NO se declaran, y por qué:**

- **Contraseña.** Play no tiene un tipo de dato para credenciales. No se declara como
  fila; se guarda con **bcrypt** (`core/security.py:14`), nunca en claro.
- **Cuerpo del grimorio.** Cifrado con AES-256-GCM en el dispositivo
  (`grimoire_crypto.dart:34-45`); el servidor recibe `encrypted_content` + `content_iv`
  y no tiene la clave. **No es contenido compartido.** Lo que sí se declara es la
  fila 8, por el título y las etiquetas.
- **Actividad de uso / analítica.** `firebase_analytics` no está en el `pubspec`.
- **Archivos y documentos, contactos, agenda, fotos, audio, salud, navegación web.**
  Nada de eso se toca.

> **Ojo con la fila 8.** La decisión previa "sin Actividad en la app" se refería a
> analítica de uso, y sigue siendo correcta para eso. Pero en la taxonomía de Play
> *Otro contenido generado por el usuario* **cuelga de "Actividad en la app"**, y el
> título y las etiquetas del grimorio viajan en claro: `GrimoireEntryCreate` cifra
> `content`, no `title` ni `tags`, y `GrimoireEntrySummary` lo dice explícitamente
> ("el título va en claro como índice"). Hay que marcar esa subcasilla.

> **La ubicación es PRECISA aunque no se lea el GPS.** Comprobado: el manifiesto
> declara **solo `INTERNET`** y no hay `geolocator` ni `permission_handler` en el
> `pubspec`. Las coordenadas salen del catálogo de ciudades. Pero Play clasifica por
> el dato, no por cómo se obtuvo.

> **El borrado no alcanza a Groq, y hoy eso es un agujero abierto.** La fila 7
> viaja a Groq. Verificado el 24/08 en su documentación: no retiene inferencias por
> defecto ni entrena con ellas, pero **puede loggear entradas y salidas hasta 30 días**
> por fiabilidad y abuso. **ZDR es activable por cualquier cliente en Data Controls y
> sigue sin activarse** (pendiente en `ARCANUM-Play-Console-Progreso.md`). Mientras no
> se active, el borrado de cuenta no puede prometer que lo enviado a Groq desaparezca
> de inmediato: activarlo es lo que cierra el hueco.

> **Anthropic no está en uso**, pese al nombre del archivo `claude_service.py`. El
> único proveedor de IA es Groq (`_GROQ_MODEL = "llama-3.3-70b-versatile"`). Si algún
> día vuelve a entrar, es una fila nueva de terceros.

> **La ubicación es PRECISA aunque no se lea el GPS.** El manifiesto declara
> solo `INTERNET` —comprobado— y las coordenadas se teclean al elegir ciudad.
> Pero Play clasifica por el dato, no por cómo se obtuvo, y unas coordenadas son
> ubicación precisa. Declararlo como aproximada sería falso.

> **Las entradas del grimorio NO se declaran como compartidas.** Se cifran con
> AES-256 en el dispositivo; el servidor almacena texto cifrado y no tiene la
> clave. Verificado en `app/routers/grimoire.py` y en los esquemas.

### Firebase Analytics: quitado

Estaba en `pubspec.yaml` sin que ningún fichero de `lib/` lo importara, y sin
`setAnalyticsCollectionEnabled(false)`. En Android el SDK recoge por su cuenta
con solo estar en el classpath: `GeneratedPluginRegistrant` lo registraba.

**Se eliminó la dependencia** (25/08). Por eso *Actividad en la app* no aparece
en la tabla: ya no se recoge. Si algún día se vuelve a añadir, hay que declararla
otra vez — es una fila del formulario, no un detalle técnico.

Crashlytics se queda: sus fallos sí se miran, y va declarado.

**Comprobado en el AAB, no supuesto.** Las clases
`com/google/android/gms/measurement` **siguen apareciendo en el dex**: las
arrastran transitivamente AdMob y Firebase Sessions. Eso asusta al verlo, pero no
significa que se recoja nada. Lo que decide es qué componentes declara el
manifiesto fusionado:

```
CrashlyticsRegistrar            presente   esperado
FirebaseSessionsRegistrar       presente   sesiones, las usa Crashlytics
FirebaseInstallationsRegistrar  presente
AnalyticsRegistrar              AUSENTE
AppMeasurement* / ContentProvider  AUSENTE
```

Sin registrar ni proveedor declarado, el SDK **nunca se inicializa**. Es peso
muerto en el binario, no codigo que corra. Si alguna vez hay que rebatir esto,
la comprobacion es leer los nombres de componente del manifiesto del AAB — no
buscar cadenas en el dex, que da un falso positivo.

Aparecen ademas dos cosas legitimas: el permiso
`com.google.android.gms.permission.AD_ID` (AdMob, ya declarado) y
`SessionLifecycleService` (Crashlytics agrupando fallos por sesion).

---

## 3. Clasificación de contenido

Cuestionario IARC, adaptativo: las preguntas cambian según lo que se responde,
así que aquí va **el fondo**, no un guion literal.

| Tema | Respuesta | Por qué |
|---|---|---|
| Violencia | No | No hay |
| Sexualidad | No | No hay |
| Lenguaje soez | No | El texto es formal |
| Sustancias controladas | **Cuidado** | Hay hierbas en Materia Arcana. Son correspondencias históricas, no instrucciones de consumo. Si el cuestionario pregunta por referencias a drogas, la respuesta honesta es que hay contenido botánico histórico sin fomento de consumo |
| Juegos de azar | No | El tarot **no** es azar simulado con premio. No hay apuestas ni moneda que se gane por azar |
| Compras integradas | **Sí** | Suscripción por RevenueCat |
| Interacción entre usuarios | No | No hay social ni chat entre personas |
| Comparte ubicación con otros usuarios | No | La ubicación no se muestra a nadie |
| Contenido de terror/oculto | **Sí, declararlo** | Es una app de práctica mágica. Ocultarlo es lo que reclasifica una ficha a posteriori |

**Público objetivo:** 18+. Coherente con la edad mínima de la política de
privacidad, y evita de raíz la política de familias.

**¿Contiene anuncios?** **No.** Este build no muestra ni un anuncio:
`MobileAds.instance.initialize()` está detrás de `ReleaseConfig.adsEnabled`
(`main.dart:35`), que es `bool.fromEnvironment('ADS_ENABLED')` sin valor por
defecto, y el AAB 1.0.0+7 se compiló sin esa bandera. Marcar "Sí" pondría el
distintivo "Contiene anuncios" en una ficha cuya app no los tiene.

> **Esto NO contradice la fila de ID de dispositivo de la sección 2.** Son dos
> preguntas distintas: aquí Play pregunta si la app **muestra** anuncios; allí,
> si **recoge** el identificador de publicidad. El SDK de AdMob viaja en el
> binario y su `ContentProvider` de auto-arranque **sí está declarado** en el
> manifiesto del AAB —comprobado: `com.google.android.gms.ads.MobileAdsInitProvider`,
> más los permisos `AD_ID` y `ACCESS_ADSERVICES_AD_ID`—, así que la fila del
> Ad ID se queda declarada. Es el caso contrario al de Analytics, donde el
> registrador estaba **ausente**: ahí el SDK no arranca y aquí sí puede.

> **Cuando se activen los anuncios hay que volver a esta casilla.** Al compilar
> con `ADS_ENABLED=true` la respuesta pasa a "Sí", y antes hay que implementar
> UMP (`TODO(compliance)` en `main.dart:36`).

---

## 4. Material gráfico

Todo generado y validado contra los requisitos de Play:

```
build/ficha/icono-512.png                    512x512   RGBA (32-bit, con alfa)
build/ficha/grafico-destacado-1024x500.png  1024x500   RGB  (24-bit, sin alfa)
build/ficha/capturas/*.png                 1080x1920   RGB  x6
```

Se regenera con `python tool/generar_material_ficha.py`.

> **Por qué 1080x1920 y no el formato del móvil.** Play exige que el lado mayor
> de una captura no pase del **doble** del menor. El formato moderno (390x844,
> y su 3x 1170x2532) lo incumple: 2532 > 2340. Las capturas salían así y Play
> las habría rechazado. 1080x1920 es 9:16 exacto, cumple, y además es el mínimo
> para entrar en las secciones destacadas.

> El capturador retrata la **raíz** de la app, no la pantalla, por dos razones:
> los diálogos viven en el overlay, y el golden de un hijo se captura en píxeles
> lógicos ignorando el `devicePixelRatio`. Al pasar a retratar la raíz apareció
> el **banner de DEBUG** en la esquina, que antes quedaba fuera del recorte.
> Está apagado con `debugShowCheckedModeBanner: false`.

Pendiente si se quiere: `Icon-maskable-512.png` y `Icon-maskable-192.png` de
`web/icons/` **siguen siendo el logo por defecto de Flutter**. No afecta a Play
—solo a la PWA instalada— pero se ve al desplegar el hosting.

---

## 5. Los 12 testers

El cuello de botella. Lo que dice Google, literal:

> Mínimo **12 testers** optados de forma **continua** durante **14 días**. Los
> que entran, prueban menos de 14 días y se salen, **no cuentan**.

### Mecánica

1. Play Console → **Pruebas** → **Prueba cerrada** → crear pista.
2. Lista de testers: correos de Google, uno por línea. **Mete más de 12** —
   14 o 15— porque alguien no aceptará o se saldrá y el contador vuelve atrás.
3. Subir el AAB a esa pista.
4. Copiar el **enlace de aceptación** y mandarlo. Cada persona tiene que:
   abrir el enlace, aceptar ser tester, e **instalar la app**.
5. No sacar a nadie de la lista durante los 14 días.
6. Desde 2026 Google también mira que los testers **usen** la app de verdad, no
   solo que estén apuntados.

### Texto para invitar

```
Estoy publicando ARCANUM en Google Play y necesito 12 personas que la prueben
antes de que pueda salir. Google lo exige: 12 cuentas apuntadas durante 14 días
seguidos.

Qué te pido:
1. Mandarme el correo de Google que usas en el móvil Android.
2. Cuando te pase el enlace, aceptar e instalar.
3. NO desinstalar ni salirte durante dos semanas. Si te sales, el contador se
   reinicia para todos.
4. Abrirla de vez en cuando. Google mira que se use de verdad.

Es gratis y no tiene letra pequeña. Si encuentras algo roto, mejor: para eso es.
```

### Seguimiento

| # | Nombre | Correo de Google | Aceptó | Instaló | Fecha de alta |
|---|---|---|---|---|---|
| 1 | | | | | |
| 2 | | | | | |
| 3 | | | | | |
| 4 | | | | | |
| 5 | | | | | |
| 6 | | | | | |
| 7 | | | | | |
| 8 | | | | | |
| 9 | | | | | |
| 10 | | | | | |
| 11 | | | | | |
| 12 | | | | | |
| 13 | | | | (reserva) | |
| 14 | | | | (reserva) | |

**La fecha que cuenta es la del último que se apunta**, no la del primero.

---

## 6. Lo que sigue bloqueado

- ~~URLs legales sin servir~~ — resuelto: ya estaban en GitHub Pages.
- **AdMob.** No se puede vincular hasta que la app exista en Play. Y
  `app-ads.txt` no verifica hasta que haya sitio web declarado en la ficha.
- **Clave pública de RevenueCat.**
- **Copia del keystore fuera del repo.** Si se pierde, no hay actualizaciones
  de esta app nunca más.
