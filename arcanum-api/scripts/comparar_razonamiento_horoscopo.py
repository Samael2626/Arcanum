# -*- coding: utf-8 -*-
"""Razonamiento por defecto contra `reasoning_effort=low`, con el modelo real.

Cierra la evidencia de la decision que tomo `claude_service`: el horoscopo va
con razonamiento bajo porque con el de por defecto se truncaba, y un truncado
es un dia SIN horoscopo. Eso ya se midio (3 de 4 y 1 de 4 truncados contra 0 de
4). Lo que faltaba era la CALIDAD con la misma muestra a los dos lados.

Las dos tandas usan el MISMO cielo, calculado una sola vez: comparar textos de
dos cielos distintos no compara nada.

Uso, desde `arcanum-api/`:

    python scripts/comparar_razonamiento_horoscopo.py

DEL PRESUPUESTO, que es lo que hace fallar esto a mitad. La cuenta gratuita de
Groq tiene DOS techos y solo uno se ve en las cabeceras:

  - 8.000 tokens por MINUTO  -> es el que gobierna la pausa entre llamadas.
  - 200.000 tokens por DIA   -> no sale en `x-ratelimit-*`, y es el que corta
    la corrida entera con un 429 de TPD. Ocho llamadas de estas gastan unos
    33.000 tokens, asi que una jornada de pruebas se lo come sin avisar.

Si sale `Rate limit ... on tokens per day`, no hay nada que ajustar: se espera
al reinicio diario. La corrida imprime lo que llevara medido antes de cortarse,
en vez de perderlo.
"""
import io
import os
import sys
import time
from datetime import date, datetime, timezone

sys.path.insert(0, os.path.abspath("."))
# La consola de Windows es cp1252 y el modelo devuelve acentos y espacios finos.
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

from dotenv import load_dotenv  # noqa: E402

load_dotenv(".env")

from app.services import claude_service as cs  # noqa: E402
from app.services import horoscope as hs  # noqa: E402
from app.services import horoscope_guard as hg  # noqa: E402
from app.services import natal_chart_engine as nce  # noqa: E402
from app.services import planetary_hours as ph  # noqa: E402

# Carta de prueba y lugar. No es de nadie: fecha redonda, Medellin.
DT = datetime(1990, 3, 14, 8, 30, tzinfo=timezone.utc)
LAT, LON = 6.24, -75.58

N = int(os.environ.get("N", "4"))
# 55 segundos: una llamada con razonamiento por defecto gasta cerca de 4.900
# tokens y el techo es de 8.000 por minuto. Dos seguidas no caben.
PAUSA = int(os.environ.get("PAUSA", "55"))


class Tanda:
    """Lo medido de una tanda, que es lo unico que se compara al final."""

    def __init__(self, etiqueta: str):
        self.etiqueta = etiqueta
        self.salidas: list[int] = []
        self.truncados = 0
        # Solo de los textos COMPLETOS: de uno cortado a media frase no se puede
        # decir que le falte nada, porque le falta todo.
        self.defectos: list[int] = []
        self.cobertura = 0
        self.regente = 0
        self.hora = 0

    @property
    def enteros(self) -> int:
        return len(self.defectos)

    def linea(self) -> str:
        if not self.salidas:
            return f"[{self.etiqueta}] sin datos: la corrida no llego a empezar"
        s = self.salidas
        partes = [f"[{self.etiqueta}] truncados {self.truncados}/{len(s)}",
                  f"salida min/med/max {min(s)}/{sum(s) // len(s)}/{max(s)}"]
        if self.defectos:
            media = sum(self.defectos) / len(self.defectos)
            partes.append(f"defectos {self.defectos} (media {media:.1f})")
            partes.append(f"cobertura {self.cobertura}/{self.enteros}")
            partes.append(f"regente {self.regente}/{self.enteros}")
            partes.append(f"hora planetaria {self.hora}/{self.enteros}")
        return " | ".join(partes)


def _cielo() -> tuple[str, list[str], str, str]:
    """El cielo de hoy, sus terminos obligatorios, y a quien pertenece el dia."""
    chart = nce.compute_natal_chart(nce.BirthData(dt_utc=DT, lat=LAT, lon=LON))
    ahora = datetime.now(timezone.utc)
    sky = hs.build_sky(chart, ahora)
    hora = ph.get_planetary_hour(ahora, LAT, LON)
    regente = ph.get_day_ruler(date.today())
    hora_planeta = getattr(hora, "planet", None)
    texto = hs.describe(sky, ahora, day_ruler=regente,
                        planetary_hour=hora_planeta)
    return (texto, hs.expected_terms(sky),
            nce.POINTS_ES.get(regente, regente or ""),
            nce.POINTS_ES.get(hora_planeta, hora_planeta or ""))


def corre(cliente, etiqueta: str, effort: str | None, sky_txt: str,
          terms: list[str], regente: str, hora: str) -> Tanda:
    tanda = Tanda(etiqueta)
    extra = {"reasoning_effort": effort} if effort else {}
    for i in range(N):
        try:
            resp = cliente.chat.completions.create(
                model="openai/gpt-oss-120b",
                messages=[{"role": "system", "content": cs.HOROSCOPE_SYSTEM_PROMPT},
                          {"role": "user", "content": sky_txt}],
                max_tokens=cs._HOROSCOPE_MAX_TOKENS,
                temperature=cs._HOROSCOPE_TEMPERATURE, **extra)
        except Exception as exc:  # noqa: BLE001
            # Se corta la tanda y se devuelve lo que lleve: perder cuatro
            # llamadas ya pagadas por no imprimirlas seria el peor final.
            print(f"CORTADA en la #{i + 1}: {type(exc).__name__} "
                  f"{str(exc)[:200]}")
            break

        fin = resp.choices[0].finish_reason
        texto = cs._limpia_espacios(resp.choices[0].message.content or "").strip()
        tanda.salidas.append(resp.usage.completion_tokens)

        faltan = cs._missing_terms(terms, texto)
        fallos = hg.defectos(texto, sky_txt)
        print(f"### [{etiqueta}] #{i + 1}  finish={fin} "
              f"salida={resp.usage.completion_tokens} chars={len(texto)} "
              f"faltan={faltan or '-'} defectos={len(fallos)}")
        if texto:
            print(texto)
        if fallos:
            print("   guarda ->", [f.split("(")[0].strip() for f in fallos])
        print()

        if fin == "length" or not texto:
            tanda.truncados += 1
        else:
            tanda.defectos.append(len(fallos))
            tanda.cobertura += not faltan
            plano = hg._plano(texto)
            tanda.regente += hg._plano(regente) in plano
            tanda.hora += hg._plano(hora) in plano
        time.sleep(PAUSA)
    return tanda


def main() -> int:
    cliente = cs._get_client()
    if cliente is None:
        print("Falta GROQ_API_KEY.")
        return 1

    sky_txt, terms, regente, hora = _cielo()
    print("terminos obligatorios:", terms)
    print("regente del dia:", regente, "| hora planetaria:", hora, "\n")

    tandas = [corre(cliente, "defecto", None, sky_txt, terms, regente, hora),
              corre(cliente, "low", "low", sky_txt, terms, regente, hora)]

    print("=" * 70)
    for t in tandas:
        print(t.linea())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
