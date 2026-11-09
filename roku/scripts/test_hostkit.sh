#!/usr/bin/env bash
# HostKit loader unit tests: code alphabet, activity dedupe, FAQ flatten, cache fallback.
# Run from a scratch root so brs 0.45 does not load the SceneGraph channel.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/source"
cp "$ROOT/channel/components/HostKit.brs" "$WORK/source/HostKit.brs"
cp "$ROOT/scripts/brs_hostkit_check.brs" "$WORK/source/brs_hostkit_check.brs"
printf 'title=HostKitTests\n' > "$WORK/manifest"
output="$(cd "$WORK" && npx --yes brs@0.45.0 --root "$WORK" source/HostKit.brs source/brs_hostkit_check.brs 2>&1)" || true
printf '%s\n' "$output"
printf '%s\n' "$output" | grep -q "brs hostkit checks passed" || { echo "hostkit checks did not pass" >&2; exit 1; }
echo "test_hostkit ok"
