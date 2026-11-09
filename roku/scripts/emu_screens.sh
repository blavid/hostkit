#!/usr/bin/env bash
# Pre-TV pass: run the channel in the free brs-engine CLI and save 1920x1080 frames.
# https://github.com/lvcabral/brs-engine
# Every screen is a fresh brs-cli process opened straight to that view with the
# harness-only launch parameter emuKeys (see EmuKeysFromArgs in main.brs). That
# parameter is honored only when pkg:/emu/enabled exists, which this script adds
# to a temp copy; package.sh strips it, so sideload and store builds ignore it.
#
# Network: the staged copy points every sunrivertownhome.com URL at a local
# fixture server. Wi-Fi uses SSID TestNet / password placeholder under a fake
# path key. No real guest key or Wi-Fi secret is used.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-/workspace/eaglewood-logs/emu-latest}"
INSTALL="${BRS_EMU_PREFIX:-/tmp/brs-emu}"
export EMU_PORT="${BRS_ECP_PORT:-8060}"
export EMU_FIXTURE_PORT="${EMU_FIXTURE_PORT:-8765}"
export EMU_SESSION="${EMU_TMUX_SESSION:-emu-eaglewood}"
export EMU_IDLE_SECONDS="${EMU_IDLE_SECONDS:-6}"
export EMU_ONLY="${EMU_ONLY:-}"

mkdir -p "$OUT"
if [[ -z "$EMU_ONLY" ]]; then rm -f "$OUT"/*.png "$OUT"/index.tsv; fi

if [[ ! -x "$INSTALL/node_modules/.bin/brs-cli" ]]; then
  echo "Installing brs-node into $INSTALL"
  npm install --prefix "$INSTALL" brs-node@2.6.2
fi

# Roku firmware raises Type Mismatch on 1 = "1"; brs-node returns false.
python3 "$(dirname "$0")/emu_strict.py" "$INSTALL/node_modules/brs-node/bin/brs.node.js"

# The CLI device defaults to 720p (docs/customization.md); the channel is FHD only.
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
# brs-node 2.6 uses iterator helpers (Node 22+). Use a local Node 22 when the
# system node is older; nothing is installed globally.
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

python3 "$ROOT/scripts/emu_tour.py"
echo "frames in $OUT"
