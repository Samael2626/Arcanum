# Hotfix Nombre y Umbral — 2026-08-13

## Causa

Al guardar una parte del nombre, el dialogo destruia su `TextEditingController` antes de que Flutter terminara de desmontar sus dependientes. El resultado era `TextEditingController was used after being disposed` y despues la asercion de framework `_dependents.isEmpty` que mostro la pantalla roja.

## Cambio

- El dialogo ahora posee y destruye su propio controlador al desmontarse.
- Guardar ocurre despues de cerrar el dialogo; el estado visible no pasa por una carga vacia durante la escritura local cifrada.
- Se redujo el marco ornamental y el tamano de la gematria para dar prioridad a la lectura.
- El catalogo pasa de 20 a 25 fichas verificadas. Se agregan Andres, Alejandro, Felipe, Jorge y Sofia como formas griegas documentadas, sin presentarlas como nombres hebreos ni habilitar gematria historica falsa.
- Archivo muestra forma, historia y raiz documentada. Fuentes quedan en nota de archivo, no como enlaces invasivos.

## Verificacion

- `flutter analyze lib`: sin issues.
- `flutter test`: 217 pruebas verdes, incluido el flujo exacto de guardar Andres desde el dialogo y comprobar que no surge excepcion.
- `flutter build apk --debug`: verde.
- OnePlus GN2200: APK instalada, arranque limpio; cero coincidencias de `FATAL EXCEPTION`, `_dependents`, `Assertion` y `Zone mismatch` en logcat.

## Alcance y limites

- Perfil local cifrado; no se agrega cliente HTTP, analytics ni Crashlytics a este modulo.
- Gematria historica solo para escritura hebrea documentada. Las formas griegas pueden usar, si se elige, una transliteracion contemplativa ARCANUM claramente marcada.
- Se excluyen del commit los registrants, `local.properties` y residuos de build generados por Flutter/Gradle.

## Fuentes de catalogo

- SBL Greek New Testament, CC BY 4.0: forma `Ἀνδρέας`.
- LSJ / Perseus: `ἀνήρ`, `ἀλέξανδρος`, `γεωργός`, `σοφία`.
- Middle Liddell / Perseus: `φίλιππος`.
