#!/usr/bin/env bash

if [ -z "${BASH_VERSION:-}" ]; then
  exec bash "$0" "$@"
fi

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$ROOT_DIR/backend"
BACKEND_ENV_FILE="$BACKEND_DIR/.env"
BACKEND_VENV="$BACKEND_DIR/.venv"
FLUTTER_DEVICE="${1:-${KEEPIN_FLUTTER_DEVICE:-chrome}}"

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

# Load backend env vars without evaluating shell syntax from .env values.
while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
  line="${raw_line%$'\r'}"

  if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
    continue
  fi

  if [[ "$line" != *=* ]]; then
    continue
  fi

  key="${line%%=*}"
  value="${line#*=}"
  key="${key#"${key%%[![:space:]]*}"}"
  key="${key%"${key##*[![:space:]]}"}"

  if [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
    export "$key=$value"
  fi
done < "$BACKEND_ENV_FILE"

API_HOST="${KEEPIN_API_HOST:-127.0.0.1}"
API_PORT="${KEEPIN_API_PORT:-8000}"

BACKEND_PID=""

cleanup() {
  if [[ -n "$BACKEND_PID" ]] && kill -0 "$BACKEND_PID" 2>/dev/null; then
    kill "$BACKEND_PID" 2>/dev/null || true
    wait "$BACKEND_PID" 2>/dev/null || true
  fi
}

backend_is_ready() {
  local health_url="http://$API_HOST:$API_PORT/health"

  if command -v curl >/dev/null 2>&1; then
    curl --silent --fail --output /dev/null "$health_url"
    return $?
  fi

  if command -v wget >/dev/null 2>&1; then
    wget --quiet --spider "$health_url"
    return $?
  fi

  kill -0 "$BACKEND_PID" 2>/dev/null
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
for _ in {1..30}; do
  if backend_is_ready; then
    break
  fi

  if ! kill -0 "$BACKEND_PID" 2>/dev/null; then
    echo "Backend exited before becoming ready."
    wait "$BACKEND_PID"
    exit 1
  fi

  sleep 1
done

if ! backend_is_ready; then
  echo "Backend did not become ready at http://$API_HOST:$API_PORT/health"
  exit 1
fi

echo "Launching Flutter on device: $FLUTTER_DEVICE"
cd "$ROOT_DIR"
flutter run -d "$FLUTTER_DEVICE"
