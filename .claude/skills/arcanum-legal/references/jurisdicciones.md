# Jurisdicciones — baseline global

ARCANUM opera desde Colombia y publica en tiendas globales. Baseline conservador: cumplir lo más estricto (GDPR) y añadir lo específico de cada plaza.

## Colombia — Ley 1581/2012 + Decreto 1377/2013 (habeas data). Autoridad: SIC

- **Autorización previa, expresa e informada** del titular, y debe poder probarse: guardar timestamp + versión del texto aceptado en base de datos, no un booleano suelto.
- **Aviso de privacidad** + **política de tratamiento** publicados.
- **Datos sensibles** (art. 5): salud, vida sexual, biométricos, origen racial, **convicciones religiosas o filosóficas**. La práctica mágica declarada, la carta natal y el contenido del grimorio son razonablemente convicciones filosóficas/religiosas → **tratamiento sensible: autorización explícita, reforzada, y advertir que no es obligatorio responder**. Es la particularidad legal más importante de ARCANUM en Colombia.
- Canal de consultas y reclamos publicado. Plazos: consulta 10 días hábiles, reclamo 15 días hábiles (prorrogables).
- **RNBD**: registro obligatorio solo para responsables con activos totales > 100.000 UVT. Un desarrollador individual normalmente no alcanza el umbral, pero el resto de obligaciones aplica igual. NO COMPROBADO para el caso concreto: verificar UVT del año y activos antes de afirmar que no toca registrar.

## Unión Europea

### GDPR
- **Base legal por finalidad**, no una global: contrato (prestar el servicio), consentimiento (ads personalizados, analytics, datos sensibles), interés legítimo (antifraude, con balancing test escrito).
- Art. 9: convicciones religiosas/filosóficas y salud son categoría especial → **consentimiento explícito** (opt-in separado, granular, revocable con la misma facilidad con que se dio).
- Derechos: acceso, rectificación, supresión, portabilidad, oposición. Respuesta en 1 mes.
- Art. 28: **DPA firmado con cada encargado** (Anthropic, Groq, RevenueCat, Google/Firebase, Railway) y lista pública de subencargados.
- Transferencias fuera del EEE: SCC / Data Privacy Framework. Documentar.
- Art. 33: notificar brecha a la autoridad en 72 h.
- ROPA (registro de actividades de tratamiento) — ver `diagramas.md`.

### EU AI Act — art. 50 (aplicable desde 2026-08-02, ya vigente)
Fuente: https://artificialintelligenceact.eu/article/50/
- Los sistemas que interactúan directamente con personas (chatbots) deben informar que se está interactuando con IA **de forma clara y distinguible, a más tardar en la primera interacción**. El oráculo lo necesita en la primera pantalla del chat, no solo en los términos.
- El contenido sintético debe llevar marcado legible por máquina. Sistemas ya en mercado antes del 2026-08-02 tienen hasta 2026-12-02 para conformarse al marcado.
- ARCANUM es *deployer* de un modelo de tercero, no *provider* del modelo; la obligación de aviso de interacción recae igual.

### DSA / consumo
- Identificación del trader y datos de contacto accesibles.
- Derecho de desistimiento de 14 días en contenido digital, salvo renuncia expresa e informada. En la práctica los reembolsos los gestionan Apple/Google, pero la política debe decirlo.

## Estados Unidos
- **CCPA/CPRA (California)**: aviso en la recolección; derecho a saber/borrar/corregir; opt-out de "sale/share" — compartir identificadores con AdMob para publicidad personalizada cuenta como *share*, así que hace falta el control equivalente a "Do Not Sell or Share My Personal Information". No discriminar por ejercer derechos.
- **COPPA**: menores de 13. ARCANUM se declara **no dirigida a menores de 13**; si el rating termina en 16+/18+, el gate de edad debe ser coherente en toda la ficha.
- Estados con ley propia (VA, CO, CT, TX, UT…): el baseline GDPR + CPRA los cubre en lo esencial.

## Reino Unido
UK GDPR + DPA 2018 (equivalente funcional) + **Children's Code (ICO Age Appropriate Design)** si es plausible que la usen menores. PECR para cookies/identificadores.

## Regla práctica
Un solo texto legal global, con secciones por jurisdicción al final ("Si resides en el EEE/UK…", "Si resides en California…", "Si resides en Colombia…"). Un documento por plaza se desincroniza siempre.
