#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
PY_VENV="${PY_VENV:-$REPO_ROOT/.venv-certora}"
SOLC_VERSION="${SOLC_VERSION:-0.8.24}"

install_system_dependencies() {
  if [ "${SETUP_SYSTEM_DEPS:-0}" != "1" ]; then
    return
  fi

  if ! command -v apt-get >/dev/null 2>&1; then
    echo "Automatic system dependency installation supports apt-get only." >&2
    exit 1
  fi

  sudo apt-get update
  sudo apt-get install -y --no-install-recommends \
    ca-certificates curl git nodejs npm openjdk-21-jdk-headless \
    python3 python3-pip python3-venv
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    echo "On Ubuntu/Debian, rerun with SETUP_SYSTEM_DEPS=1." >&2
    exit 1
  fi
}

case "$(uname -m)" in
  x86_64|amd64) ;;
  *)
    echo "This setup requires x86_64 Certora and solc binaries; found $(uname -m)." >&2
    exit 1
    ;;
esac

install_system_dependencies

for command_name in git node npm java python3; do
  require_command "$command_name"
done

if [ -f "$REPO_ROOT/package-lock.json" ]; then
  npm --prefix "$REPO_ROOT" ci
else
  npm --prefix "$REPO_ROOT" install
fi

python3 -m venv "$PY_VENV"
"$PY_VENV/bin/python" -m pip install --upgrade pip
"$PY_VENV/bin/python" -m pip install -r "$REPO_ROOT/certora/requirements.txt"
"$PY_VENV/bin/solc-select" install "$SOLC_VERSION"
"$PY_VENV/bin/solc-select" use "$SOLC_VERSION"

echo "== Installed versions =="
"$PY_VENV/bin/certoraRun" --version
"$PY_VENV/bin/solc" --version
node --version
npm --version
java -version

echo "== Baseline build =="
npm --prefix "$REPO_ROOT" run build

cat <<MSG

Environment ready. Run:
  npm --prefix "$REPO_ROOT" run certora:check

To submit a cloud verification, export CERTORAKEY or CERTORA and run:
  npm --prefix "$REPO_ROOT" run certora:verify
MSG
