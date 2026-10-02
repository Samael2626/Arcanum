# Plan: animaciones y 3D en ARCANUM

**Origen:** conversación con Samuel del 02-oct-2026, tras la «Lectura revelada» (D7 de `ARCANUM-Plan-Mesa-Tarot.md`).
**Estado:** preguntas cerradas por Samuel el 02-oct-2026 (abajo). Se empieza por la tanda 1 de la mesa.

## Reglas que no se saltan

- **Cada animación marca un acto del ritual** (revelar, sellar, cargar, cerrar, olvidar). Si no marca ninguno, sobra.
- **Una sola gramática:** atmósfera del elemento, volteo, humo, sello de cera, hilo dorado. Piezas en `lib/shared/revelado/`.
- **«Reducir movimiento» lo apaga todo** y la pantalla se entiende igual.
- **60 fps en el GN2200** (Android 12, 60 Hz). Medir con `adb logcat` como en la fase 4 de la mesa antes de dar nada por bueno.
- **Nada llamativo en el paywall:** animar la pantalla de pago se puede leer como presión al usuario.
- **Fuera de la mesa, cada pantalla en su propia rama.** `feat/mesa-tarot` no crece más allá del tarot.

## Estado de partida (comprobado el 02-oct)

- Pantallas sin ninguna animación: horóscopo, onboarding, Sendero, fragmentos, Saber, lecturas (biblioteca), paywall, perfil, ajustes.
- Ya animan: mesa de tarot, Hoy (dial de hora planetaria, nebulosa, sello del cielo), Arte (revelado del grabado), Oráculo (volteo de cartas), Grimorio.
- **3D:** existe `assets/models/luna.glb` (80 KB; `luna.opt.glb`, 6 KB) y su generador `create_luna.py`, pero **nada lo usa**. `thermion_planet_viewer.dart` es un stub: `thermion_flutter` se quitó porque rompía `analyze`/`build`/tests. `model_viewer_plus` está comentado en `pubspec.yaml`.
- La mesa ya es «3D de mentira» que funciona: cámara con perspectiva, inclinación y giro sobre `Matrix4` (`table_camera.dart`), a 60 fps en el GN2200.

---

## A. Tarot (rama `feat/mesa-tarot`)

Primera tanda, antes de instalar:

- [x] **Bordado que despierta:** con la tirada completa y desvelada, el «Interpretar» se ilumina hilo a hilo. Coste bajo.
- [x] **Huella del palo al desvelar:** ráfaga breve del elemento en el sitio de la carta (ascuas, ondas, polvo, motas), con `ElementMotion`. Coste bajo. *(Era de la fase 6.)*
- [x] **Mayor que llega:** un Arcano Mayor entra con un destello dorado y su glifo planetario aparece un instante (los glifos ya existen en `tarot_card.dart`). Coste bajo.
- [x] **De la mesa a la lectura:** las cartas de la tirada vuelan a la franja de arriba de la «Lectura revelada» en vez de cortar. Coste medio. Es el «wow».

*Tanda 1 hecha el 02-oct-2026:* `EmbroideryPainter` (el paño pinta el bordado apagado y esta capa lo enciende hilo a hilo en 1,4 s), `table/table_fx.dart` (`Imprint`, `ImprintPiece`, `ImprintPainter`: la huella espera a que termine el volteo de su palo y dura 1,6 s; los Mayores con glifo usan `tarotMajorGlyph`) y el vuelo de entrada de `LecturaRevelada` (`entrance`: 650 ms por carta, 60 ms entre una y otra, la lectura se funde encima de la mesa). Con «reducir movimiento», bordado encendido de golpe, sin huellas y sin vuelo. De paso, el texto bordado del paño usa la Cormorant de la app (antes salía con la letra del sistema). Mirado en capturas del motor; falta verlo en el GN2200.

Segunda tanda:

- [ ] **Pregunta que vuela al sello:** el texto sale del panel, viaja al sello y se hunde en la cera. *(Fase 6.)*
- [ ] **Sello que se rompe:** a la grieta de hoy se suman trozos de cera que caen al interpretar.
- [ ] **Cerrar el círculo:** anillo de oro que se cierra sobre el paño, cartas en espiral de vuelta al mazo y humo.
- [ ] **Luz de la Luna sobre el paño:** plateada en llena, oscura en nueva. *(Fase 6.)*
- [ ] **Brillo al inclinar:** reflejo dorado que recorre la carta al inclinar el móvil (pide giroscopio: ver preguntas).
- [ ] Sonido y háptica de la fase 6.

## B. Resto de la app (una rama por pantalla)

- [ ] **Horóscopo:** el sello del signo se rompe y el texto del día aparece por partes, sobre la atmósfera de su elemento y la lámina del zodiaco desenfocada (`Atmosphere` + `RevealPager`). Coste medio.
- [ ] **Grimorio:** al guardar, un sello de lacre se estampa sobre la entrada: el cifrado AES-256 hecho visible. Coste bajo.
- [ ] **Hoy:** si cambia la hora planetaria con la pantalla abierta, el dial gira y el fondo pasa al color del planeta nuevo. Coste bajo.
- [ ] **Fragmentos:** al ganar, trozos de cristal vuelan al saldo del cajón y el número sube rodando. Coste bajo. *(Coordinar con `arcanum-sendero`.)*
- [ ] **Sendero:** al completar un paso, un hilo dorado avanza hasta el siguiente. Coste bajo.
- [ ] **Oráculo:** la respuesta aparece frase a frase, como tinta. Coste bajo.
- [ ] **Onboarding natal:** la rueda natal se dibuja planeta a planeta al dar fecha, hora y lugar. Coste alto. Primera impresión de la app.
- [ ] **Saber, estudiar una carta:** ficha con `Atmosphere` y su movimiento (ya previsto en «Después de la mesa»).
- [ ] **Materia Arcana:** ficha con la atmósfera de su planeta y el grabado desenfocado detrás.
- [ ] **Sigilos (cuando exista el módulo):** el trazo se dibuja, la carga brilla, el olvido quema el sigilo en humo. Es intención → reducción → composición → carga → olvido, animado.

## C. 3D: candidatos

| Dónde | Qué | Técnica posible | Coste |
|---|---|---|---|
| Hoy | **Luna en 3D** con la fase real del día (iluminación y terminador calculados por el backend), que se puede girar con el dedo | Shader de esfera iluminada (sin librería) o `luna.glb` con un motor 3D | Medio (shader) · alto (motor) |
| Horóscopo / Cielos | **Signos del zodiaco** como medallones en relieve que se inclinan con el móvil | Capas de la lámina con parallax (sin librería) | Bajo–medio |
| Cielos | **Carta natal inclinada** como un astrolabio que se puede girar | La misma cámara de la mesa (`Matrix4`) | Medio |
| Hoy | **Planeta de la hora planetaria** como esfera con su textura | Shader de esfera | Medio |
| Tarot | **Cartas con grosor y brillo** al inclinar | Shader de reflejo + giroscopio | Bajo–medio |
| Saber (Cábala) | **Árbol de la Vida** en 3D que se recorre | Motor 3D o `Matrix4` | Alto |

**Recomendación técnica:** shaders y perspectiva con `Matrix4`, no un motor 3D.
- `thermion_flutter` ya rompió el build una vez y añade peso al APK.
- `model_viewer_plus` va dentro de un WebView: lento para abrir y pesado en un móvil modesto.
- Un shader de esfera se dibuja con la GPU en un solo paso, no necesita librería y la mesa ya demostró que este camino llega a 60 fps.
- **Sin medir:** el coste real de un shader de esfera en el GN2200. Prototipo y medición antes de decidir.

---

## Preguntas abiertas

Respuestas de Samuel del 02-oct-2026:

1. ¿Motor 3D de verdad o 3D con shaders y perspectiva? → **Probar los dos primero:** prototipo de la Luna con cada técnica, medido en el GN2200, y decidir con números.
2. ¿Giroscopio para parallax y brillos? → **Sí, con apagado:** `sensors_plus`, apagado con «reducir movimiento» y en segundo plano.
3. ¿Por dónde se empieza? → **Tanda 1 de la mesa.** Luego la Luna (prototipo doble) y los signos.
4. ¿Cómo se ve la Luna? → **Grabado antiguo:** tinta, oro y marfil, con la fase real del día.
