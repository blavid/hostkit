#!/usr/bin/env bash
# Season order, poster and QR fallbacks, and Wi-Fi response modes.
# brs 0.45 does not draw SceneGraph, so this does not open the scene.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
output="$(npx --yes brs@0.45.0 \
    --root "$ROOT/channel" \
    "$ROOT/channel/components/GuideModel.brs" \
    "$ROOT/channel/components/Menu.brs" \
    "$ROOT/channel/components/GuestRules.brs" \
    "$ROOT/channel/components/GuideUi.brs" \
    "$ROOT/channel/components/Season.brs" \
    "$ROOT/channel/components/Phase2Ui.brs" \
    "$ROOT/channel/components/ActivityCard.brs" \
    "$ROOT/scripts/brs_phase2_check.brs")"
printf '%s\n' "$output"
if ! printf '%s\n' "$output" | grep -q "brs phase2 checks passed"; then
    echo "brs phase2 checks did not pass" >&2
    exit 1
fi
if printf '%s\n' "$output" | grep -q "not yet implemented"; then
    echo "brs is missing a runtime call the channel uses" >&2
    exit 1
fi

png="$(npx --yes brs@0.45.0 \
    "$ROOT/channel/components/PngRgb.brs" \
    "$ROOT/scripts/brs_png_check.brs")"
printf '%s\n' "$png"
if ! printf '%s\n' "$png" | grep -q "brs png checks passed"; then
    echo "brs png checks did not pass" >&2
    exit 1
fi
