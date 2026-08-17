# Checkpoint — Cuanta actividad de produccion es real, y si el Grimorio guarda

- **Fecha:** 2026-08-17
- **Rama:** `fix/bogota-release` (worktree `D:/tmp/bogota2`)
- **Naturaleza:** medicion y diagnostico. Ningun cambio de comportamiento.
- **Produccion:** solo lectura. La credencial se borro del disco al terminar.

## 1. Cuantos de los 26 usuarios son reales

### Criterio, escrito antes de contar

Se marca como **senal de prueba**: dominio distinto de `gmail.com`, o la parte
local del correo contiene `test`, `prueba`, `demo`, `qa`, `samuel`, `samu`,
`escobar`, `admin`, `fake`, `+`. No prueba nada por si solo — es una senal, no
un veredicto — pero es reproducible y no depende de mi impresion.

```
altas por dia
  2026-06-23  4    2026-07-12  1    2026-07-26  2
  2026-06-27  1    2026-07-15  3    2026-08-12  3
  2026-06-30  2    2026-07-24  2    2026-08-13  1
  2026-07-02  2                     2026-08-15  5

senales de uso
  total                               26
  onboarding_completed                14
  con birth_lat y birth_lon           18
  con birth_city                      16
  con carta natal calculada           15
  con alguna sesion de adivinacion    14
  con alguna conversacion de oraculo  11
  premium                              1
  con creditos != 0                    0

dominios      gmail.com 19 · example.com 3 · arcanum.app 2 · samu.com 1 · samuel.com 1
rafagas       una sola: 2 altas en el mismo minuto (2026-06-30 03:54)
con al menos una senal de prueba: 10 de 26
```

Entre las 10 marcadas hay tres `Release Smoke` en `example.com` y una
`Oraculo Test` en `arcanum.app`: cuentas de humo, sin ambiguedad.

**Respuesta: ~16 usuarios plausiblemente reales de 26**, y **16 con alguna
senal de uso** (carta natal, sesion o conversacion). Nombres visibles como
`andres`, `Sebastián`, `Pauli`, `Thom`, `stif` respaldan que hay gente de
verdad, no solo el desarrollador.

## 2. Cuantos usuarios hay detras de las 62 sesiones

**14 usuarios distintos.** Muy concentrado:

```
 28 sesiones   2026-06-23 .. 2026-08-13     <- onboarding SIN completar; huele a desarrollo
 11 sesiones   2026-06-23 .. 2026-07-02
  5 sesiones   2026-07-24 .. 2026-08-09
  3, 3, 2, 2, 2, 1, 1, 1, 1, 1, 1
```

Los dos primeros suman **39 de 62** (63 %). Aun descontandolos, quedan 12
usuarios con al menos una tirada. **11 tuvieron conversacion con el Oraculo.**

Conclusion parcial que reordena el resto: **no estamos leyendo el poso de una
taza vacia.** Hay una docena de personas que llegaron a tirar cartas y hablar
con el Oraculo, y **ninguna escribio en su Grimorio**. El cero significa algo.

## 3. El Grimorio: ¿A (falla) o B (nadie lo usa)?

### El servidor NO es el bug — probado en local

`POST /grimoire` con el cuerpo exacto de `grimorio_editor.dart:69`, contra base
local migrada por Alembic (nunca produccion):

```
register -> 201
login    -> 200
1. cuerpo exacto del cliente                   HTTP 201
2. sin dato astral (si /astral/today falla)    HTTP 201
3. titulo vacio                                HTTP 201
4. entry_type de los cuatro del selector       HTTP 201

GET /grimoire -> HTTP 200, 4 entradas
```

Los cuatro casos guardan. Ni un 422. Y el codigo desplegado (`84ad664`) valida
**con el mismo schema**: el unico diff en el Grimorio es `_sealed_hour`, que
sobrescribe un campo despues de validar. Verificado por diff, no supuesto.

### Los logs HTTP de produccion: `POST /grimoire` no existe

Ventana real disponible: **2026-08-12T22:16 .. 2026-08-15T14:32** (empieza en el
despliegue vivo; es toda la retencion que hay). 312 peticiones.

```
  48  GET  /users/me            21  POST /oracle/tarot/draw
  27  GET  /astral/today        21  GET  /astral/overview
  16  GET  /tarot/cards          8  POST /oracle/ia
   6  GET  /grimoire             0  POST /grimoire     <-
```

**Seis aperturas del Grimorio, todas 200. Cero intentos de guardar** — ni uno
fallido. Y en la misma ventana, los mismos dispositivos hacen 21 `POST
/oracle/tarot/draw` con exito: **la red, la autenticacion y el POST funcionan en
telefonos reales**. Justo lo que el mensaje de error culpa.

### Que hacen los usuarios al abrir el Grimorio

Las seis aperturas, con lo que pasa despues:

```
>> GET /grimoire 200      -> GET /reading/passages     (4 s despues)
>> GET /grimoire 200      -> GET /materia, /library, /tarot/cards   (4 s)
>> GET /grimoire 200      -> GET /reading/progress, /materia, /library  (15 s)
>> GET /grimoire 200      -> GET /materia, /library, /tarot/cards   (4 s)
>> GET /grimoire 200      -> GET /reading/progress, /library, /materia  (4 s)
>> GET /grimoire 200      -> GET /library, /reading/progress, /materia  (5 s)
```

En las seis, lo siguiente es **otra pestana**. Nadie se queda. Y hay un detalle
que discrimina: el editor llama a `/astral/today` **dentro** del guardado. Si
alguien hubiera pulsado "sellar" y el cifrado hubiera funcionado, veriamos un
`/astral/today` pegado al `GET /grimoire`. No aparece en ninguna de las seis.

### Veredicto

**B: el camino funciona y nadie lo usa** — con el alcance honesto de la
evidencia. El Grimorio se abre de paso, mientras se recorren las pestanas, y se
cierra.

**A no queda descartada para junio y julio**, porque los logs solo cubren tres
dias. Lo que si queda descartado, para toda la ventana observable, es que el
servidor rechace: no hay ni un `POST /grimoire` con error, porque no hay ni uno.

## 4. El `catch` del editor: sigue siendo un bug, y de los que se esconden

Aunque el veredicto sea B, el diagnostico del editor esta mal, y es
precisamente lo que haria **invisible** un fallo A si ocurriese.

Correccion al planteamiento: el bloque no tiene tres pasos, tiene **dos**.
`/astral/today` ya esta aislado en su propio `try` con `debugPrint`
(`grimorio_editor.dart:52-67`), y el comentario explica bien por que es
best-effort. El `catch` exterior cubre:

| Paso | Como falla | Que dice hoy | Que deberia decir |
|---|---|---|---|
| `encryptText` (`grimoireCryptoProvider`) | el almacen seguro del dispositivo no lee o no escribe la DEK | "No se pudo sellar la entrada. Revisa tu conexión." | "No se pudo abrir la clave de este dispositivo." Y NO invitar a reintentar: reintentar no lo arregla |
| `api.grimoireCreate` | red, 401, 422, 5xx | lo mismo | "No se pudo guardar la entrada." Con reintento |

**Lo llamativo:** la pantalla hermana **ya lo hace bien**. `GrimorioDetail`
distingue las dos cosas y esta bajo test:

```
test/features/grimorio/grimorio_test.dart
  ✓ un fallo de API no se presenta como fallo criptográfico
      -> "No se pudo abrir la entrada" + boton Reintentar
  ✓ un fallo AES conserva el diagnóstico criptográfico
      -> "El sello resiste" + "clave de este dispositivo", SIN Reintentar
```

El patron existe, funciona y esta probado — a diez lineas de distancia, en el
camino de lectura. Al de escritura no llego nunca. Y el guardado del editor
**no tiene ni un test**.

No se arregla aqui, por encargo. Es un commit aparte, y con la verificacion en
dispositivo fisico al lado.

## No comprobado, y por que

- **Si `FlutterSecureStorage` funciona en un telefono real.** No hay dispositivo:
  `flutter devices` lista Windows, Chrome y Edge; `adb` no esta en el PATH. El
  test de cifrado que existe usa `FlutterSecureStorage.setMockInitialValues({})`
  — **prueba el AES, no el almacen**. Es exactamente el hueco que no se puede
  cerrar sin el OnePlus, pendiente desde hace cinco sesiones.
- **Junio y julio.** La retencion de logs empieza en el despliegue vivo del 12
  de agosto. De los dos primeros meses no hay traza HTTP: si hubo intentos de
  guardar que fallaron, no se puede ver.
- **Si alguna de las 6 aperturas llego a abrir el editor.** Abrir el editor no
  genera trafico hasta que se pulsa guardar. Un usuario pudo escribir, dudar y
  salir sin dejar rastro.
- **Cuantos de los 16 "plausiblemente reales" son personas distintas de Samuel.**
  El criterio marca correos, no identidades. Un gmail personal sin la palabra
  "samuel" seguiria siendo suyo.
