---
name: arcanum-depuracion
description: "Depuracion del codigo de ARCANUM: audita codigo muerto, obsoleto, con fallos conocidos o innecesario (app Flutter, paquetes y API), entrega un informe con evidencia y confianza por modulo, y limpia por lotes con tests verdes y el OK de Samuel. Activar cuando Samuel diga \"depura\", \"limpia el codigo\", \"codigo muerto\", \"que sobra\", \"codigo obsoleto\", \"deuda tecnica\", \"auditoria de codigo\", o antes de una release para ver que se puede quitar. No sustituye a code-review (busca fallos en un diff) ni a los gates."
---

# Depuracion de ARCANUM

Tres fases. Nunca se borra nada en la primera.

## 1. Auditar (solo lee)

```
python .claude/skills/arcanum-depuracion/scripts/auditar.py --salida D:/tmp/depuracion/auditoria.md
```

Desde la raiz de un worktree en `main` al dia. Necesita `uvx` (ruff y vulture
se bajan solos, sin instalar nada global). Busca:

| Tipo | Que | Como |
|---|---|---|
| muerto | ficheros Dart que nadie importa; imports y variables sin uso en la API | grafo de imports desde `lib/main.dart`; vulture; ruff F401/F841 |
| fallo | patrones de fallo ya vistos en ARCANUM; tests sin comprobaciones | regex (`setState(() => _f = load())`, `selectionClick`, `except: pass`...); ruff B006/B904/F811 |
| obsoleto | modelos y SDK retirados en codigo vivo; TODO de mas de 30 dias; tests saltados; carpetas sin tocar en 45 dias | regex fuera de comentarios; `git blame` |
| innecesario | dependencias sin importar; assets que nadie nombra; scripts dentro de `assets/` | pubspec frente a imports; manifiestos JSON |

Cada hallazgo lleva **evidencia** y **confianza** (alta: comprobado
mecanicamente; media: muy probable; baja: pista).

### Falsos positivos ya conocidos (el script los filtra)
- Assets por nombre compuesto (`assets/tarot/$slug.webp`) o por `manifest.json`.
- `test/capturas/`: generan imagenes, no afirman nada a proposito.
- Imports en `__init__.py`: registran modelos de SQLAlchemy.
- Menciones en comentarios o docstrings: suelen ser historia, no uso.

Si aparece otro falso positivo, **se arregla el script** (con su motivo) antes
de seguir: un informe que miente una vez deja de leerse.

## 2. Verificar y presentar

- Mirar a mano TODO lo de confianza alta antes de proponerlo. Lo que resulte
  falso positivo -> al script.
- Para cada fichero que se quiera borrar: `git log --all --oneline -- <ruta>`
  y comprobar que **ninguna rama abierta** lo toca (si no, borrarlo en `main`
  le genera conflictos a otra sesion).
- Entregar a Samuel el informe agrupado en **lotes por modulo**, con lo que se
  gana (lineas, peso, riesgo que desaparece).

## 3. Limpiar por lotes

Un lote = un modulo o un tipo. Por cada lote, con el OK de Samuel:

1. Rama propia desde `main`.
2. Aplicar. Un fallo real se arregla con su test de regresion.
3. Gates: `flutter analyze` + `flutter test --concurrency=4`; si toca API,
   pytest con las dos bases y `ARCANUM_DATA_DIR`.
4. Commit en espanol sin acentos, `git commit -- <rutas>` (indice compartido
   con otras sesiones).
5. A `main` solo con los gates en verde: **cada push a main despliega
   Railway**.

## Reglas

- **Una sesion, un frente.** Si el lote cae en un modulo que otra sesion esta
  moviendo (mesa, oraculo, sendero...), no se toca: se entrega como prompt.
- No se borra codigo de una rama ajena ni se reescribe su historia.
- Datos sensibles que aparezcan (volcados de produccion, claves, `.env`): se
  avisa a Samuel y no se mueven ni se suben.
- Codigo comentado que documenta una decision (por que NO se hace algo) no es
  basura: se queda.
