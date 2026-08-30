# -*- coding: utf-8 -*-
"""Genera las paginas .html de los documentos legales a partir de los .md.

POR QUE EXISTE ESTO
-------------------
Los tres documentos vivian solo como .md y las URLs declaradas apuntaban a
.html. GitHub Pages usa Jekyll, y **Jekyll solo convierte a .html los Markdown
que llevan front matter YAML**. Estos no lo llevaban, asi que los copiaba tal
cual: en el servidor existia /privacy-policy.md y /privacy-policy.html daba 404.

El 404 no se noto porque nadie abrio las URLs: el indice enlazaba a los .html y
tambien estaba roto.

La salida son .html de verdad, generados aqui. Asi la pagina no depende de que
Jekyll haga nada, que es una pieza movil menos entre nosotros y un campo
obligatorio de la ficha de Play.

EL .md SIGUE SIENDO LA FUENTE
-----------------------------
Se edita el .md y se corre este script. Nunca al reves. Dos copias editables de
una politica legal es una que miente.

Uso:  python construir-legales.py
      python construir-legales.py --comprobar   (no escribe; falla si hay desfase)
"""
import io
import os
import sys

import markdown

# Paleta de lib/core/theme/arcanum_colors.dart, la misma que index.html. Estas
# paginas se abren desde la ficha de Play: tienen que parecer el mismo producto.
PALETA = """
  :root{
    --fondo:#0a0a0f; --panel:#12121a; --borde:#26263a;
    --tinta:#e8e3d9; --tinta-suave:#a9a496; --oro:#c9a84c; --oro-apagado:#8a6e32;
  }
  *{box-sizing:border-box}
  body{
    margin:0; background:var(--fondo); color:var(--tinta);
    font:16px/1.75 Georgia,"Times New Roman",serif;
  }
  .barra{
    border-bottom:1px solid var(--borde); padding:1.1rem 1.25rem;
    font-family:system-ui,sans-serif; font-size:.82rem; letter-spacing:.2em;
    text-transform:uppercase;
  }
  .barra a{color:var(--oro); text-decoration:none}
  .barra a:hover,.barra a:focus{text-decoration:underline; outline:none}
  main{max-width:42rem; margin:0 auto; padding:2.5rem 1.25rem 4rem}
  h1{
    font-size:2rem; font-weight:400; color:var(--oro); margin:0 0 1.5rem;
    line-height:1.25; text-wrap:balance;
  }
  h2{
    font-size:1.25rem; font-weight:400; color:var(--oro); margin:2.6rem 0 .9rem;
    padding-top:1.4rem; border-top:1px solid var(--borde); text-wrap:balance;
  }
  h3{font-size:1.02rem; font-weight:400; color:var(--tinta); margin:1.8rem 0 .6rem}
  p{margin:0 0 1rem}
  ul,ol{padding-left:1.3rem; margin:0 0 1rem}
  li{margin:.4rem 0}
  strong{color:#fff; font-weight:400}
  a{color:var(--oro)}
  hr{border:0; border-top:1px solid var(--borde); margin:2.2rem 0}
  blockquote{
    margin:1.4rem 0; padding:.9rem 1.2rem; background:var(--panel);
    border-left:2px solid var(--oro-apagado); color:var(--tinta-suave);
  }
  blockquote p:last-child{margin:0}
  /* Las tablas se desbordan en movil si no se les da su propio scroll. El
     cuerpo de la pagina no debe moverse en horizontal nunca. */
  .tabla{overflow-x:auto; margin:0 0 1.4rem}
  table{border-collapse:collapse; width:100%; font-size:.94rem}
  th,td{
    border:1px solid var(--borde); padding:.55rem .8rem; text-align:left;
    vertical-align:top;
  }
  th{background:var(--panel); color:var(--oro-apagado); font-weight:400}
  code{
    background:var(--panel); border:1px solid var(--borde); border-radius:3px;
    padding:.1rem .35rem; font-size:.9em;
  }
  footer{
    max-width:42rem; margin:0 auto; padding:0 1.25rem 4rem;
    border-top:1px solid var(--borde); padding-top:1.5rem;
    color:var(--tinta-suave); font-size:.85rem; font-family:system-ui,sans-serif;
  }
  footer a{color:var(--oro-apagado)}
"""

PLANTILLA = """<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{titulo}</title>
<meta name="description" content="{descripcion}">
<style>{paleta}</style>
</head>
<body>

<div class="barra"><a href="./">&#8592; ARCANUM &#183; Documentos legales</a></div>

<main>
{cuerpo}
</main>

<footer>
  ARCANUM &#183; Samuel Andr&eacute;s Escobar Saldarriaga &#183; Colombia<br>
  Contacto: <a href="mailto:arcanum.magick.app@gmail.com">arcanum.magick.app@gmail.com</a>
</footer>

</body>
</html>
"""

DOCUMENTOS = [
    ("privacy-policy",
     "Política de privacidad — ARCANUM",
     "Qué datos recoge ARCANUM, para qué, con quién se comparten y qué está cifrado."),
    ("terms-of-service",
     "Términos de servicio — ARCANUM",
     "Condiciones de uso de ARCANUM, suscripciones y límites del plan gratuito."),
    ("account-deletion",
     "Eliminar tu cuenta — ARCANUM",
     "Cómo borrar tu cuenta de ARCANUM desde la App o sin tenerla instalada."),
]


def render(ruta_md):
    texto = io.open(ruta_md, encoding="utf-8").read()
    cuerpo = markdown.markdown(
        texto,
        extensions=["tables", "sane_lists", "attr_list"],
        output_format="html5",
    )
    # Cada tabla dentro de su propio contenedor con scroll. Sin esto, una tabla
    # ancha empuja el body entero y la pagina se lee de lado en movil.
    cuerpo = cuerpo.replace("<table>", '<div class="tabla"><table>')
    cuerpo = cuerpo.replace("</table>", "</table></div>")
    return cuerpo


def construir(base, titulo, descripcion):
    cuerpo = render(base + ".md")
    return PLANTILLA.format(
        titulo=titulo, descripcion=descripcion,
        paleta=PALETA, cuerpo=cuerpo,
    )


# Rutas cortas que apuntan al MISMO .md. Existen porque las fichas de tienda y
# los enlaces ya repartidos usan nombres distintos para el mismo documento, y
# una URL legal que devuelve 404 es motivo de rechazo. Se generan como paginas
# completas, no como redirecciones: los bots de app review no siempre siguen un
# redirect, y aqui no se puede permitir un "quiza".
#
# La fuente sigue siendo una sola: si dos rutas se desincronizan es porque
# alguien edito el .html a mano, que es justo lo que este script impide.
SALTO = chr(10)

ALIAS = {
    "terms": "terms-of-service",
    "privacy": "privacy-policy",
}


def main():
    comprobar = "--comprobar" in sys.argv
    desfase = []
    for base, titulo, descripcion in DOCUMENTOS:
        if not os.path.exists(base + ".md"):
            print("FALTA la fuente: " + base + ".md")
            return 1
        html = construir(base, titulo, descripcion)
        destino = base + ".html"
        actual = io.open(destino, encoding="utf-8").read() if os.path.exists(destino) else None
        if comprobar:
            estado = "al dia" if actual == html else "DESFASADO"
            if actual != html:
                desfase.append(destino)
            print("{:26} {}".format(destino, estado))
        else:
            io.open(destino, "w", encoding="utf-8", newline="\n").write(html)
            print("{:26} {:6} bytes".format(destino, len(html)))

    for alias, base in sorted(ALIAS.items()):
        titulo, descripcion = next(
            (t, d) for b, t, d in DOCUMENTOS if b == base
        )
        html = construir(base, titulo, descripcion)
        destino = alias + ".html"
        actual = io.open(destino, encoding="utf-8").read() if os.path.exists(destino) else None
        if comprobar:
            if actual != html:
                desfase.append(destino)
            print("{:26} {}".format(destino, "al dia" if actual == html else "DESFASADO"))
        else:
            io.open(destino, "w", encoding="utf-8", newline=SALTO).write(html)
            print("{:26} {:6} bytes  (alias de {}.md)".format(destino, len(html), base))

    if comprobar and desfase:
        print("\nHay .html desfasados respecto a su .md. Corre el script sin "
              "--comprobar.")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
