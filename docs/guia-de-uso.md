# Guía de uso de ARCANUM

Revisión: 2026-10-08. Público: equipo, testers y personas que ayudan a usar la app. Los pasos se contrastaron con rutas, pantallas y llamadas actuales; falta recorrerlos de punta a punta en un dispositivo Android. La prueba cerrada puede cambiar los textos y la disponibilidad.

## Antes de empezar

Necesitas acceso a la prueba cerrada, conexión para crear la cuenta y una sesión iniciada para entrar a las cinco secciones. La app abre **Cielo** y, si falta sesión, lleva a **Entrar**. La barra inferior contiene Cielo, Horóscopo, Grimorio, Saber y Oráculo. [Router](../arcanum_app/lib/core/router/app_router.dart), [secciones](../arcanum_app/lib/core/content/sections.dart).

## 1. Entrar y preparar la app

1. En **Entrar**, escribe correo y contraseña. Si aún no tienes cuenta, toca **¿Aún no tienes cuenta? Regístrate**, completa ambos campos y toca **Crear cuenta**.
2. Tras el registro aparece el onboarding. Lee **Tus datos sensibles** y elige **Acepto compartirlos** para continuar con nombre, fecha, hora y lugar de nacimiento, o **Continuar sin datos sensibles** para terminar sin esa información.
3. Al acabar se abre **Sendero**. En la primera visita sin progreso, Sendero inicia una orientación y lleva a Cielo. También puedes salir a Cielo desde Sendero.

**Si falta algo:** sin datos natales, **Tu carta** muestra **Aún no hay carta que trazar** y ofrece **Completar mi nacimiento**. El lugar de nacimiento es distinto del lugar donde vives ahora. El rechazo de datos sensibles no impide terminar el onboarding. [Acceso](../arcanum_app/lib/features/auth/login_screen.dart), [registro](../arcanum_app/lib/features/auth/register_screen.dart), [onboarding](../arcanum_app/lib/features/onboarding/presentation/onboarding_screen.dart), [Sendero](../arcanum_app/lib/features/sendero/presentation/sendero_screen.dart), [estado sin carta](../arcanum_app/lib/features/cielos/cielos_screen.dart).

## 2. Consultar el cielo y el Horóscopo

1. Abre **Cielo**. En **Ahora** mira el regente, la hora planetaria y la Luna. Desde sus enlaces puedes pasar a plantas, una fuente de Biblioteca, tu carta, el Oráculo o una entrada de Grimorio cuando el contenido lo ofrezca.
2. Cambia a **Tu carta** para ver la rueda natal, los planetas, los ángulos y los tránsitos de hoy sobre tu carta. Si falta tu nacimiento, usa **Completar mi nacimiento**.
3. Abre **Horóscopo** desde la barra inferior. Toca el sello de la lectura diaria. Antes de pedir el texto a la IA, la app solicita consentimiento y puede mostrar una confirmación de gasto de Sendero. Debajo están la agenda astral y el historial.

**Resultado:** el Horóscopo presenta una interpretación simbólica del día vinculada a la carta. Si rechazas el consentimiento, no se envía la consulta de IA. La generación depende del cupo, créditos y disponibilidad del proveedor; la agenda y otros datos astrales se presentan por separado. [Cielo](../arcanum_app/lib/features/cielo/cielo_screen.dart), [Ahora](../arcanum_app/lib/features/hoy/hoy_screen.dart), [Tu carta](../arcanum_app/lib/features/cielos/cielos_screen.dart), [Horóscopo](../arcanum_app/lib/features/horoscopo/horoscopo_screen.dart), [lectura diaria](../arcanum_app/lib/features/hoy/presentation/widgets/sky_today_card.dart).

## 3. Registrar una práctica en el Grimorio

1. Abre **Grimorio** y toca el botón con la pluma. También puedes llegar desde **Anota** en Cielo.
2. En **Nueva entrada**, elige **Nota**, **Ritual** o **Lectura**. Escribe **Título** y el cuerpo de la entrada.
3. Toca **Sellar entrada**. Al terminar, la entrada aparece en el Grimorio; tócala para leerla. **Sigilo** abre las opciones del Taller, donde se crea y guarda el documento correspondiente.

**Si falta algo:** el editor pide título y contenido. Si falla el guardado, muestra un error y conserva la pantalla para intentar de nuevo. El cuerpo se cifra en el dispositivo antes de enviarse; el título y los datos de contexto astral se guardan como campos separados. **Pasajes guardados** está en Grimorio y corresponde al recorrido de Biblioteca de abajo. [Grimorio](../arcanum_app/lib/features/grimorio/grimorio_screen.dart), [editor](../arcanum_app/lib/features/grimorio/grimorio_editor.dart), [cifrado](../arcanum_app/lib/core/crypto/grimoire_crypto.dart).

## 4. Leer una obra y guardar un pasaje

1. Abre **Saber** y cambia a **Biblioteca**. Elige una obra. En su portada, toca **Comenzar lectura** o **Reanudar lectura**; también puedes abrir **Índice** y elegir un capítulo.
2. En el lector, mantén pulsado un párrafo. En **Este pasaje**, elige **Guardar en el grimorio**.
3. En **Guardar pasaje**, añade **Tu nota (opcional)** si quieres y toca **Guardar**. La app confirma **Pasaje guardado en el grimorio**; si ya existía, lo indica.
4. Para volver al fragmento, abre **Grimorio → Pasajes guardados** y toca el pasaje. El lector abre la posición guardada. Allí puedes añadir o editar la nota, o eliminar el pasaje.

**Dato importante:** el texto citado y la posición se guardan como datos de lectura. Solo la nota personal adjunta se cifra en el dispositivo; si esa clave no está disponible en otro dispositivo, la nota puede figurar como ilegible. Saber exige sesión en la app. [Saber](../arcanum_app/lib/features/saber/saber_screen.dart), [portada](../arcanum_app/lib/features/lecturas/presentation/obra_screen.dart), [lector](../arcanum_app/lib/features/lecturas/presentation/lector_screen.dart), [pasajes](../arcanum_app/lib/features/grimorio/pasajes_screen.dart), [datos y cifrado](../arcanum_app/lib/features/lecturas/data/reading_repository.dart).

## 5. Consultar o estudiar el tarot

1. Abre **Oráculo**. Usa **Aprender** para recorrer el mazo sin hacer una tirada. Para una consulta, entra en **Consultar**.
2. Elige quién interpreta: **Tradición** devuelve el significado según Book T sin IA; **Oráculo** permite pedir una interpretación con IA después de sacar las cartas.
3. Selecciona la tirada. **Tradición** ofrece **Una carta**, **Tres cartas** y **Cruz Celta**; **Oráculo** ofrece las dos últimas. Puedes escribir una pregunta, pero es opcional.
4. Toca **Sacar una carta**, **Tirar las cartas** o **Consultar al oráculo**, según la elección. Abre las cartas para verlas. Si elegiste **Oráculo**, toca **Pedir interpretación** cuando aparezca y acepta el consentimiento de IA para enviar la consulta.

**Coste y límites:** las dos vías de tirada cuentan en el cupo diario; **sin IA** no significa gratis. La interpretación con IA es una acción adicional, su precio se muestra antes de pedirla y puede requerir créditos. Los límites y el saldo se consultan al servidor. Si no autorizas la IA, puedes seguir usando la vía Tradición. [Oráculo](../arcanum_app/lib/features/oraculo/oraculo_screen.dart), [consentimiento de IA](../arcanum_app/lib/core/privacy/ai_consent_service.dart).

## Revisión en dispositivo pendiente

Recorrer los cinco caminos en una build de Android de la prueba cerrada con una cuenta de prueba y sin datos personales reales. Registrar para cada paso el texto visible, la ruta alcanzada, cualquier bloqueo y una captura solo si ayuda a corregir la guía. Verificar al menos: primera cuenta con consentimiento aceptado y rechazado; carta sin datos natales; Grimorio con error de red; pasaje con y sin nota; Oráculo por Tradición y por IA sin consentimiento, con consentimiento y sin saldo. No usar una prueba de widget como evidencia de que todo el recorrido funcionó en el teléfono.

Al cambiar una pantalla o su límite, actualizar esta guía y el [mapa de producto](producto.md) en el mismo cambio; si afecta promesas públicas, revisar también [la web](../arcanum_app/sitio/index.html).
