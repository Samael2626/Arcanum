# Anula `planetary_hour` en las filas selladas con la coordenada de Bogota.
#
# POR QUE EXISTE
#
# Durante meses, dos caminos distintos escribieron una hora planetaria calculada
# sobre 4.71/-74.07 para todo el mundo:
#
#   tarot_readings       <- `_sky_snapshot` en el servidor      (arreglado 5f4ec60)
#   divination_sessions  <- el cliente, con el default de today()(arreglado 8247325)
#   grimoire_entries     <- idem, via grimorio_editor.dart       (arreglado 8247325)
#
# No es imprecision. La hora planetaria sale del orto y el ocaso LOCALES: a un
# mismo instante UTC, alguien en Madrid puede estar en otra hora planetaria y
# hasta bajo otro regente del dia. Quien lea su Grimorio dentro de un ano no
# tiene forma de distinguir ese dato de uno verdadero.
#
# La decision editorial ya se tomo dos veces en este proyecto: ausencia
# declarada gana a precision fingida. Esto la aplica hacia atras.
#
# QUE NO HACE
#
# - No toca `moon_phase`. La fase lunar es global: no depende del observador y
#   los valores guardados son correctos.
# - No borra filas. Solo pone `planetary_hour` a NULL.
# - No es una migracion Alembic ni pretende serlo. Se corre a mano, una vez.
#
# USO
#
#   python scripts/null_bogota_planetary_hour.py --before 2026-08-20T12:00:00Z
#   python scripts/null_bogota_planetary_hour.py --before ... --apply
#
# Sin `--apply` no escribe nada: cuenta y se calla.
#
# ANTES DE CORRERLO CON --apply
#
# Verifica que el arreglo ESTA DESPLEGADO, y no que este commiteado.
#
# Railway despliega desde `release/p0a-beta`, con AUTO DEPLOY APAGADO: un push
# a esa rama no despliega nada. (Este comentario decia `feat/onboarding-5-pasos`
# y era falso; el error se propago a varios checkpoints antes de comprobarse
# contra el panel.)
#
# Consecuencia practica: el instante del despliegue se ELIGE y se anota, no se
# estima a posteriori. Si el fix no esta sirviendo, produccion sigue escribiendo
# filas falsas y limpiar hacia atras es perseguir un blanco movil.

from __future__ import annotations

import argparse
import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from sqlalchemy import create_engine, text


class Objetivo:
    """Una tabla que sello la hora planetaria, con su columna de tiempo.

    La columna de tiempo no es la misma en las tres: `divination_sessions` usa
    `session_date` y no tiene `created_at`. Codificarlo aqui evita que el
    script asuma un esquema uniforme que no existe.
    """

    def __init__(self, tabla: str, columna_tiempo: str) -> None:
        self.tabla = tabla
        self.columna_tiempo = columna_tiempo

    def contar(self, conn, corte: datetime) -> int:
        sql = text(
            f"SELECT count(*) FROM {self.tabla} "
            f"WHERE planetary_hour IS NOT NULL AND {self.columna_tiempo} < :corte"
        )
        return int(conn.execute(sql, {"corte": corte}).scalar_one())

    def muestra(self, conn, corte: datetime, limite: int = 5) -> list[tuple]:
        sql = text(
            f"SELECT id, planetary_hour, {self.columna_tiempo} FROM {self.tabla} "
            f"WHERE planetary_hour IS NOT NULL AND {self.columna_tiempo} < :corte "
            f"ORDER BY {self.columna_tiempo} DESC LIMIT :limite"
        )
        return list(conn.execute(sql, {"corte": corte, "limite": limite}))

    def respaldar(self, conn, corte: datetime) -> list[dict]:
        """Lo que se va a perder, antes de perderlo.

        El borrado es irreversible y no hay columna donde guardar el valor
        anterior. El respaldo en disco es la unica marcha atras que existe.
        """
        sql = text(
            f"SELECT id, planetary_hour, {self.columna_tiempo} AS momento "
            f"FROM {self.tabla} "
            f"WHERE planetary_hour IS NOT NULL AND {self.columna_tiempo} < :corte"
        )
        return [
            {
                "tabla": self.tabla,
                "id": str(fila.id),
                "planetary_hour": fila.planetary_hour,
                "momento": fila.momento.isoformat() if fila.momento else None,
            }
            for fila in conn.execute(sql, {"corte": corte})
        ]

    def anular(self, conn, corte: datetime) -> int:
        sql = text(
            f"UPDATE {self.tabla} SET planetary_hour = NULL "
            f"WHERE planetary_hour IS NOT NULL AND {self.columna_tiempo} < :corte"
        )
        return int(conn.execute(sql, {"corte": corte}).rowcount)


OBJETIVOS = (
    Objetivo("tarot_readings", "created_at"),
    Objetivo("divination_sessions", "session_date"),
    Objetivo("grimoire_entries", "created_at"),
)


def parse_corte(valor: str) -> datetime:
    """ISO 8601 con zona obligatoria.

    Una fecha sin zona en un script que borra datos de produccion es la misma
    clase de error que este script viene a limpiar: un instante que significa
    cosas distintas segun quien lo lea.
    """
    texto = valor.strip().replace("Z", "+00:00")
    try:
        momento = datetime.fromisoformat(texto)
    except ValueError as error:
        raise argparse.ArgumentTypeError(f"fecha ISO 8601 invalida: {valor!r}") from error
    if momento.tzinfo is None:
        raise argparse.ArgumentTypeError(
            f"{valor!r} no lleva zona. Usa un sufijo explicito (Z o +00:00)."
        )
    if momento > datetime.now(timezone.utc):
        raise argparse.ArgumentTypeError(
            f"{valor!r} esta en el futuro: anularia filas que aun no existen."
        )
    return momento


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Anula la hora planetaria sellada con la coordenada de Bogota.",
    )
    parser.add_argument(
        "--before",
        required=True,
        type=parse_corte,
        metavar="ISO8601",
        help=(
            "Instante del despliegue del arreglo, con zona. Sin default a "
            "proposito: la fecha del commit NO es la del despliegue, y heredar "
            "una fecha inventada aqui repetiria el bug que este script limpia."
        ),
    )
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Escribe de verdad. Sin esta bandera solo cuenta.",
    )
    parser.add_argument(
        "--database-url",
        default=os.getenv("DATABASE_URL"),
        help="Por defecto, $DATABASE_URL.",
    )
    parser.add_argument(
        "--backup",
        type=Path,
        default=Path("scripts/out/bogota_planetary_hour_backup.json"),
        help="Donde se vuelca lo que se va a anular, antes de anularlo.",
    )
    args = parser.parse_args()

    if not args.database_url:
        print("Falta --database-url o $DATABASE_URL.", file=sys.stderr)
        return 2

    engine = create_engine(args.database_url)
    modo = "APLICANDO" if args.apply else "SIMULACRO (nada se escribe)"
    print(f"[{modo}] corte: {args.before.isoformat()}\n")

    with engine.begin() as conn:
        # Comprobar el esquema ANTES de contar: apuntar a la base equivocada es
        # el error facil aqui, y un traceback de psycopg2 no lo dice. Con
        # `--apply`, ademas, un fallo a mitad dejaria unas tablas anuladas y
        # otras no.
        faltan = [
            objetivo.tabla
            for objetivo in OBJETIVOS
            if not conn.execute(
                text("SELECT to_regclass(:tabla)"), {"tabla": objetivo.tabla}
            ).scalar_one()
        ]
        if faltan:
            print(
                f"Esta base no tiene {', '.join(faltan)}. "
                f"Comprueba --database-url: no parece la de ARCANUM.",
                file=sys.stderr,
            )
            return 2

        total = 0
        respaldo: list[dict] = []

        for objetivo in OBJETIVOS:
            cuantas = objetivo.contar(conn, args.before)
            total += cuantas
            print(f"  {objetivo.tabla:<22} {cuantas:>7} filas")
            for fila in objetivo.muestra(conn, args.before):
                print(f"      ej. {fila[0]}  {fila[1]!r}  {fila[2]}")
            if args.apply and cuantas:
                respaldo.extend(objetivo.respaldar(conn, args.before))

        print(f"\n  {'TOTAL':<22} {total:>7} filas")

        if not args.apply:
            print("\nSimulacro. Repite con --apply para escribir.")
            return 0

        if not total:
            print("\nNada que anular.")
            return 0

        args.backup.parent.mkdir(parents=True, exist_ok=True)
        args.backup.write_text(
            json.dumps(respaldo, indent=2, ensure_ascii=False), encoding="utf-8"
        )
        print(f"\nRespaldo escrito en {args.backup} ({len(respaldo)} filas).")

        anuladas = sum(objetivo.anular(conn, args.before) for objetivo in OBJETIVOS)
        print(f"Anuladas {anuladas} filas. moon_phase intacto.")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
