#!/usr/bin/env bash
# Exercise deploy.sh without a television.
# A fake curl records its arguments and returns a canned installer page.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REAL_PATH="$PATH"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/curl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" >> "$FAKE_CURL_ARGV"
output=""
args=("$@")
for ((i = 0; i < ${#args[@]}; i++)); do
    if [[ "${args[$i]}" == "--output" ]]; then
        output="${args[$((i + 1))]}"
    fi
done
if [[ -n "$output" ]]; then
    printf '%s' "$FAKE_CURL_BODY" > "$output"
fi
printf '%s' "${FAKE_HTTP_CODE:-200}"
exit "${FAKE_CURL_EXIT:-0}"
EOF
chmod 755 "$TMP/curl"

run_case() {
    local name="$1"
    local body="$2"
    local code="$3"
    local expect="$4"
    local password="$5"
    rm -f "$TMP/argv" "$TMP/out"
    export FAKE_CURL_ARGV="$TMP/argv"
    export FAKE_CURL_BODY="$body"
    export FAKE_HTTP_CODE="$code"
    export FAKE_CURL_EXIT=0
    export PATH="$TMP:$REAL_PATH"
    export ROKUPASS="$password"
    export ROKU_IP="127.0.0.1"
    set +e
    "$ROOT/scripts/deploy.sh" --no-guest >"$TMP/out" 2>&1
    local status=$?
    set -e
    if [[ "$status" -ne "$expect" ]]; then
        echo "FAIL $name exit $status, expected $expect"
        cat "$TMP/out"
        exit 1
    fi
    if grep -F -q "$password" "$TMP/out" "$TMP/argv"; then
        echo "FAIL $name leaked the password into output or curl arguments"
        exit 1
    fi
    echo "ok $name"
}

run_case "success" '<html><font color="red">Install Success.</font>' 200 0 's3cret-value'
run_case "failure" '<html><font color="red">Install Failure: Identical to previous version.</font>' 200 1 's3cret-value'
run_case "auth" '<html>Unauthorized</html>' 401 1 's3cret"value\with-slash'

# Missing password must fail before any upload and must not print a prior secret.
env -u ROKUPASS ROKU_IP=127.0.0.1 PATH="$REAL_PATH" "$ROOT/scripts/deploy.sh" >"$TMP/missing.out" 2>&1 && {
    echo "FAIL missing password exited 0"
    exit 1
}
if grep -q "s3cret" "$TMP/missing.out"; then
    echo "FAIL missing-password output contained a password"
    exit 1
fi
echo "ok missing password"

# Curl config quoting survives a quote and a backslash. Connection failure is expected.
cfg="$TMP/quote.cfg"
ROKUPASS='a"b\c d' ROKU_IP="127.0.0.1" python3 - "$cfg" <<'PY'
import os, sys
password = os.environ["ROKUPASS"]
def curl_quote(value: str) -> str:
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'
with open(sys.argv[1], "w", encoding="utf-8") as handle:
    handle.write("digest\n")
    handle.write("user = " + curl_quote("rokudev:" + password) + "\n")
    handle.write("silent\n")
    handle.write("connect-timeout = 1\n")
    handle.write("max-time = 2\n")
PY
set +e
PATH="$REAL_PATH" curl --config "$cfg" --output /dev/null --write-out "%{http_code}" "http://127.0.0.1:9/plugin_install" >"$TMP/quote.out" 2>"$TMP/quote.err"
quote_status=$?
set -e
if grep -qi "error while reading config" "$TMP/quote.err" || grep -qi "unquoted" "$TMP/quote.err"; then
    echo "FAIL curl rejected the password quoting"
    cat "$TMP/quote.err"
    exit 1
fi
echo "ok curl config quoting (curl exit ${quote_status})"

# The live path Blake runs: deploy.sh (not package.sh) with GUEST_PATH_KEY set.
# Fake curl stands in for the TV. The zip must contain the key, and the
# packaged channel must greet the exact live guest.json body.
exact='{"firstName":"Test","lastName":"Guest","checkout":"2026-10-27"}'
printf '%s' "$exact" > "$TMP/exact.json"
python3 - "$exact" "$ROOT/scripts/brs_guest_check.brs" "$ROOT/scripts/brs_packaged_guest_check.brs" <<'PY'
import sys

exact = sys.argv[1]
needle = exact.replace('"', '""')
for path in sys.argv[2:]:
    text = open(path, encoding="utf-8").read()
    if needle not in text:
        sys.stderr.write("exact guest body missing from a BrightScript check\n")
        sys.exit(1)
PY

python3 - "$TMP/exact.json" "$TMP/stub.port" <<'PY' &
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

body = open(sys.argv[1], "rb").read()

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):  # noqa: N802
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):
        return

server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
with open(sys.argv[2], "w", encoding="utf-8") as handle:
    handle.write(str(server.server_address[1]))
server.serve_forever()
PY
stub_pid=$!
cleanup_stub() {
    if [[ -n "${stub_pid:-}" ]]; then
        kill "$stub_pid" >/dev/null 2>&1 || true
        wait "$stub_pid" 2>/dev/null || true
    fi
}
trap 'cleanup_stub; rm -rf "$TMP"' EXIT

for _ in $(seq 1 20); do
    [[ -s "$TMP/stub.port" ]] && break
    sleep 0.1
done
if [[ ! -s "$TMP/stub.port" ]]; then
    echo "FAIL guest stub did not start"
    exit 1
fi
stub_port="$(cat "$TMP/stub.port")"
stub_ok=0
for _ in 1 2 3 4 5 6 7 8 9 10; do
    if PATH="$REAL_PATH" curl --silent --show-error --max-time 2 \
        "http://127.0.0.1:${stub_port}/guest.json?t=1" > "$TMP/stub.body"; then
        stub_ok=1
        break
    fi
    sleep 0.1
done
if [[ "$stub_ok" -ne 1 ]] || ! cmp -s "$TMP/exact.json" "$TMP/stub.body"; then
    echo "FAIL stub did not serve the live guest body"
    exit 1
fi
echo "ok stub serves the live guest body"

live_key="k$(python3 -c 'import secrets; print(secrets.token_hex(8))')"
rm -f "$TMP/argv" "$TMP/live.out"
export FAKE_CURL_ARGV="$TMP/argv"
export FAKE_CURL_BODY='<html><font color="red">Install Success.</font>'
export FAKE_HTTP_CODE=200
export FAKE_CURL_EXIT=0
export PATH="$TMP:$REAL_PATH"
export ROKUPASS='s3cret-value'
export ROKU_IP="127.0.0.1"
export GUEST_PATH_KEY="$live_key"
set +e
"$ROOT/scripts/deploy.sh" >"$TMP/live.out" 2>&1
live_status=$?
set -e
unset GUEST_PATH_KEY
if [[ "$live_status" -ne 0 ]]; then
    echo "FAIL live deploy.sh exited $live_status"
    exit 1
fi
if grep -F -q "$live_key" "$TMP/live.out" "$TMP/argv"; then
    echo "FAIL live deploy printed or passed the path key"
    exit 1
fi
if ! grep -q "Guest fetch: live." "$TMP/live.out"; then
    echo "FAIL live deploy did not take the live guest path"
    exit 1
fi
if ! unzip -p "$ROOT/dist/eaglewood.zip" components/secrets.brs | grep -F -q "$live_key"; then
    echo "FAIL deploy.sh zip is missing the path key"
    exit 1
fi
if ! unzip -p "$ROOT/dist/eaglewood.zip" components/GuestTask.xml | grep -F -q "pkg:/components/secrets.brs"; then
    echo "FAIL deploy.sh zip does not reference secrets.brs from the task"
    exit 1
fi
if ! unzip -p "$ROOT/dist/eaglewood.zip" manifest | grep -q "build_version=29"; then
    echo "FAIL deploy.sh zip is not build 26"
    exit 1
fi
echo "ok deploy.sh packages the path key"

pkg="$TMP/pkg"
rm -rf "$pkg"
mkdir -p "$pkg"
unzip -q "$ROOT/dist/eaglewood.zip" -d "$pkg"
packaged="$(npx --yes brs@0.45.0 \
    --root "$pkg" \
    "$pkg/components/secrets.brs" \
    "$pkg/components/GuestConfig.brs" \
    "$pkg/components/GuestRules.brs" \
    "$pkg/components/GuestTask.brs" \
    "$ROOT/scripts/brs_packaged_guest_check.brs")"
if printf '%s\n' "$packaged" | grep -F -q "$live_key"; then
    echo "FAIL packaged guest check printed the path key"
    exit 1
fi
if ! printf '%s\n' "$packaged" | grep -q "packaged live guest ok"; then
    echo "FAIL packaged channel did not greet Test Guest"
    printf '%s\n' "$packaged" | grep -E '^(FAIL|packaged) ' || true
    exit 1
fi
if printf '%s\n' "$packaged" | grep -q "not yet implemented"; then
    echo "FAIL packaged channel uses a BrightScript call brs cannot run"
    exit 1
fi
echo "ok packaged channel shows Welcome, Test Guest"
echo "deploy tests ok"
