---
title: "ARCANUM — Progreso Play Console"
date: 2026-08-30
tags: [arcanum, release, play-console, checklist]
cuenta: "Personal — Samael26 · ID 8910253673336308380"
paquete: "com.arcanum.magick"
app_id_play: "4973886259298198159"
---

# ARCANUM — Progreso Play Console

## Estado general

- Cuenta personal Samael26 creada. Verificación de desarrollador Android: OK.
- App "Arcanum" (`com.arcanum.magick`) creada, estado **Borrador**.
- Idioma predeterminado: es-419. Tipo: Aplicación.

## Hosting legal — RESUELTO

Publicado y verificado en vivo sin login (por la sesión de código):
- Privacidad: `https://samael2626.github.io/Arcanum/privacy-policy.html` → 200
- Borrado de cuenta: `https://samael2626.github.io/Arcanum/account-deletion.html` → 200
- Términos (`terms.html`) → 404, pendiente de publicar.

Netlify (`helpful-bavarois-495137.netlify.app`) fue callejón sin salida (deploy parcial + gated). Ignorar.
ReleaseConfig.privacyPolicyUrl y accountDeletionUrl ya apuntan a las 200.

- **Privacidad ya pegada en el campo de Play.** ✅

## DECISIÓN — pausar lo legal hasta la verdad de datos (opción B)

Las declaraciones legales viejas estaban FALSAS: decían Supabase (no usado), AdMob activo
(adsEnabled=false, sin anuncios), Firebase Analytics recogiendo uso (no se instancia en lib/).
La sesión de código lo está corrigiendo AHORA. No llenar Data Safety ni clasificación hasta que
código confirme qué se recoge de verdad — una declaración falsa a Google = rechazo y re-trabajo.

## Condición para reanudar

Cuando la sesión de código entregue checklist confirmando:
- firebase_analytics fuera del pubspec (o confirmado que no recoge),
- adsEnabled=false en release y sin recolección de Ad ID,
- terms.html publicado con URL 200,
- AAB release final firmado (ruta + versionCode).

## Al reanudar — una sola pasada en Play (orden)

1. Clasificación de contenido (cuestionario).
2. Público objetivo y niños.
3. Data Safety — exacto según lo que código confirme.
4. Anuncios (declarar: sin anuncios).
5. AI-Generated Content.
6. Ficha de Play Store (usar `.tmp/ficha/`: icono-512, gráfico-destacado, 6 capturas).
7. Subir AAB (`.tmp/arcanum-1.0.0+5.aab` o el final de código) → prueba interna → prueba cerrada.

## Pendientes manuales de Samuel (no código)

- Firmar DPA de Railway.
- Activar ZDR (zero data retention) en Groq.
- Correo a RevenueCat.
- Crear productos `arcanum_credit_1` y `arcanum_pack_3` en Play Console y App Store Connect.
- Terminar verificación de identidad (documento + constancia de domicilio) si sigue pendiente.

## Decisiones tomadas (no re-preguntar)

- Ubicación precisa sin GPS. Grimorio no compartido. Sin "Actividad en la app". Defender, no "corregir".
- Sin anuncios en el release (adsEnabled=false).
