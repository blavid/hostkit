#!/usr/bin/env bash
# Sideload the channel to the Eaglewood Roku.
# ROKUPASS is the developer-mode password. It is read from the environment,
# written into a 0600 curl config file, and never placed on a command line.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ROKU_IP="${ROKU_IP:-192.168.86.101}"

if [[ -z "${ROKUPASS:-}" ]]; then
    echo "ROKUPASS is not set. Export the developer-mode password and run this again." >&2
    exit 2
fi

if [[ ! "$ROKU_IP" =~ ^[A-Za-z0-9._:-]+$ ]]; then
    echo "ROKU_IP contains characters this script will not put in a URL." >&2
    exit 2
fi

"$ROOT/scripts/package.sh" "$@"
ZIP="$ROOT/dist/eaglewood.zip"

umask 077
cfg="$(mktemp)"
body="$(mktemp)"
cleanup() {
    rm -f "$cfg" "$body"
}
trap cleanup EXIT

ROKU_IP="$ROKU_IP" python3 - "$cfg" <<'PY'
import os
import sys

path = sys.argv[1]
password = os.environ["ROKUPASS"]
if any(ord(ch) < 32 for ch in password):
    sys.stderr.write("ROKUPASS contains a control character. Choose a developer password without one.\n")
    sys.exit(2)

def curl_quote(value: str) -> str:
    escaped = value.replace("\\", "\\\\").replace('"', '\\"')
    return '"' + escaped + '"'

with open(path, "w", encoding="utf-8") as handle:
    handle.write("digest\n")
    handle.write("silent\n")
    handle.write("show-error\n")
    handle.write("connect-timeout = 10\n")
    handle.write("max-time = 180\n")
    handle.write("user = " + curl_quote("rokudev:" + password) + "\n")
PY

echo "Uploading ${ZIP} to http://${ROKU_IP}/plugin_install"
set +e
http_code="$(
    curl --config "$cfg" \
        -F "mysubmit=Install" \
        -F "archive=@${ZIP};filename=eaglewood.zip" \
        -F "passwd=" \
        --output "$body" \
        --write-out "%{http_code}" \
        "http://${ROKU_IP}/plugin_install"
)"
curl_status=$?
set -e

if [[ "$curl_status" -ne 0 && ( -z "$http_code" || "$http_code" == "000" ) ]]; then
    echo "Could not reach the TV at ${ROKU_IP} (curl exit ${curl_status})." >&2
    exit 1
fi

python3 "$ROOT/scripts/install_result.py" "$http_code" < "$body"
