---
tags: [arcanum, modulos, diseno, proposito]
tipo: diseno
area: arcanum
actualizado: 2026-06-18
---

# ARCANUM — Propósito de cada módulo (uso mágico real)

Ver [[ARCANUM-Estado-Sesion]] · [[MOC-ARCANUM]]

> El "para qué" práctico de cada pestaña. Magia operativa, no adorno.
> Resumen: **Hoy** = cuándo · **Cielos** = quién eres · **Arte** = con qué · **Grimorio** = qué
> hiciste · **Oráculo** = qué viene.

## 🌅 Hoy — timing (cuándo obrar)
- **Hora planetaria:** cada hora la rige un planeta. Venus→amor; Marte→protección/corte;
  Mercurio→estudio/comercio/viajes; Júpiter/Sol→prosperidad/éxito; Saturno→destierro/límites;
  Luna→psiquismo/sueños. Muestra el planeta vigente + minutos restantes → entrar a la hora justa.
- **Regente del día:** capa amplia (lunes=Luna, martes=Marte...).
- **Luna:** creciente=atraer/construir; menguante=desterrar/soltar; nueva=sembrar; llena=cargar/pico.
- Uso típico: ¿Luna creciente + hora de Júpiter? → obra de dinero AHORA.

## ✶ Cielos — mapa personal (quién eres mágicamente)
- **Carta natal:** constitución espiritual; planeta regente, Sol/Luna/Asc → energías que canalizas,
  planeta patrón para talismanes, fortalezas/debilidades.
- **Tránsitos:** clima cósmico que te golpea hoy (Saturno→pruebas; Marte→energía/conflicto). Cuándo el
  cielo apoya una obra grande y cuándo esperar.

## ⚗ Arte (Materia Arcana) — correspondencias (con qué obrar)
- Qué hierba/piedra/metal/incienso por intención y planeta. Base material del hechizo.
- Uso: obra de Venus en hora de Venus → Rosa, cobre, incienso de rosa. Filtrar por tipo/intención.
- **Estado: HECHO** (backend `/materia` + pestaña Arte con lista filtrable y ficha de detalle).

## ❦ Grimorio — registro (qué hiciste y qué funcionó) [PENDIENTE]
- Diario mágico cifrado (AES-256 client-side). Ritos, sueños, tiradas, sigilos; captura luna+hora.
- Uso: rastrear qué funciona, ver patrones (condiciones que dieron resultado). Cifrado = privado total.

## ⛤ Oráculo — consejero (qué dice lo invisible) [PENDIENTE]
- Tarot + IA (Claude) que interpreta EN CONTEXTO de tu carta, luna, hora y últimas entradas del
  grimorio. Lectura personalizada, no genérica.
