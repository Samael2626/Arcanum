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
import io
import math
import pathlib

from PIL import Image, ImageDraw, ImageFont

RAIZ = pathlib.Path(__file__).resolve().parent.parent
SALIDA = RAIZ / "build" / "ficha"
CAPTURAS = RAIZ / "test" / "capturas" / "salida"

# La paleta sale de lib/core/theme/arcanum_colors.dart, no de un ojimetro.
FONDO = (0x0A, 0x0A, 0x0F)
SUPERFICIE = (0x12, 0x12, 0x1A)
ORO = (0xC9, 0xA8, 0x4C)
ORO_APAGADO = (0x8A, 0x6E, 0x32)
BURDEOS = (0x4A, 0x0E, 0x1A)
MARFIL = (0xF5, 0xF0, 0xE8)
MARFIL_APAGADO = (0xB8, 0xB0, 0xA0)

DISPLAY = RAIZ / "assets" / "fonts" / "CormorantGaramond-600.ttf"
CUERPO = RAIZ / "assets" / "fonts" / "CrimsonPro-400.ttf"


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


def texto_centrado(d, cy, texto, fuente, color, espaciado=0):
    """Dibuja centrado en horizontal, con espaciado entre letras opcional.

    PIL no sabe de letter-spacing, asi que se dibuja letra a letra. Hay que medir
    el total antes para poder centrar.
    """
    anchos = [d.textlength(c, font=fuente) for c in texto]
    total = sum(anchos) + espaciado * (len(texto) - 1)
    x = (d.im.size[0] - total) / 2
    for c, w in zip(texto, anchos):
        d.text((x, cy), c, font=fuente, fill=color, anchor="lm")
        x += w + espaciado


def rueda(d, cx, cy, radio, color, alfa, marcas=36):
    """El instrumento de la app: circulos concentricos y marcas radiales."""
    c = color + (alfa,)
    for r in (radio, radio * 0.72, radio * 0.44):
        d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=c, width=2)
    for i in range(marcas):
        a = 2 * math.pi * i / marcas
        largo = radio * (0.94 if i % 3 else 0.88)
        d.line(
            [cx + radio * math.cos(a), cy + radio * math.sin(a),
             cx + largo * math.cos(a), cy + largo * math.sin(a)],
            fill=c, width=2,
        )


def resplandor(img, cx, cy, radio, color, fuerza):
    """Halo radial suave. Se pinta en una capa aparte y se compone."""
    capa = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(capa)
    pasos = 48
    for i in range(pasos, 0, -1):
        r = radio * i / pasos
        a = int(fuerza * (1 - i / pasos) ** 2)
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=color + (a,))
    return Image.alpha_composite(img.convert("RGBA"), capa)


def grafico_destacado():
    """El 1024x500 de la cabecera de la ficha.

    Poco texto a proposito: Play lo recorta en varios tamanos segun donde
    aparezca, y lo unico que sobrevive siempre es el centro.
    """
    W, H = 1024, 500
    img = Image.new("RGBA", (W, H), FONDO + (255,))

    img = resplandor(img, W * 0.30, H * 0.5, 520, SUPERFICIE, 200)
    img = resplandor(img, W * 0.88, H * 0.30, 300, BURDEOS, 120)

    capa = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(capa)
    # Las ruedas viven en los margenes: si cruzan el logotipo, compiten con el.
    rueda(d, W * 0.90, H * 0.26, 175, ORO, 62)
    rueda(d, W * 0.09, H * 0.74, 120, ORO_APAGADO, 42, marcas=24)
    img = Image.alpha_composite(img, capa)

    d = ImageDraw.Draw(img)
    f_titulo = ImageFont.truetype(str(DISPLAY), 100)
    f_lema = ImageFont.truetype(str(CUERPO), 33)

    texto_centrado(d, H * 0.42, "ARCANUM", f_titulo, ORO + (255,), espaciado=14)

    y = H * 0.58
    d.line([W * 0.38, y, W * 0.62, y], fill=ORO_APAGADO + (200,), width=2)

    texto_centrado(d, H * 0.70, "Tarot, astrología y grimorio cifrado",
                   f_lema, MARFIL_APAGADO + (255,), espaciado=1)

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
