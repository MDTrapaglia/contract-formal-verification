#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
PY_VENV="${PY_VENV:-$REPO_ROOT/.venv-certora}"
MODE="${1:-verify}"

if [ "$MODE" != "check" ] && [ "$MODE" != "verify" ]; then
  echo "Usage: $0 [check|verify]" >&2
  exit 2
fi

if [ -x "$PY_VENV/bin/certoraRun" ]; then
  PATH="$PY_VENV/bin:$PATH"
  export PATH
fi

for command_name in certoraRun certoraCVLFormatter solc; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Missing required command: $command_name" >&2
    echo "Run bash certora/scripts/setup.sh first." >&2
    exit 1
  fi
done

cd "$REPO_ROOT"
certoraRun --version
solc --version
certoraCVLFormatter certora/specs/clusters_eth_withdraw.spec >/dev/null

if [ "$MODE" = "check" ]; then
  certoraRun certora/conf/clusters-eth-withdraw.conf --compilation_steps_only
  exit 0
fi

if [ -z "${CERTORAKEY:-}" ] && [ -n "${CERTORA:-}" ]; then
  export CERTORAKEY="$CERTORA"
fi
if [ -z "${CERTORAKEY:-}" ]; then
  echo "CERTORAKEY or CERTORA must be set for cloud verification." >&2
  exit 1
fi

certoraRun certora/conf/clusters-eth-withdraw.conf
