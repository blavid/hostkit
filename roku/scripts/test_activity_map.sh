#!/usr/bin/env bash
# Map the live activities file with the scene's ItemOnScreen rules.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
dest="$ROOT/channel/data/activities-live.json"
guide="$ROOT/channel/data/guide-live.json"
cleanup() { rm -f "$dest" "$guide"; }
trap cleanup EXIT

curl -fsSL -A "EaglewoodQrCheck/22" -o "$dest" "https://sunrivertownhome.com/data/activities.json"
curl -fsSL -A "EaglewoodQrCheck/22" -o "$guide" "https://sunrivertownhome.com/data/guide.json"
output="$(npx --yes brs@0.45.0 \
    --root "$ROOT/channel" \
    "$ROOT/channel/components/GuideModel.brs" \
    "$ROOT/channel/components/Menu.brs" \
    "$ROOT/channel/components/GuestRules.brs" \
    "$ROOT/channel/components/GuideUi.brs" \
    "$ROOT/channel/components/Season.brs" \
    "$ROOT/channel/components/Phase2Ui.brs" \
    "$ROOT/scripts/brs_activity_map.brs")"
printf '%s\n' "$output"
if ! printf '%s\n' "$output" | grep -q "activity map passed"; then
    echo "activity map did not pass" >&2
    exit 1
fi
if printf '%s\n' "$output" | grep -q "not yet implemented"; then
    echo "brs is missing a runtime call the channel uses" >&2
    exit 1
fi
