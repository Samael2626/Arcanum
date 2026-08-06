#!/usr/bin/env bash
#
# Instala los hooks de ARCANUM. Idempotente: correlo las veces que quieras.
#
#   bash scripts/install-hooks.sh
#
# Fija core.hooksPath LOCAL a .githooks (versionado en el repo). Esto tiene
# prioridad sobre el core.hooksPath global; .githooks/post-commit re-invoca
# el hook global para no perder el auto-checkpoint.
#
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

git config --local core.hooksPath .githooks
chmod +x .githooks/* 2>/dev/null || true

echo "Hooks instalados en $(git config --local core.hooksPath)"
echo "  pre-commit  — CJK + pytest + flutter analyze"
echo "  post-commit — delega en el checkpoint global si existe"
echo
echo "Para saltarlos puntualmente: ARCANUM_SKIP_HOOKS=1 git commit ..."
