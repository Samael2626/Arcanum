# Prompt — Horoscopo / Lectura del Umbral (ARCANUM)

> Fase siguiente a Puentes del Umbral (`df048cd`, rama `feat/nombre-y-umbral-foundation`).
> Direccion ya decidida en el vault: `ARCANUM-Horoscopo-Genuino-y-Monetizacion-2026-08-13`.
> Copiar de aqui hacia abajo.

---

Skills: `arcanum-dev`, `arcanum-astrologer`, `arcanum-clarividente`, `investigar`, `senior-programmer`, `checkpoint`, `obsidian-vault`. Modo cavernicola.

## Objetivo

Construir la **Lectura del Umbral**: el horoscopo genuino de ARCANUM. Hibrido, como ya se decidio: **bloque breve en Hoy, lectura completa en Oraculo**. No crear pestana nueva.

**Alcance de esta fase: solo el nucleo gratuito.** No construir creditos, no tocar RevenueCat, no construir la suscripcion Mistico. La lectura diaria es gratis por principio editorial, y la monetizacion esta condicionada a sandbox verde: mezclarlas seria juntar un gate de pagos con uno editorial. La CTA de "Profundizar con el Oraculo" se deja preparada pero **apagada**.

## Estado verificado (comprobado contra el codigo, no de memoria)

- Rama `feat/nombre-y-umbral-foundation`, ultimo commit `df048cd`. Worktree `D:/tmp/nombre-y-umbral-foundation`.
- **No existe ni una linea de horoscopo.** Se parte de cero.
- `natal_chart_engine.py` calcula local con `swisseph` + `FLG_MOSEPH`: 11 cuerpos, casas y aspectos. Sirve tal cual.
- `app/routers/astral.py:178` — `/astral/today` hace `datetime.now(timezone.utc)`. **Sin zona local.** Es P0.
- `app/services/oracle_context.py:16` — `_FALLBACK_LAT/LON` de Bogota siguen ahi. **Es P0 y ademas viola una prohibicion editorial explicita.**
- `app/models/user.py:15-20` — `birth_date`, `birth_time`, `birth_lat`, `birth_lon`, `birth_timezone` son **todos nullable**. El caso "sin hora natal" es el comun, no la excepcion.
- El Grimorio cifra antes de salir. El historial del Oraculo vive en servidor y **no debe alimentar el horoscopo automaticamente**.

## Aviso de infraestructura — leer antes de tocar backend

Esta es la primera fase en mucho tiempo que **si toca `arcanum-api/`**. Dos cosas que muerden:

1. **Railway despliega desde `feat/onboarding-5-pasos`**, no desde main. Cada push a esa rama va a produccion sin CI. **No pushear ahi.** Solo a `feat/nombre-y-umbral-foundation`.
2. El **hook de pre-commit exige Postgres** cuando cambia el backend, y con razon: sin el, los tests de integracion se saltan en silencio y el verde miente. Necesitas Docker Desktop arriba y `docker start arcanum-test-db`. **No usar `--no-verify`.**

## Los dos P0 que se arreglan primero, antes de escribir el horoscopo

Ninguna lectura es honesta si la fecha o el lugar estan mal:

1. **Zona local explicita.** `/astral/today` y todo lo que dependa de "hoy" tienen que resolver la fecha y la ventana en la zona local de la persona, nunca UTC a ciegas. Fixtures obligatorias de cambio de dia y de cerca de medianoche.
2. **Matar el fallback de Bogota.** Si faltan coordenadas, la lectura **se degrada y lo dice**; no se inventa un lugar. Una carta con el Ascendente de otra ciudad no es una aproximacion, es un dato falso.

Ambos con test que falla primero.

## Pilares editoriales (del vault, no negociables)

1. Primero el hecho calculado; despues la lectura simbolica.
2. Nombrar transito, aspecto, orbe, signo, casa y ventana local cuando existan.
3. Etiquetar tradicion y fuente de cada correspondencia.
4. Lenguaje condicional: "puede invitar", "permite observar".
5. Una practica opcional y pequena.
6. **Una tesis diaria; maximo dos factores astrales.**
7. Separar astronomia, tradicion e interpretacion editorial ARCANUM.
8. Reflexion solo opt-in y cifrada.

## Prohibiciones

- Prediccion determinista, miedo, urgencia o dependencia.
- Consejo medico, legal, financiero, de crisis, embarazo, medicacion, contratos o pareja.
- Fallback geografico inventado.
- Mezclar tradiciones sin etiqueta.
- Usar conversaciones, Grimorio, pasajes o datos natales privados como contexto automatico.
- Analytics con texto, cifrado o datos natales exactos.

## Estructura de la lectura

```text
[ORACULO · fecha local · zona]

LECTURA DEL UMBRAL      hecho breve + linea simbolica
CIELO OBSERVADO         posicion, aspecto, orbe, casa, ventana
LECTURA SIMBOLICA       tradicion + interpretacion condicionada
PRACTICA OPCIONAL       una observacion o escritura breve
POR QUE APARECE HOY     criterio determinista + fuentes + limites

[Guardar reflexion cifrada] [Volver a Hoy]
```

## Trabajo

### 1. El selector determinista es el corazon — disenarlo antes que nada

Contrato `horoscope_daily` **versionado**. Dada una carta natal y un instante, el selector elige **1 o 2 factores** y siempre los mismos: misma entrada, misma salida. Sin aleatoriedad, sin LLM en la eleccion.

Entrega antes de implementar:
- El criterio de puntuacion de factores (orbe, velocidad, personal vs. colectivo, aplicativo vs. separativo).
- Como se desempata.
- Que se muestra cuando no hay transito destacado (Luna/fase o transito colectivo, **etiquetado como tal**).
- Que se muestra sin hora natal: sin casas, sin Ascendente, sin angulos; lectura general etiquetada.
- Que se muestra con factores contradictorios: las tensiones separadas, **sin fabricar moraleja**.

### 2. Consejo de 7

Astrologo clasico, editor ARCANUM, adversario anti-charlataneria, abogado de privacidad, disenador UX, ingeniero de determinismo y esceptico cientifico. Que decidan: que factores merecen una tesis diaria; donde acaba "el cielo permite observar" y empieza "te va a pasar"; y como se dice "hoy no hay nada destacado" sin que suene a fallo del producto.

### 3. Implementar

- Backend: contrato versionado, selector determinista, endpoint. Reusar `natal_chart_engine`; no reescribir efemerides.
- Flutter: bloque breve en Hoy; lectura completa en Oraculo. Sin pantallas ni pestanas nuevas.
- Sin internet: ultima lectura cacheada con fecha, zona y estado "no actualizado". **No regenerar.**
- Trazabilidad: calculo, corpus/fuente, version editorial y timestamp. **Nunca la reflexion.**
- La CTA de profundizar se deja construida pero inerte.

### 4. Tests obligatorios

- El selector es determinista: misma entrada, misma salida, en 100 corridas.
- Cambio de dia y medianoche en zona local, con fixtures de varias zonas.
- Sin coordenadas: degrada y lo declara; **no aparece Bogota por ningun lado**.
- Sin hora natal: no aparecen casas, Ascendente ni angulos.
- Nunca mas de dos factores.
- Adversariales de contenido: 100 prompts buscando consejo medico, legal, financiero, de crisis o prediccion determinista. **Cero afirmaciones prohibidas.**
- Todo hecho mostrado procede del motor, no del texto: verificado contra el calculo.
- Analytics: ningun evento lleva texto, cifrado ni fecha/hora/lugar natal exactos.
- La reflexion se cifra antes de salir y es opt-in.

### 5. Gates

`pytest -q` (con Postgres arriba) · `flutter analyze lib` · `flutter test` · `flutter build apk --debug` · `git diff --check` · CJK y mojibake limpios · fisico en OnePlus **si aparece**.

**No commit con gates rojos.** Stage selectivo, commit en espanol sin acentos, push **solo** a `feat/nombre-y-umbral-foundation`. Checkpoint doble en `docs/checkpoints` y `D:\Brain\10-Proyectos\ARCANUM`. Actualizar `MOC-ARCANUM`.

## Entrega final compacta

Veredicto; los dos P0 y como se arreglaron; el selector y su criterio; que se muestra en cada caso dificil; pruebas incluidas las adversariales; fisico; SHA y rama; que queda para la fase de monetizacion.
