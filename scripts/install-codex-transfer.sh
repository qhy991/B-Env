#!/usr/bin/env bash
# Install @classicicn/codex-transfer locally under ~/.local/codex-transfer
set -euo pipefail

INSTALL_DIR="${CODEX_TRANSFER_HOME:-$HOME/.local/codex-transfer}"
CONFIG_DIR="${CODEX_TRANSFER_CONFIG_DIR:-$HOME/.codex-transfer}"
B_ENV_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

mkdir -p "$INSTALL_DIR" "$CONFIG_DIR/logs"

if [[ ! -f "$CONFIG_DIR/config.json" ]]; then
  cp "$B_ENV_ROOT/examples/codex-transfer.config.example.json" "$CONFIG_DIR/config.json"
  echo "Created $CONFIG_DIR/config.json from B-Env example"
fi

cd "$INSTALL_DIR"
if [[ ! -f package.json ]]; then
  npm init -y >/dev/null
fi
npm install @classicicn/codex-transfer@^0.4.1

echo "Installed codex-transfer to $INSTALL_DIR"
echo "Binary: $INSTALL_DIR/node_modules/.bin/codex-transfer"
echo "Config: $CONFIG_DIR/config.json"
echo "Next: set GENSTUDIO_API_KEY, then bash $B_ENV_ROOT/scripts/start-codex-transfer.sh"
