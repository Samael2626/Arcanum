# Ficha de Google Play — ARCANUM

Todo lo que hay que rellenar en Play Console, con la respuesta ya decidida y el
porque. Lo que dice "VERIFICAR" es lo unico que queda por decidir.

- **Paquete:** `com.arcanum.magick`
- **Bundle:** `.tmp/arcanum-1.0.0+4.aab` (versionCode 4)
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

> `app-ads.txt` sigue siendo aparte. Tiene que estar en la RAIZ del dominio que
> se declare como sitio web del desarrollador. Si se declara este, el fichero
> tiene que ir a `gh-pages`, no al build de Flutter.

---

## 0 bis. El orden correcto

El reloj de los 14 dias es lo unico que no se puede acelerar. Todo lo demas cabe
dentro de esa ventana, asi que **primero se arranca el reloj**:

```
1. ~~Desplegar hosting~~      HECHO: GitHub Pages ya servia
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

Hay un número de consultas al día. Se puede ampliar viendo un anuncio, o quitar
el límite con la suscripción. Ni una cosa ni la otra desbloquea contenido
distinto: es el mismo material.

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
| ¿Se puede pedir el borrado? | **Sí** — en la app y por web |
| URL de borrado | `https://samael2626.github.io/Arcanum/account-deletion.html` |
| ¿Cumple la política de familias? | No aplica: publico objetivo 18+ |

### Tipos de datos

| Categoría | Tipo | Recogido | Compartido | Obligatorio | Para qué |
|---|---|---|---|---|---|
| Info personal | Correo | Sí | No | Sí | Cuenta y autenticación |
| Info personal | Nombre | Sí | No | No | Personalizar |
| Info personal | Otros (fecha/hora de nacimiento) | Sí | No | No | Cálculo de la carta natal |
| Ubicación | Ubicación aproximada | Sí | No | No | Hora planetaria y fecha local |
| Ubicación | Ubicación precisa | Sí | No | No | Coordenadas de nacimiento y actuales |
| Datos financieros | Historial de compras | Sí | Sí (RevenueCat) | No | Gestionar la suscripción |
| Mensajes | Otros en la app | Sí | Sí (Groq) | No | Generar las lecturas |
| Archivos y documentos | — | No | No | — | — |
| Actividad en la app | Interacciones | Sí | Sí (Firebase Analytics) | No | **VERIFICAR — ver aviso abajo** |
| Rendimiento | Registros de fallos | Sí | Sí (Crashlytics) | No | Diagnosticar cierres |
| Rendimiento | Diagnósticos | Sí | Sí (Crashlytics) | No | Diagnosticar cierres |
| ID de dispositivo | ID de dispositivo o de otro tipo | Sí | Sí (AdMob) | No | Anuncios bonificados |

> **La ubicación es PRECISA aunque no se lea el GPS.** El manifiesto declara
> solo `INTERNET` —comprobado— y las coordenadas se teclean al elegir ciudad.
> Pero Play clasifica por el dato, no por cómo se obtuvo, y unas coordenadas son
> ubicación precisa. Declararlo como aproximada sería falso.

> **Las entradas del grimorio NO se declaran como compartidas.** Se cifran con
> AES-256 en el dispositivo; el servidor almacena texto cifrado y no tiene la
> clave. Verificado en `app/routers/grimoire.py` y en los esquemas.

### AVISO: Firebase Analytics

`firebase_analytics` está en `pubspec.yaml` pero **no se importa en ningún
fichero de `lib/`**, y no hay ninguna llamada a
`setAnalyticsCollectionEnabled(false)`. En Android el SDK de Analytics recoge
por su cuenta con solo estar en el classpath y Firebase inicializado.

Hay dos salidas honestas, y hay que elegir una:

1. **Quitar la dependencia.** No la usa nadie. Elimina una categoría entera del
   formulario y reduce la superficie de datos. Es lo que recomiendo.
2. **Dejarla y declararla**, que es como está escrita la tabla de arriba.

Lo que no vale es dejarla y no declararla.

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

**¿Contiene anuncios?** **Sí.** Hay que marcarlo, y además la ficha muestra el
distintivo "Contiene anuncios".

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
