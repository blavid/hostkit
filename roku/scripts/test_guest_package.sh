#!/usr/bin/env bash
# Package-time guest key handling. The key is generated in this process and
# must not be printed. A failure that would require showing command output
# is reported without that output when the key might be in it.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"; rm -f "$ROOT/channel/components/secrets.brs"' EXIT

part="samplekey"
sample="https://sunrivertownhome.com/tv/${part}/guest.json"
pattern='sunrivertownhome\.com/tv/[A-Za-z0-9._~-]+/guest\.json'
if ! printf '%s\n' "$sample" | grep -E -q "$pattern"; then
    echo "FAIL key pattern does not match a concrete guest URL"
    exit 1
fi
placeholder='https://sunrivertownhome.com/tv/<GUEST_PATH_KEY>/guest.json'
if printf '%s\n' "$placeholder" | grep -E -q "$pattern"; then
    echo "FAIL key pattern matches the documentation placeholder"
    exit 1
fi

python3 "$ROOT/scripts/check_tracked_guest_key.py" >"$TMP/check.out"
echo "ok tracked files have no guest path key"
python3 "$ROOT/scripts/test_tracked_guest_key.py"

env -u GUEST_PATH_KEY "$ROOT/scripts/package.sh" >"$TMP/missing.out" 2>&1 && {
    echo "FAIL package without a key exited 0"
    exit 1
}
if ! grep -q "GUEST_PATH_KEY is not set" "$TMP/missing.out"; then
    echo "FAIL missing-key error did not name GUEST_PATH_KEY"
    exit 1
fi
echo "ok missing key"

"$ROOT/scripts/package.sh" --no-guest >"$TMP/off.out"
if ! unzip -p "$ROOT/dist/eaglewood.zip" components/secrets.brs | grep -q 'return ""'; then
    echo "FAIL --no-guest package did not write an empty key"
    exit 1
fi
echo "ok --no-guest"

marker="LOCAL_SECRETS_MARKER"
printf '%s\n' "$marker" > "$ROOT/channel/components/secrets.brs"
"$ROOT/scripts/package.sh" --no-guest >"$TMP/local.out"
if unzip -p "$ROOT/dist/eaglewood.zip" components/secrets.brs | grep -q "$marker"; then
    echo "FAIL package kept a workspace secrets file"
    exit 1
fi
if ! grep -q "$marker" "$ROOT/channel/components/secrets.brs"; then
    echo "FAIL package rewrote the workspace secrets file"
    exit 1
fi
rm -f "$ROOT/channel/components/secrets.brs"
echo "ok workspace secrets file stays out of the zip"

key="k$(python3 -c 'import secrets; print(secrets.token_hex(8))')"
before="$(find "$ROOT/channel" -type f -print0 | sort -z | xargs -0 sha256sum)"
if ! GUEST_PATH_KEY="$key" "$ROOT/scripts/package.sh" >"$TMP/live.out" 2>&1; then
    echo "FAIL live package exited nonzero"
    exit 1
fi
if grep -F -q "$key" "$TMP/live.out"; then
    echo "FAIL package output contained the path key"
    exit 1
fi
if ! unzip -p "$ROOT/dist/eaglewood.zip" components/secrets.brs | grep -F -q "$key"; then
    echo "FAIL zip did not contain the path key"
    exit 1
fi
after="$(find "$ROOT/channel" -type f -print0 | sort -z | xargs -0 sha256sum)"
if [[ "$before" != "$after" ]]; then
    echo "FAIL live package changed tracked channel files"
    exit 1
fi
if git -C "$ROOT" ls-files --error-unmatch channel/components/secrets.brs >/dev/null 2>&1; then
    echo "FAIL secrets.brs is tracked"
    exit 1
fi
echo "ok live key injected only into the zip"

stub="http://127.0.0.1:8765/guest.json"
if ! GUEST_PATH_KEY="$key" "$ROOT/scripts/package.sh" --stub "$stub" >"$TMP/stub.out" 2>&1; then
    echo "FAIL stub package exited nonzero"
    exit 1
fi
if grep -F -q "$key" "$TMP/stub.out"; then
    echo "FAIL stub package output contained the path key"
    exit 1
fi
stub_file="$(unzip -p "$ROOT/dist/eaglewood.zip" components/secrets.brs)"
if ! printf '%s\n' "$stub_file" | grep -F -q "$stub"; then
    echo "FAIL stub package did not contain the stub URL"
    exit 1
fi
if printf '%s\n' "$stub_file" | grep -F -q "$key"; then
    echo "FAIL stub package contained the live path key"
    exit 1
fi
echo "ok stub package ignores the live key"

if GUEST_PATH_KEY='has"quote' "$ROOT/scripts/package.sh" >"$TMP/bad.out" 2>&1; then
    echo "FAIL a quoted key was accepted"
    exit 1
fi
if grep -F -q 'has"quote' "$TMP/bad.out"; then
    echo "FAIL rejected-key output contained the key"
    exit 1
fi
echo "ok quoted key rejected"

if "$ROOT/scripts/package.sh" --no-guest --stub "$stub" >"$TMP/both.out" 2>&1; then
    echo "FAIL --no-guest and --stub were accepted together"
    exit 1
fi
echo "ok conflicting flags rejected"
echo "guest package tests ok"
