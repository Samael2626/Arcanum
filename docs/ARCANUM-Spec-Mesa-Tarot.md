# Mesa de tarot: especificación para Flutter

Referencia visual y de tiempos: `prototipos/tarot-mesa-3d-v2.html`. Las decisiones posteriores de Samuel y el comportamiento implementado se registran aquí y en `ARCANUM-Plan-Mesa-Tarot.md`; cuando difieren del prototipo, rige la decisión registrada.

Decisiones de Samuel que no se discuten al portar:

- Módulo nuevo **Tarot**, separado del Oráculo.
- **Regla única de gestos:** tocar hace la acción directa; mantener pulsado abre el radial.
- **Sin barra de botones:** las acciones viven en la mesa. Una carta concreta del abanico se elige con la **lupa**: el dedo pasea por el abanico, la carta bajo él sube y crece y las vecinas se apartan. La lista de 78 posiciones queda solo para el lector de pantalla (06-oct, opción A del prototipo «Gestos para sacar carta»).
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

- Carta base en Flutter: 110 × 176 unidades (proporción 1:1,6 de la lámina RWS de la app); el prototipo usaba 110 × 190.
- Escalas: mazo 0,62; abanico 0,55; carta suelta 0,70. Cada tirada tiene su propia escala `s`.

### Mazos

Un mazo es **arte + contenido**:

- **Rider–Waite–Smith:** 78 cartas.
- **Arcanos Mayores:** 22 cartas, mismo arte.

En el backend, los mazos se definen como datos en `app/domain/decks.py`: nombre, cartas incluidas, si admiten invertidas y referencia a su arte. Añadir uno no cambia el motor de sesiones.

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

Las coordenadas se portaron a `app/domain/spreads.py` y el backend sirve el catálogo por `GET /tarot/spreads`. Las siete tiradas están disponibles para la mesa; llevarlas al Oráculo queda fuera de esta fase.

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

**Implementado:** `TarotSession`, persistencia y rutas `/tarot/sessions` para abrir, operar, interpretar, deshacer y cerrar. El orden permanece en el servidor; la app recibe posiciones ocupadas y cartas ya sacadas. `/tarot/spread` y `/tarot/draw-one` siguen disponibles para la app publicada.

---

## 2. Cámara

- **Perspectiva:** 1000. La mesa se transforma con `scale · rotateX(θ) · rotateZ(giro)`.
  - En Flutter: `Matrix4` con `setEntry(3, 2, 1/1000)`, `rotateX`, `rotateZ`.
- **Encuadre:** se calcula una vez, con la inclinación de reposo **θ = 30°**, ajustando el ancho al paño (el marco puede recortarse un poco) y centrando en alto. Inclinar la mesa **no** cambia el zoom.
- **Toque → mesa:** se usa la homografía inversa de la proyección; el hit-test sigue el plano de cada pieza.
- **Límites:** giro ±40°, inclinación 16–56°, zoom 1–2,6.
- **Movimiento:** el arrastre mueve el destino y la cámara lo alcanza a razón de 0,14 por fotograma. Al soltar hay inercia (×6 en giro, ×5 en inclinación).
- **Sentido:** invertido a petición de Samuel. Arrastrar a la derecha gira la mesa hacia la izquierda.
- **Corrección del 03-oct:** zoom como lupa, pellizco hacia los dedos, centro retenido en el paño, cámara guardada y doble toque para recuperar el encuadre incluso fuera de la mesa. El giro ±40° puede recortar hasta el 10 % del paño a 360 × 760 con zoom 1; la decisión sobre ese recorte sigue abierta.

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
| Mazo o montón en juego | Lo extiende (o lo junta si otro tenía el abanico) | Radial del mazo; con su abanico abierto, el radial del abanico | Centro: moverlo. Laterales: abanico. Borde de arriba: cortar. Soltarlo sobre otro: unirlos. |
| Carta del abanico | Pulsar pone la lupa; soltar saca la carta resaltada al primer hueco libre | Nada: mantener es parte de la lupa (el radial del abanico se abre manteniendo el mazo) | Deslizar pasea la lupa; subir el dedo por encima del abanico se lleva la carta a un hueco concreto |
| Carta suelta | Vuelve al montón más cercano | Radial de la carta | Moverla. Imán a los huecos; junto a otra carta de la tirada queda como aclaratoria. |
| Carta en la tirada | Desvela o lee | Radial de la carta | Moverla (intercambio si el hueco está ocupado) |
| Esquina de la carta boca abajo | — | — | La levanta y voltea (ver 5) |
| Doble toque en carta suelta | Desvela o lee | | |
| «Interpretar» bordado | Interpretación | 1,3 s: un hilo rodea la tirada y **cierra el círculo** | |
| Sello de la pregunta | Cuándo se selló | | |

- **Pellizcar con dos dedos:** zoom y desplazamiento.
- **Zona de toque de cada carta:** se amplía respecto al dibujo; los tests a 360 × 760 comprueban objetivos de al menos 48 dp para las acciones principales en reposo y zoom 1. La superposición y el lector de pantalla reales siguen pendientes en el GN2200.
- **Extracción inmediata:** al tocar el abanico se ve un dorso pendiente en el mismo fotograma y su posición queda reservada. La carta definitiva llega con la respuesta del servidor; un error la devuelve al abanico y se avisa. El umbral es de 18 px (`kTouchSlop`, 07-oct); la lupa del abanico no lo espera.

---

## 4. Radial

- Cada acción es un **círculo suelto de 52 dp**, con el nombre debajo en versalitas de 10,5 pt. No hay disco común.
  - Radio 86 (hasta 6 opciones) o 100 (7 o más).
  - Centro dibujado de 36 dp, con objetivo táctil y semántico de al menos 48 dp: cierra, o hace de **Deshacer** mientras esté vigente.
- **Gestual:** se abre al mantener pulsado y, sin levantar el dedo, se elige por el **ángulo** a más de 46 px del centro. Soltar sobre la opción la ejecuta; soltar en el centro deja el radial abierto para tocar.
- **Gramática fija:** lo imposible se apaga, nunca desaparece ni cambia de sitio.

| Radial | Opciones, en orden, empezando arriba y en sentido horario |
|---|---|
| Mazo o montón | Barajar · Cortar · Extender · Sacar · Recoger · Tirada · Unir |
| Carta | Desvelar/Leer · Girar · Recoger · Sacar (apartar) · Desvelar todas |
| Abanico | Sacar · Juntar · Barajar · Tirada |
| Paño | Sellar pregunta · Recoger todo · Lecturas · Sonido |
| Barajar | Cascada · Por encima · Sobre el paño |
| Tirada | las 7, con su esquema dibujado |
| Unir | Elegir orden · Automático |
| Recoger todo (con lectura empezada) | Cerrar el círculo · Sin guardar |

Leer, la pregunta y las lecturas guardadas usan paneles compactos anclados a lo que se tocó. La interpretación de Tradición usa «Lectura revelada» a pantalla completa, una carta por página.

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
- **Reparto:** una carta cada 110 ms, 420 ms de vuelo; al encajar vibra. El sonido espera las grabaciones de Samuel.
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
- La recuperación está pendiente de decisión de producto; por ahora usa tres ventanas consecutivas de 2 s a 55 fps o más.

En Flutter se decide con `FrameTiming`.

**Estado implementado (05-oct):** símbolos del palo, huellas, luz lunar con fundido de 2,5 s, humo al romper el sello y al cerrar, pregunta que vuela al sello en 760 ms y anillo de cierre de 3400 ms con las cartas de regreso en 900 ms. «Reducir movimiento» suprime los efectos decorativos; los niveles de calidad reducen desenfoques y cadencia. Los efectos van en capas separadas para no repintar el paño cada fotograma. El ritmo visual y los fps faltan por medir en el GN2200.

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

- **Sonido pendiente:** Samuel aportará las grabaciones; no se sintetizaron ni se añadieron muestras de prueba. Al integrarlas se variará el tono ±5 % y el volumen ±3 dB.
- **Háptica implementada** con `HapticFeedback`: los tiempos del prototipo se traducen a los golpes fijos disponibles en Flutter.
- **Silenciar** desde el radial del paño apaga la vibración y apagará el sonido cuando exista; se recuerda entre sesiones.

---

## 8. Persistencia, deshacer y memoria

- **Autoguardado continuo:** una foto JSON de la vista pública del servidor y la disposición local: montones sin revelar su orden, abanico, cartas con posición, hueco, sentido, aclaratorias, tirada, sello y cámara. En Flutter va en almacenamiento local **cifrado, como el Grimorio**.
- **Deshacer el último gesto:** foto antes de cortar, mover, extender, unir o devolver; se ofrece 5 s. Si tocó el mazo, el servidor guarda el estado anterior hasta 30 s y retrocede con el cliente. Un error de red conserva la opción de reintentar mientras siga vigente.
  - En el prototipo es un botón discreto en la esquina inferior izquierda con un anillo que se consume, y el centro del radial hace lo mismo.
  - **Trampa que ya costó un fallo:** la foto debe **copiar** los arrays de los montones, no compartirlos.
- **Lecturas guardadas:** cada cierre de círculo guarda la foto, la pregunta y el contexto astral. Se pueden **continuar** desde ahí; «Contemplar» sin tocar se descartó por ahora.
- **Contexto astral:** fase, hora planetaria y fecha se calculan al interpretar o cerrar sin interpretar, con el lugar confirmado del usuario (`user_place.dart`); sin lugar no se inventa hora. La iluminación viaja en la respuesta de interpretar, pero no se guarda en `tarot_readings`. La pregunta viaja en claro al servidor (D5); el autoguardado local de la mesa va cifrado con AES-256-GCM.

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

## 10. Estructura implementada en Flutter

```
lib/features/tarot/
  application/ TableController: operaciones en fila, deshacer local y del servidor
  data/        TableStore: foto local cifrada por usuario
  domain/      TableState y modelos de la mesa
  table/       camara, geometria, gestos, piezas, radial, efectos, calidad y haptica
  reading/     Lectura revelada
  tarot_screen.dart
```

El cliente de API está en `lib/core/api/arcanum_api.dart`; las tiradas y mazos vienen del backend. Riverpod usa `AsyncNotifier` manual, siguiendo el patrón existente en el repo; este módulo no añadió generación de código.

**Accesibilidad implementada:** cartas con nombre, sentido y hueco; opciones y centro del radial, sello, bordado, deshacer, disco lunar y carta pendiente con etiquetas y acciones semánticas. El abanico visual mantiene sus 78 posiciones (3,27 dp entre cartas en 360 × 760); la lupa separa las vecinas a más de 20 unidades de mesa bajo el dedo. Para el lector queda el nodo «Elegir carta del abanico, N cartas», invisible y sin zona de toque, que abre una lista de 78 filas de 48 dp. Los efectos decorativos quedan fuera del lector de pantalla. Las pruebas automatizadas no sustituyen la comprobación con lector real en GN2200.

---

## 11. Estado y asuntos abiertos

- **Backend de la mesa:** mazos, siete tiradas y sesión de sorteo por posiciones ya implementados, con migración 016 y tests. Falta la revisión integral de la rama antes de integrarla.
- **Oráculo con las tiradas nuevas:** requiere tocar el prompt y `oracle_guard` con el skill `arcanum-voz`, y cuidar el cupo de Groq, que ya se agota a diario. La Rueda del año (12 cartas) es la más cara.
- **Arte vectorial de ARCANUM:** `TarotFacePainter` no se pudo portar al prototipo HTML. En Flutter sí existe: decidir qué mazo lo usa.
- **Motor de interpretación:** Tradición funciona en la mesa con significados por posición y sentido. El Oráculo con las tiradas nuevas queda pendiente.
- **Cartas pequeñas en la Cruz Celta y la Rueda:** mitigadas con la zona de toque y el zoom, pero siguen siendo pequeñas en un móvil de 360 dp.
- **Validación en GN2200:** medir fps con Impeller, completar Cruz Celta, comprobar lector de pantalla, tacto, efectos y textos largos. Sin esas medidas no se afirma 60 fps ni aprobación móvil.
- **Cerradas el 07-oct (Samuel):** la calidad vuelve a subir tras 6 s a ≥55 fps; cada recaída después de subir dobla la espera (12, 24 s) y a la tercera ya no lo intenta en esa mesa. El umbral de arrastre pasa a 18 px (`kTouchSlop`) y la lupa del abanico sigue al dedo desde el primer píxel.
- **Cerradas el 06-oct:** el giro ±40° ya no recorta: la cámara se aleja lo justo (`TableCamera.fitScale`). El abanico frente al sello y el bordado: se recoge solo al llenar la tirada y empieza al lado de la caja del mazo, a 32 dp o más de los bordes de pantalla.
