#!/usr/bin/env bash
# One strict brs-engine run for HostKit M2: intro, pairing, claim, configured
# Home, offline cache, and expired-code refresh. Reuses emu_strict.py.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-/workspace/eaglewood-logs/hostkit-m2}"
INSTALL="${BRS_EMU_PREFIX:-/tmp/brs-emu}"
export EMU_PORT="${BRS_ECP_PORT:-8061}"
export EMU_FIXTURE_PORT="${EMU_FIXTURE_PORT:-8766}"
export HOSTKIT_WORKER_PORT="${HOSTKIT_WORKER_PORT:-8787}"
export EMU_SESSION="${EMU_TMUX_SESSION:-emu-hostkit-m2}"
export EMU_IDLE_SECONDS="${EMU_IDLE_SECONDS:-6}"

mkdir -p "$OUT"
rm -f "$OUT"/*.png "$OUT"/*.log "$OUT"/index.tsv

if [[ ! -x "$INSTALL/node_modules/.bin/brs-cli" ]]; then
  echo "Installing brs-node into $INSTALL"
  npm install --prefix "$INSTALL" brs-node@2.6.2
fi

python3 "$(dirname "$0")/emu_strict.py" "$INSTALL/node_modules/brs-node/bin/brs.node.js"

CLI_JS="$INSTALL/node_modules/brs-node/bin/brs.cli.js"
python3 - "$CLI_JS" <<'PY'
import pathlib, sys
path = pathlib.Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
old, new = 'displayMode:"720p"', 'displayMode:"1080p"'
if old not in text and new not in text:
    raise SystemExit("brs-cli has no displayMode default to switch to 1080p")
if old in text:
    path.write_text(text.replace(old, new, 1), encoding="utf-8")
PY

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
export EMU_WORK="$WORK"
export EMU_ROOT="$ROOT"
export EMU_OUT="$OUT"
export HOSTKIT_ROOT="$(cd "$ROOT/.." && pwd)"

NODE_BIN="$(command -v node)"
if [[ "$("$NODE_BIN" -p 'process.versions.node.split(".")[0]')" -lt 22 ]]; then
  if [[ ! -x "$INSTALL/node22/node_modules/.bin/node" ]]; then
    npm install --prefix "$INSTALL/node22" node@22 --silent
  fi
  NODE_BIN="$INSTALL/node22/node_modules/.bin/node"
fi
export EMU_CLI="$NODE_BIN $CLI_JS"
export EMU_NODE_PATH="$INSTALL/node_modules"
export BRS_NO_UPDATE_CHECK=1

python3 "$ROOT/scripts/emu_hostkit_m2.py"
echo "frames in $OUT"
