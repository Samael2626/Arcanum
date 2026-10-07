# Guías oficiales para los efectos de Atlas de reliquias

## ¿Dónde aporta valor el vidrio y cómo mantener la lectura?

### Takeaway
Usar translucidez para navegación y controles flotantes; dejar el contenido principal sobre superficies estables. En E, la barra inferior es candidata clara y las tarjetas de texto deben conservar contraste aunque cambie el arte detrás.

### Cited Findings
- Apple define Liquid Glass como una capa funcional para controles y navegación que flota sobre el contenido; desaconseja aplicarlo a la capa de contenido y pide usarlo con moderación. Sus materiales estándar sí sirven para diferenciar contenido. — [Apple HIG: Materials](https://developer.apple.com/design/human-interface-guidelines/materials)
- Apple recomienda la variante regular cuando hay texto o el fondo puede afectar la legibilidad; clear se reserva para controles sobre medios visualmente ricos, con posible capa oscura detrás si el fondo es brillante. — [Apple HIG: Materials](https://developer.apple.com/design/human-interface-guidelines/materials)
- Los materiales de Apple responden a ajustes del sistema que reducen transparencia o aumentan contraste. — [Apple HIG: Materials](https://developer.apple.com/design/human-interface-guidelines/materials)
- WCAG 2.2 AA fija 4.5:1 para texto normal, 3:1 para texto grande y 3:1 para indicadores visuales necesarios de controles y gráficos informativos. Son requisitos web; funcionan como objetivos de diseño verificables para esta maqueta y como referencia útil para la app. — [W3C: Contrast Minimum](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum); [W3C: Non-text Contrast](https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast)
- Flutter documenta que `BackdropFilter` difumina todo lo pintado bajo su recorte; sin recorte puede procesar pantalla completa. Es relativamente costoso y `ImageFiltered` resulta más simple y barato si solo se difumina una imagen. — [Flutter: BackdropFilter](https://api.flutter.dev/flutter/widgets/BackdropFilter-class.html)

### Inferences
- En E, fijar texto de tarjetas sobre un relleno suficientemente oscuro y reservar el vidrio dinámico para la barra inferior o una hoja contextual. El destello puede cruzar el borde, sin atravesar ni disminuir el contraste de letras.
- Para Flutter, recortar cada blur a su control y medirlo en dispositivo físico. Si el arte del fondo es estático, prerenderizar su suavizado o usar `ImageFiltered`; esto es una propuesta técnica, no un resultado de rendimiento medido.

### Gaps
- No hay medición de contraste sobre todos los fotogramas y estados de E. Tampoco hay perfil de GPU para el blur de E en un dispositivo real.

## ¿Qué movimiento hace sentir viva la interfaz sin distraer o marear?

### Takeaway
El movimiento debe explicar una acción, confirmar un resultado o mantener continuidad espacial. La magia pasiva de E necesita poder detenerse y la revelación debe poder interrumpirse.

### Cited Findings
- Apple pide movimiento con propósito, breve y preciso, opcional y cancelable; recomienda evitar añadir espera a interacciones frecuentes. La información importante no debe depender solo de la animación. — [Apple HIG: Motion](https://developer.apple.com/design/human-interface-guidelines/motion)
- Material 3 Expressive propone muelles para interacciones fluidas e interrumpibles, con esquema expressive para momentos destacados y standard para tareas utilitarias. Separa movimiento espacial de efectos como color y opacidad. La misma página indica que su implementación de motion physics para Flutter no está disponible. — [Material 3: Motion](https://m3.material.io/styles/motion)
- Apple identifica escalado, giros, movimiento periférico, parallax, blur animado y movimiento continuo como posibles desencadenantes; ante Reduce Motion recomienda desactivar lo ornamental y sustituir las transiciones que comunican jerarquía por disoluciones, resaltados o cambios de color. — [Apple: Reduced Motion evaluation criteria](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/reduced-motion-evaluation-criteria)
- WCAG 2.2 exige mecanismo de pausa, parada u ocultación para movimiento que empieza solo, dura más de cinco segundos y convive con otro contenido. Para movimiento no esencial disparado por interacción, el criterio 2.3.3 pide poder desactivarlo; este último es nivel AAA. — [W3C: Pause, Stop, Hide](https://www.w3.org/WAI/WCAG22/Understanding/pause-stop-hide); [W3C: Animation from Interactions](https://www.w3.org/WAI/WCAG22/Understanding/animation-from-interactions)
- Flutter expone `AccessibilityFeatures.disableAnimations` para indicar que la plataforma pide desactivar o simplificar animaciones. — [Flutter API: disableAnimations](https://api.flutter.dev/flutter/dart-ui/AccessibilityFeatures/disableAnimations.html)

### Inferences
- En E: destello del borde solo ocasional; ninguna pulsación debe esperar a que termine. La carta puede responder al toque y cambiar inmediatamente su estado semántico; la animación visual puede continuar sin bloquear la siguiente acción. Para Reduce Motion, omitir órbitas, parallax y giro 3D, conservar un fundido corto o cambio de énfasis que indique la transición.
- El ajuste de intensidad de la maqueta es valioso, pero en producto debe obedecer primero la preferencia del sistema y ofrecer pausa persistente para ambientación. No trasladar mecánicamente los tokens de M3 a Flutter: la fuente oficial aún no presenta soporte de Flutter para ese sistema.

### Gaps
- No se ha probado la sensación de duración ni la tolerancia al movimiento con usuarios de ARCANUM. Material 3 no aporta una configuración oficial de motion physics para Flutter en la página consultada.

## ¿Qué pruebas debe pasar E antes de entrar en Flutter?

### Takeaway
Probar lectura, tacto, semántica y fluidez en condiciones reales; el brillo percibido en una captura de escritorio no certifica calidad móvil.

### Cited Findings
- Flutter recomienda probar todos los controles con TalkBack y VoiceOver, que cada interacción activa tenga respuesta, contraste suficiente, acciones importantes reversibles, tamaños de toque de al menos 48×48 px y escalado grande de texto. — [Flutter: Accessibility](https://docs.flutter.dev/ui/accessibility)
- Flutter recoge 48×48 dp como mínimo recomendado en Android y 44×44 pt en iOS; ofrece pruebas automáticas para tamaño de toque, etiquetas y contraste, además de inspección en dispositivos. — [Flutter: UI design and styling](https://docs.flutter.dev/ui/accessibility/ui-design-and-styling); [Flutter: Accessibility testing](https://docs.flutter.dev/ui/accessibility/accessibility-testing)
- Flutter avisa que `saveLayer` y ciertas opacidades y clips pueden causar jank; DevTools Performance permite encontrar fotogramas lentos y capas fuera de pantalla. — [Flutter: Performance best practices](https://docs.flutter.dev/perf/best-practices)
- La documentación de `BackdropFilter` indica que filtros agrupados no solapados pueden compartir un `BackdropKey` y reducir trabajo; los filtros que se solapan no deben compartirlo. — [Flutter: BackdropFilter](https://api.flutter.dev/flutter/widgets/BackdropFilter-class.html)
- Flutter recomienda probar la interfaz en pantalla pequeña con el mayor tamaño de fuente configurado. — [Flutter: UI design and styling](https://docs.flutter.dev/ui/accessibility/ui-design-and-styling)

### Inferences
- Matriz mínima para E: teléfono pequeño, texto máximo, modo gris, contraste aumentado, Reduce Motion, transparencia reducida, TalkBack/VoiceOver y uso con una mano. Verificar tarjetas, barra inferior, revelación y estado de carta. El título, el resultado y el botón principal deben seguir legibles y utilizables sin animación ni color.
- En perfil Flutter medir portada quieta, scroll, entrada a Mesa y revelación con la combinación de blur, arte y destellos activada. Revisar DevTools para fotogramas lentos y `saveLayer`; si falla, quitar primero blur grande y efectos superpuestos.
- Para el HTML actual, la barra inferior de 390×844 usa `backdrop-filter`, mientras la tarjeta Mesa conserva un relleno casi opaco; esa observación sale del código local `prototipos/atlas_reliquias_juice.html`. La prueba útil consiste en alternar vidrio con y sin movimiento mientras se observa si se gana profundidad sin perder lectura.

### Gaps
- No hay resultados de pruebas de accesibilidad, contraste ni frame times del diseño E en Flutter. No afirmar que ya cumple WCAG o que mantiene 60 fps.
