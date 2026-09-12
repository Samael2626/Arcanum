#!/usr/bin/env python3
"""Recorre ARCANUM en un aparato de verdad y retrata cada parada.

POR QUE EXISTE
--------------
Los tests de widget y las capturas de `test/capturas/` prueban piezas sueltas
con datos falsos. Hay una clase de fallo que solo aparece con la app entera,
la cuenta real y el dedo: contenido duplicado entre pestanas, estado que no se
comparte, cabeceras que se apilan. Los dos recorridos de septiembre de 2026
sacaron cinco fallos asi, y ninguno lo veia la suite.

Esto automatiza ese recorrido para no volver a improvisarlo: toca, espera,
captura, y al final imprime QUE hay que comparar en las fotos. No afirma nada
por su cuenta -- las conclusiones las saca quien las mira.

REQUISITOS
----------
  - Un aparato conectado (`adb devices`) CON SESION INICIADA. Sin sesion la
    guarda del router manda todo a /login y no hay nada que recorrer.
  - La build que se quiere probar, instalada.

COMO SE INSTALA SIN PERDER LA SESION
------------------------------------
    flutter build apk --release --dart-define=REVENUECAT_API_KEY=<clave>
    adb install -r build/app/outputs/flutter-apk/app-release.apk

`flutter install` NO sirve: desinstala la version anterior antes de poner la
nueva -- lo dice en su salida, "Uninstalling old version..." -- y con ella se
va `flutter_secure_storage`, donde vive el token. Ya paso una vez.

USO
---
    python tools/recorrido_app.py                # recorrido entero
    python tools/recorrido_app.py --solo cielo   # solo las paradas que casen

Las capturas van a `docs/recorridos/<fecha>/`. Las de un recorrido anterior no
se borran: comparar el de hoy con el de ayer es la mitad de la gracia.

PRIVACIDAD
----------
Una captura de pantalla se lleva lo que haya encima, incluidas notificaciones
con mensajes personales. Si sale una, se borra el fichero y no se describe.
El script avisa de esto al terminar; revisar antes de pegar nada en ningun
sitio.

PARA ANADIR UNA PARADA
----------------------
Una entrada mas en `PARADAS`. Los toques van en fracciones del ancho y el alto
(0.0 a 1.0), no en pixeles, para que valga en cualquier pantalla.
"""
from __future__ import annotations

import argparse
import datetime as dt
import pathlib
import re
import subprocess
import sys
import time

PAQUETE = "com.arcanum.magick"
ACTIVIDAD = f"{PAQUETE}/.MainActivity"

# Las cinco pestanas, en el orden de `arcanumSections`. El shell las reparte a
# lo ancho en partes iguales, asi que el centro de la i-esima de N esta en
# (i + 0.5) / N.
PESTANAS = ["cielo", "horoscopo", "grimorio", "saber", "oraculo"]
Y_BARRA = 0.93


def centro_pestana(nombre: str) -> tuple[float, float]:
    i = PESTANAS.index(nombre)
    return ((i + 0.5) / len(PESTANAS), Y_BARRA)


# ── El recorrido ────────────────────────────────────────────────────────────
#
# Cada parada: un nombre para el fichero, los actos que la preparan y lo que
# hay que MIRAR en la foto. Los actos son tuplas:
#
#   ("pestana", nombre)          toca una pestana de la barra
#   ("toca", x, y)               toca en fracciones de pantalla
#   ("baja", n) / ("sube", n)    n arrastres
#   ("espera", segundos)
PARADAS: list[dict] = [
    {
        "nombre": "01-cielo-ahora",
        "actos": [("pestana", "cielo"), ("espera", 3)],
        "mirar": "El instrumento del instante y el siguiente paso. NO debe "
                 "haber tarjeta 'TU CIELO DE HOY': esa vive en Horoscopo.",
    },
    {
        "nombre": "02-cielo-ahora-fondo",
        "actos": [("baja", 3)],
        "mirar": "El final de la cara 'Ahora'. Sigue sin aparecer la tarjeta.",
    },
    {
        "nombre": "03-cielo-tu-carta",
        "actos": [("sube", 3), ("toca", 0.68, 0.155), ("espera", 3)],
        "mirar": "Tu Sol, tu Ascendente y la rueda natal.",
    },
    {
        "nombre": "04-horoscopo",
        "actos": [("pestana", "horoscopo"), ("espera", 3)],
        "mirar": "Arranca DIRECTO con la tarjeta. Sin entradilla que repita el "
                 "subtitulo de la barra.",
    },
    {
        "nombre": "05-horoscopo-sello-abierto",
        # 0.505 y no 0.60: a 0.60 el toque cae en el ARO y abre la hoja de lore
        # del planeta, no el sello. Medido sobre la captura.
        "actos": [("toca", 0.5, 0.505), ("espera", 7)],
        "mirar": "El sello abierto y la lectura. Si sale el dialogo del "
                 "consentimiento, es que no estaba dado: NO aceptarlo por "
                 "nadie, capturarlo y parar.",
    },
    {
        "nombre": "06-cruce-cielo-tras-abrir",
        # La cara se queda donde se dejo, asi que hay que pedir "Ahora"
        # explicitamente: si no, se retrata "Tu carta" y no se cruza nada.
        "actos": [("pestana", "cielo"), ("espera", 2),
                  ("toca", 0.31, 0.155), ("espera", 3), ("baja", 2)],
        "mirar": "LA COMPROBACION CRUZADA. Aqui no puede haber una segunda "
                 "tarjeta con su propio sello. Hubo un tiempo en que la habia, "
                 "y abrir una dejaba la otra cerrada.",
    },
    {
        "nombre": "07-capitulo-desde-cielo",
        # Coordenadas comprobadas en vivo el 12-sep-2026 sobre 1080x2400: el
        # chip "Leelo en Culpeper" cae en la segunda fila de la rejilla del
        # regente, a la izquierda. Si el instrumento no esta en el regente, el
        # chip no existe y el toque cae en el vacio.
        "actos": [("sube", 3), ("baja", 1), ("espera", 2),
                  ("toca", 0.334, 0.752), ("espera", 4)],
        "mirar": "Al abrirse, la cabecera de arriba NO debe decir 'Cielo' sino "
                 "el nombre de la planta, y la pestana marcada abajo debe ser "
                 "Saber.",
    },
    {
        "nombre": "08-grimorio",
        "actos": [("pestana", "grimorio"), ("espera", 3)],
        "mirar": "Un solo titulo y un solo subtitulo, los de la barra. Dentro "
                 "solo el filete con el simbolo, sin repetir 'Grimorio'.",
    },
    {
        "nombre": "09-saber-plantas",
        "actos": [("pestana", "saber"), ("espera", 3)],
        "mirar": "Filtros por tipo y por planeta, y la rejilla de materias.",
    },
    {
        "nombre": "10-saber-biblioteca",
        "actos": [("toca", 0.72, 0.135), ("espera", 3)],
        "mirar": "Las obras, con 'Reanudar lectura' si hay progreso.",
    },
    {
        "nombre": "11-oraculo-consultar",
        "actos": [("pestana", "oraculo"), ("espera", 3)],
        "mirar": "El renglon 'LEE  Oraculo  Tradicion' con el filete bajo la "
                 "activa, y debajo la linea que dice que hace la elegida.",
    },
    {
        "nombre": "12-oraculo-tradicion",
        "actos": [("toca", 0.40, 0.245), ("espera", 3)],
        "mirar": "Con 'Tradicion' elegida: aparece 'Una carta' y DESAPARECE el "
                 "aviso de que hablas con un modelo de IA.",
    },
    {
        "nombre": "13-oraculo-aprender",
        "actos": [("toca", 0.72, 0.135), ("espera", 3)],
        "mirar": "El mazo carta por carta.",
    },
]


def _buscar_adb() -> str:
    """`adb` no suele estar en el PATH en Windows, y pedir que se anada es
    pedir un paso que se olvida. Se busca donde el SDK lo deja."""
    import os  # noqa: PLC0415
    import shutil  # noqa: PLC0415

    if (encontrado := shutil.which("adb")):
        return encontrado
    candidatas = []
    for var in ("ANDROID_HOME", "ANDROID_SDK_ROOT", "LOCALAPPDATA"):
        raiz = os.environ.get(var)
        if not raiz:
            continue
        base = pathlib.Path(raiz)
        candidatas += [
            base / "platform-tools" / "adb.exe",
            base / "Android" / "Sdk" / "platform-tools" / "adb.exe",
            base / "platform-tools" / "adb",
        ]
    for c in candidatas:
        if c.exists():
            return str(c)
    return "adb"


ADB = _buscar_adb()


def adb(*args: str, binario: bytes = False):
    orden = [ADB, *args]
    if binario:
        return subprocess.run(orden, capture_output=True, check=True).stdout
    return subprocess.run(
        orden, capture_output=True, text=True, check=True
    ).stdout


def tamano_pantalla() -> tuple[int, int]:
    salida = adb("shell", "wm", "size")
    m = re.search(r"(\d+)x(\d+)", salida)
    if not m:
        sys.exit("No se pudo leer el tamano de pantalla con `adb shell wm size`.")
    return int(m.group(1)), int(m.group(2))


def hay_sesion() -> bool:
    """La barra de pestanas solo existe con sesion.

    Se mira el brillo medio de la franja de abajo: con barra ronda 27, sin ella
    -- la pantalla de login -- se queda por debajo de 10. Es tosco a proposito;
    lo unico que tiene que distinguir son esos dos casos.
    """
    try:
        from PIL import Image  # noqa: PLC0415
        import numpy as np  # noqa: PLC0415
    except ImportError:
        print("  (sin Pillow/numpy: no se comprueba la sesion)")
        return True
    import io  # noqa: PLC0415

    datos = adb("exec-out", "screencap", "-p", binario=True)
    im = Image.open(io.BytesIO(datos)).convert("RGB")
    alto = im.height
    franja = np.asarray(
        im.crop((0, int(alto * 0.895), im.width, int(alto * 0.965))), dtype=float
    )
    return float(franja.mean()) > 18


def en_primer_plano() -> bool:
    salida = adb("shell", "dumpsys", "window")
    for linea in salida.splitlines():
        if "mCurrentFocus" in linea:
            return PAQUETE in linea
    return False


def asegurar_primer_plano() -> None:
    """La app se va a segundo plano sola -- el sistema la echa, o alguien toca
    el telefono -- y entonces los toques caen en otra parte.

    En algunos moviles ni caen: el lanzador rechaza la inyeccion con
    `SecurityException: Injecting to another application requires
    INJECT_EVENTS`, y el recorrido muere a media parada. Se comprueba antes de
    cada una y se vuelve a traer si hace falta.
    """
    if en_primer_plano():
        return
    print("    (la app no estaba delante: se vuelve a abrir)")
    adb("shell", "am", "start", "-n", ACTIVIDAD)
    time.sleep(6)
    if not en_primer_plano():
        sys.exit(
            "No se consigue traer ARCANUM al frente. Mira el telefono: puede "
            "estar bloqueado, o con un dialogo del sistema encima."
        )


def ejecutar(actos: list, ancho: int, alto: int) -> None:
    for acto in actos:
        clase = acto[0]
        if clase == "pestana":
            fx, fy = centro_pestana(acto[1])
            adb("shell", "input", "tap", str(int(fx * ancho)), str(int(fy * alto)))
            time.sleep(2)
        elif clase == "toca":
            adb("shell", "input", "tap",
                str(int(acto[1] * ancho)), str(int(acto[2] * alto)))
            time.sleep(2)
        elif clase in ("baja", "sube"):
            desde, hasta = (0.75, 0.29) if clase == "baja" else (0.29, 0.83)
            for _ in range(acto[1]):
                adb("shell", "input", "swipe",
                    str(ancho // 2), str(int(alto * desde)),
                    str(ancho // 2), str(int(alto * hasta)), "400")
                time.sleep(1.5)
        elif clase == "espera":
            time.sleep(acto[1])
        else:
            sys.exit(f"Acto desconocido: {clase}")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--solo", help="recorre solo las paradas cuyo nombre "
                                   "contenga este texto")
    ap.add_argument("--salida", help="carpeta destino (por defecto "
                                     "docs/recorridos/<fecha>)")
    args = ap.parse_args()

    try:
        adb("get-state")
    except (subprocess.CalledProcessError, FileNotFoundError):
        return print(f"No hay aparato conectado. adb usado: {ADB}") or 1

    destino = pathlib.Path(
        args.salida
        or f"docs/recorridos/{dt.date.today().isoformat()}"
    )
    destino.mkdir(parents=True, exist_ok=True)

    ancho, alto = tamano_pantalla()
    print(f"Aparato de {ancho}x{alto}. Capturas en {destino}/\n")

    adb("shell", "am", "force-stop", PAQUETE)
    adb("shell", "am", "start", "-n", ACTIVIDAD)
    time.sleep(9)

    if not hay_sesion():
        print("LA APP ESTA EN EL LOGIN: no hay sesion y no hay nada que "
              "recorrer.\nEntra con la cuenta y vuelve a lanzar esto.")
        return 1

    paradas = [p for p in PARADAS
               if not args.solo or args.solo.lower() in p["nombre"]]
    if not paradas:
        return print(f"Ninguna parada casa con «{args.solo}».") or 1

    for parada in paradas:
        asegurar_primer_plano()
        ejecutar(parada["actos"], ancho, alto)
        png = destino / f"{parada['nombre']}.png"
        png.write_bytes(adb("exec-out", "screencap", "-p", binario=True))
        print(f"  {parada['nombre']}")

    print("\n" + "=" * 72)
    print("QUE MIRAR EN CADA UNA")
    print("=" * 72)
    for parada in paradas:
        print(f"\n{parada['nombre']}\n  {parada['mirar']}")

    print("\n" + "=" * 72)
    print("ANTES DE ENSENAR ESTAS CAPTURAS A NADIE")
    print("=" * 72)
    print("Una captura se lleva lo que haya encima: notificaciones, mensajes,\n"
          "nombres. Miralas una a una y borra la que traiga algo personal.")
    print("\nLos toques son a ciegas, por coordenadas: si una parada salio en\n"
          "el sitio equivocado, la foto lo dice. No te fies del orden, fiate\n"
          "de lo que se ve.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
