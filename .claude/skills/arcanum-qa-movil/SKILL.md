---
name: arcanum-qa-movil
description: "Prueba de un modulo de ARCANUM en el movil real (GN2200) manejado por Claude con adb y uiautomator: build con id propio que no pisa la app de Play, reglas del movil compartido entre sesiones, recorrido por lista de comprobacion del modulo, capturas e informe con lo visto y lo descartado. Activar cuando Samuel diga \"instalalo en el cel\", \"pruebalo en el movil\", \"QA en el telefono\", \"testea el taller/la mesa en el cel\", o tras mezclar un modulo que solo falta verificar en dispositivo. No sustituye a arcanum-qa-tester (recorrido exploratorio de toda la app) ni a los gates (flutter test, pytest)."
---

# QA en el movil, por modulos

Claude instala, toca, captura y juzga. A Samuel solo se le pide lo que no se
automatiza: iniciar sesion, y lo que se juzga con el dedo (fluidez, 90 Hz,
vibracion). Todo lo demas lo hace la skill.

## 0. Reglas que no se saltan

1. **Nunca instalar sobre `com.arcanum.magick`.** Es la app de Play (firma de
   Play, `versionCode` de produccion). Una build de prueba encima falla por
   firma y obliga a desinstalar: se pierden los datos. Toda prueba va con id
   propio: `com.arcanum.magick.<modulo>` (`.sigilos`, `.mesaqa`...).
2. **El movil es compartido entre sesiones.** Antes de CADA toque:
   `scripts/adb_seguro.sh foco` debe devolver el paquete propio. Si hay otra
   app delante (WhatsApp, la ARCANUM de otra sesion), **parar y avisar**; no
   traer la propia al frente por encima de lo que esta usando otra persona.
3. **Tocar por texto, no por coordenadas.** `uiautomator dump` y buscar el
   nodo por `text`/`content-desc`; los botones se mueven al cambiar su texto.
4. **Los cambios temporales de compilacion se restauran siempre** (trap en el
   script), aunque la compilacion falle. Nunca se commitean.
5. **Backend:** por defecto la build habla con PRODUCCION. Lo que se guarde
   queda en la cuenta real de quien inicie sesion. Para pruebas destructivas,
   back local con `--dart-define=API_BASE_URL=http://127.0.0.1:8000` y
   `adb reverse tcp:8000 tcp:8000` (como hizo la mesa).
6. En Git Bash: `MSYS_NO_PATHCONV=1` para rutas `/sdcard/...`.

## 1. Instalar

```
bash .claude/skills/arcanum-qa-movil/scripts/instalar_qa.sh <modulo> [ruta_app] [--local]
```

- Cambia `applicationId` y el `package_name` de `google-services.json` a
  `com.arcanum.magick.<modulo>` SOLO durante la compilacion y lo restaura.
- Compila `--profile` (rendimiento real, sin depurador) con
  `GRADLE_USER_HOME=D:\Softwares\gradle-taller` (el de `D:\tmp\.gradle` esta
  corrupto).
- `google-services.json` no se versiona: se toma de
  `D:\Proyectos\Arcanum\arcanum_app\android\app\`.
- Instala con `adb install -r` y comprueba `versionName` y la fecha.
- Se instala al lado de la de Play con el mismo nombre e icono: decirle a
  Samuel cual es cual (la de prueba aparece como segunda ARCANUM).

## 2. Recorrer

Leer la lista del modulo en `references/` y recorrerla en orden. Por cada paso:

1. `foco` -> si no es el propio, parar.
2. `dump` -> localizar el nodo -> `tocar_texto "<texto>"`.
3. `captura <nombre>` -> mirar la imagen (Read) antes de seguir: lo que dice
   la lista que debe verse, ¿se ve?
4. `log` -> buscar `ARCANUM`, `Exception`, `RenderFlex overflowed`.

Lo que la lista marca como **[dedo]** se le pide a Samuel con una pregunta
concreta («arrastra la letra M: ¿va pegada al dedo o con retraso?»).

## 3. Informar

- Hallazgos por gravedad: (a) pierde o expone datos, (b) rompe el flujo,
  (c) se ve mal. Cada uno con su captura y el paso exacto.
- **Tambien lo descartado y por que**, y lo que NO se pudo comprobar.
- Si un toque fallo o llevo a otro sitio, decirlo: a veces eso es el hallazgo.
- Fallo real encontrado -> test de regresion en el repo antes de cerrarlo.
- Al terminar: desinstalar la build de prueba solo si Samuel lo pide (puede
  querer seguir mirando), y anotar el resultado en el vault del modulo.

## Modulos

| Modulo | Id | Lista |
|---|---|---|
| Taller de sigilos | `com.arcanum.magick.sigilos` | `references/sigilos.md` |

Para un modulo nuevo: copiar `references/sigilos.md` como plantilla y
escribir su lista a partir de lo que su vault y sus tests dicen que hace.
