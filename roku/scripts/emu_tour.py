#!/usr/bin/env python3
"""Open each screen in a fresh brs-cli process and save one PNG per screen.

Each capture launches the staged channel with --deep-link emuKeys=<keys>. The
scene replays those keys before the frame is saved, so no capture depends on
the state of an earlier one. Ctrl+S (tmux) saves the PNG named by --snapshot.
Every PNG must hash differently; a repeat fails the run.
"""

from __future__ import annotations

import math
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

ROOT = Path(os.environ["EMU_ROOT"])
WORK = Path(os.environ["EMU_WORK"])
OUT = Path(os.environ["EMU_OUT"])
CLI = os.environ["EMU_CLI"]
NODE_PATH = os.environ["EMU_NODE_PATH"]
PORT = os.environ["EMU_PORT"]
FIX_PORT = int(os.environ["EMU_FIXTURE_PORT"])
SESSION = os.environ["EMU_SESSION"]
IDLE_SECONDS = int(os.environ["EMU_IDLE_SECONDS"])
ONLY = [s for s in os.environ.get("EMU_ONLY", "").split(",") if s]
TMUX = ["tmux", "-f", "/exec-daemon/tmux.portal.conf"]
SNAP = WORK / "snap.png"
LOG = WORK / "emu.log"
ORIGIN = f"http://127.0.0.1:{FIX_PORT}"
FAKE_KEY = "emu-fixture-key"
IMAGE_CACHE = Path(os.environ.get("EMU_IMAGE_CACHE", "/tmp/emu-eaglewood-images"))
FIX = WORK / "fixtures"

# Rail rows, from menu.json order. Build 40: keys start on the rail's Home row
# (Left there is a no-op, so rail() still works from the start).
RAIL = {"home": 0, "wifi": 1, "todo": 2, "rules": 3, "fixes": 4, "book": 5, "checkout": 6}
TODO = ["dining", "hiking", "winter", "summer", "biking"]


def rail(section: str) -> list[str]:
    return ["Left"] + ["Down"] * RAIL[section]


def fy() -> list[str]:
    return rail("todo") + ["Right"]


def screens() -> list[dict]:
    s: list[dict] = []

    def add(slug: str, keys: list[str], shows: str, stage: str = "key", wait: float = 0.0, need: str = "", same_as: str = "", ecp: list[str] | None = None, visits: list[str] | None = None, card: str = "") -> None:
        # Build 40: the corner ad shows on every page, rail collapsed or not.
        if not card:
            card = "hidden" if AD_HIDDEN(slug) else "qr"
        s.append({"slug": slug, "keys": keys, "shows": shows, "stage": stage, "wait": wait, "need": need, "same_as": same_as, "ecp": ecp or [], "visits": visits or [], "card": card})

    add("home-start-focus", [], "Startup: Home row of the left rail focused (build 40), Home preview and corner ad")
    add("home-rail-focus", rail("home"), "Home, rail Home row focused (Left on the rail is a no-op)", same_as="home-start-focus")
    add("home-prompt-focus", ["Right"], "Home, Book Direct strip focused, QR card and badge")
    add("home-tile-wifi-focus", ["Right", "Down"], "Home, Wi-Fi tile focused")
    add("home-tile-todo-focus", ["Right", "Down", "Right"], "Home, Things to Do tile focused")
    add("home-tile-dining-focus", ["Right", "Down", "Right", "Right"], "Home, Dining tile focused")
    add("home-tile-hiking-focus", ["Right", "Down", "Down"], "Home, Hiking tile focused (bottom row)")
    add("home-tile-fixes-focus", ["Right", "Down", "Down", "Right"], "Home, Quick Fixes tile focused")
    add("home-tile-checkout-focus", ["Right", "Down", "Down", "Right", "Right"], "Home, Checkout tile focused")
    add("rail-wifi-focus", rail("wifi"), "Rail Wi-Fi row focused, Wi-Fi preview")
    add("wifi-with-qr", rail("wifi") + ["Select"], "Wi-Fi with the local TestNet placeholder QR", need="qr wifi")
    add("wifi-error", rail("wifi") + ["Select"], "Wi-Fi with no guest key: status panel, Password Unavailable", stage="nokey")
    # Build 34: Things to Do is the Roku "For You" grid: one card row per
    # non-empty category (Fishing has none, so it has no row).
    add("rail-todo-focus", rail("todo"), "Rail Things to Do focused: For You rows preview beside the expanded rail")
    add("fy-grid", fy(), "For You grid: rail collapsed to icons, Dining row first card focused, 1 of N; corner ad shown")
    add("fy-move-right", fy() + ["Right"], "For You grid, second Dining card focused, 2 of N")
    add("fy-move-right3", fy() + ["Right"] * 3, "For You grid, fourth Dining card, row scrolled")
    if GRID_COLS != 3:
        add(f"fy-move-right{GRID_COLS}", fy() + ["Right"] * GRID_COLS, "For You grid, first scrolled card: arrows both sides")
    add("fy-move-last", fy() + ["Right"] * 9, "For You grid, last Dining card: left arrow only")
    for k, child in enumerate(TODO[1:], 1):
        add(f"fy-row-{child}", fy() + ["Down"] * k, f"For You grid, {child.title()} row focused at the top slot")
    add("fy-left-to-rail", fy() + ["Left"], "Left from the first card returns to the expanded rail on Things to Do", same_as="rail-todo-focus")
    add("fy-detail", fy() + ["Select"], "Card detail (first Dining) with its QR", need="qr detail")
    add("fy-detail-second", fy() + ["Right", "Select"], "Second Dining card detail")
    add("fy-detail-summer", fy() + ["Down"] * TODO.index("summer") + ["Select"], "First Summer card detail with its QR", need="qr detail")
    add("fy-detail-scrolled", fy() + ["Down"] * TODO.index("summer") + ["Select"] + ["Down"] * 3, "First Summer detail, body scrolled")
    add("fy-detail-qr-blocked", fy() + ["Down"] * TODO.index("summer") + ["Select"], "Summer detail with the QR fetch blocked: no-link layout", stage="qrblocked", wait=7)
    add("fy-detail-back", fy() + ["Right", "Select", "Back"], "Back from the card detail returns to the grid on card 2", same_as="fy-move-right")
    add("fy-back-to-rail", fy() + ["Down", "Back"], "Back from the grid returns to the expanded rail", same_as="rail-todo-focus")
    add("rail-rules-focus", rail("rules"), "Rail House Rules focused")
    add("house-rules", rail("rules") + ["Select"], "House Rules page")
    # Build 34: Quick Fixes is the Roku Settings pattern.
    add("rail-fixes-focus", rail("fixes"), "Rail Quick Fixes focused: fix list column shown beside the rail")
    add("fx-list", rail("fixes") + ["Right"], "Fix list focused: rail row reads < Quick Fixes, issue 1 steps preview")
    for index in range(1, 12):
        add(f"fx-list-{index + 1:02d}", rail("fixes") + ["Right"] + ["Down"] * index, f"Fix list, issue {index + 1} focused with its steps preview")
    add("fx-steps", rail("fixes") + ["Right", "Right"], "Issue 1 steps: rail slid off, list is the < breadcrumb column")
    add("fx-steps-03", rail("fixes") + ["Right", "Down", "Down", "Right"], "Issue 3 steps, breadcrumb column")
    add("fx-steps-long", rail("fixes") + ["Right", "Right"], "Fixture long fix steps, top", stage="longfix")
    add("fx-steps-scrolled", rail("fixes") + ["Right", "Right", "Down", "Down", "Down"], "Fixture long fix steps scrolled", stage="longfix")
    add("fx-steps-back", rail("fixes") + ["Right", "Down", "Right", "Left"], "Left from the steps slides back to the fix list on issue 2", same_as="fx-list-02")
    add("fx-list-back", rail("fixes") + ["Right", "Down", "Back"], "Back from the fix list returns to the rail on Quick Fixes", same_as="rail-fixes-focus")
    # Build 32: Blake's TV path, sent as real ECP key presses so they go
    # through roSGScreen focus and onKeyEvent. Each press must log focus=scene.
    blake = ["Left", "Down", "Down", "Select", "Down", "Down", "Up", "Up", "Right", "Right", "Down", "Up", "Left", "Left", "Down", "Up", "Back",
             "Down", "Select", "Back", "Down", "Select", "Down", "Down", "Right", "Down", "Back", "Up", "Back",
             "Down", "Select", "Back", "Down", "Select", "Back", "Up", "Up", "Up", "Up", "Up", "Up", "Select", "Back", "Up", "Up"]
    add("blake-path-focus", [], "Blake's TV path (Things to Do, Dining, moves, back out, every section) as ECP keys; ends on Home rail", ecp=blake, same_as="home-rail-focus",
        visits=["todo", "rules", "fixes", "book", "checkout", "home"])
    # Build 37 QA gate 5: Blake's exact key presses from tv-b36-blake.log, as ECP.
    tv1 = "down up left down up down down down down down down up up right down right down left down right up left right right right down left left down left left down down up left left left left down down up up".split()
    tv2 = "left down down right right right right".split()
    add("tv-replay-1", [], "Replay of Blake's first build 36 TV session (42 presses); no errors, rail highlight tracks", ecp=[k.capitalize() for k in tv1], visits=["todo", "fixes"], same_as="blake-path-focus")
    add("tv-replay-2", [], "Replay of Blake's second build 36 TV session (7 presses)", ecp=[k.capitalize() for k in tv2], visits=["todo"], same_as="fy-move-right3")
    # Build 37 QA gate 3: OK opens a Things to Do item and a Quick Fixes step.
    add("ok-opens-todo", fy() + ["Select"], "OK on the first Things to Do card opens its detail", need="qr detail", same_as="fy-detail")
    add("ok-opens-fix", rail("fixes") + ["Right", "Select"], "OK on the first Quick Fixes item opens its steps", same_as="fx-steps")
    # Build 33: Home badge QR host unreachable; the card keeps its frame and
    # caption and shows the no-link text after the 5 s deadline.
    # Build 34: the corner ad replaces the Home QR card and badge.
    add("ad-2", ["Right", "adnext"], "Home with the second corner ad (rotation frame 2)")
    add("ad-3", ["Right", "adnext", "adnext"], "Home with the third corner ad (rotation frame 3)")
    add("wifi-stale-etag", rail("wifi") + ["Select"], "Stale etags seeded, cache files missing: 304 refetches without the etag, TestNet shown", stage="staleetag", need="qr wifi", same_as="wifi-with-qr")
    add("rail-book-focus", rail("book"), "Rail Book Direct focused, corner ad shown")
    add("book-direct", rail("book") + ["Select"], "Book Direct page: photo, Scan me QR card and text across the box; corner ad shown")
    # Build 41 (TV checklist step 4): Right on the Book Direct rail row opens the page.
    add("book-right-opens", rail("book") + ["Right"], "Right on the rail's Book Direct row opens the page", same_as="book-direct")
    add("rail-checkout-focus", rail("checkout"), "Rail Checkout focused")
    add("checkout", rail("checkout") + ["Select"], "Checkout Instructions page")
    add("home-after-idle", rail("book") + ["Select"], "Home after the idle timer fired on Book Direct", wait=IDLE_SECONDS + 3, same_as="book-direct")
    # HostKit M3: unconfigured intro + pairing screens (Pixel reviews these).
    add("intro-1", [], "Marketing intro 1: HostKit pitch", stage="unconfigured", card="hidden")
    add("intro-2", ["Select"], "Marketing intro 2: Set up once", stage="unconfigured", card="hidden")
    add("intro-3", ["Select", "Select"], "Marketing intro 3: Ready to pair", stage="unconfigured", card="hidden")
    add("pairing", ["Select", "Select", "Select"], "Pairing: 6-character code, short URL, and QR", stage="unconfigured", card="hidden", need="pair")
    add("pairing-refreshed", ["Select", "Select", "Select"], "Pairing screen after the 15-minute code expires and a new code is issued", stage="unconfigured", card="hidden", need="pair-refresh")
    return s


class Handler(BaseHTTPRequestHandler):
    def do_GET(self) -> None:
        path = self.path.split("?", 1)[0]
        if path.startswith("/blocked-qr/"):
            # Network blocked: drop the connection with no response.
            self.close_connection = True
            return
        if self.headers.get("If-None-Match") == STALE_ETAG:
            # Stale etag seeded by stage "staleetag": answer 304 although the
            # channel's cache file is missing (the tv-b33 case).
            self.send_response(304)
            self.end_headers()
            return
        target = FIX / path.lstrip("/")
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


def qr_png(text: str, dest: Path) -> None:
    try:
        import qrcode
    except ImportError:
        subprocess.check_call([sys.executable, "-m", "pip", "install", "qrcode", "pillow", "-q"])
        import qrcode
    dest.parent.mkdir(parents=True, exist_ok=True)
    qrcode.make(text, border=2).convert("RGB").save(dest)


def public_image(path: str, dest: Path) -> None:
    """Public site photos, cached once. Falls back to the packaged placeholder."""
    dest.parent.mkdir(parents=True, exist_ok=True)
    cached = IMAGE_CACHE / path.lstrip("/")
    if not cached.is_file():
        try:
            request = Request("https://sunrivertownhome.com" + path, headers={"User-Agent": "Mozilla/5.0 (eaglewood-emu)"})
            with urlopen(request, timeout=10) as response:
                data = response.read()
            cached.parent.mkdir(parents=True, exist_ok=True)
            cached.write_bytes(data)
        except Exception:
            shutil.copy(ROOT / "channel/images/tv-placeholder.jpg", dest)
            return
    shutil.copy(cached, dest)


def build_fixtures() -> None:
    data = FIX / "data"
    data.mkdir(parents=True, exist_ok=True)
    for name in ["guide.json", "checkout.json", "activities.json", "menu.json"]:
        text = (ROOT / "channel/data" / name).read_text(encoding="utf-8")
        (data / name).write_text(text.replace("https://sunrivertownhome.com", ORIGIN), encoding="utf-8")
    blob = "\n".join((ROOT / "channel" / p).read_text(encoding="utf-8") for p in ["data/guide.json", "data/activities.json", "components/Season.brs"])
    for path in sorted(set(re.findall(r'(?:https://sunrivertownhome\.com)?(/(?:data/qr|images)/[A-Za-z0-9_./-]+\.(?:png|jpg|jpeg))', blob))):
        if "/data/qr/" in path:
            qr_png("EMU TEST QR " + Path(path).stem, FIX / path.lstrip("/"))
        else:
            public_image(path, FIX / path.lstrip("/"))
    wifi = FIX / "tv" / FAKE_KEY
    wifi.mkdir(parents=True, exist_ok=True)
    (wifi / "wifi.json").write_text(json.dumps({"ssid": "TestNet", "password": "{{WIFI_PASSWORD}}"}), encoding="utf-8")
    qr_png("WIFI:T:WPA;S:TestNet;P:placeholder;;", wifi / "wifi.png")


STALE_ETAG = '"emu-stale"'
LONG_FIX_PATH = "/data-longfix/guide.json"
BADGE_BLOCKED_PATH = "/data-badgeblocked/guide.json"
BADGE_QR = "/data/qr/book-direct-booking.png"


def long_fix_guide() -> str:
    """guide.json with one emulator-only fix first whose steps overflow the panel."""
    guide = json.loads((ROOT / "channel/data/guide.json").read_text(encoding="utf-8"))
    steps = []
    for issue in guide.get("troubleshooting") or []:
        steps += issue.get("steps") or []
    guide["troubleshooting"].insert(0, {"issue": "Emulator fixture: long steps", "steps": [" ".join(steps[i:i + 3]) for i in range(0, 24, 3)]})
    return json.dumps(guide, ensure_ascii=False).replace("https://sunrivertownhome.com", ORIGIN)


def hostkit_root() -> Path:
    return Path(os.environ.get("HOSTKIT_ROOT", str(ROOT.parent)))


def load_customer0() -> dict:
    path = hostkit_root() / "schema" / "eaglewood.customer0.json"
    return json.loads(path.read_text(encoding="utf-8"))


def rewrite_hostkit_urls(value):
    if isinstance(value, str):
        return value.replace("https://sunrivertownhome.com", ORIGIN)
    if isinstance(value, list):
        return [rewrite_hostkit_urls(v) for v in value]
    if isinstance(value, dict):
        return {k: rewrite_hostkit_urls(v) for k, v in value.items()}
    return value


def long_fix_hostkit(cfg: dict) -> dict:
    steps = []
    for cat in cfg.get("faqs") or []:
        if cat.get("id") == "quick-fixes":
            for item in cat.get("items") or []:
                steps += item.get("steps") or []
            long_item = {
                "q": "Emulator fixture: long steps",
                "a": " ".join(steps[:24]),
                "steps": [" ".join(steps[i:i + 3]) for i in range(0, 24, 3)],
            }
            cat["items"] = [long_item] + list(cat.get("items") or [])
    return cfg


def write_hostkit_seed(stage: Path, name: str) -> None:
    """Seed a paired device + last-good config so guest screens load from HostKit."""
    hk = stage / "config" / "hostkit.json"
    hk.parent.mkdir(parents=True, exist_ok=True)
    worker = os.environ.get("HOSTKIT_BASE_URL") or f"http://127.0.0.1:{os.environ.get('HOSTKIT_WORKER_PORT', '8787')}"
    if name == "unconfigured":
        # Pairing talks to the local Worker. Do not seed a token.
        hk.write_text(json.dumps({"baseUrl": worker}), encoding="utf-8")
        return
    cfg = load_customer0()
    if name == "longfix":
        cfg = long_fix_hostkit(cfg)
    if name == "qrblocked":
        cfg = json.loads(json.dumps(cfg).replace("/data/qr/", "/blocked-qr/"))
    if name == "badgeblocked":
        cfg = json.loads(json.dumps(cfg).replace("/data/qr/book-direct-booking.png", "/blocked-qr/book-direct-booking.png"))
    cfg = rewrite_hostkit_urls(cfg)
    seed = {"deviceToken": "emu-hostkit-device", "propertyId": "eaglewood", "configText": json.dumps(cfg)}
    (stage / "emu" / "hostkit-seed.json").write_text(json.dumps(seed), encoding="utf-8")
    # Keep the ORIGIN-rewritten cache. An empty base URL skips the Worker fetch,
    # which would otherwise overwrite cache with live sunrivertownhome.com URLs.
    hk.write_text(json.dumps({"baseUrl": ""}), encoding="utf-8")


def build_stage(name: str, key: str) -> Path:
    stage = WORK / f"stage-{name}"
    shutil.copytree(ROOT / "channel", stage)
    if name == "longfix":
        (stage / "data" / "guide.json").write_text(long_fix_guide(), encoding="utf-8")
        (FIX / LONG_FIX_PATH.lstrip("/")).parent.mkdir(parents=True, exist_ok=True)
        (FIX / LONG_FIX_PATH.lstrip("/")).write_text(long_fix_guide(), encoding="utf-8")
        task = stage / "components" / "GuideTask.brs"
        task.write_text(task.read_text(encoding="utf-8").replace("https://sunrivertownhome.com/data/guide.json", "https://sunrivertownhome.com" + LONG_FIX_PATH, 1), encoding="utf-8")
    if name == "badgeblocked":
        blocked = BADGE_QR.replace("/data/qr/", "/blocked-qr/")
        served = FIX / BADGE_BLOCKED_PATH.lstrip("/")
        served.parent.mkdir(parents=True, exist_ok=True)
        served.write_text((FIX / "data" / "guide.json").read_text(encoding="utf-8").replace(BADGE_QR, blocked), encoding="utf-8")
        for path in [stage / "data" / "guide.json", stage / "components" / "Season.brs"]:
            path.write_text(path.read_text(encoding="utf-8").replace(BADGE_QR, blocked), encoding="utf-8")
        task = stage / "components" / "GuideTask.brs"
        task.write_text(task.read_text(encoding="utf-8").replace("https://sunrivertownhome.com/data/guide.json", "https://sunrivertownhome.com" + BADGE_BLOCKED_PATH, 1), encoding="utf-8")
    if name == "qrblocked":
        acts = stage / "data" / "activities.json"
        acts.write_text(acts.read_text(encoding="utf-8").replace("/data/qr/", "/blocked-qr/"), encoding="utf-8")
        served = FIX / "data-qrblocked" / "activities.json"
        served.parent.mkdir(parents=True, exist_ok=True)
        served.write_text((FIX / "data" / "activities.json").read_text(encoding="utf-8").replace("/data/qr/", "/blocked-qr/"), encoding="utf-8")
        task = stage / "components" / "GuideTask.brs"
        task.write_text(task.read_text(encoding="utf-8").replace("https://sunrivertownhome.com/data/activities.json", "https://sunrivertownhome.com/data-qrblocked/activities.json", 1), encoding="utf-8")
    if name == "staleetag":
        seed = "".join(f'    seed.Write("{p}Etag", Chr(34) + "emu-stale" + Chr(34))\n' for p in ["wifiJson", "wifiPng", "guide", "checkout", "activities", "menu"])
        block = '    seed = CreateObject("roRegistrySection", "EaglewoodGuide")\n' + seed + '    seed.Flush()\n    print "Eaglewood: emu seeded stale etags"\n'
        for file, head in [("WifiTask.brs", "sub fetchWifi()\n"), ("GuideTask.brs", "sub fetchGuideBundle()\n")]:
            task = stage / "components" / file
            text = task.read_text(encoding="utf-8")
            if head not in text:
                raise SystemExit(f"{file}: fetch sub not found")
            task.write_text(text.replace(head, head + block, 1), encoding="utf-8")
    (stage / "emu").mkdir()
    (stage / "emu" / "enabled").write_text("screenshot harness\n", encoding="utf-8")
    write_hostkit_seed(stage, name)
    (stage / "components" / "secrets.brs").write_text(
        "' emulator fixture only\n"
        f'function GuestPathKey() as string\n    return "{key}"\nend function\n\n'
        'function GuestStubUrl() as string\n    return ""\nend function\n',
        encoding="utf-8",
    )
    for path in list((stage / "components").glob("*.brs")) + list((stage / "data").glob("*.json")):
        text = path.read_text(encoding="utf-8")
        path.write_text(text.replace("https://sunrivertownhome.com", ORIGIN), encoding="utf-8")
    xml = stage / "components" / "MainScene.xml"
    xml.write_text(xml.read_text(encoding="utf-8").replace('duration="600"', f'duration="{IDLE_SECONDS}"', 1), encoding="utf-8")
    scene = stage / "components" / "MainScene.brs"
    text = scene.read_text(encoding="utf-8")
    if "m.idleTimer.duration = 600" not in text:
        raise SystemExit("idle timer was not found in the staged copy")
    scene.write_text(text.replace("m.idleTimer.duration = 600", f"m.idleTimer.duration = {IDLE_SECONDS}", 1), encoding="utf-8")
    return stage


def tmux(*args: str) -> None:
    subprocess.check_call([*TMUX, *args], stdout=subprocess.DEVNULL)


def stop() -> None:
    subprocess.run([*TMUX, "send-keys", "-t", f"{SESSION}:0.0", "C-c"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    time.sleep(0.3)
    subprocess.run([*TMUX, "kill-session", "-t", SESSION], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    subprocess.run(["pkill", "-f", "brs.cli.js --root"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    time.sleep(0.3)


def log_text() -> str:
    return LOG.read_text(encoding="utf-8", errors="replace") if LOG.exists() else ""


def wait_log(text: str, seconds: float) -> None:
    deadline = time.time() + seconds
    while time.time() < deadline:
        if text in log_text():
            return
        time.sleep(0.2)
    raise RuntimeError(f"emulator did not log {text!r}\n{log_text()[-1500:]}")


def launch(stage: Path, keys: list[str], ecp: bool = False, ready: str = "Eaglewood: screen=home zone=") -> None:
    stop()
    for f in (LOG, SNAP):
        if f.exists():
            f.unlink()
    tmux("new-session", "-d", "-s", SESSION, "-x", "200", "-y", "50", "-c", str(WORK))
    link = f" --deep-link emuKeys={'-'.join(keys)}" if keys else ""
    cmd = (
        f"export BRS_NO_UPDATE_CHECK=1 BRS_ECP_PORT={PORT} NODE_PATH={NODE_PATH}; "
        f"{CLI} --root {stage} --snapshot {SNAP} --log {LOG} --colors 0{link}{' --ecp' if ecp else ''}{os.environ.get('EMU_CLI_EXTRA', '')}"
    )
    tmux("send-keys", "-t", f"{SESSION}:0.0", cmd, "C-m")
    wait_log(ready, 60)
    if keys:
        wait_log("emu keys done", 60)


ECP_NAMES = {"Left": "Left", "Right": "Right", "Up": "Up", "Down": "Down", "Select": "Select", "Back": "Back"}


def send_ecp(keys: list[str]) -> None:
    # The ECP listener can come up a few seconds after the home screen log.
    deadline = time.time() + 30
    while True:
        try:
            urlopen(f"http://127.0.0.1:{PORT}/query/device-info", timeout=3).read()
            break
        except Exception:
            if time.time() > deadline:
                raise
            time.sleep(1)
    for key in keys:
        urlopen(Request(f"http://127.0.0.1:{PORT}/keypress/{ECP_NAMES[key]}", data=b"", method="POST"), timeout=5).read()
        # Build 37: human pace (Blake's TV presses are >= ~0.5 s apart). Back-to-back
        # posts under host load dropped one press of seven in a run (EMULATOR-LIMITS).
        time.sleep(float(os.environ.get("EMU_ECP_GAP", "0.5")))
        time.sleep(float(os.environ.get("EMU_ECP_GAP", "0.9")))


def focus_problems(keys: list[str], visits: list[str]) -> str:
    """Every ECP press must reach the scene with focus=scene, and the path must visit each section in order."""
    lines = log_text().splitlines()
    presses = [l for l in lines if re.search(r"Eaglewood: key \S+ press=true", l)]
    if len(presses) != len(keys):
        return f"{len(presses)} of {len(keys)} key presses reached onKeyEvent"
    stuck = [l for l in presses if "focus=scene" not in l]
    if stuck:
        return f"{len(stuck)} press(es) without scene focus: {stuck[0].strip()}"
    if any("Eaglewood: key error" in l for l in lines):
        return "key error logged"
    screens = [m.group(1) for m in (re.search(r"Eaglewood: screen=(\S+)", l) for l in lines) if m]
    at = 0
    for want in visits:
        while at < len(screens) and screens[at] != want:
            at += 1
        if at == len(screens):
            return f"path never reached {want} in order"
    return ""


# Build 35 corner ad, from NavV2 AdRect (FHD): x 96-534, y 758-972.
CARD_BOX = (96, 758, 534, 972)
AD = {"x0": 96, "y0": 758, "x1": 534, "y1": 972}


def ink_box(img, box, pred):
    im = img.crop(box).convert("RGB")
    w, h = im.size
    px = im.load()
    xs, ys = [], []
    for y in range(h):
        for x in range(w):
            if pred(px[x, y]):
                xs.append(x)
                ys.append(y)
    if not xs:
        return None
    return (box[0] + min(xs), box[1] + min(ys), box[0] + max(xs), box[1] + max(ys))


def first_glyph_box(img, box, pred):
    """Ink box of the first glyph (leftmost run of inked columns) in box."""
    im = img.crop(box).convert("RGB")
    w, h = im.size
    px = im.load()
    cols = [[y for y in range(h) if pred(px[x, y])] for x in range(w)]
    start = next((x for x in range(w) if cols[x]), None)
    if start is None:
        return None
    end = start
    while end + 1 < w and cols[end + 1]:
        end += 1
    ys = [y for x in range(start, end + 1) for y in cols[x]]
    return (box[0] + start, box[1] + min(ys), box[0] + end, box[1] + max(ys))


_CAP_CACHE = {}


def reference_cap_height(size: int, bold: bool = True) -> int:
    """Cap height of "H" in the emulator's own SceneGraph font at size px,
    rendered from brs-node's bundled font (Metropolis; SemiBold for bold)."""
    key = (size, bold)
    if key not in _CAP_CACHE:
        import zipfile
        from PIL import Image, ImageDraw, ImageFont
        name = "fonts/Metropolis-SemiBold.ttf" if bold else "fonts/Metropolis-Regular.ttf"
        assets = os.path.join(os.environ.get("EMU_NODE_PATH", "/tmp/brs-emu/node_modules"), "brs-node", "assets", "common.zip")
        if not os.path.exists(assets):
            assets = "/tmp/brs-emu/node_modules/brs-node/assets/common.zip"
        import io
        font = ImageFont.truetype(io.BytesIO(zipfile.ZipFile(assets).read(name)), size)
        im = Image.new("L", (size * 3, size * 3))
        ImageDraw.Draw(im).text((size, size // 2), "H", font=font, fill=255)
        b = im.point(lambda v: 255 if v > 128 else 0).getbbox()
        _CAP_CACHE[key] = b[3] - b[1]
    return _CAP_CACHE[key]


def near(rgb, want, tol):
    return all(abs(a - b) <= tol for a, b in zip(rgb, want))


RAIL_X = (110, 520)
# Build 40: the For You grid and its hint bar start right of the corner ad.
HINT_X = 248  # variant A: grid beside the icon rail (RailX + collapsed width + 40)
GRID_COLS = 4
CARD_W = 363  # variant A: 9px narrower so the right arrow fits in action-safe
PITCH = CARD_W + 28
GRID_RIGHT = HINT_X + GRID_COLS * PITCH - 28
LAST_CARD_MAX_X = 1786  # variant A geometry: last card right edge
RIGHT_ARROW_X = (1798, 1810)  # variant A geometry: right arrow span
# Screens where the corner ad is hidden.
# Build 42: hidden on every Things to Do screen (rail row, grid, card details)
# and on Book Direct; shown on Home, Wi-Fi, House Rules, Quick Fixes, Checkout.
AD_HIDDEN = lambda slug: slug.startswith("fy-") or slug.startswith("intro-") or slug in ("rail-todo-focus", "ok-opens-todo", "tv-replay-2", "rail-book-focus", "book-direct", "book-right-opens", "home-after-idle", "pairing", "pairing-refreshed")
SAFE_BOTTOM = 1026  # action-safe bottom at FHD


def rail_expanded(img) -> bool:
    """The expanded rail shows its brand line ("Eaglewood 19") at top left."""
    return ink_box(img, (120, 70, 330, 112), lambda p: min(p) > 230) is not None


def rail_problem(img) -> str:
    """Pixel b35 Home #1: the last rail pill ends at y <= 726 and the panel
    ends at y 742, above the corner ad at 758."""
    im = img.convert("RGB")
    px = im.load()
    xs = range(RAIL_X[0], RAIL_X[1], 4)
    pill = [(0xF2, 0xA9, 0x3B), (0x3A, 0x4A, 0x66)]
    last_pill = None
    for y in range(560, 758):
        hits = sum(1 for x in xs if any(near(px[x, y], c, 12) for c in pill))
        if hits >= len(xs) // 2:
            last_pill = y
    if last_pill is not None and last_pill + 1 > 726:
        return f"rail pill ends at y {last_pill + 1}, want <= 726"
    text = ink_box(im, (180, 727, 520, 757), lambda p: min(p) > 200)
    if text is not None:
        return f"rail row ink below y 726 ({text})"

    def lum(y):
        return sum(sum(px[x, y]) for x in xs) / len(xs)

    drops = [(lum(y - 1) - lum(y), y) for y in range(728, 758)]
    drop, edge = max(drops)
    if drop < 15 or edge != 742:
        return f"rail panel ends at y {edge} (step {drop:.0f}), want 742"
    return ""


def amber_rail_index(img):
    """Rail row drawn amber (focused), from pixels: pill top = 142 + 84*i, 80 tall."""
    px = img.load()
    xs = range(RAIL_X[0], RAIL_X[1], 4)
    ys = [y for y in range(100, 743) if sum(1 for x in xs if near(px[x, y], (0xF2, 0xA9, 0x3B), 12)) >= len(xs) // 2]
    if len(ys) < 60 or ys[-1] - ys[0] > 90:
        return None
    index, off = divmod(ys[0] - 142, 84)
    return index if off <= 2 else (index + 1 if off >= 82 else None)


def last_paint(text: str) -> str:
    return text.rsplit("Eaglewood: fy paint", 1)[-1] if "Eaglewood: fy paint" in text else ""


def b38_grid_problem(img, text: str) -> str:
    """Build 38 tests on a For You grid capture: the OK Details chip, no orphan
    row label, rows of at most 10 with a matching N of M counter."""
    paint = last_paint(text)
    if not paint:
        return "no fy paint in the log"
    px = img.load()
    # Hint chip: #3A4A66 keycap from x HINT_X (558 since build 40), y 922-958, then #C9D1E0 "Details".
    chip = sum(1 for x in range(HINT_X + 4, HINT_X + 36) for y in range(926, 954) if near(px[x, y], (0x3A, 0x4A, 0x66), 14))
    if chip < 32 * 28 * 0.6:
        return f"OK chip not drawn at x {HINT_X}, y 920 ({chip} px)"
    if ink_box(img, (HINT_X + 6, 926, HINT_X + 42, 954), lambda p: near(p, (0xF4, 0xEF, 0xE3), 45)) is None:
        return "OK chip has no #F4EFE3 text"
    if ink_box(img, (HINT_X + 48, 920, HINT_X + 192, 960), lambda p: near(p, (0xC9, 0xD1, 0xE0), 40)) is None:
        return "no 'Details' text after the OK chip"
    cards = [dict(kv.split("=", 1) for kv in re.findall(r"\b(?:r|c|x|y|capH|focused)=\S+", l)) for l in paint.splitlines() if "Eaglewood: fy card" in l]
    for c in cards:
        bottom = int(c["y"]) + 209 + int(c["capH"])
        if c["focused"] == "yes":
            bottom += int(0.08 * (209 + int(c["capH"]))) + 12
        if bottom > 918:
            return f"card r={c['r']} c={c['c']} ends at y {bottom}, collides with the hint chip at 920"
    rows = re.findall(r"Eaglewood: fy row r=(\d+) id=(\S+) count=(\d+) label=(yes|no) labelY=(-?\d+) cardsY=(-?\d+)", paint)
    if not rows:
        return "no fy row lines"
    shown = {c["r"] for c in cards}
    for r, rid, count, label, labelY, cardsY in rows:
        if int(count) > 10:
            return f"row {rid} holds {count} cards, cap is 10"
        if label == "yes" and (r not in shown or int(cardsY) + 120 > 1023):
            return f"orphan row label {rid}: label shown, cards at y {cardsY} not visible"
    m = re.findall(r"Eaglewood: fy count text=(\d+) of (\d+) row=(\S+) rowCount=(\d+)", paint)
    if not m:
        return "no N of M counter"
    n, total, rid, rc = m[-1]
    if total != rc or int(total) > 10 or not 1 <= int(n) <= int(total):
        return f"counter {n} of {total} vs row {rid} count {rc}"
    return ""


ROW_NAMES = {"dining": "Dining", "hiking": "Hiking", "winter": "Winter", "summer": "Summer", "biking": "Biking"}


def hint_end(x: int, key: str, text: str) -> int:
    return x + len(key) * 14 + 24 + 12 + len(text) * 15 + 8 + 24


def b39_hint_problem(img, slug: str, text: str) -> str:
    """Build 39: "▼ next row" / "▲ previous row" chips after OK Details, and the
    centered 24x12 #F2A93B down chevron at y 880; hidden where no row exists."""
    paint = last_paint(text)
    order = [rid for _, rid in sorted((int(r), rid) for r, rid in re.findall(r"Eaglewood: fy row r=(\d+) id=(\S+)", text))]
    order = list(dict.fromkeys(order))
    focus = 0 if slug in ("fy-grid",) or slug.startswith("fy-move") else TODO.index(slug.removeprefix("fy-row-"))
    hints = re.findall(r"Eaglewood: fy hints row=(\d+) of=(\d+) next=(.*?) prev=(.*?) chevron=(yes|no) chevronX=(\d+) chevronY=(\d+) nextX=(-?\d+) prevX=(-?\d+)", text)
    if not hints:
        return "no fy hints line"
    row, count, nxt, prv, chev, cx, cy, nx, pvx = hints[-1]
    nx, pvx = int(nx), int(pvx)
    want_next = ROW_NAMES[order[focus + 1]] if focus + 1 < len(order) else ""
    want_prev = ROW_NAMES[order[focus - 1]] if focus > 0 else ""
    if int(row) != focus or nxt != want_next or prv != want_prev:
        return f"hints row={row} next='{nxt}' prev='{prv}', want row={focus} next='{want_next}' prev='{want_prev}'"
    if (nx >= 0) != bool(want_next) or (pvx >= 0) != bool(want_prev):
        return f"chip shown/hidden wrong: nextX {nx} prevX {pvx}"
    px = img.load()
    amber = (0xF2, 0xA9, 0x3B)
    label_ink = lambda p: near(p, (0xC9, 0xD1, 0xE0), 40)

    def chip_problem(x, name, before_end, stop):
        keycap = sum(1 for xx in range(x + 2, x + 46) for y in range(924, 956) if near(px[xx, y], (0x3A, 0x4A, 0x66), 14))
        arrow = ink_box(img, (x, 922, x + 48, 958), lambda p: near(p, amber, 40))
        if keycap < 44 * 32 * 0.5:
            return f"{name} keycap not drawn at x {x}"
        if arrow is None:
            return f"{name} chip has no amber chevron"
        w, h = arrow[2] - arrow[0] + 1, arrow[3] - arrow[1] + 1
        if not (20 <= w <= 25 and 9 <= h <= 13):
            return f"{name} chevron {w}x{h}, want 24x12"
        if not (18 <= x - before_end <= 48):
            return f"{name} chip starts {x - before_end}px after the previous text, want 24"
        ink = ink_box(img, (x + 50, 920, min(x + 260, stop - 4), 960), label_ink)
        if ink is None or ink[3] - ink[1] + 1 < 15:
            return f"{name} label not drawn as 24px text ({ink})"
        return ink

    details = ink_box(img, (HINT_X + 52, 920, HINT_X + 192, 960), label_ink)
    end = details[2] if details else 0
    for x, name, stop in ((nx, "next", pvx if pvx > 0 else 1820), (pvx, "prev", 1820)):
        if x < 0:
            continue
        got = chip_problem(x, name, end, stop)
        if isinstance(got, str):
            return got
        end = got[2]
    extra = ink_box(img, (end + 4, 920, 1820, 960), lambda p: near(p, amber, 40))
    if extra is not None:
        return f"hidden row chip still drawn ({extra})"
    # Centered chevron: build 40, 3 cards from x 558 at pitch 400 span 558-1730, center 1144.
    want_x = HINT_X + (GRID_COLS * PITCH - 28 - 24) // 2
    # From y 870: the peek row is clipped at y 868 and its photos can hold amber.
    box = ink_box(img, (HINT_X - 8, 870, 1830, 905), lambda p: near(p, amber, 40))
    if want_next:
        if chev != "yes" or int(cx) != want_x or int(cy) != 880:
            return f"chevron log x {cx} y {cy} shown={chev}, want x {want_x} y 880"
        if box is None:
            return "centered chevron not drawn"
        w, h = box[2] - box[0] + 1, box[3] - box[1] + 1
        if abs((box[0] + box[2]) / 2 - (want_x + 11.5)) > 2 or not (878 <= box[1] <= 884) or not (20 <= w <= 25 and 9 <= h <= 13):
            return f"centered chevron at {box} ({w}x{h}), want 24x12 at x {want_x}, y 880"
        cards = [l for l in paint.splitlines() if "Eaglewood: fy card" in l]
        for l in cards:
            y = int(re.search(r" y=(-?\d+)", l).group(1)); cap = int(re.search(r"capH=(\d+)", l).group(1))
            bottom = y + 209 + cap + (int(0.08 * (209 + cap)) + 12 if "focused=yes" in l else 0)
            if bottom > 872:
                return f"card ends at y {bottom}, collides with the chevron at 880"
    elif box is not None or chev != "no":
        return f"centered chevron shown on the last row ({box})"
    return ""


def b40_peek_problem(img, slug: str, text: str) -> str:
    """Build 40: under the last whole row, the next row's card tops peek in:
    top inside the action-safe zone, clipped at y 868 (above the chevron),
    at least 24px visible, and the band really holds photo pixels."""
    paint = last_paint(text)
    order = list(dict.fromkeys(rid for _, rid in sorted((int(r), rid) for r, rid in re.findall(r"Eaglewood: fy row r=(\d+) id=(\S+)", text))))
    focus = 0 if slug == "fy-grid" or slug.startswith("fy-move") else TODO.index(slug.removeprefix("fy-row-"))
    peeks = re.findall(r"Eaglewood: fy peek r=(\d+) id=(\S+) top=(-?\d+) clip=(\d+) visible=(-?\d+) cards=(\d+)", paint)
    if focus + 1 >= len(order):
        return "" if not peeks else f"peek drawn under the last row ({peeks[-1]})"
    if not peeks:
        return "no fy peek line: next row does not peek in"
    r, rid, top, clip, visible, cards = peeks[-1]
    top, clip, visible = int(top), int(clip), int(visible)
    if rid != order[focus + 1]:
        return f"peek row {rid}, want {order[focus + 1]}"
    if not (54 <= top < clip <= 868) or clip > SAFE_BOTTOM or visible < 24 or int(cards) < 1:
        return f"peek top {top} clip {clip} visible {visible} cards {cards}: want top in the safe zone, >= 24px shown above y 868"
    px = img.load()
    y0, y1 = top + 2, clip - 2
    varied = sum(1 for x in range(HINT_X + 10, HINT_X + 362, 6)
                 if max(px[x, y][0] for y in range(y0, y1)) - min(px[x, y][0] for y in range(y0, y1)) > 12 or px[x, y0][0] + px[x, y0][1] + px[x, y0][2] > 150)
    if varied < 20:
        return f"peek band y {y0}-{y1} shows no photo pixels ({varied} columns)"
    below = ink_box(img, (HINT_X, clip + 1, GRID_RIGHT, 876), lambda p: max(p) > 120)
    if below is not None:
        return f"peek drawn past its clip at y {clip} ({below})"
    return ""


def b40_arrow_problem(img, slug: str, text: str) -> str:
    """Build 40: a 12x24 amber arrow left/right of the focused row when cards
    are off that side: first card right only, middle both, last left only."""
    paint = last_paint(text)
    focus = 0 if slug == "fy-grid" or slug.startswith("fy-move") else TODO.index(slug.removeprefix("fy-row-"))
    lines = [dict(re.findall(r"(\w+)=(\S+)", l.split("fy arrows ", 1)[1])) for l in paint.splitlines() if "Eaglewood: fy arrows " in l]
    row = next((a for a in lines if int(a["r"]) == focus), None)
    if row is None:
        return f"no fy arrows line for row {focus}"
    count, col = int(row["count"]), int(row["col"])
    want_left, want_right = col > 0 and int(row["first"]) > 0, int(row["first"]) + int(row["shown"]) < count
    if slug == "fy-grid" and (row["left"], row["right"]) != ("no", "yes" if count > GRID_COLS else "no"):
        return f"first card: arrows left={row['left']} right={row['right']}, want left=no right={'yes' if count > GRID_COLS else 'no'}"
    if slug == f"fy-move-right{GRID_COLS}" and (row["left"], row["right"]) != ("yes", "yes" if count > GRID_COLS + 1 else "no"):
        return f"middle card: arrows left={row['left']} right={row['right']}, want both"
    if slug == "fy-move-last" and (col != count - 1 or (row["left"], row["right"]) != ("yes", "no")):
        return f"last card col {col} of {count}: arrows left={row['left']} right={row['right']}, want left only"
    # Variant A geometry: the last whole card ends by x 1786 and the right
    # arrow sits at x 1798-1810, inside action-safe.
    last_end = HINT_X + GRID_COLS * PITCH - 28
    if last_end > LAST_CARD_MAX_X:
        return f"last card ends at x {last_end}, want <= {LAST_CARD_MAX_X}"
    rx = int(row["rightX"])
    if row["right"] == "yes" and (rx, rx + 12) != RIGHT_ARROW_X:
        return f"right arrow at x {rx}-{rx + 12}, want {RIGHT_ARROW_X[0]}-{RIGHT_ARROW_X[1]}"
    paint_cards = [dict(re.findall(r"(\w+)=(\S+)", l.split("Eaglewood: fy card ", 1)[1])) for l in paint.splitlines() if "Eaglewood: fy card " in l]
    for c in paint_cards:
        if c.get("focused") != "yes" and c.get("x", "").lstrip("-").isdigit() and int(c["x"]) + CARD_W > LAST_CARD_MAX_X:
            return f"card r{c.get('r')} c{c.get('c')} ends at x {int(c['x']) + CARD_W}, want <= {LAST_CARD_MAX_X}"
    amber = lambda p: near(p, (0xF2, 0xA9, 0x3B), 40)
    y = int(row["y"])
    for side, x in (("left", int(row["leftX"])), ("right", int(row["rightX"]))):
        box = ink_box(img, (x - 3, y - 3, x + 15, y + 27), amber)
        if row[side] == "yes":
            if box is None:
                return f"{side} arrow logged shown but not drawn at x {x} y {y}"
            w, h = box[2] - box[0] + 1, box[3] - box[1] + 1
            if not (8 <= w <= 13 and 18 <= h <= 25):
                return f"{side} arrow {w}x{h}, want about 12x24"
            if x < 48 or x + 12 > 1872:
                return f"{side} arrow at x {x} outside action-safe"
        elif box is not None:
            return f"{side} arrow drawn but no cards are off that side ({box})"
    _ = want_left, want_right
    return ""


def b40_book_problem(img, text: str) -> str:
    """Build 40: Book Direct uses the whole box: blocks span >= 80% of the panel
    width, nothing past the panel, QR and site address drawn in the card."""
    m = re.findall(r"Eaglewood: book layout (.*)", text)
    if not m:
        return "no book layout line"
    rects = {k: tuple(int(v) for v in re.findall(r"-?\d+", val)) for k, val in re.findall(r"(\w+)=(\S+(?: \S+)?)(?= \w+=|$)", m[-1])}
    try:
        def box(name):
            x, y, w, h = rects[name][:4]
            return x, y, w, h
        px_, py_, pw, ph = box("panel")
        blocks = [box(n) for n in ("photo", "card", "body", "savings", "chips")]
    except (KeyError, ValueError):
        return f"book layout line unreadable: {m[-1]}"
    left = min(b[0] for b in blocks)
    right = max(b[0] + b[2] for b in blocks)
    if right - left < 0.8 * pw:
        return f"content spans x {left}-{right} ({(right - left) / pw:.0%} of the {pw}px panel), want >= 80%"
    for b in blocks:
        if b[0] < px_ or b[0] + b[2] > px_ + pw or b[1] < py_ or b[1] + b[3] > py_ + ph:
            return f"block {b} outside the panel {rects['panel']}"
    ink = ink_box(img, (px_ + 8, py_ + 8, px_ + pw - 8, py_ + ph - 8), lambda p: min(p) > 200)
    if ink is None or (ink[2] - ink[0]) < 0.8 * pw:
        return f"drawn ink spans {ink}, want >= 80% of the panel width"
    # Build 41 (Pixel b40): body 24px under the photo, wrapped across the full
    # width, and the leftover height split evenly around the savings line.
    g = re.findall(r"Eaglewood: book gaps photoToBody=(-?\d+) bodyToSavings=(-?\d+) savingsToChips=(-?\d+) bodyLines=(\d+)", text)
    if not g:
        return "no book gaps line"
    top, ga, gb, nlines = (int(v) for v in g[-1])
    if not 20 <= top <= 28:
        return f"body starts {top}px under the photo, want about 24"
    if ga < 12 or gb < 12 or abs(ga - gb) > 2:
        return f"uneven text spacing: body-to-savings {ga}px, savings-to-chips {gb}px"
    bx, by, bw, bh = box("body")
    sy = box("savings")[1]
    body_ink = ink_box(img, (bx, by, bx + bw, sy - 1), lambda p: min(p) > 180)
    if body_ink is None:
        return "body text not drawn"
    if abs(body_ink[1] - (by + 8)) > 12:
        return f"body ink starts at y {body_ink[1]}, want about {by + 8}"
    if body_ink[3] - body_ink[1] > 50 and body_ink[2] - bx < 0.8 * bw:
        return f"body wraps at x {body_ink[2]}: lines use {(body_ink[2] - bx) / bw:.0%} of the {bw}px width, want >= 80%"
    qx, qy, qw, qh = box("qr")
    q = ink_box(img, (qx, qy, qx + qw, qy + qh), lambda p: min(p) > 230)
    dark = sum(1 for x in range(qx, qx + qw, 4) for y in range(qy, qy + qh, 4) if sum(img.getpixel((x, y))) < 120)
    if q is None or dark < 200:
        return f"Book Direct QR not drawn in {rects['qr']} ({dark} dark samples)"
    cx, cy, cw, ch = box("card")
    dom = ink_box(img, (cx, qy + qh, cx + cw, cy + ch), lambda p: near(p, (0xF2, 0xA9, 0x3B), 40) or min(p) > 200)
    if dom is None:
        return "site address not drawn under the QR"
    return ""


def b38_fixes_problem(img, slug: str) -> str:
    """Build 38: the "< Quick Fixes" rail row keeps a muted #3A4A66 416x80 pill,
    and the fix-list footer shows an OK chip (#3A4A66 keycap, #F4EFE3 text)."""
    px = img.load()
    top = 142 + 84 * RAIL["fixes"]
    xs = range(RAIL_X[0] + 10, RAIL_X[1] - 10, 4)
    rows = [y for y in range(top - 4, top + 86) if sum(1 for x in xs if near(px[x, y], (0x3A, 0x4A, 0x66), 12)) >= len(xs) // 3]
    if len(rows) < 60:
        return f"no muted pill behind < Quick Fixes ({len(rows)} rows)"
    if slug.startswith("fx-list"):
        found = None
        for y in range(880, 1040, 2):
            run = 0
            for x in range(560, 1820):
                run = run + 1 if near(px[x, y], (0x3A, 0x4A, 0x66), 10) else 0
                if run >= 40:
                    found = (x, y)
                    break
            if found:
                break
        if not found:
            return "no OK chip in the fix-list footer"
        x, y = found
        if ink_box(img, (x - 50, y - 18, x + 10, y + 18), lambda p: near(p, (0xF4, 0xEF, 0xE3), 45)) is None:
            return "footer OK chip has no #F4EFE3 text"
    return ""


def state_problem(text: str) -> str:
    """Build 37 QA gate 3: after every key press the rail row drawn focused
    (node state from the scene's "state" line) is the current section when
    the rail has focus, and no row is drawn focused anywhere else."""
    states = [l for l in text.splitlines() if "Eaglewood: state key=" in l]
    presses = [l for l in text.splitlines() if re.search(r"Eaglewood: key \S+ press=true", l)]
    if len(states) != len(presses):
        return f"{len(states)} state lines for {len(presses)} presses"
    for n, line in enumerate(states, 1):
        f = dict(re.findall(r"(\w+)=(\S*)", line))
        lit = f.get("lit", "?")
        if f.get("zone") == "rail" and f.get("section") in RAIL:
            if lit != f["section"]:
                return f"press {n} ({f.get('key')}): rail on {f['section']} but lit={lit}"
        elif lit != "none" and f.get("zone") != "rail":
            return f"press {n} ({f.get('key')}): zone={f.get('zone')} but rail lit={lit}"
    return ""


def caption_problem(img, text: str) -> str:
    """Build 37: every shown Things to Do card has a title and a meta line
    (node state from the "fy card" log of the last paint) and both draw ink
    on the card: title white 30px bold (cap height checked), meta #C9D1E0
    at least 8px under it, no ellipsis."""
    paint = text.rsplit("Eaglewood: fy paint", 1)
    if len(paint) < 2:
        return "no fy paint logged"
    cards = [dict(re.findall(r"(\w+)=([^ ]*(?: (?!\w+=)[^ ]*)*)", l.split("Eaglewood: fy card ", 1)[1]))
             for l in paint[1].splitlines() if "Eaglewood: fy card " in l]
    if not cards:
        return "no Things to Do cards shown"
    # Build 43 (Blake's TV, b42 strips): node state of every shown card: the
    # photo is 363x209, the caption body 96-269px right under it, both caption
    # labels visible and inside the body, and the row clip non-empty and
    # holding the whole card.
    boxes = [dict(re.findall(r"(\w+)=(\S+)", l.split("Eaglewood: fy cardbox ", 1)[1]))
             for l in paint[1].splitlines() if "Eaglewood: fy cardbox " in l]
    if len(boxes) != len(cards):
        return f"{len(boxes)} fy cardbox lines for {len(cards)} cards"
    for b in boxes:
        tag = f"card r{b['r']} c{b['c']}"
        cap_h = int(b["capH"])
        cx, cy, cw, ch = (int(v) for v in b["clip"].split(","))
        if (int(b["photoW"]), int(b["photoH"])) != (CARD_W, 209):
            return f"{tag}: photo {b['photoW']}x{b['photoH']}, want {CARD_W}x209"
        if int(b["capY"]) != 209 or not (96 <= cap_h <= 269):
            return f"{tag}: caption body y {b['capY']} h {cap_h}, want y 209 and h 96-269"
        if b["nameVis"] != "yes" or b["metaVis"] != "yes":
            return f"{tag}: caption labels hidden (name {b['nameVis']}, meta {b['metaVis']})"
        if not (209 <= int(b["nameY"]) < int(b["metaY"]) < 209 + cap_h):
            return f"{tag}: caption text y {b['nameY']}/{b['metaY']} outside body 209-{209 + cap_h}"
        sx = int(b["slotX"])
        if cw <= 0 or ch <= 0 or cx > sx - 6 or cx + cw < sx + CARD_W + 6 or cy > 0 or cy + ch < 52 + 209 + cap_h:
            return f"{tag}: row clip {b['clip']} does not hold the card"
    cap30 = reference_cap_height(30)
    for c in cards:
        tag = f"card r{c['r']} c{c['c']}"
        if not c.get("name") or not c.get("meta"):
            return f"{tag}: empty title or meta in node state"
        if "…" in c["name"] + c["meta"] or "..." in c["name"] + c["meta"]:
            return f"{tag}: ellipsis in caption"
        # brs-node moves a scaled card by its scaleRotateCenter offset but draws
        # it at unscaled size (EMULATOR-LIMITS), so: shifted origin, 1:1 boxes.
        scale = 1.0
        shift = 0.08 if c.get("focused") == "yes" else 0.0
        x, y = round(int(c["x"]) - shift * CARD_W / 2), round(int(c["y"]) - shift * 104.5)
        w, h = CARD_W, 209 + int(c["capH"])
        top = y + 209 + 4
        name_h = 8 + int(c["nameLines"]) * 42  # Nav2CapPad + lines * Nav2NameLine - 4
        x0, x1 = max(x, 0) + 4, min(x + w, 1919) - 4
        title = ink_box(img, (x0, top, x1, top + name_h), lambda p: min(p) > 240)
        meta = ink_box(img, (x0, top + name_h + 2, x1, min(y + h, 1079) - 4), lambda p: near(p, (0xC9, 0xD1, 0xE0), 22))
        if title is None or meta is None:
            return f"{tag} ({c['name']}): caption ink missing (title {title}, meta {meta})"
        # First line only, so a two-line title's stacked capitals count once.
        glyph = first_glyph_box(img, (x0, top, x1, top + 40), lambda p: min(p) > 240)
        if glyph is None:
            return f"{tag} ({c['name']}): title first line has no ink"
        cap = glyph[3] - glyph[1] + 1
        if min(abs(cap - cap30), abs(cap - cap30 * scale)) > 1.5:
            return f"{tag}: title cap height {cap}px, want {cap30}px +-1 (30px bold; 24px would be {reference_cap_height(24)}px)"
        if meta[1] - title[3] < 8:
            return f"{tag}: meta {meta[1] - title[3]}px under the title, want >= 8"
        # Every pre-broken line drew (a clipped last line ellipsizes instead).
        lines_t, lines_m = int(c["nameLines"]), int(c["metaLines"])
        if title[3] - title[1] + 1 < (lines_t - 1) * 38 + 18:
            return f"{tag}: title ink {title[3] - title[1] + 1}px tall for {lines_t} line(s)"
        if meta[3] - meta[1] + 1 < (lines_m - 1) * 33 + 14:
            return f"{tag}: meta ink {meta[3] - meta[1] + 1}px tall for {lines_m} line(s)"
        if meta[3] > y + h - 4:
            return f"{tag}: meta ink ends at y {meta[3]}, past the caption panel ({y + h})"
    return ""


def scrim_span_problem(img) -> str:
    """The meta scrim (y 571-608) darkens the backdrop relative to the 16px
    gap under it (y 611-622); find where that darkening stops on the right."""
    px = img.load()

    def dark(x):
        strip = sum(sum(px[x, y]) for y in range(580, 600)) / 20
        gap = sum(sum(px[x, y]) for y in range(612, 621)) / 9
        return gap - strip > 12

    right = max((x for x in range(1500, 1760) if dark(x)), default=None)
    left = min((x for x in range(560, 700) if dark(x)), default=None)
    if right is None or left is None or abs(right - 1715) > 2 or abs(left - 588) > 2:
        return f"detail meta strip spans x {left}-{right}, want 588-1716"
    return ""


def geometry_problem(slug: str, data: bytes) -> str:
    """Build 35 pixel-position assertions for the pixel review P1/P2 fixes."""
    from io import BytesIO
    from PIL import Image
    img = Image.open(BytesIO(data)).convert("RGB")
    if rail_expanded(img):
        problem = rail_problem(img)
        if problem:
            return problem
    want = next((sec for sec in RAIL if slug == f"{'home' if sec == 'home' else 'rail-' + sec}{'-rail' if sec == 'home' else ''}-focus"), None)
    if want is not None:
        got = amber_rail_index(img)
        if got != RAIL[want]:
            return f"amber rail pill at row {got}, want {RAIL[want]} ({want})"
    if slug == "fy-detail-qr-blocked":
        # Pixel b35 TtD #1: with no QR the meta strip spans x 588-1716.
        problem = scrim_span_problem(img)
        if problem:
            return problem
    if slug in ("fy-grid", "fy-move-right3", "fy-row-biking"):
        # P1: the N of M counter ends on title-safe x 1726.
        box = ink_box(img, (1400, 150, 1919, 240), lambda p: near(p, (0xF4, 0xEF, 0xE3), 40))
        if box is None:
            return "counter not found"
        if not (1700 <= box[2] <= 1726):
            return f"counter ink ends at x {box[2]}, want 1700-1726"
    if slug in ("home-prompt-focus", "ad-2", "ad-3", "fy-grid", "book-direct", "fx-steps-long") and not AD_HIDDEN(slug):
        # P2: ad at x 96-534, y 758-972; QR >= 150px; domain gold inside title-safe.
        qr = ink_box(img, (300, AD["y0"], AD["x1"], AD["y1"]), lambda p: min(p) > 245)
        if qr is None or qr[2] - qr[0] + 1 < 150 or qr[3] - qr[1] + 1 < 150:
            return f"ad QR under 150px ({qr})"
        if qr[0] < AD["x0"] or qr[2] > AD["x1"] or qr[1] < AD["y0"] or qr[3] > AD["y1"]:
            return f"ad QR outside the ad rect ({qr})"
        dom = ink_box(img, (AD["x0"], 900, AD["x1"], 1080), lambda p: near(p, (0xF2, 0xA9, 0x3B), 30))
        if dom is None or dom[3] > 972 or dom[2] > AD["x1"]:
            return f"ad domain missing or below title-safe ({dom})"
        if dom[3] - dom[1] + 1 < 15:
            return f"ad domain ink {dom[3] - dom[1] + 1}px tall, under 24px type"
        head = ink_box(img, (AD["x0"], AD["y0"], 300, 850), lambda p: min(p) > 245)
        if head is None or head[1] < AD["y0"] or head[3] - head[1] + 1 < 50:
            return f"ad headline not two 30px lines ({head})"
        below = ink_box(img, (AD["x0"], 973, AD["x1"], 1000), lambda p: min(p) > 245 or near(p, (0xF2, 0xA9, 0x3B), 30))
        if below is not None:
            return f"ad ink below title-safe y 972 ({below})"
    if AD_HIDDEN(slug) and "detail" in slug or slug == "ok-opens-todo":
        # Variant A: the card detail (nav fyItem, section = the card's row) hides the ad.
        vis = re.findall(r"Eaglewood: ad visible=(\w+) nav=(\w*)", log_text())
        if not vis or vis[-1][0] != "false":
            return f"card detail: last ad state {vis[-1] if vis else None}, want visible=false"
    if slug in ("fy-detail", "fy-detail-second"):
        # P3: the detail meta line draws on its scrim, >= 16px above the body panel (y 625).
        meta = ink_box(img, (588, 560, 1300, 624), lambda p: min(p) > 150)
        if meta is None:
            return "detail meta line not drawn"
        if meta[3] > 625 - 16:
            return f"detail meta ink ends at y {meta[3]}, want <= 609"
    if slug.startswith("fy-") and "detail" not in slug:
        problem = caption_problem(img, log_text())
        if problem:
            return problem
    if slug.startswith(("fy-grid", "fy-move", "fy-row-")):
        problem = b38_grid_problem(img, log_text()) or b39_hint_problem(img, slug, log_text())
        if problem:
            return problem
    if slug.startswith(("fy-grid", "fy-move", "fy-row-")):
        problem = b40_peek_problem(img, slug, log_text()) or b40_arrow_problem(img, slug, log_text())
        if problem:
            return problem
    if slug == "book-direct":
        problem = b40_book_problem(img, log_text())
        if problem:
            return problem
    if slug == "home-start-focus":
        # Build 40: startup lands on the rail's Home row before any key.
        first = next((l for l in log_text().splitlines() if "Eaglewood: screen=" in l), "")
        if "screen=home zone=rail" not in first:
            return f"startup log '{first.strip()}', want screen=home zone=rail"
        if amber_rail_index(img) != RAIL["home"]:
            return f"startup amber rail pill at row {amber_rail_index(img)}, want Home"
    if slug.startswith("fx-list") and slug != "fx-list-back" or slug == "fx-list":
        problem = b38_fixes_problem(img, slug)
        if problem:
            return problem
    return ""


def card_problem(data: bytes, want: str) -> str:
    """want "qr": the corner ad is drawn and its QR has ink (not blank).
    want "hidden": the ad is gone (rail collapsed), so no QR modules there."""
    from io import BytesIO
    from PIL import Image
    px = list(Image.open(BytesIO(data)).convert("RGB").crop(CARD_BOX).getdata())
    black = sum(1 for r, g, b in px if r + g + b < 60) / len(px)
    white = sum(1 for r, g, b in px if r + g + b > 700) / len(px)
    bright = sum(1 for r, g, b in px if max(r, g, b) > 140) / len(px)
    stats = f"black {black:.3f} white {white:.3f} bright {bright:.2f}"
    if want == "qr" and (black < 0.02 or white < 0.02 or bright < 0.15):
        return f"corner ad blank or missing its QR ({stats})"
    if want == "hidden":
        # The baked domain line (#F2A93B, x 200-534, y 925-965) is the ad's
        # signature; card photos can be white or dark but not this gold run.
        img = Image.open(BytesIO(data)).convert("RGB").crop((200, 925, 534, 965))
        gold = sum(1 for p in img.getdata() if abs(p[0] - 0xF2) < 20 and abs(p[1] - 0xA9) < 20 and abs(p[2] - 0x3B) < 30)
        if gold > 300:
            return f"corner ad still drawn where it should be hidden (gold {gold}; {stats})"
    return ""


def qr_ready(tag: str) -> bool:
    """The emulator's cross-thread cachefs read is racy; a ready line proves the QR drew."""
    return any(tag in line and "status=ready" in line.replace(" ", "") for line in log_text().splitlines())


def snapshot() -> bytes:
    last = b""
    for _ in range(10):
        if SNAP.exists():
            SNAP.unlink()
        tmux("send-keys", "-t", f"{SESSION}:0.0", "C-s")
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


def launch_retrying(stage, keys, ecp: bool = False, ready: str = "Eaglewood: screen=home zone=") -> None:
    # brs-node sometimes stalls before the key timer runs; a fresh process fixes it.
    for attempt in range(3):
        try:
            launch(stage, keys, ecp, ready)
            return
        except RuntimeError as err:
            if "did not log" not in str(err) or attempt == 2:
                raise
            print(f"retry    launch stalled: {err}", flush=True)



PAIR_CODE_RE = re.compile(r"HostKit: pair start code=([A-HJ-KM-NP-Z2-9]{6})")


def worker_url(path: str) -> str:
    port = int(os.environ.get("HOSTKIT_WORKER_PORT", "8787"))
    return f"http://127.0.0.1:{port}{path}"


def http_json(method: str, path: str, body: dict | None = None) -> tuple[int, object]:
    data = None if body is None else json.dumps(body).encode()
    headers = {"Content-Type": "application/json"} if data is not None else {}
    req = Request(worker_url(path), data=data, method=method, headers=headers)
    try:
        with urlopen(req, timeout=10) as res:
            raw = res.read().decode()
            return res.status, json.loads(raw) if raw else {}
    except HTTPError as err:
        raw = err.read().decode() if err.fp else ""
        try:
            parsed = json.loads(raw) if raw else {}
        except json.JSONDecodeError:
            parsed = raw
        return err.code, parsed


def last_pair_codes() -> list[str]:
    return PAIR_CODE_RE.findall(log_text())


def refresh_pairing_code(first: str) -> tuple[str, str]:
    """Expire the current pairing code via the local test hook and wait for a new one."""
    status, body = http_json("POST", "/v1/__test/expire", {"code": first})
    if status != 200:
        raise RuntimeError(f"expire hook HTTP {status} {body}")
    deadline = time.time() + 25
    second = first
    while time.time() < deadline:
        log = log_text()
        if "HostKit: code refreshed" in log:
            codes = last_pair_codes()
            if len(codes) >= 2 and codes[-1] != first:
                second = codes[-1]
                time.sleep(0.8)
                return first, second
        time.sleep(0.2)
    codes = last_pair_codes()
    raise RuntimeError(f"code did not refresh (first={first}, codes={codes[-3:]})")


HOSTKIT_WORKER = None


def start_hostkit_worker():
    """Local Worker so the unconfigured pairing screen can fetch a code."""
    global HOSTKIT_WORKER
    port = int(os.environ.get("HOSTKIT_WORKER_PORT", "8787"))
    env = os.environ.copy()
    env["PORT"] = str(port)
    env["PUBLIC_BASE"] = f"http://127.0.0.1:{port}"
    env["ALLOW_TEST_HOOKS"] = "1"
    env["HOST_TOKEN"] = "host-preview"
    log_path = WORK / "worker.log"
    log = open(log_path, "w")
    proc = subprocess.Popen(
        ["node", str(hostkit_root() / "worker" / "server.js")],
        cwd=str(hostkit_root() / "worker"),
        env=env,
        stdout=log,
        stderr=subprocess.STDOUT,
        start_new_session=True,
    )
    HOSTKIT_WORKER = proc
    deadline = time.time() + 10
    last = ""
    while time.time() < deadline:
        try:
            urlopen(f"http://127.0.0.1:{port}/health", timeout=1).read()
            print(f"worker   http://127.0.0.1:{port} pid={proc.pid}", flush=True)
            return proc
        except Exception as err:
            last = str(err)
            if proc.poll() is not None:
                break
            time.sleep(0.1)
    raise RuntimeError(f"hostkit worker did not start: {last}\n{log_path.read_text(errors='replace')[-1000:]}")


def stop_hostkit_worker(proc) -> None:
    if proc is None:
        return
    pid = getattr(proc, "pid", None)
    if not pid:
        return
    try:
        os.killpg(pid, 15)
    except (ProcessLookupError, PermissionError, OSError):
        try:
            proc.terminate()
        except Exception:
            pass
    try:
        proc.wait(timeout=5)
    except Exception:
        try:
            os.killpg(pid, 9)
        except Exception:
            pass


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    build_fixtures()
    stages = {"key": build_stage("key", FAKE_KEY), "nokey": build_stage("nokey", ""), "longfix": build_stage("longfix", FAKE_KEY), "qrblocked": build_stage("qrblocked", FAKE_KEY), "badgeblocked": build_stage("badgeblocked", FAKE_KEY), "staleetag": build_stage("staleetag", FAKE_KEY), "unconfigured": build_stage("unconfigured", FAKE_KEY)}
    threading.Thread(target=ThreadingHTTPServer(("127.0.0.1", FIX_PORT), Handler).serve_forever, daemon=True).start()
    worker = start_hostkit_worker()
    rows = []
    seen: dict[str, str] = {}
    failed = 0
    plan = [s for s in screens() if not ONLY or s["slug"] in ONLY]
    # Build 38: the corner ads keep >= 4.5:1 text contrast (build_ads.py asserts).
    if not ONLY or "ad-contrast" in ONLY:
        run = subprocess.run([sys.executable, str(Path(__file__).with_name("build_ads.py")), "--check"], capture_output=True, text=True)
        worst = min((float(v) for v in re.findall(r"contrast ([\d.]+):1", run.stdout)), default=0.0)
        # Build 41 (Pixel b40): every ad's text ink ends >= 16px before its QR.
        # Measured on the baked layers: on screen the photo behind is as bright as text.
        gaps = [int(v) for v in re.findall(r"text-to-QR gap (-?\d+)px", run.stdout)]
        ok = run.returncode == 0 and worst >= 4.5 and len(gaps) >= 3 and min(gaps) >= 16
        rows.append(("ad-contrast", "-", "Corner ad text contrast, build_ads.py --check", "(none)", "captured" if ok else "fail", f"worst {worst:.1f}:1, text-to-QR gap >= {min(gaps)}px" if ok else (run.stderr.strip().splitlines() or ["check failed"])[-1], ""))
        failed += 0 if ok else 1
        print(f"{'captured' if ok else 'fail':8} ad-contrast worst {worst:.1f}:1, gap >= {min(gaps) if gaps else 0}px", flush=True)
    try:
        for item in plan:
            note = ""
            digest = ""
            try:
                tries = 0
                while True:
                    tries += 1
                    ready = "HostKit: screen=intro-1" if item["stage"] == "unconfigured" else "Eaglewood: screen=home zone="
                    launch_retrying(stages[item["stage"]], item["keys"], bool(item["ecp"]), ready)
                    if item["ecp"]:
                        time.sleep(4)
                        send_ecp(item["ecp"])
                    time.sleep(float(os.environ.get("EMU_SETTLE", "12")) + item["wait"])
                    if item["need"] in ("pair", "pair-refresh"):
                        if ("HostKit: screen=pairing" in log_text() and "HostKit: pair start code=" in log_text()) or tries >= 4:
                            break
                    elif not item["need"] or qr_ready(item["need"]) or tries >= 4:
                        break
                if item["need"] in ("pair", "pair-refresh"):
                    log = log_text()
                    if "HostKit: screen=pairing" in log and "HostKit: pair start code=" in log:
                        note = "pairing code issued"
                    else:
                        note = "pairing code not issued"
                        # keep going; the status check below will fail if needed
                elif item["need"]:
                    note = f"qr ready after {tries} launch(es)" if qr_ready(item["need"]) else f"qr not ready after {tries} launches"
                if item.get("need") in ("pair", "pair-refresh") and "pairing code not issued" in (note or ""):
                    data = snapshot() if SNAP.exists() else b""
                    digest = hashlib.sha256(data).hexdigest() if data else ""
                    if data:
                        (OUT / f"{item['slug']}.png").write_bytes(data)
                    status, note = "fail", "pairing code not issued"
                    raise RuntimeError("pairing code not issued")
                if item.get("need") == "pair-refresh":
                    codes = last_pair_codes()
                    if not codes:
                        raise RuntimeError("pairing-refreshed: no code in log")
                    first, second = refresh_pairing_code(codes[-1])
                    note = f"refreshed {first} -> {second}"
                data = snapshot()
                digest = hashlib.sha256(data).hexdigest()
                (OUT / f"{item['slug']}.png").write_bytes(data)
                (OUT / f"{item['slug']}.log").write_text(log_text(), encoding="utf-8")
                if os.environ.get("EMU_PANE"):
                    pane = subprocess.run([*TMUX, "capture-pane", "-p", "-S", "-5000", "-t", f"{SESSION}:0.0"], capture_output=True, text=True).stdout
                    (OUT / f"{item['slug']}.pane").write_text(pane, encoding="utf-8")
                if digest in seen and seen[digest] == item["same_as"]:
                    status, note = "captured", f"expected: same pixels as {seen[digest]}"
                elif digest in seen:
                    status, note = "fail", f"same pixels as {seen[digest]}"
                else:
                    seen[digest] = item["slug"]
                    status = "captured"
                if item["stage"] != "unconfigured" and item["card"] and status != "fail":
                    problem = card_problem(data, item["card"])
                    if problem:
                        status, note = "fail", problem
                if item["stage"] != "unconfigured" and status != "fail":
                    problem = geometry_problem(item["slug"], data)
                    if problem:
                        status, note = "fail", problem
                if item["ecp"] and status != "fail":
                    problem = focus_problems(item["ecp"], item["visits"])
                    note = problem or f"{len(item['ecp'])} ECP presses, every one focus=scene; visited {', '.join(item['visits'])}"
                    if problem:
                        status = "fail"
                if item["stage"] == "staleetag" and status != "fail":
                    # M3: guide/checkout come from HostKit, so only the /tv Wi-Fi path still refetches.
                    want = ["emu seeded stale etags", "wifi cache-miss refetch", "ssid len= 7"]
                    missing = [w for w in want if w not in log_text()]
                    if missing:
                        status, note = "fail", "stale-etag log missing: " + ", ".join(missing)
                    else:
                        note = "304 on stale etag with no cache: wifi, guide and checkout refetched; " + note
                # Build 37 QA gate 1: any caught error (fixed marker), any runtime
                # error the strict emulator reports, or any "error" app log fails.
                # brs-node emits a failed WriteAsciiFile/ReadAsciiFile as a "warning"
                # with a backtrace; firmware just returns false, and the app handles
                # false (e.g. "wifi cache-write failed, etag not kept"). Those lines
                # are counted in the note, not failed; anything else still fails.
                io_warn = [l for l in log_text().splitlines() if re.search(r"BRIGHTSCRIPT: ERROR: (Write|Read)AsciiFile: file open for (write|read) failed", l)]
                errors = [l for l in log_text().splitlines() if l not in io_warn and ("EAGLEWOOD-CAUGHT" in l or "Type Mismatch" in l
                          or re.search(r"pkg:/\S+\(\d+", l) or ("error" in l.lower() and "Eaglewood" in l))]
                if io_warn and not errors:
                    note = (note + "; " if note else "") + f"{len(io_warn)} emulator file-open warning(s), handled"
                if errors:
                    status, note = "fail", "; ".join(errors[:2])
                elif status != "fail" and item["stage"] != "unconfigured":
                    problem = state_problem(log_text())
                    opened = {"ok-opens-todo": "nav2 fy open row=", "ok-opens-fix": "screen=fixes zone=fxsteps", "book-right-opens": "emu keys done section=book zone=panel"}.get(item["slug"])
                    if not problem and opened:
                        if opened not in log_text():
                            problem = f"OK did not open: no '{opened}' log line"
                        else:
                            note = f"OK opened ({opened})"
                    if problem:
                        status, note = "fail", problem
            except Exception as err:  # keep going; the row records it
                status, note = "fail", str(err).splitlines()[0]
                (OUT / f"{item['slug']}.log").write_text(log_text(), encoding="utf-8")
            if status == "fail":
                failed += 1
            sha = digest if status != "fail" or "same pixels" in note else ""
            rows.append((item["slug"], f"{item['slug']}.png", item["shows"], "-".join(item["keys"]) or "(none)", status, note, sha))
            print(f"{status:8} {item['slug']} {note}", flush=True)
    finally:
        stop()
        stop_hostkit_worker(worker)
        index = OUT / ("index.tsv" if not ONLY else "index-partial.tsv")
        lines = ["screen\tfile\tshows\tkeys\tstatus\tnotes\tsha256\n"]
        lines += ["\t".join(r) + "\n" for r in rows]
        index.write_text("".join(lines), encoding="utf-8")
    print(f"{len(rows)} screens, {len(seen)} unique, {failed} failed")
    if failed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
