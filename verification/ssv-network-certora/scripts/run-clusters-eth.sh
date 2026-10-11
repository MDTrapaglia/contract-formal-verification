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

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    echo "Run bash certora/scripts/setup.sh first." >&2
    exit 1
  fi
}

for command_name in certoraRun certoraCVLFormatter solc npm; do
  require_command "$command_name"
done

cd "$REPO_ROOT"

echo "== Tool versions =="
certoraRun --version
solc --version

echo "== CVL syntax check =="
certoraCVLFormatter certora/specs/clusters_eth.spec >/dev/null

echo "== Hardhat build =="
npm run build

if [ "$MODE" = "check" ]; then
  echo "== Certora local compilation =="
  certoraRun certora/conf/clusters-eth.conf --compilation_steps_only
  exit 0
fi

if [ -z "${CERTORAKEY:-}" ] && [ -n "${CERTORA:-}" ]; then
  export CERTORAKEY="$CERTORA"
fi

if [ -z "${CERTORAKEY:-}" ]; then
  echo "CERTORAKEY or CERTORA must be set for cloud verification." >&2
  exit 1
fi

echo "== Certora Cloud verification =="
certoraRun certora/conf/clusters-eth.conf
