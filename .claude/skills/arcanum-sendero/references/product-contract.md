# Contrato de producto: Sendero

## Propósito

Enseñar todas las funciones reales de ARCANUM mediante uso guiado, sin forzar al
usuario ni convertir su primera sesión en una clase larga.

**Sendero es la guía. Fragmentos Arcanos es la moneda de práctica.**
Completar cada lección vigente da 1 Fragmento, una sola vez por lección y cuenta. Después,
marcar cada carta real estudiada en Oráculo → Aprender da 1 la primera vez.
El servicio económico del backend concede ambos premios; Flutter no acuña.

## Decisiones cerradas

- Nombre visible del tutorial: **Sendero**.
- Formato: recorrido modular, práctico y progresivo.
- Libertad: saltar, pausar, cerrar, retomar y repetir en cualquier momento.
- Voz: mística, cercana y simple.
- Ritmo: orientación inicial de unos dos minutos; recorridos de uno a tres
  minutos que pueden completarse seguidos o durante varias visitas.
- Acciones: usar la app real. Si una acción consume el crédito diario, explicar
  el efecto y ejecutarla solo después de aceptación explícita.
- Persistencia: progreso por cuenta, sincronizado entre dispositivos, con caché
  local para continuar sin conexión.
- Usuarios actuales: invitación única y opcional para recordar cómo usar la app.
- Funciones nuevas: mini recorrido opcional, mostrado una sola vez y repetible.
- Premium: explicación breve orientada a despertar interés; no simular acceso ni
  convertir el recorrido en un muro de pago.
- Fragmentos Arcanos: 1 por cada lección completada por primera vez,
  más 1 por cada carta real marcada estudiada por primera vez. La revelación
  muestra el incremento confirmado por backend y el canje de 12 por crédito.

## Currículo inicial

El inventario definitivo sale del código vivo. La estructura acordada parte de:

1. Orientación: menú, áreas principales, ayudas `?`, créditos y regreso a
   Sendero.
2. Cielo y Horóscopo: carta natal, tránsitos y lectura diaria.
3. Oráculo: elegir experiencia, formular pregunta, confirmar gasto y completar
   una lectura real.
4. Grimorio: crear una entrada y comprender su protección.
5. Saber: explorar plantas y libros, leer y guardar pasajes.
6. Fragmentos Arcanos: revelar el regalo de Sendero y explicar estudio,
   acumulación y conversión con cifras del servicio canónico.
7. Cuenta: perfil, ajustes, privacidad, saldo y plan.

Antes de implementar, confrontar esta lista con rutas, capacidades y permisos
actuales. Agregar, dividir o retirar recorridos si la app real lo exige; no
prometer funciones inexistentes.

## Experiencia visual

La guía vive sobre la pantalla real. Usa foco suave sobre el control relevante,
velo oscuro tenue y una tarjeta compacta. La salida permanece visible. Las
transiciones son lentas y deliberadas, sin rebotes, pulsos agresivos ni bloqueos
artificiales.

El progreso se muestra como recorridos completados, no como obligación. Debe ser
accesible desde navegación o ajustes para continuar y repetir.

El regalo de Fragmentos Arcanos merece una revelación breve y
serena. Muestra el incremento confirmado por backend, no una animación optimista
antes de persistirlo.

## Estado conceptual

Cada recorrido necesita al menos:

- `id`: estable y no ligado al texto visible.
- `version`: incrementa cuando cambia materialmente la enseñanza.
- `status`: disponible, en progreso, completado, omitido o descartado.
- `step`: último paso confirmado.
- `completed_at`: fecha de finalización si aplica.
- `dismissed_version`: versión descartada para no insistir.

La implementación concreta se decide contra los modelos y endpoints existentes.
No crear tablas, claves ni rutas por intuición antes de auditar el repositorio.
Las reglas monetarias salen del servicio de economía, nunca de constantes del
tutorial.
