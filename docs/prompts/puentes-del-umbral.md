# Prompt — Puentes del Umbral (ARCANUM)

> Fase siguiente a Nombre y Umbral V1.1 (`8b2a436`, rama `feat/nombre-y-umbral-foundation`).
> Copiar de aqui hacia abajo.

---

Skills: `arcanum-dev`, `arcanum-kabbalist`, `arcanum-tarot`, `arcanum-clarividente`, `investigar`, `senior-programmer`, `checkpoint`, `obsidian-vault`. Modo cavernicola.

## Objetivo

Construir **Puentes del Umbral**: la integracion **opt-in** del nombre de la persona con Tarot, Oraculo y Cielos. Nada mas. No construir Horoscopo. No crear pestanas nuevas. No tocar produccion, Railway, Firebase, RevenueCat, AdMob, migraciones ni `release/p0a-beta`.

## Estado del que partes (verificado)

- Rama `feat/nombre-y-umbral-foundation`, ultimo commit `8b2a436 feat(nombres): calibrar IA para el catalogo editorial`.
- Catalogo de 128 fichas en cinco tradiciones con licencia verificada. Cola de 27 apellidos, **cero publicados**.
- `NameTradition.allowsHistoricalGematria` es invariante tipado: solo hebrea abre el calculo 1-400.
- `flutter analyze` limpio, 246 tests verdes, APK debug construido.
- El catalogo NO se amplia en esta fase. Hay una cola de 66 candidatos sin verificar en `tools/names/`, y una medicion que dice que ningun modelo de Groq sirve para decidir significados: inventan entre 75% y 92% sobre etimologias no resueltas. Si en algun momento se te ocurre pedirle a un modelo que rellene una ficha, la respuesta ya esta medida y es no.
- **Pendiente heredado:** verificacion fisica en el OnePlus no ejecutada (el equipo no estaba conectado). Si aparece, ejecutarla antes de cerrar.
- La frontera actual esta fijada por `test/features/name_threshold/network_isolation_test.dart`, tercer test: Tarot y Cielos no pueden ni nombrar `name_threshold` ni `readingIdentityProvider`. **Ese test tiene que cambiar a proposito, no por accidente.** Cambiarlo es la decision, no el tramite.

## La tension central que tienes que resolver primero

Los tres puentes no son el mismo puente:

- **Tarot y Cielos son locales.** Cruzarlos no saca un solo byte del dispositivo. Puente barato.
- **El Oraculo es una llamada de red a un tercero (Groq).** Cruzarlo significa **enviar el nombre de la persona a un servidor ajeno**. Puente caro.

El modulo se prometio local y cifrado. Ese puente concreto es el unico punto donde esa promesa se puede romper, asi que decidelo explicitamente y por separado:

1. Que cruza exactamente hacia el Oraculo: el nombre legal, el nombre elegido, o **solo la lectura simbolica ya escrita y auditada**. Recomendacion de partida, discutible con evidencia: **cruza la lectura, no el nombre**.
2. Consentimiento distinto y mas explicito para el puente remoto que para los locales. No un unico interruptor que los agrupe.
3. Que se le dice a la persona, con esas palabras, sobre lo que sale del telefono.

Si decides que el nombre si viaja, justificalo y refleja la decision en la politica de privacidad.

## Limites editoriales (heredados, no negociables)

- La lectura simbolica **nunca** es una afirmacion sobre destino, personalidad, salud, dinero o relaciones.
- El puente **sugiere una resonancia, no dicta una interpretacion**. Prohibido: "tu nombre indica que esta carta significa X para ti", "por tu nombre te corresponde", "tu numero te hace".
- Gematria historica 1-400 solo con escritura hebrea documentada o aportada explicitamente por la persona. El puente no puede relajar esto.
- La transliteracion a hebreo es contemplativa ARCANUM, editable, y nunca "origen hebreo" ni "traduccion historica".
- El apellido no cruza ningun puente en esta fase: no hay nada publicable que cruzar.
- Magia sobria. Que se sienta intimo y bello sin volverse determinista.

## Trabajo

### 1. Investigar y decidir antes de escribir codigo

Revisa el modulo, los tests y el vault. Entrega, corto:

- Que dato exacto cruza cada puente, con su tipo. No "el perfil": el campo.
- Donde vive el consentimiento, como se revoca y que se borra al revocarlo.
- Como se ve un puente apagado (que es el estado por defecto).
- Que cambia en `network_isolation_test.dart` y por que ese cambio es correcto.

### 2. Consejo de 7

Filologo, especialista en fuentes, cabalista riguroso, editor ARCANUM, disenador UX, abogado de privacidad y adversario anti-charlataneria. Que decidan: que cruza y que no; como se pide el consentimiento sin que parezca un tramite legal ni una trampa; como se muestra la resonancia sin que se lea como prediccion; y donde exactamente esta el limite entre sugerir y afirmar.

### 3. Implementar

Solo despues de aprobar lo anterior. Worktree limpio. No tocar trabajo ajeno ni artefactos generados.

- Consentimiento por modulo, apagado por defecto, revocable, con borrado real al revocar.
- Puente Tarot: la resonancia acompana la tirada, no la reinterpreta.
- Puente Cielos: la resonancia acompana la carta, no altera el calculo astronomico.
- Puente Oraculo: lo que se decidio en el punto 1, con su consentimiento propio.
- UI: mejorar solo lo necesario. Sin pantallas ni pestanas nuevas.

### 4. Tests obligatorios

- Con el puente apagado, ningun modulo ve el nombre (extension del test de aislamiento actual, no su borrado).
- Revocar borra de verdad; no queda residuo en almacenamiento ni en memoria del provider.
- El apellido no cruza ningun puente.
- El payload que sale hacia el Oraculo contiene exactamente lo decidido y nada mas, verificado sobre el cuerpo real de la peticion.
- Ningun texto de puente contiene las formulas deterministas prohibidas.
- La gematria historica sigue cerrada para tradiciones no hebreas incluso a traves del puente.

### 5. Gates

`flutter analyze lib` · `flutter test` · `flutter build apk --debug` · `git diff --check` · CJK y mojibake limpios · fisico en OnePlus **si aparece** (crear identidad, encender un puente, tirar una carta, revocar, confirmar que desaparece; logcat sin FATAL EXCEPTION, `_dependents`, Assertion ni Zone mismatch).

**No commit con gates rojos.** Si todo verde: stage selectivo, commit en espanol sin acentos, push **solo** a la rama feature. Checkpoint doble en `docs/checkpoints` y `D:\Brain\10-Proyectos\ARCANUM`. Actualizar `MOC-ARCANUM`.

## Entrega final compacta

Veredicto; que cruza cada puente y que se quedo fuera; como funciona el consentimiento; que cambio en el test de aislamiento y por que; pruebas y fisico; SHA y rama; que queda listo para Horoscopo.
