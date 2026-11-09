#!/usr/bin/env python3
"""HostKit M2 emulator tour: intro, pairing, claim, Home, offline cache, expiry."""

from __future__ import annotations

import hashlib
import json
import os
import re
import shutil
import signal
import subprocess
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.request import Request, urlopen

ROOT = Path(os.environ["EMU_ROOT"])
WORK = Path(os.environ["EMU_WORK"])
OUT = Path(os.environ["EMU_OUT"])
HOSTKIT_ROOT = Path(os.environ["HOSTKIT_ROOT"])
CLI = os.environ["EMU_CLI"]
NODE_PATH = os.environ["EMU_NODE_PATH"]
PORT = os.environ["EMU_PORT"]
FIX_PORT = int(os.environ["EMU_FIXTURE_PORT"])
WORKER_PORT = int(os.environ["HOSTKIT_WORKER_PORT"])
SESSION = os.environ["EMU_SESSION"]
TMUX = ["tmux", "-f", "/exec-daemon/tmux.portal.conf"]
SNAP = WORK / "snap.png"
LOG = WORK / "emu.log"
ORIGIN = f"http://127.0.0.1:{FIX_PORT}"
WORKER = f"http://127.0.0.1:{WORKER_PORT}"
HOST = {"Authorization": "Bearer host-preview", "Content-Type": "application/json"}
FAKE_KEY = "emu-fixture-key"
FIX = WORK / "fixtures"

WORKER_PROC = None
PANE_PID = None


class Handler(BaseHTTPRequestHandler):
    def do_GET(self) -> None:
        target = FIX / self.path.split("?", 1)[0].lstrip("/")
        if not target.is_file():
            self.send_response(404)
            self.end_headers()
            return
        body = target.read_bytes()
        kind = {".json": "application/json", ".png": "image/png", ".jpg": "image/jpeg"}.get(target.suffix, "application/octet-stream")
        self.send_response(200)
        self.send_header("Content-Type", kind)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt: str, *args: object) -> None:
        return


def start_worker() -> None:
    global WORKER_PROC
    stop_worker()
    env = os.environ.copy()
    env["PORT"] = str(WORKER_PORT)
    env["PUBLIC_BASE"] = WORKER
    env["ALLOW_TEST_HOOKS"] = "1"
    env["HOST_TOKEN"] = "host-preview"
    log = open(WORK / "worker.log", "w")
    WORKER_PROC = subprocess.Popen(
        [sys.executable.replace("python3", "node") if False else "node", str(HOSTKIT_ROOT / "worker" / "server.js")],
        cwd=str(HOSTKIT_ROOT / "worker"),
        env=env,
        stdout=log,
        stderr=subprocess.STDOUT,
        start_new_session=True,
    )
    deadline = time.time() + 10
    last_err = ""
    while time.time() < deadline:
        try:
            urlopen(f"{WORKER}/health", timeout=1).read()
            print(f"worker   {WORKER} pid={WORKER_PROC.pid}", flush=True)
            return
        except Exception as err:
            last_err = str(err)
            if WORKER_PROC.poll() is not None:
                break
            time.sleep(0.1)
    raise RuntimeError(f"worker did not start: {last_err}\n{(WORK / 'worker.log').read_text(errors='replace')[-1000:]}")


def stop_worker() -> None:
    global WORKER_PROC
    if WORKER_PROC is None:
        return
    pid = WORKER_PROC.pid
    try:
        os.killpg(pid, signal.SIGTERM)
    except (ProcessLookupError, PermissionError, OSError):
        try:
            WORKER_PROC.terminate()
        except Exception:
            pass
    try:
        WORKER_PROC.wait(timeout=5)
    except Exception:
        try:
            os.killpg(pid, signal.SIGKILL)
        except Exception:
            pass
    WORKER_PROC = None


def http_json(method: str, path: str, body: dict | None = None, headers: dict | None = None) -> tuple[int, dict]:
    data = None if body is None else json.dumps(body).encode()
    req = Request(WORKER + path, data=data, method=method, headers=headers or {})
    try:
        with urlopen(req, timeout=8) as response:
            raw = response.read()
            return response.status, json.loads(raw.decode() or "{}")
    except Exception as err:
        status = getattr(getattr(err, "code", None), "__int__", lambda: 0)()
        if hasattr(err, "code"):
            status = err.code
            raw = getattr(err, "read", lambda: b"{}")()
            try:
                return status, json.loads(raw.decode() or "{}")
            except Exception:
                return status, {}
        raise


def build_fixtures() -> None:
    data = FIX / "data"
    data.mkdir(parents=True, exist_ok=True)
    for name in ["guide.json", "checkout.json", "activities.json", "menu.json"]:
        text = (ROOT / "channel/data" / name).read_text(encoding="utf-8")
        (data / name).write_text(text.replace("https://sunrivertownhome.com", ORIGIN), encoding="utf-8")
    wifi = FIX / "tv" / FAKE_KEY
    wifi.mkdir(parents=True, exist_ok=True)
    (wifi / "wifi.json").write_text(json.dumps({"ssid": "TestNet", "password": "{{WIFI_PASSWORD}}"}), encoding="utf-8")


def build_stage(name: str, *, configured: bool = False, worker_url: str = WORKER) -> Path:
    stage = WORK / f"stage-{name}"
    if stage.exists():
        shutil.rmtree(stage)
    shutil.copytree(ROOT / "channel", stage)
    (stage / "emu").mkdir(exist_ok=True)
    (stage / "emu" / "enabled").write_text("screenshot harness\n", encoding="utf-8")
    (stage / "components" / "secrets.brs").write_text(
        "' emulator fixture only\n"
        f'function GuestPathKey() as string\n    return "{FAKE_KEY}"\nend function\n\n'
        'function GuestStubUrl() as string\n    return ""\nend function\n',
        encoding="utf-8",
    )
    (stage / "config").mkdir(exist_ok=True)
    (stage / "config" / "hostkit.json").write_text(json.dumps({"baseUrl": worker_url}) + "\n", encoding="utf-8")
    if configured:
        config_text = (HOSTKIT_ROOT / "schema" / "eaglewood.customer0.json").read_text(encoding="utf-8")
        seed = {"deviceToken": "emu-offline-token", "propertyId": "eaglewood", "configText": config_text}
        (stage / "emu" / "hostkit-seed.json").write_text(json.dumps(seed), encoding="utf-8")
    for path in list((stage / "components").glob("*.brs")) + list((stage / "data").glob("*.json")):
        text = path.read_text(encoding="utf-8")
        path.write_text(text.replace("https://sunrivertownhome.com", ORIGIN), encoding="utf-8")
    return stage


def tmux(*args: str, check: bool = True) -> subprocess.CompletedProcess:
    return subprocess.run([*TMUX, *args], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=check)


def pane_pid() -> int | None:
    proc = subprocess.run([*TMUX, "list-panes", "-t", f"{SESSION}:0.0", "-F", "#{pane_pid}"], capture_output=True, text=True)
    if proc.returncode != 0:
        return None
    text = proc.stdout.strip().splitlines()
    if not text:
        return None
    try:
        return int(text[0])
    except ValueError:
        return None


def kill_pid_tree(pid: int) -> None:
    """Kill only this pid and its descendants. Never a broad pkill."""
    children = []
    try:
        out = subprocess.check_output(["ps", "-o", "pid=", "--ppid", str(pid)], text=True)
        for line in out.split():
            try:
                children.append(int(line))
            except ValueError:
                pass
    except Exception:
        pass
    for child in children:
        kill_pid_tree(child)
    try:
        os.kill(pid, signal.SIGTERM)
    except (ProcessLookupError, PermissionError, OSError):
        return


def stop_emu() -> None:
    global PANE_PID
    pid = PANE_PID or pane_pid()
    tmux("send-keys", "-t", f"{SESSION}:0.0", "C-c", check=False)
    time.sleep(0.2)
    tmux("kill-session", "-t", SESSION, check=False)
    if pid:
        kill_pid_tree(pid)
    PANE_PID = None
    time.sleep(0.2)


def log_text() -> str:
    return LOG.read_text(encoding="utf-8", errors="replace") if LOG.exists() else ""


def wait_log(pattern: str, seconds: float) -> None:
    deadline = time.time() + seconds
    rx = re.compile(pattern)
    while time.time() < deadline:
        if rx.search(log_text()):
            return
        time.sleep(0.15)
    raise RuntimeError(f"emulator did not log /{pattern}/\n{log_text()[-2000:]}")


def launch(stage: Path, keys: list[str], ready: str) -> None:
    global PANE_PID
    stop_emu()
    for f in (LOG, SNAP):
        if f.exists():
            f.unlink()
    tmux("new-session", "-d", "-s", SESSION, "-x", "200", "-y", "50", "-c", str(WORK))
    link = f" --deep-link emuKeys={'-'.join(keys)}" if keys else ""
    cmd = (
        f"export BRS_NO_UPDATE_CHECK=1 BRS_ECP_PORT={PORT} NODE_PATH={NODE_PATH}; "
        f"{CLI} --root {stage} --snapshot {SNAP} --log {LOG} --colors 0{link}"
    )
    tmux("send-keys", "-t", f"{SESSION}:0.0", cmd, "C-m")
    PANE_PID = pane_pid()
    wait_log(ready, 60)
    if keys:
        wait_log("emu keys done", 60)


def snapshot() -> bytes:
    last = b""
    for _ in range(10):
        if SNAP.exists():
            SNAP.unlink()
        tmux("send-keys", "-t", f"{SESSION}:0.0", "C-s", check=False)
        deadline = time.time() + 5
        while time.time() < deadline and not (SNAP.exists() and SNAP.read_bytes().endswith(b"IEND\xaeB`\x82")):
            time.sleep(0.1)
        if not SNAP.exists():
            continue
        data = SNAP.read_bytes()
        if data == last:
            return data
        last = data
        time.sleep(0.5)
    if last:
        return last
    raise RuntimeError("snapshot was not saved")


def last_code() -> str:
    codes = re.findall(r"HostKit: pair start code=([A-HJ-NP-Z2-9]{6})", log_text())
    if not codes:
        raise RuntimeError(f"no pairing code in log\n{log_text()[-1500:]}")
    return codes[-1]


def capture(slug: str, shows: str, keys: list[str], ready: str, stage: Path, wait: float = 0.8, need: list[str] | None = None) -> dict:
    launch(stage, keys, ready)
    if need:
        for pat in need:
            wait_log(pat, 20)
    time.sleep(wait)
    data = snapshot()
    (OUT / f"{slug}.png").write_bytes(data)
    (OUT / f"{slug}.log").write_text(log_text(), encoding="utf-8")
    digest = hashlib.sha256(data).hexdigest()
    return {"slug": slug, "shows": shows, "keys": keys, "data": data, "digest": digest, "log": log_text()}


def log_errors(text: str) -> list[str]:
    io_warn = [l for l in text.splitlines() if re.search(r"BRIGHTSCRIPT: ERROR: (Write|Read)AsciiFile: file open for (write|read) failed", l)]
    return [
        l
        for l in text.splitlines()
        if l not in io_warn
        and ("Type Mismatch" in l or re.search(r"pkg:/\S+\(\d+", l) or ("error" in l.lower() and ("HostKit" in l or "Eaglewood" in l)))
    ]


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    build_fixtures()
    fixture = ThreadingHTTPServer(("127.0.0.1", FIX_PORT), Handler)
    threading.Thread(target=fixture.serve_forever, daemon=True).start()
    start_worker()
    unconfigured = build_stage("unconfigured", configured=False, worker_url=WORKER)
    offline = build_stage("offline", configured=True, worker_url="http://127.0.0.1:8799")
    rows = []
    seen: dict[str, str] = {}
    failed = 0

    def record(item: dict, status: str, note: str) -> None:
        nonlocal failed
        digest = item.get("digest", "")
        if status == "captured" and digest:
            if digest in seen:
                status, note = "fail", f"same pixels as {seen[digest]}"
            else:
                seen[digest] = item["slug"]
        if status == "captured":
            errors = log_errors(item.get("log", ""))
            if errors:
                status, note = "fail", "; ".join(errors[:2])
        if status == "fail":
            failed += 1
        rows.append((item["slug"], f"{item['slug']}.png", item["shows"], "-".join(item.get("keys") or []) or "(none)", status, note, digest if status != "fail" or "same pixels" in note else ""))
        print(f"{status:8} {item['slug']} {note}", flush=True)

    try:
        intro1 = capture("intro-1", "Marketing intro 1: HostKit pitch", [], r"HostKit: screen=intro-1", unconfigured)
        record(intro1, "captured", "intro page 1")

        intro2 = capture("intro-2", "Marketing intro 2: Set up once", ["OK"], r"HostKit: screen=intro-1", unconfigured)
        if "HostKit: screen=intro-2" not in intro2["log"]:
            record(intro2, "fail", "did not reach intro-2")
        else:
            record(intro2, "captured", "intro page 2")

        intro3 = capture("intro-3", "Marketing intro 3: Ready to pair", ["OK", "OK"], r"HostKit: screen=intro-1", unconfigured)
        if "HostKit: screen=intro-3" not in intro3["log"]:
            record(intro3, "fail", "did not reach intro-3")
        else:
            record(intro3, "captured", "intro page 3")

        pairing = capture(
            "pairing",
            "Pairing: 6-character code, short URL, QR",
            ["OK", "OK", "OK"],
            r"HostKit: screen=intro-1",
            unconfigured,
            wait=1.2,
            need=[r"HostKit: screen=pairing", r"HostKit: pair start code="],
        )
        code = ""
        try:
            code = last_code()
            note = f"code={code}"
            if not re.fullmatch(r"[A-HJ-NP-Z2-9]{6}", code):
                record(pairing, "fail", f"illegal code {code}")
            else:
                record(pairing, "captured", note)
        except Exception as err:
            record(pairing, "fail", str(err).splitlines()[0])

        # Claim through the local Worker while this pairing session is still up.
        if code:
            status, body = http_json("POST", "/v1/pair/claim", {"code": code, "propertyId": "eaglewood"}, HOST)
            if status != 200:
                record({"slug": "home-configured", "shows": "Configured Home after claim", "keys": ["OK", "OK", "OK"], "digest": "", "log": log_text()}, "fail", f"claim HTTP {status} {body}")
            else:
                try:
                    wait_log(r"HostKit: paired", 20)
                    wait_log(r"HostKit: config source=", 20)
                    wait_log(r"Eaglewood: screen=home zone=", 30)
                    time.sleep(1.0)
                    data = snapshot()
                    (OUT / "home-configured.png").write_bytes(data)
                    (OUT / "home-configured.log").write_text(log_text(), encoding="utf-8")
                    item = {"slug": "home-configured", "shows": "Configured Home after the Worker claim", "keys": ["OK", "OK", "OK"], "data": data, "digest": hashlib.sha256(data).hexdigest(), "log": log_text()}
                    source = re.findall(r"HostKit: config source=(\S+)", item["log"])
                    record(item, "captured", f"claimed {code}; config source={source[-1] if source else 'missing'}")
                except Exception as err:
                    (OUT / "home-configured.log").write_text(log_text(), encoding="utf-8")
                    record({"slug": "home-configured", "shows": "Configured Home after the Worker claim", "keys": [], "digest": "", "log": log_text()}, "fail", str(err).splitlines()[0])
        else:
            record({"slug": "home-configured", "shows": "Configured Home after the Worker claim", "keys": [], "digest": "", "log": ""}, "fail", "no code to claim")

        # Restart with the Worker down and a seeded last-good cache.
        stop_worker()
        offline_cap = capture(
            "home-offline",
            "Configured Home from cached config while the Worker is offline",
            [],
            r"Eaglewood: screen=home zone=",
            offline,
            wait=1.0,
            need=[r"HostKit: config source=cachefs"],
        )
        if "HostKit: config source=cachefs" not in offline_cap["log"]:
            record(offline_cap, "fail", "cache fallback not logged")
        else:
            record(offline_cap, "captured", "source=cachefs")

        # Expired code auto-refresh.
        start_worker()
        unconfigured2 = build_stage("unconfigured-expire", configured=False, worker_url=WORKER)
        expired = capture(
            "pairing-refreshed",
            "Pairing screen after the 15-minute code expires and a new code is issued",
            ["OK", "OK", "OK"],
            r"HostKit: screen=intro-1",
            unconfigured2,
            wait=0.8,
            need=[r"HostKit: pair start code="],
        )
        try:
            first = last_code()
            status, body = http_json("POST", "/v1/__test/expire", {"code": first}, HOST)
            if status != 200:
                record(expired, "fail", f"expire hook HTTP {status} {body}")
            else:
                wait_log(r"HostKit: code refreshed", 25)
                wait_log(r"HostKit: pair start code=", 25)
                # Wait until a second, different code is logged.
                deadline = time.time() + 20
                second = first
                while time.time() < deadline:
                    codes = re.findall(r"HostKit: pair start code=([A-HJ-NP-Z2-9]{6})", log_text())
                    if len(codes) >= 2 and codes[-1] != first:
                        second = codes[-1]
                        break
                    time.sleep(0.2)
                time.sleep(0.8)
                data = snapshot()
                (OUT / "pairing-refreshed.png").write_bytes(data)
                (OUT / "pairing-refreshed.log").write_text(log_text(), encoding="utf-8")
                item = {"slug": "pairing-refreshed", "shows": "Pairing screen after the 15-minute code expires and a new code is issued", "keys": ["OK", "OK", "OK"], "digest": hashlib.sha256(data).hexdigest(), "log": log_text()}
                if second == first or "HostKit: code refreshed" not in item["log"]:
                    record(item, "fail", f"code did not refresh (first={first}, last={second})")
                else:
                    record(item, "captured", f"refreshed {first} -> {second}")
        except Exception as err:
            (OUT / "pairing-refreshed.log").write_text(log_text(), encoding="utf-8")
            record(expired if "digest" in expired else {"slug": "pairing-refreshed", "shows": "expired refresh", "keys": [], "digest": "", "log": log_text()}, "fail", str(err).splitlines()[0])
    finally:
        stop_emu()
        stop_worker()
        try:
            fixture.shutdown()
        except Exception:
            pass
        index = OUT / "index.tsv"
        lines = ["screen\tfile\tshows\tkeys\tstatus\tnotes\tsha256\n"]
        lines += ["\t".join(r) + "\n" for r in rows]
        index.write_text("".join(lines), encoding="utf-8")
    print(f"{len(rows)} screens, {len(seen)} unique, {failed} failed")
    if failed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
