#!/usr/bin/env bash
# Start codex-transfer proxy: Codex Responses API → Infini-AI Chat Completions
set -euo pipefail

CONFIG="${CODEX_TRANSFER_CONFIG:-$HOME/.codex-transfer/config.json}"
PID_FILE="$HOME/.codex-transfer/logs/codex-transfer.pid"
INSTALL_DIR="${CODEX_TRANSFER_HOME:-$HOME/.local/codex-transfer}"
BIN="$INSTALL_DIR/node_modules/.bin/codex-transfer"

if [[ -z "${CODEX_TRANSFER_API_KEY:-}" ]]; then
  echo "Set CODEX_TRANSFER_API_KEY before starting." >&2
  echo "Example: export CODEX_TRANSFER_API_KEY=sk-your-infini-ai-key" >&2
  exit 1
fi

if [[ ! -x "$BIN" ]]; then
  echo "codex-transfer not found at $BIN" >&2
  echo "Run: bash $(dirname "$0")/install-codex-transfer.sh" >&2
  exit 1
fi

if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
  echo "codex-transfer already running (PID $(cat "$PID_FILE"))"
  curl -sS "http://127.0.0.1:4446/health" || true
  echo
  exit 0
fi

mkdir -p "$HOME/.codex-transfer/logs"
"$BIN" -d -c "$CONFIG" --api-key "$CODEX_TRANSFER_API_KEY"
sleep 1
curl -sS "http://127.0.0.1:4446/health"
echo
