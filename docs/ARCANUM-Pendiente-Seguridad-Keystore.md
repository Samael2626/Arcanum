---
title: "ARCANUM — Pendiente de seguridad: keystore / key.properties"
date: 2026-08-31
tags: [arcanum, seguridad, keystore, pendiente]
estado: pendiente
prioridad: media
---

# Pendiente de seguridad — keystore y contraseñas

## Estado actual (31/08/2026)
- `upload-keystore.jks` respaldado **fuera del disco**: Google Drive → `Legal/KeyStore/`. ✅ (lo crítico/irrecuperable, resuelto).
- Backup local también en `D:\Proyectos\Arcanum-keystore-backup\` (SHA-256 `744e77e1...`).
- El keystore NUNCA estuvo en git (verificado). No hay nada que rotar del keystore.

## Lo que falta cambiar (decisión: aplazado por Samuel)
- En Drive se subió también `key.properties`, que contiene `storePassword` / `keyPassword` **en texto plano**, en la misma carpeta que el `.jks`.
- Riesgo: si alguien accede al Drive, obtiene la llave **y** su contraseña juntas → puede firmar la app como si fuera Samuel.

### Acciones a hacer (cuando se retome)
1. Mover los valores de `storePassword` y `keyPassword` a un **gestor de contraseñas** (Bitwarden / 1Password / Google Password Manager).
2. **Borrar `key.properties`** de Google Drive (dejar solo el `.jks`).
3. Activar **2FA** en la cuenta de Google de ese Drive.

## Otras credenciales pendientes
- **Cuenta de servicio de Google Cloud para RevenueCat** (JSON con permiso sobre los pedidos de Play). Los pasos estan en `ARCANUM-Play-Console-Progreso.md`. Cuando se descargue ese JSON, aplicarle esta misma regla: fuera del repo, y no en la misma carpeta de Drive que el keystore.

## Regla a futuro
- El valor por defecto de cualquier credencial en el código debe ser vacío y reventar al arrancar, nunca una clave que funcione. (Origen de la fuga de BD del 22/jun–26/ago.)
