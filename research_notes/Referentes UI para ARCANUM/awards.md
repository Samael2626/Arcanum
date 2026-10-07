# Referentes premiados de UI/UX móvil

## ¿Qué referentes recientes aportan patrones transferibles a ARCANUM E?

### Takeaway
Los premios de Apple y Google señalan un principio común: la interfaz memorable enlaza la recompensa sensorial con una acción comprensible y con información útil. Cinco patrones concretos sirven para la portada E.

### Cited Findings
- **1. Astronomía como interfaz, no como adorno.** Moonlitt ganó Interaction en Apple Design Awards 2026. Apple destaca su incorporación de fase lunar y eventos celestes con incorporación sencilla, interacciones claras y Liquid Glass; sus creadores dicen que procuraron simplificar capas de cálculos astronómicos, ubicación y visualización 3D. — [Apple Design Awards 2026](https://developer.apple.com/design/awards/); [entrevista al equipo de Moonlitt](https://developer.apple.com/news/?id=v1nphz91)
- **2. Información inmediata y profundidad opcional.** Tide Guide ganó Visuals and Graphics en 2026 y fue finalista antes. Apple destaca sus gráficos a pantalla completa comprensibles, widgets que ahorran pasos y una paleta que cambia con el cielo; el creador explica que expone condiciones actuales al principio y permite profundizar en métricas por capas. — [Apple Design Awards 2026](https://developer.apple.com/design/awards/); [entrevista al creador de Tide Guide](https://developer.apple.com/news/?id=4r9b23wx)
- **3. Una microanimación que acompaña un resultado.** CapWords ganó Delight and Fun en 2025: convierte una foto en una pegatina interactiva mediante una breve animación y añade sonido a la transición de tarjetas. Su equipo explica que la animación aparece durante el procesamiento, antes de mostrar el resultado. — [Apple Design Awards 2025](https://developer.apple.com/design/awards/2025/); [historia de diseño de CapWords](https://developer.apple.com/articles/capwords/)
- **4. Tacto y respuesta para objetos centrales.** Google otorgó Best Game 2025 a Pokémon TCG Pocket y destacó la apertura táctil de sobres y la contemplación de las cartas. Apple señala los botones grandes y ruedas con respuesta háptica de (Not Boring) Camera, finalista 2026, sin que eso impida controles precisos. — [Google Play Best of 2025](https://blog.google/products-and-platforms/platforms/google-play/best-apps-games-2025/); [Apple Design Awards 2026](https://developer.apple.com/design/awards/)
- **5. Personalidad contenida y acceso universal.** grug ganó Delight and Fun 2026 con una idea diaria, estilo dibujado coherente y sin funciones superfluas. Structured, finalista de Inclusivity 2026, fue destacada por su lectura fácil y por reservar espacio al descanso; Guitar Wiz ganó esa categoría con VoiceOver, tipografía dinámica y contraste aumentado. — [Apple Design Awards 2026](https://developer.apple.com/design/awards/)

### Inferences
- Para E, el pequeño cielo de portada debería mostrar un dato real y fechado —por ejemplo fase y próximo evento— y el brillo cambiar solo cuando cambia un estado o llega una recompensa. El dato astral debe provenir del motor de efemérides de ARCANUM; Moonlitt demuestra el valor de la relación entre estética y utilidad, no verifica los cálculos de nuestra app.
- La tarjeta principal puede mostrar una lectura de una línea y ofrecer detalle al entrar. Esto aprovecha el espacio vacío de E sin ocultar acciones frecuentes bajo una portada decorativa.
- El momento de revelar una carta o completar un sigilo merece una secuencia breve de anticipación, respuesta y reposo, asociada al contenido revelado. Si hay latencia real, una animación útil puede cubrirla sin inventar progreso.
- La carta del tarot puede tener fricción visual y respuesta táctil moderadas; la apertura del mazo debe conservar controles obvios y permitir omitir la animación.
- La identidad de ARCANUM puede concentrarse en unos pocos detalles propios —trazo orbital, destello y sonido opcional— mientras los textos, la navegación y el contraste siguen siendo sencillos. Las preferencias de reducción de movimiento y tipografía grande deben diseñarse junto con el efecto.

### Gaps
- Los premios y descripciones oficiales son selección editorial, no estudios comparativos que demuestren más retención o mejor conversión para ARCANUM. Haría falta probar tareas reales con usuarios de la app.
- Google Play Best of 2026 aún no aparece publicado a fecha 7 de octubre de 2026; la referencia más reciente localizada en la fuente oficial es 2025.

## ¿Qué límites tiene trasladar estas referencias a un prototipo HTML?

### Takeaway
Los ganadores sirven como inspiración de comportamiento; su calidad depende de datos reales, hardware y pruebas en la plataforma final.

### Cited Findings
- Moonlitt combina cálculos astronómicos, ciclos lunares, posición solar y lunar y datos de ubicación en la experiencia, según sus desarrolladores. — [Entrevista al equipo de Moonlitt](https://developer.apple.com/news/?id=v1nphz91)
- Apple describe en Tide Guide datos horarios, temperatura del agua y oleaje que pueden consultarse a medida que el usuario profundiza. — [Entrevista al creador de Tide Guide](https://developer.apple.com/news/?id=4r9b23wx)
- Google caracteriza a Focus Friend, su Best App 2025, como una herramienta sencilla y simpática para mantener la atención. — [Google Play Best of 2025](https://blog.google/products-and-platforms/platforms/google-play/best-apps-games-2025/)

### Inferences
- El prototipo HTML puede representar estados, movimiento y jerarquía, pero no validar por sí solo la exactitud del calendario astral, respuesta háptica de Flutter ni rendimiento en móviles modestos.
- Elegir menos efectos con función definida puede ser más fiel a los referentes premiados que sumar destellos por toda la pantalla.

### Gaps
- No se encontraron mediciones públicas comparables de duración óptima o densidad de partículas para los ganadores citados; esos parámetros deben ajustarse en pruebas de ARCANUM.
