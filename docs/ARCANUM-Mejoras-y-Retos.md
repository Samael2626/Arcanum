---
tags: [arcanum, roadmap, retos, semana-4]
tipo: roadmap
area: arcanum
actualizado: 2026-09-04
---

# ARCANUM — Oportunidades de Mejora y Retos Futuros

Ver [[ARCANUM-Estado-Sesion]] · [[ARCANUM-Semana3-Flutter]]

## 1. Seguridad y tokens en Flutter ✅ HECHO (commit `529f9dd`)
Migrado a **Dio** con interceptor: adjunta `Bearer <access>`, y ante `401` refresca silenciosamente
(`/auth/refresh`, rota el refresh token, reintenta 1 vez; si falla, limpia sesión). Tokens en
**`flutter_secure_storage`**. `RegisterData` incluye datos natales.

## 2. Cifrado del Grimorio (client-side) ⏳ PENDIENTE (necesita pantallas Grimorio)
Backend ya guarda `encrypted_content` + `content_iv` (server nunca ve plaintext). Falta cliente:
- **AES-256-CBC** (`pointycastle`), IV aleatorio por entrada.
- **Derivación:** ⚠️ NO derivar la clave AES de la contraseña directamente (cambiar contraseña =
  perder todo). Patrón: `PBKDF2(password,salt)` → **KEK** que cifra una **DEK** aleatoria; guardar la
  DEK envuelta. Cambiar contraseña = re-envolver la DEK, no re-cifrar todo.
- DEK desbloqueada en `flutter_secure_storage` (biometría opcional).

## 3. Micro-animaciones ✅ HECHO (parcial)
`PulsingGlyph`: pulso/brillo dorado en el glifo planetario de "Hoy". Fade+slide-in al cargar.
Seguir: transiciones entre pestañas, animación de la fase lunar.

## 4. Gestión de estado ✅ HECHO (base)
**Riverpod** adoptado: `AuthNotifier` (sesión), `arcanumApiProvider`, providers de Dio/storage/repo.
Pantallas con `ConsumerWidget`/`ConsumerStatefulWidget`. Ampliar a futuros features (oráculo, grimorio).

---

## Pendiente para conectar las pestañas restantes (backend nuevo)
- **Grimorio:** endpoints CRUD de `grimoire_entries` + cifrado cliente (reto #2).
- **Arte (Materia Arcana):** endpoints de `materia_items` (hierbas/piedras/metales) + buscador.
- **Oráculo:** tarot (mazos/spreads) + IA ritual (Groq con contexto natal/luna/hora).
- **Onboarding** (5 pasos) pulido.

## Deuda: tres goldens de Hoy no se pueden regenerar ⏳ PENDIENTE (04/09/2026)

`flutter test test/capturas --update-goldens --run-skipped` deja **seis** capturas
al día y falla en tres:

- `04-sello-abierto`
- `04b-pliegue`
- `05-texto-abierto`

Las tres mueren en el mismo sitio: `find.text('Abrir el sello del Sol')` no
encuentra nada después del `drag` sobre el `ListView`, así que el `tap` explota
con `Bad state: No element` (`test/capturas/hoy_capturas_test.dart:292`). Las
tres capturas que sí salen son las del sello **cerrado**, que no necesitan ese
toque.

**No lo causó la banda del año.** Comprobado con `git stash` sobre
`sky_today_card.dart` y `hoy_capturas_test.dart`: fallaban igual antes del
cambio. Es deuda anterior.

Consecuencia práctica: las capturas del sello **abierto** que se suben a Play no
se pueden actualizar, así que envejecen cada vez que se toca esa pantalla.
Arreglarlo cuando alguien vuelva a `SkyTodayCard` — probablemente el `drag` fijo
de `-900` px ya no deja el botón donde estaba.

## Deuda: el botón de "tu siguiente paso" se desborda a 360 px ⏳ PENDIENTE (04/09/2026)

`hoy_screen.dart:340` — el `Row` del botón de acción no envuelve ni recorta:
con una etiqueta larga se desborda **26 px** a la derecha en un ancho lógico de
360 (el teléfono de referencia del capturador). Apareció al montar la app entera
por el router en `test/features/navegacion/boton_horoscopo_test.dart`, que
produce un "siguiente paso" distinto al de las capturas.

No es del botón del horóscopo: el FAB es una capa superpuesta y no participa en
ese `Row`. Ese test corre a 411 px para no fallar por algo que no prueba.

Arreglo probable: `Flexible` + `softWrap` sobre el `Text`, o `FittedBox`. Cuando
alguien toque esa tarjeta.

## Operativo
- `C:` se llenó (0 GB) → Dart falla al compilar. Lanzar Flutter con `TEMP`/`TMP`/`TMPDIR` = `D:\tmp`,
  o liberar `C:` / fijar TEMP permanente.
