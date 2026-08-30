# Los documentos legales NO viven aqui

La fuente unica es la rama **`gh-pages`**, en la raiz del repositorio:

- `privacy-policy.md`
- `terms-of-service.md`
- `account-deletion.md`

Se edita el `.md`, se corre `construir-legales.py` y se sube. Eso es lo que
GitHub Pages sirve y lo que `ReleaseConfig` enlaza desde la app.

## Por que no hay copia aqui

El 30 de agosto de 2026 llegaron a existir **tres** juegos de textos legales:
los `.md` publicados en `gh-pages`, un `legal-site/*.html` y un `docs/*.html`,
los dos ultimos sin publicar y ya divergentes entre si y respecto al vivo.

Tres textos que dicen cosas distintas sobre los mismos datos no es redundancia:
es la infraccion. Ante una autoridad o ante app review, el que cuenta es el
publicado, y tener otros dos contradiciendolo en el repositorio solo sirve para
demostrar que no sabiamos cual regia.

Los `.html` de `assets/` que quedan aqui son de la pagina de presentacion, no de
los documentos legales.

Relacionado: `docs/ARCANUM-Data-Safety.md`, que se contrasta contra el `.md` vivo.
