# PROMPT para Codex — Terminar Taller de Sigilos ARCANUM

Cargar skill `arcanum-dev` y `arcanum-chaos` antes de empezar.

## Contexto

Prototipo HTML Canvas single-file de un Taller de Sigilos para la app ARCANUM (app movil premium de practica magica, Flutter+FastAPI). Archivo: `D:\Proyectos\Arcanum\arcanum-sigil-prototype\index.html` (~1177 lines).

## Que esta implementado
- 4 motores de render toggleables y fusibles (Estrella, Sello/Kamea, Grid, Alquimia)
- Reduccion basica (letras unicas, sin vocales)
- Estampas planetarias (click en canvas)
- Export PNG
- Decoraciones (bordes dobles, esquinas)
- Sistema de transformaciones (mirror, rot90/180/270)
- UI: panel izquierdo + canvas 1000x700

## Pendiente — implementar en orden

### 1. SISTEMA DE GNOSIS (carga + olvido del sigilo)
Modal fullscreen black overlay con:
- Timer configurable 30s/60s/120s para contemplacion
- Animacion de respiracion (circulo que pulsa, 4s in/4s hold/4s out/4s hold)
- Boton "Cargar" que inicia el timer
- Boton "Olvidar" que cierra modal, limpia canvas y muestra toast "El sigilo obra en el Caos"
- Texto instructivo: "Fija tu mirada en el sigilo. Vacía tu mente. Cuando el tiempo termine, cierra los ojos y olvida."
- Al terminar el timer: sonido tenue (opcional) + boton "Olvidar" se pone prominente
- Acceso por boton "⟠ Cargar" en el panel

### 2. GALERIA DE SIGILOS (localStorage)
- Boton "Guardar" en panel que serializa: letters, activeEngines, todos los opt* params, PNG thumbnail (canvas.toDataURL)
- Panel lateral desplegable tipo "Galeria" con toggle
- Grid de miniaturas (aprox 80x80px) con nombre (fecha + intencion truncada)
- Click en miniatura: restaura config completo y renderiza
- Boton eliminar por item
- Persistencia en localStorage key "arcanum_sigils"

### 3. REDUCCION MEJORADA
En la seccion de reduccion, agregar dropdown con 3 opciones:
- "Spare (sin vocales, unicas)" — la actual
- "Con vocales (unicas)" — unique letters pero conservando A/E/I/O/U
- "A-O Principle" — segun Spare: reducir vocales a A, consonantes a representacion

Mostrar paso a paso en el info-box:
Linea 1: intencion original
Linea 2: solo letras
Linea 3: reduccion final
Linea 4: valores gematricos

### 4. SVG REAL (no wrapper)
Reemplazar buildSVG() actual (que embebe PNG) por serializacion real:
- Renderizar a un canvas offscreen por capas
- Extraer paths como comandos SVG (M, L, C, A)
- O alternativa: render a SVG usando parse de ImageData (mas simple pero menos preciso)
- Agregar opcion "Fondo transparente" checkbox
- El SVG debe ser editable en Illustrator/Inkscape

### 5. MOBILE RESPONSIVE
- Agregar CSS @media (max-width: 768px)
- Panel se vuelve plegable con hamburger toggle
- Canvas se redimensiona a 100% width con aspect ratio
- Touch events para estampas (touchstart→clientX/Y)
- Reducir font-sizes y paddings

### 6. TEXTO EDUCATIVO
Agregar tooltips/descripciones en el panel:
- Cada familia muestra breve descripcion al hacer hover (title attr o div oculto)
- Explicacion de que hace cada parametro
- Al pie: "Metodo de Austin Osman Spare — Chaos Magic — ARCANUM"

## Reglas
- Single-file: TODO en index.html (incluyendo CSS y JS)
- Sin librerias externas
- Estetica dark esoterica (burgundy/gold/navy)
- Texto de UI en espanol
- ID de elementos en ingles (consistente con lo existente)
- No romper funcionalidad existente
- Al terminar: commit + push automatico a `feat/onboarding-5-pasos`

## Referencias en vault (D:\Brain\10-Proyectos\ARCANUM\)
- [[Taller-Sigilos-Estado-Completo]]
- [[Motor-Alquimia-Goetica]]
- [[Taller-Sigilos-Decisiones]]
