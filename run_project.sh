#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$ROOT_DIR/backend"
BACKEND_ENV_FILE="$BACKEND_DIR/.env"
BACKEND_VENV="$BACKEND_DIR/.venv"

if [[ ! -d "$BACKEND_VENV" ]]; then
  echo "Backend virtualenv not found at $BACKEND_VENV"
  echo "Create it first with:"
  echo "  cd backend && python3 -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt"
  exit 1
fi

if [[ ! -f "$BACKEND_ENV_FILE" ]]; then
  echo "Backend env file not found at $BACKEND_ENV_FILE"
  echo "Create it first with:"
  echo "  cp backend/.env.example backend/.env"
  exit 1
fi

# Load backend host/port if present in backend/.env.
set -a
source "$BACKEND_ENV_FILE"
set +a

API_HOST="${KEEPIN_API_HOST:-127.0.0.1}"
API_PORT="${KEEPIN_API_PORT:-8000}"

BACKEND_PID=""

cleanup() {
  if [[ -n "$BACKEND_PID" ]] && kill -0 "$BACKEND_PID" 2>/dev/null; then
    kill "$BACKEND_PID" 2>/dev/null || true
    wait "$BACKEND_PID" 2>/dev/null || true
  fi
}

trap cleanup EXIT INT TERM

echo "Starting KeepIn backend on http://$API_HOST:$API_PORT"
(
  cd "$BACKEND_DIR"
  source "$BACKEND_VENV/bin/activate"
  python -m uvicorn app.main:app --reload --host "$API_HOST" --port "$API_PORT"
) &
BACKEND_PID=$!

echo "Waiting for backend to boot..."
sleep 2

echo "Launching Flutter in Chrome"
cd "$ROOT_DIR"
flutter run -d chrome
