# Mesa de tarot: especificación para Flutter

Fuente de verdad del comportamiento: `prototipos/tarot-mesa-3d-v2.html` (rama `release/1.0.6`, commit `463f00b` o posterior).
Este documento traduce ese prototipo a decisiones de la app. Donde el prototipo y este texto no coincidan, manda el prototipo y hay que corregir este texto.

Decisiones de Samuel que no se discuten al portar:

- Módulo nuevo **Tarot**, separado del Oráculo.
- **Regla única de gestos:** tocar hace la acción directa; mantener pulsado abre el radial.
- **Sin barra de botones:** todo vive en la mesa.
- **Sin velas.**
- **Nada de menús que se reordenen:** cada acción tiene siempre su sitio.

---

## 1. Modelo de la mesa

### Unidades de mesa

Todo se posiciona en un plano de **600 × 900 unidades** que luego proyecta la cámara. Nunca se trabaja en píxeles.

| Zona | Rango | Uso |
|---|---|---|
| Estante (madera) | y < 168 | Mazos guardados. Soltar una carta aquí la aparta. |
| Paño | x 18–582, y 172–882 | Donde se juega |
| Área de tirada | x 36–564, y 200–670 | Los huecos se definen en fracciones de esta área |
| Zona cercana | y 690–880 | Mazo en juego (470, 782) y abanico (y = 782) |
| Bordado «Interpretar» | centro (300, 484), anillo r = 202, palabra en y ≈ 700 | Bajo la tirada: ninguna de las 7 tiradas lo pisa |

- Carta base: 110 × 190 unidades.
- Escalas: mazo 0,62; abanico 0,55; carta suelta 0,70. Cada tirada tiene su propia escala `s`.

### Mazos

Un mazo es **arte + contenido**:

- **Rider–Waite–Smith:** 78 cartas.
- **Arcanos Mayores:** 22 cartas, mismo arte.

En el backend, cada mazo es una fila: nombre, cartas incluidas, si admite invertidas y referencia a su arte. Así, añadir un mazo nuevo no toca el motor.

### Tiradas

Son datos, no código: una lista de posiciones `[fx, fy, giro, nombre, significado]`.

| Tirada | Cartas | Escala | Etiqueta en el paño |
|---|---|---|---|
| Una carta | 1 | 1 | nombre |
| Tres cartas | 3 | 0,9 | nombre |
| Cruz simple | 5 | 0,74 | número |
| Relación | 5 | 0,74 | número |
| Herradura | 7 | 0,64 | número |
| Cruz Celta | 10 | 0,56 | número (la 2 va a 90°) |
| Rueda del año | 12 | 0,46 | número |

Las coordenadas exactas están en `SPREADS` del prototipo. El backend debería servir este catálogo para que la app y el Oráculo lean la misma definición.

### Sorteo en el servidor

El servidor decide el orden y las invertidas. El cliente solo elige **posiciones**.

```
sesion = {
  mazo,
  montones: { pid: [id_carta | null, ...] },   // null = ya sacada; los índices no se mueven
  invertidas: { id_carta: bool },               // se deciden al barajar
  sacadas: [id_carta, ...]
}
```

| Operación | Efecto |
|---|---|
| `abrir(mazo)` | Un montón `p0` en orden de fábrica |
| `barajar(pid)` | Fisher–Yates con azar criptográfico solo en ese montón; fija las invertidas |
| `cortar(pid, n)` | Las n de arriba pasan a un montón nuevo; devuelve su pid |
| `unir([pid de arriba a abajo], destino)` | Concatena los montones |
| `sacar(pid, posición)` | Devuelve `{id, carta, invertida}` y deja un `null` en su sitio |
| `devolver(id, pid)` | Al fondo del montón |
| `recoger(pid)` | Todas las sacadas vuelven al fondo |

**Todo esto está por construir en FastAPI.** Hoy solo existen `/tarot/spread` y `/tarot/draw-one`, que devuelven cartas ya elegidas.

---

## 2. Cámara

- **Perspectiva:** 1000. La mesa se transforma con `scale · rotateX(θ) · rotateZ(giro)`.
  - En Flutter: `Matrix4` con `setEntry(3, 2, 1/1000)`, `rotateX`, `rotateZ`.
- **Encuadre:** se calcula una vez, con la inclinación de reposo **θ = 30°**, ajustando el ancho al paño (el marco puede recortarse un poco) y centrando en alto. Inclinar la mesa **no** cambia el zoom.
- **Toque → mesa:** es la inversa de la proyección (`toTable` en el prototipo): primero se deshace la inclinación y después el giro.
- **Límites:** giro ±40°, inclinación 16–56°, zoom 1–2,6.
- **Movimiento:** el arrastre mueve el destino y la cámara lo alcanza a razón de 0,14 por fotograma. Al soltar hay inercia (×6 en giro, ×5 en inclinación).
- **Sentido:** invertido a petición de Samuel. Arrastrar a la derecha gira la mesa hacia la izquierda.

---

## 3. Gestos

Umbrales:

- Mantener: **430 ms**.
- Un toque se convierte en arrastre al superar **6 px**.
- Doble toque: dos toques en menos de **320 ms**.

| Sobre… | Tocar | Mantener | Arrastrar |
|---|---|---|---|
| Tapete o marco | — | Radial del paño | Gira e inclina la mesa |
| Doble toque en tapete o marco | Restablece la cámara | | |
| Mazo del estante | Lo pone en juego | — | Al paño: lo pone en juego |
| Mazo o montón en juego | Lo extiende (o lo junta si otro tenía el abanico) | Radial del mazo | Centro: moverlo. Laterales: abanico. Borde de arriba: cortar. Soltarlo sobre otro: unirlos. |
| Carta del abanico | La saca al primer hueco libre | Radial del abanico | La saca y la lleva |
| Carta suelta | Vuelve al montón más cercano | Radial de la carta | Moverla. Imán a los huecos; junto a otra carta de la tirada queda como aclaratoria. |
| Carta en la tirada | Desvela o lee | Radial de la carta | Moverla (intercambio si el hueco está ocupado) |
| Esquina de la carta boca abajo | — | — | La levanta y voltea (ver 5) |
| Doble toque en carta suelta | Desvela o lee | | |
| «Interpretar» bordado | Interpretación | 1,3 s: un hilo rodea la tirada y **cierra el círculo** | |
| Sello de la pregunta | Cuándo se selló | | |

- **Pellizcar con dos dedos:** zoom y desplazamiento.
- **Zona de toque de cada carta:** su tamaño visible más ~8 px por lado, para que en la Cruz Celta supere los 48 dp.

---

## 4. Radial

- Cada acción es un **círculo suelto de 52 dp**, con el nombre debajo en versalitas de 10,5 pt. No hay disco común.
  - Radio 86 (hasta 6 opciones) o 100 (7 o más).
  - Centro de 44 dp: cierra, o hace de **Deshacer** mientras esté vigente.
- **Gestual:** se abre al mantener pulsado y, sin levantar el dedo, se elige por el **ángulo** a más de 46 px del centro. Soltar sobre la opción la ejecuta; soltar en el centro deja el radial abierto para tocar.
- **Gramática fija:** lo imposible se apaga, nunca desaparece ni cambia de sitio.

| Radial | Opciones, en orden, empezando arriba y en sentido horario |
|---|---|
| Mazo o montón | Barajar · Cortar · Extender · Sacar · Recoger · Tirada · Unir |
| Carta | Desvelar/Leer · Girar · Recoger · Sacar (apartar) · Desvelar todas |
| Abanico | Sacar · Juntar · Barajar |
| Paño | Sellar pregunta · Recoger todo · Lecturas · Sonido |
| Barajar | Cascada · Por encima · Sobre el paño |
| Tirada | las 7, con su esquema dibujado |
| Unir | Elegir orden · Automático |
| Recoger todo (con lectura empezada) | Cerrar el círculo · Sin guardar |

Leer, la pregunta, la interpretación y las lecturas guardadas son **paneles compactos** anclados a lo que se tocó. Nunca hojas que suben desde abajo.

---

## 5. Animación y física

- **Volteo por palo:** son los valores de `_FlipSpec` en `tarot_card.dart`. **Se reutiliza `TarotCardView` tal cual.**
- **Giro por esquina:** la carta **bisagra sobre el borde opuesto** (se suma `T = h − R·h` a la rotación) y sigue al dedo:
  - `cos(ángulo) = 1 − recorrido / ancho`. Cuenta todo movimiento que aleje la esquina: hacia el borde contrario, hacia arriba o en diagonal.
  - Pasados **70°** termina de voltearse y la bisagra se disuelve mientras dura el volteo de su palo. Si no, vuelve atrás.
  - Inclinación diagonal de ±12° según se coja una esquina de arriba o de abajo.
- **Peso al arrastrar:** la inclinación es un muelle.
  - Objetivo = velocidad × 1,3, con un máximo de 15°.
  - En cada fotograma: velocidad = velocidad × 0,74 + (objetivo − actual) × 0,16.
  - Al soltar, el objetivo se reduce ×0,8 por fotograma y la carta oscila hasta calmarse.
  - En Flutter: `SpringSimulation` o un `Ticker` con esta misma integración.
- **Reparto:** una carta cada 110 ms, 420 ms de vuelo; al encajar suena un golpe suave y vibra 8 ms.
- **Barajados:** son animación, porque el azar lo pone el servidor.
  - **Cascada:** dos mitades que se entrelazan.
  - **Por encima:** 4 rondas de bloques de 3.
  - **Sobre el paño:** remolino de 1,7 s.

---

## 6. Efectos

| Efecto | Qué es | Coste |
|---|---|---|
| Símbolos del palo | Junto a la carta desvelada, tantos como su número (5 de Oros = 5 pentáculos). Figuras: corona y su palo. Mayores: número romano. Invertida: símbolos invertidos. | Bajo |
| Huella del palo | Bastos, brasas a los lados. Copas, 3 ondas en el paño. Espadas, destello diagonal y esquirlas. Oros, polvo a ras de mesa. | Breve |
| Luz de la Luna | Capa sobre la mesa según la iluminación de la fase registrada: plateada desde arriba en Llena, oscuridad en Nueva. La fase se dibuja en la cabecera. | Estática |
| Pregunta sellada | El texto vuela y se encoge hasta un sello de lacre sobre el paño; se rompe al interpretar. | Breve |
| Cerrar el círculo | Anillo dorado que se apaga, humo, las cartas vuelven despacio y se guarda la lectura. | Breve |

**Calidad adaptativa:** la mesa mide sus fps cada 2 s.

- Por debajo de 40 baja un nivel: primero quita brillos caros; después hace los efectos a medio ritmo y quita las huellas.
- Vuelve a subir tras un rato holgado.

En Flutter se decide con `FrameTiming`.

---

## 7. Sonido y háptica

Todo el sonido está en re dórico pentatónico, con reverberación de 2,8 s. Nada suena áspero.

| Evento | Sonido | Vibración |
|---|---|---|
| Barajar en cascada | 10 roces de papel y 3 campanitas ascendentes | 8 ms |
| Cortar | Roce y campana grave | 12 ms |
| Encajar en un hueco | Golpe de madera suave y una nota | 8 ms |
| Desvelar | Campana de cristal (dos notas) | 10 ms |
| Desvelar un Mayor | Cuenco con batido de 5 s | 12, 40, 12 |
| Sellar / romper el sello | Tono cálido / chasquido y 4 notas descendentes | 14 / 8, 30, 8 |
| Cerrar el círculo | Acorde lento | 10, 60, 10 |
| Opción del radial bajo el dedo | — | 4 ms |

- **En Flutter no se sintetiza:** se graban muestras de estos mismos sonidos y se varía el tono ±5 % y el volumen ±3 dB en cada disparo, para que no suene enlatado.
- **Háptica** con `HapticFeedback`.
- **Silenciar** desde el radial del paño.

---

## 8. Persistencia, deshacer y memoria

- **Autoguardado continuo:** una foto JSON de toda la mesa (`serialize` del prototipo): mazo, montones del servidor, abanico, cartas con posición, hueco, sentido, aclaratorias, tirada, sello, lectura y cámara. En Flutter va en almacenamiento local **cifrado, como el Grimorio**.
- **Deshacer el último gesto:** foto antes de cortar, mover, extender, unir o devolver; se ofrece 5 s.
  - En el prototipo es un botón discreto en la esquina inferior izquierda con un anillo que se consume, y el centro del radial hace lo mismo.
  - **Trampa que ya costó un fallo:** la foto debe **copiar** los arrays de los montones, no compartirlos.
- **Lecturas guardadas:** cada cierre de círculo guarda la foto, la pregunta y el contexto astral. Se pueden **contemplar** (reconstrucción sin tocar) o **continuar** desde ahí.
- **Contexto astral:** fase, iluminación, hora planetaria y fecha. Se registra con la primera carta que entra en la tirada. En la app sale del backend (`lunar_calendar.py`, `planetary_hours.py`) con el lugar del usuario (`user_place.dart`).

---

## 9. Rendimiento: lo aprendido en el prototipo

Medido en Chromium sin GPU y en el móvil de Samuel.

| Qué costaba | Impacto | Lección para Flutter |
|---|---|---|
| Velas 3D con ~140 caras | 59 → 19 fps | Geometría decorativa en un `CustomPainter` con `RepaintBoundary`, repintada solo al mover la cámara |
| Una capa animada con fusión sobre el paño | La mitad de los fps | Nada animado que obligue a repintar el paño; el paño va en su propia `RepaintBoundary` |
| Variable de estilo en toda la mesa por fotograma | ~10 fps | No reconstruir el árbol de la mesa por fotograma; animar solo transform y opacidad |
| Desenfoques de fondo y sombras con blur | Gran parte del lag en móvil | Sombras con degradado pintado, nunca `BackdropFilter` sobre la mesa |
| Abanico de 78 cartas completas | ~14 fps | Cartas del abanico solo con dorso; se completan al sacarlas |

Estado final del prototipo, sin GPU: quieta 60 fps, Cruz Celta ~57–59, abanico ~30–34. **En Flutter con Impeller se espera más, pero hay que medirlo en el móvil real.**

---

## 10. Estructura propuesta en Flutter

```
lib/features/tarot/
  data/        catalogo de tiradas y mazos, cliente de sesion de sorteo, persistencia cifrada
  domain/      TableState (lo que hoy es serialize), reglas de montones, deshacer
  table/       TableCamera (Matrix4 + inversa), TableView (Stack de piezas), hit-test en unidades de mesa
  pieces/      DeckPiece (caja con grosor), CardPiece (envuelve TarotCardView + bisagra + muelle)
  radial/      RadialMenu (Overlay, seleccion por angulo, gramatica fija)
  fx/          FxPainter (huellas, humo, luz lunar), PipsRow
  audio/       muestras y variacion de tono, HapticFeedback
  tarot_screen.dart
```

Estado con Riverpod (`@riverpod` + generación de código), como pide el repo.

---

## 11. Abierto

- **Backend:** mazos, catálogo de tiradas y sesión de sorteo por posiciones (sección 1). Con migración y tests.
- **Oráculo con las tiradas nuevas:** requiere tocar el prompt y `oracle_guard` con el skill `arcanum-voz`, y cuidar el cupo de Groq, que ya se agota a diario. La Rueda del año (12 cartas) es la más cara.
- **Arte vectorial de ARCANUM:** `TarotFacePainter` no se pudo portar al prototipo HTML. En Flutter sí existe: decidir qué mazo lo usa.
- **Motor de interpretación:** en el prototipo es un hueco («aquí respondería Tradición u Oráculo»).
- **Cartas pequeñas en la Cruz Celta y la Rueda:** mitigadas con la zona de toque y el zoom, pero siguen siendo pequeñas en un móvil de 360 dp.
