# -*- coding: utf-8 -*-
"""Genera el material grafico de la ficha de Google Play.

Play no acepta cualquier PNG. Lo verificado en su propia documentacion:

    icono      512x512   PNG 32-bit CON alfa
    grafico    1024x500  JPEG o PNG 24-bit SIN alfa
    capturas   min 320, max 3840, PNG 24-bit SIN alfa
               y el lado mayor NO puede pasar del doble del menor

Esa ultima regla es la que descarta el formato de movil moderno: 390x844 tiene
844 > 2*390 y Play lo rechaza. Por eso el capturador retrata a 1080x1920.

Uso:  python tool/generar_material_ficha.py
Sale: build/ficha/
"""
import pathlib

from PIL import Image

RAIZ = pathlib.Path(__file__).resolve().parent.parent
SALIDA = RAIZ / "build" / "ficha"
CAPTURAS = RAIZ / "test" / "capturas" / "salida"
ORIGEN_DESTACADO = RAIZ / "tool" / "ficha" / "grafico-destacado-1024x500.png"

# Unico color que queda: el fondo del tema, contra el que se aplana el alfa.
FONDO = (0x0A, 0x0A, 0x0F)


def sin_alfa(img, fondo=FONDO):
    """Aplana sobre el fondo del tema y devuelve RGB de 24 bits.

    Descartar el canal alfa a secas deja halos claros donde habia semitransparencia.
    Componer contra el fondo real es lo que conserva el aspecto.
    """
    if img.mode == "RGB":
        return img
    plano = Image.new("RGB", img.size, fondo)
    plano.paste(img, mask=img.convert("RGBA").split()[3])
    return plano


def grafico_destacado():
    """El 1024x500 de la cabecera de la ficha.

    Ya no se dibuja aqui. El arte definitivo es el sello del astrolabio con el
    color realzado del icono del lanzador, sobre orbitas y campo de estrellas;
    sale del generador vectorial y vive versionado en tool/ficha/. Redibujarlo
    con PIL solo servia para tener dos graficos distintos peleandose.
    """
    origen = ORIGEN_DESTACADO
    if not origen.exists():
        raise SystemExit(f"Falta el arte del grafico destacado: {origen}")
    img = Image.open(origen)
    if img.size != (1024, 500):
        raise SystemExit(f"Play exige 1024x500 y el arte mide {img.size[0]}x{img.size[1]}")
    return sin_alfa(img)


def icono():
    """El 512x512 de la ficha, en RGBA porque Play pide 32 bits."""
    origen = RAIZ / "web" / "icons" / "Icon-512.png"
    img = Image.open(origen).convert("RGBA")
    if img.size != (512, 512):
        img = img.resize((512, 512), Image.LANCZOS)
    return img


def main():
    SALIDA.mkdir(parents=True, exist_ok=True)

    ico = icono()
    ico.save(SALIDA / "icono-512.png")
    print(f"  icono-512.png            {ico.size[0]}x{ico.size[1]}  RGBA")

    graf = grafico_destacado()
    graf.save(SALIDA / "grafico-destacado-1024x500.png")
    print(f"  grafico-destacado…png    {graf.size[0]}x{graf.size[1]}  RGB")

    destino = SALIDA / "capturas"
    destino.mkdir(exist_ok=True)
    for p in sorted(CAPTURAS.glob("*.png")):
        img = sin_alfa(Image.open(p))
        w, h = img.size
        if max(w, h) > 2 * min(w, h):
            raise SystemExit(
                f"{p.name}: {w}x{h} incumple la regla del doble de Play"
            )
        img.save(destino / p.name)
        print(f"  capturas/{p.name:24} {w}x{h}  RGB")


if __name__ == "__main__":
    main()
