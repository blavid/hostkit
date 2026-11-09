#!/usr/bin/env bash
# Build 43: Things to Do card geometry holds under any text metrics.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
output="$(npx --yes brs@0.45.0 --root "$ROOT/channel" \
    "$ROOT/channel/components/GuestRules.brs" \
    "$ROOT/channel/components/Phase2Ui.brs" \
    "$ROOT/channel/components/NavV2.brs" \
    "$ROOT/scripts/brs_fycard_check.brs" 2>&1)"
printf '%s\n' "$output"
printf '%s\n' "$output" | grep -q "brs fycard checks passed" || { echo "fycard checks did not pass" >&2; exit 1; }
# A row must never carry an empty clip ([0,0,0,0]).
if grep -nE 'clippingRect *= *\[ *0 *, *0 *, *0 *, *0 *\]' channel/components/*.brs; then
    echo "empty clippingRect assignment found (device semantics differ); use FyRowClip" >&2
    exit 1
fi
echo "test_fycard ok"
