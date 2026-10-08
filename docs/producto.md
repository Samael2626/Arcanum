# Mapa de producto de ARCANUM

Estado: comportamiento comprobado en el código el 2026-10-08. Público: equipo de producto, diseño, documentación y QA. Este mapa describe entradas y tareas de la app; no sustituye una prueba en dispositivo ni una guía paso a paso.

## Entrada y acceso

- La app intenta abrir `/hoy`. Si no hay sesión, la guarda central envía a `/login`. Registro, login, onboarding y privacidad son las rutas públicas; el resto exige sesión en el router. Tras registrarse se abre el onboarding y, al terminarlo o rechazar el tratamiento de datos sensibles, se abre Sendero. [Router](../arcanum_app/lib/core/router/app_router.dart), [registro](../arcanum_app/lib/features/auth/register_screen.dart), [onboarding](../arcanum_app/lib/features/onboarding/presentation/onboarding_screen.dart).
- El onboarding pide consentimiento para datos sensibles antes de solicitar nombre, fecha, hora y lugar de nacimiento. Rechazarlo permite terminar sin esos datos; algunas vistas personalizadas necesitan el perfil natal. [Onboarding](../arcanum_app/lib/features/onboarding/presentation/onboarding_screen.dart), [carta natal](../arcanum_app/lib/features/cielos/cielos_screen.dart).
- La barra principal tiene cinco destinos, en el orden de la tabla siguiente. El cajón también permite llegar a Sendero, Perfil, Ajustes y otras rutas de cuenta. [Secciones](../arcanum_app/lib/core/content/sections.dart), [cajón](../arcanum_app/lib/core/router/arcanum_drawer.dart).

## Cinco secciones principales

| Sección y ruta | Tarea principal | Dentro de la sección | Límite que conviene explicar |
|---|---|---|---|
| **Cielo** `/hoy` | Observar el momento y relacionarlo con la carta natal. | **Ahora:** regente, hora planetaria, Luna y saltos a otras tareas. **Tu carta:** rueda natal, planetas, ángulos y tránsitos. | La carta personal necesita datos natales; no es una sexta pestaña llamada Cielos. |
| **Horóscopo** `/horoscopo` | Leer el día sobre la carta propia. | Sello para pedir la lectura, agenda astral e historial plegado. | La lectura generada usa IA, pide consentimiento y está sujeta a cupo o créditos; la información astral de contexto es otra pieza. |
| **Grimorio** `/grimorio` | Registrar una práctica y volver a ella. | Entradas de nota o ritual, documentos de sigilos y acceso a pasajes guardados de Biblioteca. | Se cifra en el dispositivo el **cuerpo** de la entrada. Título y contexto astral viajan como campos separados. |
| **Saber** `/saber` | Consultar fuentes y correspondencias. | **Plantas:** fichas de materia y filtros. **Biblioteca:** obras, índice, lector y progreso. **Sellos:** catálogo y procedencia. | Saber es una sola pestaña con tres caras. El router exige sesión para entrar, aunque algunos datos de catálogo puedan servirse públicamente desde la API. |
| **Oráculo** `/oraculo` | Tirar cartas o estudiar el mazo. | **Consultar:** tiradas; vía **Tradición** con significados del Book T o vía **Oráculo** con interpretación opcional de IA. **Aprender:** catálogo de cartas. | Ambas vías de tirada cuentan en el cupo diario; la interpretación con IA es un paso separado que pide consentimiento. |

Fuentes de las cinco filas: [router](../arcanum_app/lib/core/router/app_router.dart), [Cielo](../arcanum_app/lib/features/cielo/cielo_screen.dart), [Horóscopo](../arcanum_app/lib/features/horoscopo/horoscopo_screen.dart), [Grimorio](../arcanum_app/lib/features/grimorio/grimorio_screen.dart), [Saber](../arcanum_app/lib/features/saber/saber_screen.dart) y [Oráculo](../arcanum_app/lib/features/oraculo/oraculo_screen.dart).

## Recorridos que conectan las secciones

| Intención | Secuencia visible | Resultado y condición |
|---|---|---|
| Empezar | Registro → consentimiento y datos del onboarding → Sendero → Cielo. | Sendero guía una función cada vez; se puede rechazar el consentimiento de datos sensibles y continuar sin perfil natal. [Registro](../arcanum_app/lib/features/auth/register_screen.dart), [onboarding](../arcanum_app/lib/features/onboarding/presentation/onboarding_screen.dart), [Sendero](../arcanum_app/lib/features/sendero/presentation/sendero_screen.dart). |
| Entender el cielo personal | Cielo **Ahora** → **Tu carta** → rueda, planetas y tránsitos; Horóscopo para la lectura diaria. | El Horóscopo solicita consentimiento para IA antes de pedir el texto. [Cielo](../arcanum_app/lib/features/cielo/cielo_screen.dart), [carta natal](../arcanum_app/lib/features/cielos/cielos_screen.dart), [lectura diaria](../arcanum_app/lib/features/hoy/presentation/widgets/sky_today_card.dart). |
| Dejar memoria de una práctica | Cielo o Grimorio → nueva entrada → elegir nota/ritual y escribir título y cuerpo → guardar → abrir la entrada. | El editor cifra el cuerpo antes de llamar a la API. El tipo sigilo lleva a un taller; no se escribe como una plantilla de ritual. [Grimorio](../arcanum_app/lib/features/grimorio/grimorio_screen.dart), [editor](../arcanum_app/lib/features/grimorio/grimorio_editor.dart). |
| Leer y conservar un fragmento | Saber **Biblioteca** → obra → índice/capítulo → guardar pasaje → Grimorio **Pasajes guardados**. | El fragmento citado y su posición se guardan como datos de lectura; solo la nota personal adjunta se cifra en el cliente. [Rutas de lectura](../arcanum_app/lib/core/router/app_router.dart), [lector](../arcanum_app/lib/features/lecturas/presentation/lector_screen.dart), [repositorio](../arcanum_app/lib/features/lecturas/data/reading_repository.dart). |
| Consultar el tarot | Oráculo **Consultar** → elegir Tradición u Oráculo y tirada → sacar cartas → pedir interpretación con IA si se eligió la vía Oráculo. | Una carta está en Tradición; ambas vías tienen tres cartas y Cruz Celta. La consulta de IA requiere consentimiento y puede agotar cupo o créditos. [Oráculo](../arcanum_app/lib/features/oraculo/oraculo_screen.dart), [consentimiento](../arcanum_app/lib/core/privacy/ai_consent_service.dart). |

## Funciones transversales

- **Sendero** (`/sendero`) acompaña tareas dentro de las secciones y registra avance. **Fragmentos** (`/fragmentos`) muestra saldo y una conversión a créditos cuyos valores vienen del servidor. [Sendero](../arcanum_app/lib/features/sendero/presentation/sendero_screen.dart), [Fragmentos](../arcanum_app/lib/features/fragmentos/presentation/fragmentos_screen.dart).
- **Perfil, Ajustes, Privacidad y pagos** tienen rutas propias fuera de la barra principal. [Router](../arcanum_app/lib/core/router/app_router.dart), [cajón](../arcanum_app/lib/core/router/arcanum_drawer.dart).
- **Taller de sigilos** se abre desde Cielo o el editor del Grimorio. Sus familias y documentos guardados son parte de recorridos existentes, no una sexta sección principal. [Cielo Ahora](../arcanum_app/lib/features/hoy/hoy_screen.dart), [editor](../arcanum_app/lib/features/grimorio/grimorio_editor.dart).

## Reglas para mantener este mapa

Al cambiar una tarea, comprobar primero la ruta en `app_router.dart`, el nombre en `sections.dart`, la pantalla y el flujo de API. Corregir aquí el recorrido y su límite; después revisar [la web pública](../arcanum_app/sitio/index.html), las capturas y la guía de uso que se escriba a partir de este mapa. Las notas `ARCANUM-Avance-*` y las specs antiguas registran decisiones de su fecha; no definen por sí solas lo que la app ofrece hoy.
