# Checklist de prelanzamiento

Ningún item se salta. Cada uno se marca con evidencia (archivo:línea, captura o URL), no con un "sí".

## Bloqueantes (sin esto no se publica)

- [ ] Reporte in-app de contenido generado por IA, en cada respuesta del oráculo y las lecturas. `Play AI-Generated Content`
- [ ] Aviso de IA visible en la primera interacción del chat. `AI Act art. 50`
- [ ] Modal de consentimiento nombrando Anthropic y Groq antes del primer envío, con opción de rechazar. `Apple 5.1.2(i)`
- [ ] UMP/CMP integrado: `requestConsentInfoUpdate` → `loadAndShowConsentFormIfRequired` → `canRequestAds` antes de inicializar ads. `AdMob EEE/UK`
- [ ] Punto de entrada permanente a Opciones de privacidad en Ajustes cuando sea requerido.
- [ ] Borrado de cuenta in-app + URL web pública, y el borrado propaga a RevenueCat y Firebase. `Play`, `Apple 5.1.1(v)`
- [ ] Consentimiento de datos sensibles (natal, práctica) explícito, separado y revocable, con versión y timestamp persistidos. `Ley 1581 art. 5`, `GDPR art. 9`
- [ ] Enlace a la política de privacidad dentro de la app y en la metadata de la ficha.
- [ ] Política, `legal-site/`, `docs/` y `privacy_screen.dart` dicen lo mismo, y coinciden con el código auditado.
- [ ] Data safety de Play relleno campo por campo contra el inventario real, incluidas las preguntas de eliminación.
- [ ] Ningún prompt ni respuesta loggeado junto a un identificador de usuario.
- [ ] Ninguna clave de API en el repo ni en el historial.

## Antes de enviar a review

- [ ] Ficha de tienda sin promesas de resultado ni lenguaje predictivo (`disclaimers.md`, líneas rojas).
- [ ] Posicionamiento diferenciado frente a `Apple 4.3(b)`: la ficha debe dejar claro que es instrumento de práctica, no otra app de tiradas.
- [ ] Age rating coherente entre ficha, cuestionario y onboarding; declaración de no dirigida a menores de 13.
- [ ] Paywall: precio, periodicidad, renovación automática y cancelación visibles antes de comprar.
- [ ] Advertencias duras en la materia médica tóxica o abortiva, en la propia ficha del ítem.
- [ ] System prompt del oráculo cubre crisis de salud mental con contención y líneas de ayuda.
- [ ] Contacto de soporte publicado y funcional (Apple 1.2, Ley 1581 canal de reclamos).
- [ ] DPAs firmados y lista de subencargados publicada.
- [ ] `docs/legal/` con casos de uso, DFD, ROPA y mapa de borrado regenerados contra el código de este release.

## Post-lanzamiento (recurrente)

- [ ] Revisión trimestral de las políticas de ambas tiendas por WebFetch (cambian sin aviso).
- [ ] Revisar reportes de contenido y documentar qué se hizo con ellos.
- [ ] Procedimiento de brecha listo: quién decide, a quién se notifica, reloj de 72 h.
- [ ] Revisar plazos de derechos: CO 10/15 días hábiles, UE 1 mes.
- [ ] Colombia: si los activos superan 100.000 UVT, registrar en el RNBD y presentar reportes semestrales de reclamos.
