#!/usr/bin/env bash
# Run guest name, checkout, and wrap rules on the brs interpreter.
# brs 0.45 does not draw SceneGraph, so this does not open the scene.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
python3 "$ROOT/scripts/write_guest_secrets.py" --dest "$ROOT/channel/components/secrets.brs" --ensure-empty
output="$(npx --yes brs@0.45.0 \
    --root "$ROOT/channel" \
    "$ROOT/channel/components/GuestRules.brs" \
    "$ROOT/scripts/brs_guest_check.brs")"
printf '%s\n' "$output"
if ! printf '%s\n' "$output" | grep -q "brs guest checks passed"; then
    echo "brs guest checks did not pass" >&2
    exit 1
fi
if printf '%s\n' "$output" | grep -q "not yet implemented"; then
    echo "brs is missing a runtime call the channel uses" >&2
    exit 1
fi
