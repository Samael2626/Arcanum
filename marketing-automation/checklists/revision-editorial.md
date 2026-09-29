# Checklist de revisión editorial

Usar antes de aprobar cualquier borrador generado. `ready_for_review` significa
«puede revisarlo una persona», no «publicar».

## 1. Hechos y procedencia

- [ ] Cada afirmación aparece en el paquete factual o se elimina.
- [ ] `source_ids` solo contiene fuentes entregadas al workflow.
- [ ] No se añadieron funciones de roadmap ni capacidades supuestas.
- [ ] Calificadores como «preciso», «riguroso», «estructurado», «profundo»,
      «metódico» o «fundamental» están respaldados literalmente por la fuente.
- [ ] El texto no promete predicción, resultados personales ni eficacia
      sobrenatural.
- [ ] No ofrece consejo médico, psicológico, legal o financiero.

## 2. Voz ARCANUM

- [ ] Suena serio y simbólico, pero lo entiende una persona nueva.
- [ ] Habla de app, aplicación o instrumento; no de páginas, capítulos, volumen
      o libro.
- [ ] No hay tautologías como «método metódico».
- [ ] No hay prosa inflada como «artificio alguno» o «lo inescrutable».
- [ ] No hay urgencia falsa, superlativos vacíos, emojis genéricos ni voz de
      entidad omnisciente.
- [ ] Una frase concreta reemplaza cualquier relleno solemne.

## 3. Trabajo de cada campo

- [ ] El `hook` abre una tensión concreta sin prometer desenlace.
- [ ] El `script` desarrolla una sola idea con hechos comprobables.
- [ ] Cada tarjeta del `carousel` aporta información distinta.
- [ ] La `caption` añade contexto; no repite el hook, el script ni la premisa.
- [ ] El `cta` tiene de 3 a 10 palabras e invita a una función confirmada.
- [ ] `alt_text` queda vacío hasta que exista el recurso visual definitivo.

## 4. Gate y decisión humana

- [ ] El workflow termina sin errores y `validation.valid` es `true`.
- [ ] `validation.errors` está vacío; los avisos fueron revisados.
- [ ] El recurso visual tiene licencia y atribución comprobadas, si aplica.
- [ ] Una persona leyó la pieza completa fuera del editor de n8n.
- [ ] Decisión registrada: `approved`, `needs_revision` o `rejected`.
- [ ] Nada se publica automáticamente mientras no exista estado `approved`.

## Motivo de devolución

- [ ] Hecho no respaldado
- [ ] Medio confundido
- [ ] Voz artificial o grandilocuente
- [ ] Repetición entre campos
- [ ] CTA genérico o función inexistente
- [ ] Riesgo de compliance
- [ ] Recurso visual ausente, sin licencia o inaccesible
