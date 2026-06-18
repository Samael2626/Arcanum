---
tags: [arcanum, roadmap, retos, semana-4]
tipo: roadmap
area: arcanum
actualizado: 2026-06-18
---

# ARCANUM — Oportunidades de Mejora y Retos Futuros

Ver [[ARCANUM-Estado-Sesion]] · [[ARCANUM-Semana3-Flutter]]

Puntos críticos a atender en los próximos hitos. (Análisis senior añadido a cada uno.)

## 1. Seguridad y tokens en Flutter (Semana 4 — prioridad alta)
`core/api/arcanum_api.dart` es básico (http + coords hardcodeadas). Al integrar login:
- **Migrar a Dio** con un `Interceptor` que adjunte `Authorization: Bearer <access>`.
- **Refresco silencioso**: ante `401`, pausar la cola de peticiones, llamar `POST /auth/refresh`
  (el backend YA rota el refresh token), reintentar la original. Evitar tormentas de refresh con
  un lock/single-flight.
- Tokens en **`flutter_secure_storage`** (Keychain iOS / Keystore Android).
- *Nota backend:* el logout ya blacklistea el access token en Redis → el cliente debe descartar
  ambos tokens al cerrar sesión.

## 2. Cifrado del Grimorio (client-side) (Semana 7)
El backend ya está diseñado para esto: `grimoire_entries` guarda `encrypted_content` + `content_iv`
y el servidor NUNCA ve el plaintext. Falta el lado cliente:
- **AES-256-CBC** vía `pointycastle`; IV aleatorio por entrada (no secreto, se guarda junto).
- **Derivación de clave:** ⚠️ no derivar la clave AES directamente de la contraseña — si el usuario
  cambia la contraseña, perdería todo. Patrón recomendado:
  1. `PBKDF2(password, salt)` → **KEK** (key-encryption-key).
  2. Generar una **DEK** aleatoria (la que cifra el grimorio).
  3. Guardar la **DEK envuelta** (cifrada con la KEK). Cambiar contraseña = re-envolver la DEK,
     no re-cifrar todo.
- Guardar la DEK desbloqueada en `flutter_secure_storage` (con biometría opcional para abrirla).

## 3. Micro-animaciones (polish continuo)
Elevar "Hoy" a experiencia premium dinámica:
- **Pulso/brillo dorado** alrededor del glifo del regente del día (`AnimationController` con
  `BoxShadow`/escala sutil en loop suave).
- Transición suave al cargar la fase lunar (fade/scale del `MoonDisc`).
- Implícitas (`AnimatedSwitcher`, `Hero`) entre estados de carga y contenido.
- Mantener sutileza: old money, nada estridente.

## 4. Gestión de estado (Semana 4+ cuando lleguen pantallas reales)
`setState`/`FutureBuilder` bastan hoy en "Hoy". Al llegar el chat del Oráculo (IA), CRUD del
Grimorio, sesión de usuario compartida:
- Adoptar **Riverpod** (ya elegido en las notas): `Provider`/`AsyncNotifier` para auth, datos del
  cielo, sesión de oráculo. Type-safe, testeable, sin árboles de widgets sobrecargados.
- Estado de auth global (token + usuario) como `Notifier` que el interceptor de Dio consulta.

---

## Orden sugerido
Semana 4 = **(1) auth/Dio + Riverpod del estado de sesión** (habilita Cielos/Grimorio reales) →
luego pantallas feature → **(2) cifrado** en Grimorio → **(3) micro-animaciones** como capa de pulido.
