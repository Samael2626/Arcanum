# Checkpoint — Despliegue del corte de Bogotá y la anulacion que no hacia falta

- **Fecha:** 2026-08-17
- **Rama:** `release/p0a-beta` (codigo listo, **sin desplegar**)
- **SHA en la rama de despliegue:** `fae72e4`
- **Estado:** PARADO A PROPOSITO en el punto 2. Ver abajo.

## 1. El corte esta en la rama que despliega

Suite completa contra ese arbol, antes de pushear:

```
307 passed, 3 skipped, 82 warnings in 36.60s
```

`fae72e4` es descendiente directo de `84ad664`, asi que el push fue
fast-forward:

```
84ad664..fae72e4  fae72e4 -> release/p0a-beta
```

**Esto no desplego nada**: auto deploy esta apagado en el servicio.

Se pusheo `fae72e4` y no `21a14f1`: la rama de despliegue no necesita el
documento del prompt. Entre los dos commits solo hay un `.md`.

## 2. El despliegue: no lo puede disparar el CLI

`railway deployment` ofrece `up` (sube el DIRECTORIO LOCAL, que no es lo mismo
que desplegar la rama de GitHub y cambiaria la procedencia del despliegue) y
`redeploy` (repite el despliegue actual, o sea `84ad664` otra vez). Ninguno
despliega el commit nuevo de una rama conectada con auto deploy apagado: eso es
el boton del panel.

No se sustituyo por `deployment up`. Cambiar la fuente de un despliegue de
produccion para ahorrarse un clic es exactamente el tipo de atajo que este
encargo prohibe.

**Pendiente: Samuel dispara el deploy y se anota el instante con zona.**

## 3. El simulacro: CERO filas, y la razon no es un error de conexion

Contado contra la base de produccion (Supabase, solo lectura), con un corte de
referencia igual al instante actual — o sea, el maximo posible:

```
[SIMULACRO] corte: 2026-08-17T01:38:53.966797+00:00

  tarot_readings               0 filas
  divination_sessions          0 filas
  grimoire_entries             0 filas

  TOTAL                        0 filas
```

Un cero es motivo de parar, no de continuar. Investigado:

```
tabla                    filas  ph NOT NULL  moon NOT NULL
tarot_readings               0            0              0
divination_sessions         62            0              0   rango 2026-06-23 .. 2026-08-15
grimoire_entries             0            0              0

usuarios: 26
```

**No hay ni una fila contaminada en produccion.** Y no es que la base este
vacia: 26 usuarios y 62 sesiones de adivinacion reales, la ultima del 15 de
agosto. Las 62 tienen `planetary_hour` **y** `moon_phase` a NULL.

Comprobado ademas que no hay una cuarta tabla escondida: en todo el esquema
`public`, las columnas `planetary_hour` / `moon_phase` existen exactamente en
las tres tablas que el script ya cubre.

### Que significa

El bug era real en el codigo, pero **nunca llego a escribir**:

- `tarot_readings` esta vacia: `_sky_snapshot` sella ahi, y ahi no hay filas.
- `grimoire_entries` esta vacia: es la otra via del cliente.
- `divination_sessions` tiene trafico real, pero quien las crea no manda esas
  dos columnas.

Conclusion: **la anulacion (puntos 3 y 4 del encargo) no tiene objeto.** No se
corrio `--apply`, y correrlo seria un no-op: el script imprime "Nada que
anular" y sale sin escribir. El despliegue del corte sigue teniendo todo el
sentido — evita la contaminacion futura — pero no hay pasado que limpiar.

## Preparado igualmente, porque hacia falta de todos modos

- `arcanum-api/scripts/out/` estaba sin trackear y sin ignorar. Ya esta en
  `.gitignore` (`0551700`): ahi cae un respaldo con ids reales, y es la unica
  marcha atras de un borrado irreversible.
- Verificado que el directorio existe y es escribible.
- El propio script afirmaba en su cabecera que Railway despliega desde
  `feat/onboarding-5-pasos`. Corregido en el mismo commit: un comentario que
  miente dentro de la herramienta que borra datos es peor que no tener
  comentario.

## Hallazgos laterales — declarados, sin arreglar aqui

1. **`tarot_readings` esta VACIA en produccion**, con 26 usuarios y dos meses de
   uso. El endpoint de tirada existe y guarda por `save_reading`. O nadie ha
   hecho una tirada que se guarde, o el guardado no llega nunca. Encaja con el
   hallazgo de que los tests de tirada nunca mandaban `Idempotency-Key` y
   siempre recibian 422: cabe que la app tampoco la mande y este recibiendo lo
   mismo. **No comprobado** — requiere mirar el cliente y los logs de
   produccion, y es un encargo aparte.
2. **`divination_sessions` no recibe `moon_phase` ni `planetary_hour`** de quien
   las crea, pese a tener las columnas. Es la razon de que el bug no dejara
   rastro ahi, pero tambien significa que el dato astral de esas sesiones nunca
   se guardo.
3. **La base de produccion es Supabase por el pooler de transacciones**
   (`:6543`). El cortafuegos `_guard()` de `tests_pg` rechaza exactamente esa
   forma de URL, que es lo correcto. Si algun dia hay que escribir de verdad
   contra produccion, conviene comprobar antes si el pooler de transacciones da
   problemas con sentencias preparadas.
