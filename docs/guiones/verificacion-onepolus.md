# Guion — Verificación en OnePlus físico

Séptima sesión pendiente. Cinco funciones apiladas que nadie ha visto en un
aparato. Este guion existe para que la sesión dure veinte minutos y no dos
horas, y para que **lo que más probablemente esté roto falle primero**.

**Regla de oro:** si algo falla, se anota y **se sigue**. No se arregla sobre la
marcha. Arreglar a mitad de una verificación convierte una lista de hechos en
una lista de opiniones.

---

## 0. Antes de conectar nada (5 min, se puede hacer ya)

Falta lo que no está en el repo, y sin esto no hay APK:

```
FALTA  android/key.properties          <- hay plantilla: android/key.properties.example
FALTA  android/app/google-services.json <- de la consola de Firebase
```

`build.gradle:22` aborta con un mensaje explícito si falta la firma, así que no
hay sorpresa silenciosa. Copia la plantilla y rellena los cuatro valores; el
keystore va **fuera del control de versiones**.

`google-services.json` se descarga de Firebase (proyecto de ARCANUM, app Android
`com.arcanum.magick`).

> Ninguno de los dos se commitea. Si acaban en un commit, hay que rotar claves.

### Conectar el aparato

1. OnePlus → Ajustes → Acerca del teléfono → tocar 7 veces "Número de compilación".
2. Opciones de desarrollador → **Depuración USB** activada.
3. Cable, y aceptar la huella RSA en el teléfono.

```bash
flutter devices        # debe aparecer el OnePlus, no solo Windows/Chrome/Edge
```

`adb` no está en el PATH de esta máquina. Si `flutter devices` no lo ve:
`%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe devices`.

**Si el teléfono no aparece, la sesión termina aquí.** Anótalo y para: sin
aparato, todo lo de abajo es ficción.

### Arrancar

```bash
cd D:\tmp\bogota2\arcanum_app
flutter run --release -d <id-del-onepolus>
```

Release, no debug: el rendimiento del selector en debug no significa nada (JIT).
Si quieres logs, `flutter run --profile`.

---

## 1. El selector de ciudades — PRIMERO, es lo más frágil

Va primero a propósito: es lo único que se juzga con el pulgar y lo que más
depende del aparato. **Perfil → DÓNDE VIVES → "Indicar dónde vivo".**

| # | Qué haces | Qué tiene que pasar | Falla si |
|---|---|---|---|
| 1.1 | Abrir la hoja | Aparece en menos de 1 s con el país y el buscador | Tarda, o sale "catálogo no disponible" |
| 1.2 | Escribir `cor` | Resultados **mientras escribes**, sin tirón | Se traba al teclear |
| 1.3 | Mirar la lista | `Córdoba, Córdoba, Argentina` y `Córdoba, Andalucía, España` distinguibles | Filas ambiguas o cortadas |
| 1.4 | **Mirar la última fila** | Se ve entera con el teclado abierto | **El teclado la tapa** |
| 1.5 | Escribir `medellin` sin tilde | Encuentra `Medellín, Antioquia, Colombia` | No aparece |
| 1.6 | Pulsar Enter | **No elige nada**, solo baja el teclado | Elige el primero solo |
| 1.7 | Tocar una fila | Se marca en oro, **la hoja NO se cierra** | Se cierra al primer toque |
| 1.8 | Pulsar "Usar este lugar" | Cierra y el perfil muestra la ciudad | |
| 1.9 | Abrir el desplegable de países | Se despliega sin tirón (son 245) | **Da tirón o tarda** |
| 1.10 | Mirar el pie | Aparece la atribución de GeoNames | No está (es obligación legal) |

**Lo que más me preocupa: 1.4 y 1.9.** El teclado real trae barra de
sugerencias y puede ser de terceros; un desplegable de 245 entradas en gama
media puede pegar un tirón perceptible. Los tests de escritorio no ven ninguna
de las dos.

**Anota el tiempo de 1.2 a ojo:** ¿se siente instantáneo o se nota? Medido en
escritorio son 3,6 ms en el peor caso, pero eso es JIT sobre portátil.

### Rescate

| # | Qué haces | Qué tiene que pasar |
|---|---|---|
| 1.11 | Escribir `zzzqqq` | "No encontramos ninguna localidad" + "¿No encuentras tu localidad?" |
| 1.12 | Tocar el rescate | Se abre el flujo de país + ciudad libre |
| 1.13 | `España` / `Córdoba` → Buscar | Pide confirmación antes de devolver nada |
| 1.14 | Pulsar "Corregir" | **No guarda nada** y vuelve a los campos |

---

## 2. Residencia, y que el cielo cambie de verdad

Es la prueba de que todo lo construido hoy sirve para algo.

| # | Qué haces | Qué tiene que pasar |
|---|---|---|
| 2.1 | Perfil, sin residencia | "Vives donde naciste · <tu ciudad>" |
| 2.2 | Poner una residencia **lejana** (Tokio, Sídney) | El perfil la muestra en oro |
| 2.3 | **Ir a Hoy sin reiniciar la app** | La hora planetaria y el regente **han cambiado** |
| 2.4 | Volver al perfil → "Vivo donde nací" | Vuelve al estado 2.1 |
| 2.5 | Ir a Hoy otra vez | Vuelve la hora de antes |

> **2.3 es el punto crítico de toda la sesión.** Es la transición de estado que
> no tiene test: guardar llama a `refreshUser()` para que Hoy repida su cielo.
> Si no cambia sin reiniciar, ese camino está roto y es un fallo real.
>
> Elige un lugar con **muchas horas de diferencia**. Con una ciudad cercana la
> hora planetaria puede coincidir por casualidad y no probarías nada.

---

## 3. Hoy y el horóscopo

| # | Qué haces | Qué tiene que pasar |
|---|---|---|
| 3.1 | Abrir Hoy | Regente, hora planetaria y luna **de tu lugar**, no de Bogotá |
| 3.2 | Mirar "TU CIELO DE HOY" | Un texto de dos párrafos que **nombra tus planetas** |
| 3.3 | Leerlo | Habla de tu tránsito concreto, no de "hoy es un día de cambios" |
| 3.4 | Cerrar la app y volver a abrir | **El mismo texto**, no uno nuevo |
| 3.5 | Modo avión, abrir Hoy | Cae a la lectura local, no a "revisa tu conexión" |

**3.2 y 3.3 dependen del deploy del backend**, que llevas tú. Sin él,
`/astral/horoscope` no existe y verás el estado de fallo — que también hay que
comprobar que se ve bien.

**3.4 prueba la idempotencia**: el horóscopo se genera una vez al día. Un texto
distinto en la segunda apertura significa que la clave no está funcionando.

---

## 4. Grimorio y el almacén cifrado

Lo que lleva pendiente desde antes. `setMockInitialValues({})` prueba el AES,
**no** el almacén seguro del aparato.

| # | Qué haces | Qué tiene que pasar |
|---|---|---|
| 4.1 | Grimorio → escribir una entrada → sellar | Se guarda sin error |
| 4.2 | Volver a la lista | La entrada aparece con su título |
| 4.3 | Abrirla | El contenido se descifra y se lee |
| 4.4 | **Cerrar la app del todo y reabrir** | La entrada **sigue legible** |
| 4.5 | Mirar la hora sellada | La de **tu** lugar, o ausente. Nunca la de Bogotá |

> **4.4 es la prueba real de `FlutterSecureStorage`.** Si la clave no
> sobrevive al reinicio, la entrada queda ilegible para siempre — y ese es el
> dato más sensible de la app.
>
> Si 4.1 falla con "No se pudo sellar la entrada. Revisa tu conexión", **no te
> lo creas**: ese `catch` culpa a la conexión de todo, incluido un fallo de
> cifrado. Está diagnosticado y sin arreglar. Anota qué pasó de verdad.

---

## 5. Tarot, de paso

| # | Qué haces | Qué tiene que pasar |
|---|---|---|
| 5.1 | Oráculo → tirada | Salen las cartas |
| 5.2 | Pedir la lectura con IA | Responde nombrando tus cartas |
| 5.3 | Repetir la tirada | Al agotar el cupo, aparece el paywall, no un error crudo |

---

## Qué traer de vuelta

1. **Qué falló, con el número del paso.** Sin interpretar: lo que viste.
2. **Capturas de 1.2, 1.4, 2.3 y 3.2.** Son las cuatro que no se pueden
   describir con palabras.
3. **La sensación de 1.2 y 1.9**: ¿instantáneo, o se nota?
4. **El modelo exacto de OnePlus y la versión de Android.** Cambia lo que
   significa un tirón.
5. Lo que no llegaste a probar, marcado como tal.

## Lo que NO se hace en esta sesión

- **No arreglar nada sobre la marcha.** Anotar y seguir.
- No commitear desde el teléfono conectado con cambios a medias.
- `key.properties` ni `google-services.json` **jamás** entran en un commit.
- No tocar `release/p0a-beta`.

---

## Y si el aparato sigue sin aparecer

Dilo y para. Siete sesiones diciendo "pendiente" ya cuestan más que el problema:
si el OnePlus no va a estar, la decisión honesta es **conseguir otro Android
cualquiera** o asumir por escrito que se libera sin verificación en aparato — y
que eso es una decisión, no un descuido.
