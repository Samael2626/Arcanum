# Plan de documentación y web de ARCANUM

Fecha: 2026-10-07. Alcance: organizar conocimiento y mostrar el producto con precisión.

## Diagnóstico

- Ya existen estado, specs, auditorías y checkpoints, pero no había un índice ni una regla clara para mantener páginas estables.
- Firebase está configurado para servir [`arcanum_app/sitio/`](../arcanum_app/sitio/), según `arcanum_app/firebase.json`. Esa página contiene una presentación breve, soporte y enlaces legales.
- [`legal-site/index.html`](../legal-site/index.html) es una presentación antigua con etiquetas P0/P1/P2 y un formulario de vista previa. No usarlo como inventario de funciones vigentes.
- La navegación actual del producto tiene cinco secciones: Cielo, Horóscopo, Grimorio, Saber y Oráculo. Dentro de ellas hay funciones como tarot, biblioteca, materia y Taller de sigilos; se deben describir desde la experiencia real, sin prometer pantallas separadas que no existen.

## Qué mostrar en la web pública

| Página o bloque | Pregunta que responde | Evidencia necesaria |
|---|---|---|
| Inicio | ¿Qué es ARCANUM y para quién sirve? | Captura actual y descripción contrastada con la app |
| Recorrido | ¿Qué puedo hacer en Cielo, Horóscopo, Grimorio, Saber y Oráculo? | Capturas actuales de dispositivo o emulador, una acción real por sección |
| Cómo funciona | ¿De dónde salen los cálculos y qué hace la IA? | Código astral, configuración del modelo y límites claros de uso |
| Privacidad en lenguaje claro | ¿Qué se cifra y qué datos salen del dispositivo? | Flujo real, consentimiento y enlace a la política vigente en `gh-pages` |
| Ayuda | ¿Cómo empiezo, recupero acceso, gestiono pagos y elimino la cuenta? | Flujos probados y enlace a eliminación de cuenta vigente |
| Estado y cambios | ¿Qué versión se muestra y qué cambió? | Versión/release real, fecha y cambios visibles para usuarios |

Primera versión: ampliar la página de Firebase existente con recorrido, tres a cinco capturas actuales, preguntas frecuentes y fecha de revisión. Mantener `app-ads.txt` en la raíz. Conservar los enlaces legales a `gh-pages`; no copiar allí sus textos. No publicar diagramas internos, arquitectura de seguridad detallada ni un roadmap que parezca promesa de entrega.

## Qué documentar dentro del repositorio

| Documento estable | Contenido mínimo | Fuente |
|---|---|---|
| Mapa de producto | Secciones, recorridos y límites de cada función | Router y pantallas |
| Arquitectura | Contexto, contenedores y flujos sensibles | Código y configuración |
| Contratos | API y errores importantes; enlazar OpenAPI generado | Routers y esquemas |
| Datos y privacidad | Qué se almacena, cifra, envía a terceros y borra | Modelos, cliente y política vigente |
| Operación | Entornos, despliegue, pruebas, observabilidad y recuperación | README, CI y configuración |
| Decisiones | ADR breve para elecciones difíciles de revertir | PR y evidencia |

## Control sin duplicar trabajo

1. **Fuente:** Git para documentación técnica y producto; `gh-pages` para los legales; sitio Firebase para contenido público. El vault, si está disponible, enlaza a estas fuentes y guarda notas personales, sin crear otra versión normativa.
2. **Cambio:** un PR que altera un flujo actualiza la página estable correspondiente y su diagrama. La descripción del PR explica qué cambió y cómo se verificó.
3. **Estado:** issues/PR para trabajo pendiente; `ARCANUM-Estado.md` para el panorama consolidado. Marcar en documentos viejos que son históricos cuando puedan confundir.
4. **Revisión:** antes de cada release, recorrer los enlaces, las capturas, la versión mostrada y las afirmaciones de privacidad/pagos. La fecha de revisión no reemplaza la comprobación.

## Primer lote ejecutable

1. Mantener este índice y el mapa de arquitectura como entrada técnica.
2. Hacer inventario visual de las cinco secciones en la build actual; escoger capturas sin datos personales.
3. Redactar la guía de uso por recorridos reales: primer inicio, consulta del cielo, guardar en Grimorio, leer en Saber y usar el Oráculo.
4. Ampliar `arcanum_app/sitio/index.html` con ese material; revisar enlaces legales y `app-ads.txt` antes de desplegar.
5. Dibujar las secuencias sensibles indicadas en [arquitectura.md](arquitectura.md) a medida que se verifiquen sus flujos.

No hace falta elegir un generador nuevo de documentación para este lote: Markdown y Mermaid en Git cubren índice, revisión y diagramas; el sitio estático existente cubre la cara pública. Reconsiderarlo si aparecen múltiples autores, búsqueda de muchas páginas o traducciones.

## Implementación web — 7 de octubre de 2026

- La página pública de Firebase en [`arcanum_app/sitio/index.html`](../arcanum_app/sitio/index.html) muestra el recorrido por Cielo, Horóscopo, Grimorio, Saber y Oráculo, con capturas generadas desde pruebas de widgets con datos ficticios.
- Las fuentes de las capturas son `arcanum_app/test/capturas/hoy_capturas_test.dart` y `arcanum_app/test/capturas/navegacion_capturas_test.dart`. Al cambiar esas pantallas, regenerar y revisar las imágenes de `arcanum_app/sitio/assets/` antes del siguiente despliegue.
- El texto de privacidad distingue el cuerpo cifrado de las entradas del Grimorio de sus títulos y datos de contexto. La afirmación se contrastó con `arcanum_app/lib/features/grimorio/grimorio_editor.dart`.
- La página conserva los enlaces legales de `gh-pages` y `app-ads.txt` en la raíz de Hosting. La llamada a la acción envía un correo para solicitar acceso a la prueba cerrada.

## Guía de uso — 8 de octubre de 2026

El [mapa de producto](producto.md) y la [guía de uso](guia-de-uso.md) cubren los cinco recorridos del primer lote con fuentes en código. Falta verificarlos de punta a punta en Android; la guía enumera los casos a probar.

## Diagramas de arquitectura — 8 de octubre de 2026

El [mapa de arquitectura](arquitectura.md) ya incluye secuencias de registro, consentimiento y perfil natal, y de creación y lectura del Grimorio. Ambas están contrastadas con el código, no con un recorrido completo en Android. La [revisión de privacidad del 9 de octubre](legal/privacidad-onboarding.md) quitó el borrador natal de `SharedPreferences`, trasladó el perfil pendiente a almacenamiento seguro vinculado a la cuenta y cerró las escrituras natales sin consentimiento en la API. La revocación ahora borra el historial de práctica en el servidor, vacía las respuestas duplicadas en la contabilidad e impide nuevas escrituras personales mientras siga revocada. Falta verificar el tiempo de purga de copias de seguridad y recorrer el flujo en Android. Después corresponden pagos y créditos, Oráculo y un modelo de datos acotado.
