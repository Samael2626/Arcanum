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
- ~~Activar ZDR (zero data retention) en Groq.~~ **HECHO 03/09/2026** — activado para las APIs de inferencia. La política y la página de borrado ya lo dicen; la tabla de Data Safety de `play-ficha.md` también.
- Correo a RevenueCat.
- Crear productos `arcanum_credit_1` y `arcanum_pack_3` en Play Console y App Store Connect.
- Terminar verificación de identidad (documento + constancia de domicilio) si sigue pendiente.

## Decisiones tomadas (no re-preguntar)

- Ubicación precisa sin GPS. Grimorio no compartido. Sin "Actividad en la app". Defender, no "corregir".
- Sin anuncios en el release (adsEnabled=false).

## Pendiente ANTES DE PRODUCCION — el SDK de AdMob viaja sin usarse

No bloquea la prueba cerrada. La declaracion conservadora del Ad ID en la
seccion 2 de `play-ficha.md` es correcta y suficiente para esta pasada. Esto se
decide antes de subir a **produccion**, no ahora.

### El hecho, ya comprobado (no volver a extraerlo)

`google_mobile_ads: ^9.0.0` esta en `arcanum_app/pubspec.yaml:52`, pero
`MobileAds.instance.initialize()` esta detras de `ReleaseConfig.adsEnabled`
(`main.dart:35`), que es `bool.fromEnvironment('ADS_ENABLED')` sin valor por
defecto. El AAB 1.0.0+7 se compilo sin la bandera: **no se muestra ni un anuncio**.

Aun asi el SDK viaja en el binario. Leido del manifiesto del propio AAB
(`base/manifest/AndroidManifest.xml` de
`Arcanum-release/.../bundle/release/app-release.aab`, 31/08):

```
com.google.android.gms.ads.MobileAdsInitProvider    PRESENTE
com.google.android.gms.ads.AdActivity               PRESENTE
com.google.android.gms.ads.AdService                PRESENTE
com.google.android.gms.ads.APPLICATION_ID           PRESENTE
com.google.android.gms.permission.AD_ID             PRESENTE
android.permission.ACCESS_ADSERVICES_AD_ID          PRESENTE
```

`MobileAdsInitProvider` es un `ContentProvider`: Android lo arranca **antes** que
el codigo Dart, asi que no depende de que `adsEnabled` sea falso. Es el caso
**inverso** al de Firebase Analytics, que se pudo dar por no recogido porque
`AnalyticsRegistrar` estaba **AUSENTE** del manifiesto. Por eso la fila del Ad ID
se declara y se queda.

**NO COMPROBADO:** que el provider llegue a leer el Ad ID sin que nadie llame a
`initialize()`. No se midio. Declarar de mas es el lado seguro del error.

### La decision, antes de produccion

- **(a) Anuncios de verdad.** Implementar el consentimiento UMP —hoy es un
  `TODO(compliance)` en `main.dart:36`, ver el bloque "Gap abierto: consentimiento
  de ads (UMP)" en `.agents/skills/arcanum-legal/references/ia-y-datos.md`— y
  compilar con `ADS_ENABLED=true`. Entonces la casilla "Contiene anuncios" de
  `play-ficha.md` pasa a **Si**, y hay que revisar la ficha, que hoy no los menciona.
- **(b) Sacar el SDK.** Si no van a usarse a corto plazo, quitar
  `google_mobile_ads` del `pubspec.yaml` (y lo que arrastre en `build.gradle`) y
  recompilar. El manifiesto deja de traer `MobileAdsInitProvider`, `AD_ID` y
  `ACCESS_ADSERVICES_AD_ID`, y **se puede quitar la fila de ID de dispositivo de
  Data Safety**. Es la opcion limpia: menos permisos, menos que declarar, menos
  que defender.

Lo que no vale es dejarlo como esta al llegar a produccion: pedir permisos de
publicidad en una app sin publicidad es de lo que Play pregunta.
