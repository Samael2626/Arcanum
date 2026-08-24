# Plantillas de redacción

Reglas de estilo para todo documento legal de ARCANUM:

- Español con acentos, segunda persona, frases cortas. Un usuario debe entenderlo sin abogado.
- Sin fórmulas vacías ("nos reservamos el derecho de modificar en cualquier momento" sin decir cómo se avisa).
- Cada afirmación debe ser verificable en el código. Si no se puede verificar, no se escribe.
- Fecha de última actualización y número de versión al inicio. La versión aceptada se guarda por usuario.
- Los dos sitios se editan juntos: `legal-site/` y `docs/`. Comprobar con `diff` antes de commitear.

## Política de privacidad — esqueleto

1. Quién es el responsable y cómo contactarlo (nombre, país, correo). Obligatorio en CO, UE y Apple 5.1.1.
2. Qué datos se recogen, agrupados por finalidad, **tomados de la auditoría del repo, no de la memoria**: cuenta, perfil natal, consultas al oráculo, grimorio, compras, publicidad, diagnóstico.
3. Para qué y con qué base legal (tabla: dato → finalidad → base legal → retención).
4. Datos sensibles: qué se considera sensible aquí (convicciones, salud implícita en las consultas), que su entrega es voluntaria, y consentimiento explícito separado.
5. Con quién se comparte: tabla de subencargados de `ia-y-datos.md`, con enlace a la política de cada uno.
6. Transferencias internacionales y su salvaguarda.
7. Cuánto se conserva cada categoría y qué pasa al borrar la cuenta (incluida la retención residual por fraude o ley, si la hay).
8. Derechos y cómo ejercerlos, con plazos por jurisdicción: CO 10/15 días hábiles, UE 1 mes.
9. Publicidad y analítica: qué SDK, cómo revocar el consentimiento y dónde está ese control dentro de la app.
10. Menores.
11. Seguridad: cifrado en tránsito, cifrado del grimorio, control de acceso. Solo lo que exista de verdad.
12. Cómo se notifican los cambios.
13. Secciones por jurisdicción (EEE/UK, California, Colombia).

## Términos de servicio — esqueleto

1. Qué es ARCANUM y qué no es (aquí vive la tesis: instrumento de práctica, no predicción).
2. Cuenta: edad mínima, veracidad, responsabilidad sobre credenciales.
3. Uso aceptable y causales de suspensión.
4. Contenido del usuario: es suyo; licencia limitada solo para prestar el servicio; el grimorio no se lee.
5. IA: qué modelos, que el output puede ser inexacto, que no es consejo profesional, y la advertencia contractual que exige Anthropic sobre verificar afirmaciones fácticas.
6. Suscripciones y créditos: precio, periodicidad, renovación automática, cómo cancelar, qué pasa con los créditos no usados, reembolsos vía tienda, derecho de desistimiento en la UE.
7. Publicidad y recompensas por ver anuncios.
8. Propiedad intelectual del contenido de la app y de las fuentes de dominio público.
9. Limitación de responsabilidad, redactada para no chocar con las normas imperativas de consumo (en la UE y en Colombia no se puede excluir todo).
10. Ley aplicable y foro; mención a la autoridad de control correspondiente.
11. Contacto.

## Textos de UI (con acentos, breves)

**Consentimiento IA — antes del primer envío al modelo** (Apple 5.1.2(i)):
> Tus consultas se procesan con modelos de IA de Anthropic y Groq para generar la lectura. Se envía el texto de tu consulta y los datos de tu carta que la lectura necesita. No se envía tu correo ni el contenido de tu grimorio. [Acepto] [Ahora no]

**Aviso de IA — primera pantalla del chat** (AI Act art. 50):
> Estás hablando con un modelo de IA. Sus respuestas son simbólicas y pueden contener errores.

**Datos sensibles — onboarding** (Ley 1581 art. 5):
> Tu fecha, hora y lugar de nacimiento y lo que escribas sobre tu práctica pueden revelar convicciones personales. Entregarlos es voluntario y puedes borrarlos cuando quieras.

**Reporte de contenido** (Play AI-Generated Content):
> Reportar esta respuesta — [ofensiva] [peligrosa] [sin sentido]

**Borrado de cuenta**:
> Se eliminarán tu perfil, lecturas, conversaciones y grimorio. Es permanente y no se puede deshacer. Las compras ya realizadas no se reembolsan por esta vía.
