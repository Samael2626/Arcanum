# Informe: Taller de Sigilos de ARCANUM

Fecha: 2 de octubre de 2026
Rama: `feature/taller-sigilos`, punta `c46104e` (11 commits y 103 archivos por delante de `main`).
Fuentes: `Sigilos-Taller-v3.md` (vault, 30-sep) y verificación del 2-oct contra el remoto.

## 0. Correcciones respecto a la versión anterior de este informe

| Dato anterior | Dato verificado |
|---|---|
| Head `2fc797d`, merge de `release/1.0.6` | Ese commit no existe. La punta es `c46104e`. |
| Salida en la 1.0.7 | El tag `v1.0.7+15` ya existe y NO incluye el taller. La salida pasa a la siguiente release. |
| Gate: 229 checks | 240 checks, 0 FAIL (corrido el 2-oct). |
| Fuzz semilla 21, n=40 | Corrido con n=150, 0 fallos. |
| Pruebas Dart (337 tests) y suite de 976 | NO verificadas el 2-oct: el entorno de revisión no tiene Flutter. Son cifras del 30-sep. |
| Promesa de los Términos «ya no es cierta en la rama» | La rama no está en `main`; `legal-site/index.html` sigue anunciando «Generador de sigilos» como P2. |
| `local.properties` y `devtools_options.yaml` sin trackear | Estado de la máquina local; no se pudo comprobar desde el remoto. |

## 1. Qué es

Módulo que convierte una intención escrita en un glifo personal con método trazable a fuentes históricas, sin IA (decisión del 28-sep). Las letras del usuario son el material del signo; no es un generador de mandalas.

## 2. Estado

### Prototipo JS (`arcanum-sigil-prototype/`, fuente de verdad)
- Motor de letras: reducción en 3 modos, gemelas por geometría, alfabeto A–Z de trazo único, composición Fusión / Bloque / Cruz, 13 remates, edición por letra, legibilidad %.
- Familias: Rosa-Cruz v2 (manuscrito F de Mathers), Kamea (7 tablas de Agrippa 1651, 3 erratas declaradas), Sello personal, Sello histórico (23 piezas de Agrippa + 80 sellos de la Goetia 1916, dominio público) y Comparar.
- Capas (9 tipos, anidado, guías con imán), 7 estilos + 7 relampagueantes, galería, deshacer/rehacer, UI móvil primero, todo en español.

### Migración a Flutter
- Paquete `arcanum_app/packages/arcanum_sigilos` con paridad por fixtures contra el prototipo (letras, capas, escena/estilo, pintor propio, interacción).
- App de prueba `prototipos/taller_lienzo`, medida en un GN2200 real a 60 Hz.
- Taller dentro del Grimorio (tipo «Sigilo»), guardado cifrado por el PUT existente, carga 4-4-4-4 con Olvidar/Guardar, intención oculta, pellizco, vibración y lector de pantalla.
- En v1 solo entran letras, capas, estilo, carga y guardado.

## 3. Pruebas

Verificadas el 2-oct sobre `origin/feature/taller-sigilos`:

| Batería | Resultado |
|---|---|
| `_gate.mjs` | 240 checks, 0 FAIL |
| `_edge.mjs` | 17 checks, 0 FAIL |
| `_fuzz.mjs` semilla 21, n=150 | 0 fallos |

Para correrlas en el entorno de revisión hubo que apuntar `chromium.launch` a un Chromium local; ese ajuste no está en el repo.

Declaradas, no reverificadas el 2-oct (sin Flutter): 337 tests de taller+grimorio, paridad de 52 SVG, pintor frente a Chromium (peor caso 0,029 %), interacción (316 puntos + 10 gestos), suite de la app 976 tests (30-sep). La matriz física (5 estilos × 3 pilas) bajó los frames fuera de presupuesto de 17–32 % a 0–2,1 % (peor caso 5,3 %).

## 4. Pendiente

Antes de salir:
1. QA en vivo en la app de depuración (`com.arcanum.magick`).
2. Medición a 90 Hz y arrastre con dedo real.
3. Relanzar la suite completa con las dos bases de test conectadas (si salen ~172 saltados, el verde no vale).
4. Merge a `main` y release posterior a la 1.0.7. Ojo: `main` despliega solo a producción.
5. Cerrar la promesa de los Términos: mergear el taller o quitar la tarjeta P2 de `legal-site/index.html`.

v2:
6. Rosa-Cruz, Kamea, Sello personal y Comparar en Flutter, conservando la etiqueta de «hipótesis» en el lazo y el recorrido de casillas.
7. Catálogo histórico a Materia/Saber.
8. Ciclo crear → cargar → olvidar → anotar con Hoy, Grimorio y Bitácora.
9. Estilización caligráfica como capa opcional.

Menores: codificación corrupta de `Sigilos-Taller-v2.md`; cita de Cooper mal asignada por el conector NotebookLM.

## 5. Veredicto

El motor está maduro en prototipo y con pruebas que hoy pasan limpias. La migración a Dart completó las 4 etapas según el registro del 30-sep. Lo que separa el taller de una release es QA en dispositivo, 90 Hz, la suite completa y el merge. La v2 y el catálogo en Materia pueden ir después sin bloquear.
