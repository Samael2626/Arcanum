#!/usr/bin/env bash
#
# ARCANUM — un comando, un veredicto.
#
# Existe porque la verificacion estaba repartida en tres sitios que no se
# hablan, y cada uno cubria un trozo distinto:
#
#   .githooks/pre-commit   CJK, codificacion, pytest, tests_pg, flutter analyze
#                          -- pero NO flutter test ni dart format
#   .github/workflows      todo lo anterior MAS flutter test y dart format
#                          -- pero solo en main/develop/feat/**/fix/**
#   la memoria de quien commitea   el resto
#
# El agujero medido el 19-sep-2026: nueve commits en refactor/** sin pasar por
# CI ni una vez, y `dart format` en rojo con 95 de 211 ficheros. Nada lo dijo,
# porque nadie preguntaba.
#
# Esto pregunta todo de una vez y no se fia de las ramas.
#
#   scripts/verificar.sh            todo
#   scripts/verificar.sh rapido     lo que no necesita Docker (~40 s)
#   scripts/verificar.sh app        solo Flutter
#   scripts/verificar.sh api        solo backend
#
# Salida: cada bloque dice VERDE o ROJO con su numero, y al final un resumen.
# Codigo de salida 1 si algo esta rojo -- sirve para encadenarlo.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1

MODO="${1:-todo}"
ROJO=$'\033[0;31m'; VERDE=$'\033[0;32m'; AMBAR=$'\033[1;33m'; GRIS=$'\033[0;90m'; OFF=$'\033[0m'
LOGS="${TMPDIR:-/tmp}/arcanum-verificar"
mkdir -p "$LOGS"

FALLOS=()
SALTADOS=()

titulo() { printf '\n%s── %s %s\n' "$GRIS" "$1" "$OFF"; }
verde()  { printf '%s  VERDE%s  %s\n' "$VERDE" "$OFF" "$1"; }
rojo()   { printf '%s  ROJO %s  %s\n' "$ROJO" "$OFF" "$1"; FALLOS+=("$1"); }
salto()  { printf '%s  --   %s  %s\n' "$AMBAR" "$OFF" "$1"; SALTADOS+=("$1"); }

# Corre un comando, guarda su log y reporta. No aborta: queremos el cuadro
# entero, no el primer fallo. Un informe que se corta en el primer rojo
# obliga a repetir la corrida por cada problema.
corre() {
  local nombre="$1" log="$LOGS/$2"; shift 2
  if "$@" >"$log" 2>&1; then
    verde "$nombre"
  else
    rojo "$nombre  ${GRIS}log: $log${OFF}"
  fi
}

hay() { command -v "$1" >/dev/null 2>&1; }

# ── Flutter ──────────────────────────────────────────────────────────────
app() {
  titulo "App (arcanum_app)"
  if ! hay flutter; then salto "Flutter entero — flutter no esta en PATH"; return; fi

  # El formato PRIMERO: es el que rompe el CI y el que nadie mira.
  # --output=none no toca los ficheros; solo dice si cambiarian.
  if (cd arcanum_app && dart format --output=none --set-exit-if-changed lib test) \
       >"$LOGS/formato.log" 2>&1; then
    verde "dart format"
  else
    local n
    n="$(grep -oE '\([0-9]+ changed\)' "$LOGS/formato.log" | grep -oE '[0-9]+' | tail -1)"
    rojo "dart format — ${n:-?} ficheros cambiarian  ${GRIS}arreglo: cd arcanum_app && dart format lib test${OFF}"
  fi

  corre "flutter analyze" analyze.log \
    bash -c "cd arcanum_app && flutter analyze"

  corre "flutter test" flutter_test.log \
    bash -c "cd arcanum_app && flutter test"
}

# Los retratos NO son un test: se regeneran con --update-goldens y siempre
# pasan. Corren aparte para que nadie confunda "56 verdes" con cobertura.
capturas() {
  titulo "Retratos (no son un test: se regeneran)"
  if ! hay flutter; then salto "capturas — flutter no esta en PATH"; return; fi
  corre "capturas regeneradas" capturas.log \
    bash -c "cd arcanum_app && flutter test test/capturas --update-goldens --run-skipped"
}

# ── Backend ──────────────────────────────────────────────────────────────
api() {
  titulo "Backend (arcanum-api)"
  local PY; PY="$(hay python && echo python || echo python3)"
  if ! hay "$PY"; then salto "Backend entero — python no esta en PATH"; return; fi

  corre "pytest tests_unit" pytest_unit.log \
    bash -c "cd arcanum-api && $PY -m pytest tests_unit -q --no-header --disable-warnings"

  # Los de integracion y los de esquema real necesitan Postgres. Sin base NO
  # se dan por verdes: se marcan saltados, que es lo honesto. Un verde con la
  # mitad de la suite dormida es peor que un rojo.
  if ! hay docker || ! docker ps >/dev/null 2>&1; then
    salto "pytest tests + tests_pg — Docker no responde"
    return
  fi

  local DB="${TEST_DATABASE_URL:-postgresql://postgres:postgres@127.0.0.1:5434/arcanum_test}"
  if docker ps --format '{{.Names}}' | grep -q '^arcanum-test-db$'; then
    corre "pytest tests (integracion)" pytest_int.log \
      bash -c "cd arcanum-api && TEST_DATABASE_URL='$DB' DATABASE_URL='$DB' $PY -m pytest tests -q --no-header --disable-warnings"
  else
    salto "pytest tests — falta el contenedor arcanum-test-db  ${GRIS}docker start arcanum-test-db${OFF}"
  fi

  local PGDB="${MIGRATION_TEST_DATABASE_URL:-postgresql://postgres:test@127.0.0.1:55434/arcanum_migration_test}"
  if docker ps --format '{{.Names}}' | grep -q '^arcanum-svc-test$'; then
    corre "pytest tests_pg (esquema Alembic real)" pytest_pg.log \
      bash -c "cd arcanum-api && MIGRATION_TEST_DATABASE_URL='$PGDB' $PY -m pytest tests_pg -q --no-header --disable-warnings -rs"
  else
    salto "pytest tests_pg — falta el contenedor arcanum-svc-test  ${GRIS}docker start arcanum-svc-test${OFF}"
  fi
}

# ── Higiene del repo ─────────────────────────────────────────────────────
higiene() {
  titulo "Higiene"
  local PY; PY="$(hay python && echo python || echo python3)"

  # CJK y codificacion sobre lo que cambio contra main, no sobre el repo
  # entero: en el repo entero tarda 73 s medidos y nadie lo espera.
  local CAMBIADOS
  CAMBIADOS="$(git diff --name-only origin/main...HEAD 2>/dev/null | grep -E '\.(py|dart|md|json|yaml|yml)$' || true)"
  if [ -z "$CAMBIADOS" ]; then
    salto "CJK y codificacion — nada cambiado contra origin/main"
  else
    corre "CJK" cjk.log bash -c "echo '$CAMBIADOS' | tr '\n' '\0' | xargs -0 -r $PY scripts/check_cjk.py"
    corre "codificacion" enc.log bash -c "echo '$CAMBIADOS' | tr '\n' '\0' | xargs -0 -r $PY scripts/check_encoding.py"
  fi

  # El CI no se dispara en toda rama. Si estas en una que no cubre, el verde
  # de aqui es el UNICO verde que vas a tener antes de mezclar.
  local RAMA; RAMA="$(git branch --show-current 2>/dev/null || echo '?')"
  case "$RAMA" in
    main|master|develop|feat/*|fix/*)
      verde "rama '$RAMA' — el CI la cubre" ;;
    *)
      printf '%s  AVISO%s  rama %s no dispara el CI (solo main, develop, feat/**, fix/**)\n' \
        "$AMBAR" "$OFF" "'$RAMA'" ;;
  esac
}

case "$MODO" in
  app)    app ;;
  api)    api ;;
  rapido) higiene; app ;;
  todo)   higiene; app; api; capturas ;;
  *) echo "uso: $0 [todo|rapido|app|api]"; exit 2 ;;
esac

# ── Veredicto ────────────────────────────────────────────────────────────
printf '\n%s────────────────────────────────%s\n' "$GRIS" "$OFF"
if [ ${#SALTADOS[@]} -gt 0 ]; then
  printf '%sSaltados (%d) — no cuentan como verde:%s\n' "$AMBAR" "${#SALTADOS[@]}" "$OFF"
  printf '  · %s\n' "${SALTADOS[@]}"
fi
if [ ${#FALLOS[@]} -eq 0 ]; then
  printf '%sTodo lo que se pudo correr, en verde.%s\n' "$VERDE" "$OFF"
  [ ${#SALTADOS[@]} -gt 0 ] && printf '%sPero hay %d bloques sin correr: esto no es un verde completo.%s\n' \
    "$AMBAR" "${#SALTADOS[@]}" "$OFF"
  exit 0
fi
printf '%sROJO (%d):%s\n' "$ROJO" "${#FALLOS[@]}" "$OFF"
printf '  · %s\n' "${FALLOS[@]}"
exit 1
