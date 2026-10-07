# Lista: Taller de sigilos (`com.arcanum.magick.sigilos`)

Camino: Grimorio -> pluma (nueva entrada) -> tipo «Sigilo» -> «Abrir el taller».
Requiere sesion iniciada (la pide Samuel una vez). Todo lo que se guarde va al
Grimorio de esa cuenta EN PRODUCCION: usar intenciones de prueba («Prueba de
taller uno») y borrarlas al final si Samuel lo pide.

Lo marcado [dedo] lo juzga Samuel; lo demas, Claude con captura.

## A. Entrar y forjar
1. Abrir el taller: aparece «Escribe tu intención y pulsa «Forjar».». Captura.
2. Escribir la intencion, «Forjar»: el sigilo aparece centrado en el lienzo,
   sin texto montado ni cortado. Captura.
3. El teclado no sugiere ni corrige la intencion (intencion privada).
4. Pestañas Crear · Capas · Estilo · Guardar: todas abren, nada desborda
   (buscar franjas amarillas y negras en la captura y `overflowed` en el log).

## B. Lienzo y radial
5. Tocar una letra: radial alrededor, nombre de la letra bajo el anillo,
   botones de 48 dp sin taparse. Captura.
6. Girar +15 / reflejo / ampliar: el sigilo cambia; Deshacer lo devuelve.
7. [dedo] Arrastrar una letra: va pegada al dedo, el iman engancha con una
   vibracion corta.
8. [dedo] Pellizco con dos dedos sobre una letra: escala y gira; no pierde la
   seleccion.
9. Boton +: el abanico cabe entero en el lienzo, etiquetas legibles. Captura.
10. Girar el telefono a horizontal: lienzo a la izquierda, hoja a la derecha,
    radial sin salirse. Captura. Volver a vertical.

## C. Capas y privacidad
11. Añadir Anillo, Inscripcion y Rotulo: el texto por defecto son las LETRAS
    del sigilo (p. ej. «M P E S»), NUNCA la intencion. Captura. **Si aparece
    la intencion: hallazgo grave (a).**
12. Simbolo: elegir uno y tocar el lienzo; queda donde se toco.

## D. Estilo
13. Cambiar preset (Oro, Lacre...) y Caligrafia Recta/Curva/Pluma.
14. Con Pluma, arrastrar una letra: la tinta se mueve con ella (no se queda
    el dibujo viejo detras). Captura durante y despues.

## E. Guardar, cargar, soltar
15. Guardar -> «Guardar en el Grimorio»: aviso «Sigilo guardado…».
16. Volver al Grimorio: la entrada se llama «Sigilo del D de mes» (sin la
    intencion) y lleva la MINIATURA del sigilo en lugar de la capitular.
    Captura. Si sale la capitular: mirar el log (`miniatura`).
17. Abrir la entrada: sigilo dibujado; la intencion oculta hasta «Ver la
    intención».
18. «Cargar» -> 30 s -> fila de chips y «Empezar» caben a 390 de ancho.
    [dedo] la respiracion (4-4-4-4) se sigue con comodidad.
19. «Anotar»: el detalle muestra «Cargado 1 vez» con fecha, segundos, luna y
    hora.
20. «Cargar» otra vez -> «Olvidar»: aviso «¿Soltar el sigilo?» con el texto de
    que la intencion se borra para siempre. «Volver» no cambia nada.
21. Repetir y «Soltar»: el detalle dice «Soltado el …», sin «Ver la
    intención», sin «Cargar» ni «Seguir en el taller»; el dibujo sigue igual
    que antes. La miniatura de la lista tambien sigue.

## F. Compartir
22. «Imagen (PNG)» y «Vector (SVG)»: se abre el panel de compartir. Guardar el
    SVG en el telefono, sacarlo con `adb pull` y abrirlo en el navegador del
    PC: el texto de anillos y rotulo se ve en Crimson Pro (trazos), igual que
    en la app, sin `<text>` salvo el separador ✠ (sin fuente empaquetada,
    conocido).

## G. Salir sin guardar
23. Cambiar algo y cerrar con la X: «¿Salir sin guardar?». «Seguir aquí»
    mantiene el cambio.

## Conocido (no reportar como nuevo)
- ✠ del anillo sale con la fuente del sistema.
- En Cielos y Lecturas el `_retry` con flecha solo avisa en depuracion; en
  profile no se ve.
