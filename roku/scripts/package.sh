#!/usr/bin/env bash
# Zip the channel with manifest at the archive root. Roku rejects a zip that
# wraps the channel in an extra folder.
# The guest path key is written only into the staged copy of secrets.brs.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CHANNEL="$ROOT/channel"
OUT="$ROOT/dist"
ZIP="$OUT/eaglewood.zip"
LIMIT=$((4 * 1024 * 1024))

NO_GUEST=0
STUB_URL=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-guest)
            NO_GUEST=1
            shift
            ;;
        --stub)
            if [[ $# -lt 2 ]]; then
                echo "--stub requires a guest.json URL." >&2
                exit 2
            fi
            STUB_URL="$2"
            shift 2
            ;;
        *)
            echo "Unknown argument." >&2
            exit 2
            ;;
    esac
done

if [[ "$NO_GUEST" -eq 1 && -n "$STUB_URL" ]]; then
    echo "Use either --no-guest or --stub, not both." >&2
    exit 2
fi

python3 "$ROOT/scripts/check_tracked_guest_key.py"

STAGE="$(mktemp -d)"
cleanup() {
    rm -rf "$STAGE"
}
trap cleanup EXIT

mkdir -p "$STAGE"
cp -a "$CHANNEL/." "$STAGE/"
rm -f "$STAGE/components/secrets.brs"
# The screenshot harness marker must never ship.
rm -rf "$STAGE/emu"
short_commit="$(git -C "$ROOT" rev-parse --short=7 HEAD 2>/dev/null || true)"
python3 - "$STAGE/components/BuildStamp.brs" "$short_commit" <<'PY'
import pathlib
import re
import sys

path, short = sys.argv[1], sys.argv[2]
file = pathlib.Path(path)
text = file.read_text(encoding="utf-8")
placeholder = 'return "unknown"'
if placeholder not in text:
    sys.stderr.write("BuildStamp.brs is missing the commit placeholder.\n")
    sys.exit(1)
if not re.fullmatch(r"[0-9a-f]{7}", short or ""):
    sys.stderr.write("Package could not read a 7-character commit.\n")
    sys.exit(1)
file.write_text(text.replace(placeholder, f'return "{short}"', 1), encoding="utf-8")
PY

if [[ "$NO_GUEST" -eq 1 ]]; then
    python3 "$ROOT/scripts/write_guest_secrets.py" --dest "$STAGE/components/secrets.brs" --no-guest
elif [[ -n "$STUB_URL" ]]; then
    GUEST_STUB_URL="$STUB_URL" python3 "$ROOT/scripts/write_guest_secrets.py" \
        --dest "$STAGE/components/secrets.brs" \
        --stub-from-env
else
    python3 "$ROOT/scripts/write_guest_secrets.py" --dest "$STAGE/components/secrets.brs" --key-from-env
fi

mkdir -p "$OUT/snapshot"
python3 "$ROOT/scripts/guide_snapshot.py" --into-stage "$STAGE" --snapshot-dir "$OUT/snapshot"

rm -f "$ZIP"
(
    cd "$STAGE"
    zip -r -X -D "$ZIP" manifest source components images data -x '*.DS_Store' -x '*/.DS_Store'
)

python3 - "$ZIP" <<'PY'
import sys
import zipfile

import json

path = sys.argv[1]
required = ("manifest", "components/secrets.brs", "data/guide.json", "data/checkout.json", "data/activities.json")
with zipfile.ZipFile(path) as archive:
    names = archive.namelist()
    missing = [name for name in required if name not in names]
    if missing:
        sys.stderr.write("Package is missing " + ", ".join(missing) + ".\n")
        sys.exit(1)
    if any(name.startswith("channel/") for name in names):
        sys.stderr.write("Package wraps the channel in an extra folder.\n")
        sys.exit(1)
    if "data/wifi.json" in names or "data/wifi.png" in names:
        sys.stderr.write("Package must not include Wi-Fi secrets.\n")
        sys.exit(1)
    for name in ("data/guide.json", "data/checkout.json", "data/activities.json"):
        try:
            payload = json.loads(archive.read(name).decode("utf-8"))
        except (UnicodeError, json.JSONDecodeError):
            sys.stderr.write(name + " is not UTF-8 JSON.\n")
            sys.exit(1)
        if not isinstance(payload, dict):
            sys.stderr.write(name + " is not a JSON object.\n")
            sys.exit(1)
    activities = json.loads(archive.read("data/activities.json").decode("utf-8"))
    if not isinstance(activities.get("activitySections"), list):
        sys.stderr.write("data/activities.json is missing activitySections.\n")
        sys.exit(1)
PY

bytes="$(wc -c < "$ZIP" | tr -d ' ')"
echo "Packaged ${ZIP} (${bytes} bytes)"
if (( bytes > LIMIT )); then
    echo "Package is ${bytes} bytes, over the 4 MB certification limit (${LIMIT})." >&2
    exit 1
fi
