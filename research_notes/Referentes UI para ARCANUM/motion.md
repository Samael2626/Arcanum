# Movimiento e interacción para ARCANUM

## 1. ¿Cómo debe abrirse una reliquia desde la portada?

### Takeaway
La transición debería conservar el objeto tocado como referencia: la tarjeta «Mesa» crece y se convierte en la superficie de la lectura, mientras el resto cede el foco. Es el cambio de mayor impacto para el prototipo E.

### Cited Findings
- Google describe que expandir una tarjeta para mostrar contenido nuevo guía la mirada cuando los elementos compartidos se desplazan a su nueva posición — [Google Design: Making Motion Meaningful](https://design.google/library/making-motion-meaningful).
- En Google Photos, una traslación de la cuadrícula y un fundido breve comunican una eliminación múltiple sin animar cada elemento; el equipo lo eligió para reducir la complejidad visual — [Google Design: Making Motion Meaningful](https://design.google/library/making-motion-meaningful).
- Material 3 emplea resortes que admiten interrupciones y cambios de destino durante la animación — [Material 3: Motion](https://m3.material.io/styles/motion).

### Inferences
- En `atlas_reliquias_juice.html`, sustituir el desplazamiento lateral de ambas escenas por una transición compartida: rectángulo de la tarjeta `Mesa` → rectángulo de la mesa, con la imagen de la carta anclada visualmente; fundir las demás tarjetas. El botón Atrás invierte la transformación. Si se toca otra ruta a mitad de animación, el nuevo destino debe responder de inmediato.

### Gaps
- No hay evidencia aquí de que esta transición específica mejore la conversión o la comprensión en usuarios de ARCANUM; requiere prueba con usuarios.

## 2. ¿Dónde poner el momento de asombro?

### Takeaway
Una sola recompensa sensorial en la acción de revelar: desplazamiento y giro de carta, destello localizado, respuesta háptica opcional y resultado textual inmediato. El espectáculo debe confirmar la acción, no retrasarla.

### Cited Findings
- CapWords ganó la categoría Delight and Fun de Apple en 2025; su transformación de foto a pegatina animada y sonido al cambiar tarjetas hacen más memorable una tarea concreta — [Apple Design Awards 2025](https://developer.apple.com/design/awards/2025/).
- El equipo de CapWords atribuye buena parte del deleite al instante en que la foto se convierte en pegatina y describe la combinación de sonido, tacto y visión — [Apple Developer: Behind the appealing design of CapWords](https://developer.apple.com/articles/capwords).
- Apple recomienda feedback animado breve, preciso y cancelable, y desaconseja movimiento ornamental en acciones frecuentes — [Apple HIG: Motion](https://developer.apple.com/design/human-interface-guidelines/motion).
- Apple cita los hápticos al desbloquear «gems» de Opal como un detalle que da encanto a la experiencia — [Apple Design Awards 2025](https://developer.apple.com/design/awards/2025/).

### Inferences
- En el prototipo, la revelación debe ser el único efecto luminoso intenso. Mostrar el texto de la carta en el mismo toque, sin esperar al fin del giro. Un pulso háptico suave puede marcar el contacto y otro el asentamiento, si la plataforma y los ajustes lo permiten. El brillo debe seguir la carta, no barrer toda la pantalla. Las repeticiones de «velar/revelar» pueden ser más discretas.

### Gaps
- Las fuentes no proporcionan duraciones ni amplitudes válidas para ARCANUM. Tampoco demuestran que el sonido beneficie este contexto; ofrecerlo como opción, no imponerlo.

## 3. ¿Cómo hacer que la portada parezca viva sin animación constante?

### Takeaway
Que cambie por información real del momento: fase lunar, hora, próxima efeméride y práctica disponible. El movimiento ambiental ha de señalar cambios, no simular actividad sin contenido.

### Cited Findings
- Moonlitt ganó Interaction en los Apple Design Awards 2026; Apple destaca su interfaz elegante, incorporación fácil y tratamiento de la luna — [Apple Design Awards 2026](https://developer.apple.com/design/awards/).
- El equipo de Moonlitt explica que buscó simplificar capas de cálculos astronómicos, ciclos y posiciones en una experiencia fácil de explorar — [Apple Developer: ADA Q&A Moonlitt](https://developer.apple.com/news/?id=v1nphz91).
- Tide Guide combina datos por hora y visualizaciones claras con una paleta que acompaña el color del cielo durante el día; permite profundizar en capas de información — [Apple Design Awards 2026](https://developer.apple.com/design/awards/); [Apple Developer: Tide Guide](https://developer.apple.com/news/?id=4r9b23wx).

### Inferences
- En E, el hero «Tu cielo está en movimiento» debería mostrar un dato real y verificable («Luna creciente · próxima fase…») y cambiar acento cromático por momento del día o evento. Animar únicamente el cambio de estado, no mantener tres bucles permanentes. Si no hay datos, usar un estado de carga o disponibilidad explícito.

### Gaps
- No se estudió la confiabilidad de los datos astrológicos de ARCANUM ni cómo se actualizan en la app; la propuesta visual depende de esa integración.

## 4. ¿Cómo hacer intuitiva la lectura después del efecto?

### Takeaway
Usar foco progresivo: una instrucción visible cada vez, atenuar lo terminado, y dejar la siguiente acción al alcance. La ceremonia visual sirve al recorrido.

### Cited Findings
- Mela, finalista Interaction 2025, resalta y atenúa pasos, medidas y tiempos en el momento adecuado durante el modo de cocina — [Apple Design Awards 2025](https://developer.apple.com/design/awards/2025/).
- Crouton ganó Interaction 2024 por jerarquía clara e interacciones que permiten encontrar el siguiente paso sin desviar la atención de la tarea — [Apple Design Awards 2024](https://developer.apple.com/design/awards/2024/).
- Apple identifica el onboarding fácil de Moonlitt como parte de su mérito de interacción — [Apple Design Awards 2026](https://developer.apple.com/design/awards/).

### Inferences
- En la Mesa E, secuenciar «Escribe una pregunta» → «Elige tirada» → «Revela» → «Guarda o continúa»; el área central cambia según el paso y conserva un título breve del paso actual. La carta revelada reemplaza la instrucción anterior, evitando sumar capas y botones. Una breve indicación gestual puede aparecer una vez y desaparecer.

### Gaps
- El prototipo actual solo muestra una carta de ejemplo y no representa el flujo real del tarot; los pasos propuestos deben alinearse con la implementación existente antes de pasar a Flutter.

## 5. ¿Qué ritmo de movimiento mantiene elegancia y accesibilidad?

### Takeaway
Dos intensidades coherentes: rápida y sobria para navegación repetida; más expresiva solo en la revelación. Toda información debe existir también en texto y todo adorno poder pausarse.

### Cited Findings
- Material 3 distingue un esquema expresivo, con pequeño rebote, de uno estándar, más funcional. Separa resortes espaciales de efectos como opacidad y color; su implementación Flutter figuraba como no disponible en la documentación consultada — [Material 3: Motion](https://m3.material.io/styles/motion).
- Apple aconseja que el movimiento sea intencional, opcional, breve y cancelable; no debe ser el único vehículo de información — [Apple HIG: Motion](https://developer.apple.com/design/human-interface-guidelines/motion).
- Google Design señala que en Google Photos el movimiento simbólico breve reduce trayectorias superpuestas y complejidad visual — [Google Design: Making Motion Meaningful](https://design.google/library/making-motion-meaningful).

### Inferences
- Para E: navegación y presión de tarjeta con una respuesta corta sin rebote visible; solo la carta tiene una desaceleración con leve asentamiento. Mantener `prefers-reduced-motion`, botón de pausa y texto del resultado. En Flutter, definir curvas y resortes propios, sin asumir que los tokens Material 3 de Compose existen en Flutter.

### Gaps
- Los valores exactos deben medirse en el dispositivo objetivo, con perfiles de batería y fluidez. La documentación no valida el rendimiento del blur, del 3D o de las sombras en ARCANUM.
