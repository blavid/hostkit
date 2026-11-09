#!/usr/bin/env python3
"""Check the manifest, image sizes, greeting rules, secret handling, and zip."""

from __future__ import annotations

import re
import subprocess
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
from greeting import FONT_SIZES, build_greeting, sanitize_name_part, wrap_by_width  # noqa: E402

MANIFEST = ROOT / "channel" / "manifest"
IMAGES = ROOT / "channel" / "images"
SCENE_BRS = ROOT / "channel" / "components" / "MainScene.brs"
SCENE_XML = ROOT / "channel" / "components" / "MainScene.xml"
RULES_BRS = ROOT / "channel" / "components" / "GuestRules.brs"
GUIDE_UI_BRS = ROOT / "channel" / "components" / "GuideUi.brs"
GUIDE_FORMAT_BRS = ROOT / "channel" / "components" / "GuideFormat.brs"
GUIDE_MODEL_BRS = ROOT / "channel" / "components" / "GuideModel.brs"
SEASON_BRS = ROOT / "channel" / "components" / "Season.brs"
PHASE2_BRS = ROOT / "channel" / "components" / "Phase2Ui.brs"
CARD_BRS = ROOT / "channel" / "components" / "ActivityCard.brs"
# These files run on the render thread. The scene includes the guide scripts.
RENDER_THREAD_FILES = (
    SCENE_BRS,
    SCENE_XML,
    RULES_BRS,
    GUIDE_UI_BRS,
    GUIDE_FORMAT_BRS,
    GUIDE_MODEL_BRS,
    SEASON_BRS,
    PHASE2_BRS,
    CARD_BRS,
)
# roDateTime and roDeviceInfo are usable there. roSGNode is how the scene is built.
# roByteArray (build 33): the QR reload writes its own PNG copy from the task's bytes.
RENDER_THREAD_CREATE = {"roSGNode", "roDeviceInfo", "roDateTime", "roByteArray"}
# Creating these logs "MAIN|TASK-only component failed on RENDER thread".
RENDER_THREAD_FORBIDDEN = (
    "roFontRegistry",
    "roUrlTransfer",
    "roVideoPlayer",
    "roAudioPlayer",
    "roAudioResource",
    "roDatagramSocket",
    "roStreamSocket",
    "roHttpAgent",
    "roDataCache",
    "roImageMetadata",
    "roAudioMetadata",
    "roVideoMetadata",
    "roCaptionRenderer",
    "roScreen",
    "roCompositor",
    "roRegion",
    "roBitmap",
    "roTextToSpeech",
    "roAppManager",
    "roChannelStore",
    "roEVPCipher",
    "roEVPDigest",
    "roHMAC",
    "roRSA",
)
TASK_BRS = ROOT / "channel" / "components" / "GuestTask.brs"
CONFIG_BRS = ROOT / "channel" / "components" / "GuestConfig.brs"
ZIP_PATH = ROOT / "dist" / "eaglewood.zip"
LIMIT = 4 * 1024 * 1024
ORIGIN = "https://sunrivertownhome.com/tv/"

REQUIRED = {
    "title": "Eaglewood",
    "major_version": "1",
    "minor_version": "0",
    "build_version": "29",
    "mm_icon_focus_fhd": "pkg:/images/icon_fhd.jpg",
    "mm_icon_focus_hd": "pkg:/images/icon_hd.jpg",
    "splash_screen_fhd": "pkg:/images/splash_fhd.jpg",
    "splash_screen_hd": "pkg:/images/splash_hd.jpg",
    "splash_screen_sd": "pkg:/images/splash_sd.jpg",
    "ui_resolutions": "fhd",
    "rsg_version": "1.3",
    "network_not_required": "1",
    "supports_input_launch": "1",
    "splash_min_time": "0",
}

IMAGE_SPECS = {
    "background.jpg": (1920, 1080),
    "splash_fhd.jpg": (1920, 1080),
    "splash_hd.jpg": (1280, 720),
    "splash_sd.jpg": (720, 480),
    "icon_fhd.jpg": (540, 405),
    "icon_hd.jpg": (290, 218),
    "scrim.png": (4, 1080),
}

GREETING_CASES = [
    ("", "", "Welcome to Eaglewood 19"),
    ("   ", "", "Welcome to Eaglewood 19"),
    ("Alex", "", "Welcome, Alex"),
    ("Alex", "Rivera", "Welcome, Alex Rivera"),
    ("Alex", "R2", "Welcome, Alex"),
    ("R2", "Rivera", "Welcome to Eaglewood 19"),
    ("Mary-Jane", "O'Brien", "Welcome, Mary-Jane O'Brien"),
    ("José", "García", "Welcome, José García"),
    ("Ann  Marie", "van  Horn", "Welcome, Ann Marie van Horn"),
    ("St. James", "Park", "Welcome, St. James Park"),
    ("Alex123", "Lee", "Welcome to Eaglewood 19"),
    ("A" * 40, "Lee", "Welcome, " + ("A" * 32) + " Lee"),
    (None, "Lee", "Welcome to Eaglewood 19"),
]


def fail(message: str) -> None:
    print(f"FAIL {message}")
    raise SystemExit(1)


def print_lines(path: Path) -> list[str]:
    lines = []
    for line in path.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if stripped.startswith("print "):
            lines.append(stripped)
    return lines


def check_debug_prints(path: Path, required: list[str]) -> None:
    lines = print_lines(path)
    for line in lines:
        if not line.startswith('print "Eaglewood:'):
            fail(f"debug print must start with Eaglewood: {path.name}: {line}")
        if "GuestPathKey()" in line:
            fail(f"debug print must not read the path key in {path.name}")
    for needle in required:
        if not any(needle in line for line in lines):
            fail(f"{path.name} is missing a debug print containing {needle!r}")


def parse_manifest() -> dict[str, str]:
    text = MANIFEST.read_text(encoding="utf-8")
    if not text.endswith("\n"):
        fail("manifest must end with a newline")
    if "\r" in text:
        fail("manifest must use LF line endings")
    values: dict[str, str] = {}
    for line in text.splitlines():
        if not line or line.startswith("#"):
            continue
        if "=" not in line:
            fail(f"manifest line is not name=value: {line}")
        key, value = line.split("=", 1)
        values[key] = value
    return values


def check_manifest(values: dict[str, str]) -> None:
    for key, expected in REQUIRED.items():
        if values.get(key) != expected:
            fail(f"manifest {key}={values.get(key)!r}, expected {expected!r}")
    if "roku" in values["title"].lower():
        fail("title must not contain Roku")
    for key, uri in values.items():
        if not uri.startswith("pkg:/"):
            continue
        path = ROOT / "channel" / uri.removeprefix("pkg:/")
        if not path.is_file():
            fail(f"{key} points at missing {path}")


def check_images() -> None:
    from PIL import Image

    for name, size in IMAGE_SPECS.items():
        path = IMAGES / name
        with Image.open(path) as image:
            if image.size != size:
                fail(f"{name} is {image.size}, expected {size}")
            if name == "scrim.png" and image.mode != "RGBA":
                fail(f"scrim mode is {image.mode}")
            if name != "scrim.png" and image.mode not in ("RGB", "L"):
                fail(f"{name} mode is {image.mode}; icons and photos must be opaque")


def channel_text_files() -> list[Path]:
    files: list[Path] = []
    for path in (ROOT / "channel").rglob("*"):
        if not path.is_file() or path.suffix.lower() in {".jpg", ".png", ".jpeg"}:
            continue
        if path.name == "secrets.brs":
            continue
        files.append(path)
    return files


def check_greeting_rules() -> None:
    rules = RULES_BRS.read_text(encoding="utf-8")
    if f"return [{', '.join(str(size) for size in FONT_SIZES)}]" not in rules:
        fail("BrightScript font ladder does not match scripts/greeting.py")
    if "function NamePartLimit()" not in rules or "return 32" not in rules:
        fail("name parts must be capped at 32 characters")
    for first, last, expected in GREETING_CASES:
        actual = build_greeting(first, last)
        if actual != expected:
            fail(f"greeting {(first, last)!r} -> {actual!r}, expected {expected!r}")
    if build_greeting("Alex", "Lee", current=False) != "Welcome to Eaglewood 19":
        fail("a stay that is not current must use the fallback greeting")
    if sanitize_name_part("O\u2019Brien") != "O'Brien":
        fail("curly apostrophe was not normalized")
    wrapped = wrap_by_width("hello world", 50, 10)
    if wrapped != ["hello", "world"]:
        fail(f"wrap on space returned {wrapped!r}")


def check_render_thread() -> None:
    create_pattern = re.compile(r'CreateObject\(\s*"([^"]+)"')
    for path in RENDER_THREAD_FILES:
        text = path.read_text(encoding="utf-8")
        for name in RENDER_THREAD_FORBIDDEN:
            if name in text:
                fail(f"{path.name} references {name}, which cannot be created on the render thread")
        for match in create_pattern.finditer(text):
            kind = match.group(1)
            if kind not in RENDER_THREAD_CREATE:
                fail(f"{path.name} creates {kind} on the render thread")
    rules = RULES_BRS.read_text(encoding="utf-8")
    if "FromISO8601String" in rules:
        fail("checkout instants must be computed without handing a string to roDateTime")
    if "function DaysFromCivil(" not in rules or "Val(" not in rules or "Mid(" not in rules:
        fail("YYYY-MM-DD must be parsed with Mid and Val and converted with days-from-civil")
    scene = SCENE_BRS.read_text(encoding="utf-8")
    if 'm.greeting.font = "font:LargeBoldSystemFont"' not in scene:
        fail("the label must still draw font:LargeBoldSystemFont")
    if "ApplyPlainGreeting(FallbackGreeting())" not in scene:
        fail("init must set the fallback text before greeting layout")
    plain_at = scene.find("ApplyPlainGreeting(FallbackGreeting())")
    layout_at = scene.find("ApplyGreetingLayout(")
    if plain_at < 0 or layout_at < 0 or plain_at > layout_at:
        fail("plain greeting text must be assigned before greeting layout")
    check_font_sources()


def check_font_sources() -> None:
    """Font node uris must be packaged .ttf files. The font registry must not appear."""
    uri_in_tag = re.compile(r"<Font\b[^>]*\buri=\"([^\"]+)\"", re.IGNORECASE | re.DOTALL)
    uri_assign = re.compile(r"(?i)\.uri\s*=\s*\"([^\"]+)\"")
    ttf = re.compile(r"pkg:/.*\.ttf\Z", re.IGNORECASE)
    for path in (ROOT / "channel").rglob("*"):
        if not path.is_file() or path.suffix.lower() not in {".brs", ".xml"}:
            continue
        text = path.read_text(encoding="utf-8", errors="replace")
        if "roFontRegistry" in text:
            fail(f"{path.relative_to(ROOT)} references roFontRegistry")
        if "GetOneLineWidth" in text or "GetOneLineHeight" in text:
            fail(f"{path.relative_to(ROOT)} measures text at runtime")
        for uri in uri_in_tag.findall(text):
            if ttf.fullmatch(uri) is None:
                fail(f"{path.relative_to(ROOT)} Font uri {uri!r} is not a packaged .ttf")
        if 'CreateObject("roSGNode", "Font")' in text or "<Font" in text:
            assigned = uri_assign.findall(text)
            if not assigned or any(ttf.fullmatch(uri) is None for uri in assigned):
                fail(f"{path.relative_to(ROOT)} has a Font node without a packaged .ttf uri")
        for uri in re.findall(r'uri="(font:[^"]+)"', text):
            fail(f"{path.relative_to(ROOT)} uses Font uri {uri!r}; system faces belong on the Label font attribute")


def check_greeting_draws() -> None:
    xml = SCENE_XML.read_text(encoding="utf-8")
    source = SCENE_BRS.read_text(encoding="utf-8")
    if 'uri="font:' in xml:
        fail("a Font uri cannot load a system font; the label draws no glyphs")
    if 'font="font:LargeBoldSystemFont"' not in xml:
        fail("greeting Label must set font:LargeBoldSystemFont")
    if xml.find('id="background"') > xml.find('id="greeting"'):
        fail("greeting Label must come after the background Poster")
    if 'width="1132"' not in xml or 'wrap="true"' not in xml or 'maxLines="2"' not in xml:
        fail("greeting Label must wrap to two lines inside the 1132px home column")
    if 'm.greeting.font = "font:LargeBoldSystemFont"' not in source:
        fail("init must select the system font in BrightScript")
    if "m.greeting.text = text" not in source:
        fail("greeting text must be assigned on the label")
    if "Eaglewood: greeting = " not in source:
        fail("debug port must print the greeting")
    if "sub init()" not in source or source.find("ShowGreeting(FallbackGreeting())") > source.find("end sub"):
        fail("init() must show the fallback greeting before the first end sub")
    check_debug_prints(
        SCENE_BRS,
        [
            "Eaglewood: greeting = ",
            "Eaglewood: ui = ",
            "Eaglewood: task created",
            "Eaglewood: task started",
            "Eaglewood: relaunch",
            "skip reason=",
            "generation missing",
        ],
    )


def check_guest_fetch() -> None:
    task = TASK_BRS.read_text(encoding="utf-8")
    config = CONFIG_BRS.read_text(encoding="utf-8")
    rules = RULES_BRS.read_text(encoding="utf-8")
    if 'SetCertificatesFile("common:/certs/ca-bundle.crt")' not in task:
        fail("guest fetch must set the CA bundle")
    if "InitClientCertificates()" not in task:
        fail("guest fetch must call InitClientCertificates")
    if "wait(3000, port)" not in task:
        fail("guest fetch timeout must be 3 seconds")
    if "AsyncGetToString" not in task or "AsyncCancel" not in task:
        fail("guest fetch must use one async request and cancel it on timeout")
    if "EnableEncodings(true)" not in task or "RetainBodyOnError(true)" not in task:
        fail("guest fetch must decode gzip and keep an error body for the log")
    if "ReadGeneration()" not in task:
        fail("guest fetch must re-read generation before publishing the result")
    main = (ROOT / "channel" / "source" / "main.brs").read_text(encoding="utf-8")
    if "PrepareGuestCertificates()" not in main or 'SetCertificatesFile("common:/certs/ca-bundle.crt")' not in main:
        fail("main thread must initialize the HTTPS certificate bundle")
    check_debug_prints(
        TASK_BRS,
        [
            "key loaded",
            "url = ",
            "request sent",
            "response code=",
            "failure reason=",
            "snippet=",
            "parse ok=",
            "checkout decision=",
            "skip reason=",
            "RedactSecret(",
        ],
    )
    if print_lines(CONFIG_BRS) or print_lines(RULES_BRS):
        fail("guest config and name rules must not print")
    if task.count(ORIGIN) or rules.count(ORIGIN):
        fail("the guest origin belongs only in GuestConfig.brs")
    if config.count(ORIGIN) != 1:
        fail("GuestConfig.brs must contain the guest origin once")
    origin_hits = []
    for path in channel_text_files():
        hits = path.read_text(encoding="utf-8", errors="replace").count(ORIGIN)
        if hits:
            origin_hits.append((path, hits))
    if origin_hits != [(CONFIG_BRS, 1)]:
        fail(f"guest origin appears outside GuestConfig.brs: {origin_hits}")
    if "GuestPathKey()" not in config or "GuestStubUrl()" not in config:
        fail("the live URL must be built from the generated key and optional stub")
    task_xml = (ROOT / "channel" / "components" / "GuestTask.xml").read_text(encoding="utf-8")
    if "pkg:/components/secrets.brs" not in task_xml:
        fail("GuestTask must include secrets.brs so the path key is in task scope")
    if 'extends="Task"' not in task_xml:
        fail("guest fetch must run on a Task node")


def check_secret_file_is_untracked() -> None:
    ignore = (ROOT / ".gitignore").read_text(encoding="utf-8")
    if "channel/components/secrets.brs" not in ignore:
        fail(".gitignore must exclude channel/components/secrets.brs")
    result = subprocess.run(
        [sys.executable, str(ROOT / "scripts" / "check_tracked_guest_key.py")],
        cwd=ROOT,
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        detail = (result.stderr or result.stdout).strip()
        fail(detail or "tracked guest-key check failed")


def check_no_secrets() -> None:
    banned = re.compile(r"\b(?:\d{3}[-. ]\d{3}[-. ]\d{4}|\d{16}|WIFI_PASSWORD|DOOR_CODE|HOST_CONTACT)\b")
    for path in channel_text_files():
        text = path.read_text(encoding="utf-8", errors="replace")
        found = banned.search(text)
        if found:
            fail(f"unexpected sensitive token {found.group(0)!r} in {path}")


def check_guide() -> None:
    task_path = ROOT / "channel" / "components" / "GuideTask.brs"
    task_xml = ROOT / "channel" / "components" / "GuideTask.xml"
    task = task_path.read_text(encoding="utf-8")
    xml = task_xml.read_text(encoding="utf-8")
    scene = SCENE_BRS.read_text(encoding="utf-8")
    scene_xml = SCENE_XML.read_text(encoding="utf-8")
    if 'extends="Task"' not in xml:
        fail("guide fetch must run on a Task node")
    if 'SetCertificatesFile("common:/certs/ca-bundle.crt")' not in task:
        fail("guide fetch must set the CA bundle")
    if "InitClientCertificates()" not in task:
        fail("guide fetch must call InitClientCertificates")
    if "If-None-Match" not in task:
        fail("guide fetch must send If-None-Match")
    if "cachefs:/eaglewood/guide.json" not in task or "pkg:/data/guide.json" not in task:
        fail("guide fetch must read cachefs and the packaged snapshot")
    if "cachefs:/eaglewood/checkout.json" not in task or "pkg:/data/checkout.json" not in task:
        fail("checkout fetch must read cachefs and the packaged snapshot")
    if "https://sunrivertownhome.com/data/guide.json" not in task:
        fail("guide URL missing from GuideTask.brs")
    if "https://sunrivertownhome.com/data/checkout.json" not in task:
        fail("checkout URL missing from GuideTask.brs")
    if 'duration="600"' not in scene_xml or "duration = 600" not in scene:
        fail("idle timeout must be 600 seconds")
    for needle in (
        "Eaglewood: idle return home",
        "Eaglewood: back exit",
        "Eaglewood: focus restored",
        "Eaglewood: screen=",
    ):
        if needle not in scene:
            fail(f"MainScene.brs is missing {needle}")
    for needle in (
        'print "Eaglewood: guide version="',
        'print "Eaglewood: checkout decision="',
        '" request sent"',
        '" response code="',
        '" etag stored"',
        '" etag match"',
    ):
        if needle not in task:
            fail(f"GuideTask.brs is missing {needle}")
    if "GetOneLineWidth" in task or "roFontRegistry" in task:
        fail("guide task must not measure fonts")
    result = subprocess.run(
        [sys.executable, str(ROOT / "scripts" / "guide_snapshot.py"), "--check"],
        cwd=ROOT,
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        detail = (result.stderr or result.stdout).strip()
        fail(detail or "sanitized guide snapshot check failed")
    print(result.stdout.strip())


def check_zip() -> None:
    if not ZIP_PATH.is_file():
        print("skip zip (dist/eaglewood.zip not built)")
        return
    size = ZIP_PATH.stat().st_size
    if size > LIMIT:
        fail(f"zip is {size} bytes, over 4 MB")
    with zipfile.ZipFile(ZIP_PATH) as archive:
        names = archive.namelist()
        if "components/BuildStamp.brs" not in names:
            fail("zip is missing components/BuildStamp.brs")
        else:
            stamp = archive.read("components/BuildStamp.brs").decode("utf-8")
            if 'return "unknown"' in stamp or not re.search(r'return "[0-9a-f]{7}"', stamp):
                fail("package did not inject the short commit")
    if "manifest" not in names:
        fail("zip is missing manifest at the archive root")
    if "components/secrets.brs" not in names:
        fail("zip is missing components/secrets.brs")
    for name in ("data/guide.json", "data/checkout.json", "data/activities.json"):
        if name not in names:
            fail(f"zip is missing {name}")
    if "data/wifi.json" in names or "data/wifi.png" in names:
        fail("zip includes Wi-Fi secrets")
    if any(name.startswith("/") or name.startswith("\\") or ".." in name.split("/") for name in names):
        fail(f"zip has unsafe entry names: {names}")
    if any(name.startswith("channel/") for name in names):
        fail("zip wraps the channel in an extra folder")
    print(f"zip {size} bytes, {len(names)} entries")


def check_phase2() -> None:
    season = SEASON_BRS.read_text(encoding="utf-8")
    phase2 = PHASE2_BRS.read_text(encoding="utf-8")
    scene = SCENE_BRS.read_text(encoding="utf-8")
    xml = SCENE_XML.read_text(encoding="utf-8")
    config = CONFIG_BRS.read_text(encoding="utf-8")
    if "function ResolveContentUrl(" not in season or "function ContentOrigin(" not in season:
        fail("relative activity URLs must resolve against the site origin")
    if "function WifiScreenMode(" not in season:
        fail("Wi-Fi responses need a screen mode")
    if 'return "pkg:/images/tv-placeholder.jpg"' not in season:
        fail("the channel must bundle its own TV placeholder")
    placeholder = IMAGES / "tv-placeholder.jpg"
    if not placeholder.is_file():
        fail("missing channel/images/tv-placeholder.jpg")
    from PIL import Image

    with Image.open(placeholder) as image:
        if image.size != (64, 64):
            fail(f"tv-placeholder.jpg is {image.size}, expected 64x64")
    if "Wi-Fi details coming soon" not in phase2:
        fail("a 503 with no cache must show the coming-soon line")
    if "Book your next stay direct and save!" not in phase2:
        fail("the home strip needs the direct-booking headline")
    if "Wi-Fi details couldn't load right now." not in phase2:
        fail("Wi-Fi fallback needs the host message")
    if "function NetworkValue(" not in phase2:
        fail("the Wi-Fi network value must drop a Network name prefix")
    if "function HomePromptTitle(" not in phase2:
        fail("the home strip title must come from HomePromptTitle")
    png = (ROOT / "channel" / "components" / "PngRgb.brs").read_text(encoding="utf-8")
    wifi = (ROOT / "channel" / "components" / "WifiTask.brs").read_text(encoding="utf-8")
    if "function ExpandPngBytes(" not in png or "function SafeUri(" not in png:
        fail("QR PNGs need the indexed rewrite and a redacted URI")
    if "function StorePngBytes(" not in png or "tmp:/" not in png:
        fail("QR saves must try cachefs and then tmp")
    if "function WithQrVersion(" not in season or "?v=rgb2" not in season or "&v=rgb2" not in season:
        fail("public QR URLs must add v=rgb2")
    if "sub ClearStaleQrCache(" not in png or "qrCacheVersion" not in png:
        fail("startup must clear stale QR cache once per version")
    if "ClearStaleQrCache(" in scene:
        fail("QR cache cleanup must not run on the render thread")
    qr_task = (ROOT / "channel" / "components" / "QrTask.brs").read_text(encoding="utf-8")
    if "ClearStaleQrCache(busy)" not in qr_task:
        fail("QR cache cleanup must run on the QR task")
    if "digest.Process(raw)" not in png or 'digest.Setup("md5")' not in png or "digest.Final()" not in png:
        fail("QR files must be named from md5 via roEVPDigest Process")
    if "fs.Rename(" not in png or "fs.MoveFile(" in png:
        fail("QR files must be renamed into place")
    if "fs.Exists(" not in qr_task:
        fail("a missing QR note must be skipped before ReadAsciiFile")
    if "wifi png format bitdepth=" not in wifi:
        fail("wifi png format must be logged")
    if "sub MountQrPosterBody(" not in phase2:
        fail("public QR posters must use the Wi-Fi local-file mount")
    diag = (ROOT / "channel" / "components" / "QrDiag.brs").read_text(encoding="utf-8")
    if "sub MountQrPoster(" not in diag or "sub GuardMountQrPoster(" not in diag:
        fail("QR mount must be wrapped in try/catch")
    if 'print "Eaglewood: qr "; slot; " error="' not in diag:
        fail("a caught QR error must be logged")
    stamp = (ROOT / "channel" / "components" / "BuildStamp.brs").read_text(encoding="utf-8")
    if 'return "unknown"' not in stamp or "build 43 · " not in stamp:
        fail("the build label must keep a package-time commit placeholder")
    if 'print "Eaglewood: build 43 "' not in scene:
        fail("startup must log build 43 and the commit")
    if "decor-heart" in phase2:
        fail("the Book Direct heart poster is still in the scene")
    qr_xml = (ROOT / "channel" / "components" / "QrTask.xml").read_text(encoding="utf-8")
    if 'id="finalUri"' not in qr_xml or "alwaysNotify" not in qr_xml:
        fail("each QR task needs a finalUri field")
    fetch = scene[scene.find("sub StartQrFetch("):scene.find("sub onBadgeQrUri(")]
    observed = fetch.find('observeField("finalUri"')
    started = fetch.find('control = "RUN"')
    if observed < 0 or started < 0 or observed > started:
        fail("finalUri must be observed on the task before it runs")
    if "m.qrPaths" not in scene or "deliver uri=" not in phase2:
        fail("a finished QR path must be stored and assigned to the poster")
    if "function ActivitiesFromFetch(" not in season or "function ActivityById(" not in season:
        fail("detail must resolve qrUrl by activity id")
    if "function ActivitiesCacheDropsQr(" not in season or "function ActivitiesCacheGeneration(" not in season:
        fail("a stale activities cache must be recognizable")
    guide_task = (ROOT / "channel" / "components" / "GuideTask.brs").read_text(encoding="utf-8")
    if "activities cache discarded" not in guide_task or 'HttpGet(url, "")' not in guide_task:
        fail("a 304 or a cache missing qrUrl must be deleted and fetched again")
    if "activitiesCacheKey" not in guide_task or "DeleteActivitiesCache()" not in guide_task:
        fail("the activities cache generation must discard the stale file and etag")
    if 'print "Eaglewood: detail open id="' not in phase2:
        fail("opening detail must log detail open id and qrUrl")
    if "ActivitiesFromText(" not in (ROOT / "channel" / "components" / "GuideTask.brs").read_text(encoding="utf-8"):
        fail("304 and 200 activities must share one parse path")
    if "RetainBodyOnError(true)" not in qr_task or "InitClientCertificates()" not in qr_task:
        fail("public QR downloads must use the Wi-Fi certificate setup")
    if "raw.WriteFile(path)" not in qr_task or "fs.Exists(path)" not in qr_task:
        fail("public QR bytes must be written to the final file and checked with Exists")
    if "incoming.tmp" in qr_task or ".Rename(" in qr_task:
        fail("public QR saves must not use a temp file or rename")
    if 'item["qrUrl"] = qr' not in season or 'item["qrUri"] = qr' not in season or "function ChooseActivities(" not in season:
        fail("activity qrUrl must be passed through to the detail item")
    if "function AaField(" not in GUIDE_MODEL_BRS.read_text(encoding="utf-8"):
        fail("activity fields must be read by the exact key and the lowercase key")
    if "function QrContentFileName(" not in png or "function CommitQrBytes(" not in png:
        fail("QR files must be content-named")
    if 'print "Eaglewood: heartbeat"' not in scene or 'id="heartbeatTimer"' not in xml:
        fail("the render thread needs a 5 second heartbeat")
    if 'print "Eaglewood: key "' not in scene:
        fail("every key event must be logged")
    if "function BookQrFits(" not in phase2 or "findNode(id)" not in phase2:
        fail("Book Direct must measure its QR slot and assign the live poster")
    if 'print "Eaglewood: qr detail open url="' not in phase2:
        fail("activity detail must fetch its QR when the screen opens")
    if "sub EnsureQrSlot(" not in phase2 or "sub ShowQrFrame(" not in phase2:
        fail("badge, book, and detail must share one QR slot helper")
    if 'EnsureQrSlot("badge"' not in phase2 or 'EnsureQrSlot("book"' not in phase2 or 'EnsureQrSlot("detail"' not in phase2:
        fail("badge, book, and detail must open a QR through EnsureQrSlot")
    deliver = scene[scene.find("sub DeliverQrPath("):scene.find("sub RememberQrFormat(")]
    if "ShowQrFrame(slot, true)" not in deliver or "AssignQrPoster(slot, uri)" not in deliver:
        fail("a finished QR path must show the frame and then assign the poster")
    if "ShowBookQr" in deliver or "ShowDetailQr" in deliver or "UpdateBadgeVisible" in deliver:
        fail("QR deliver must use the same helper for every slot")
    debug = phase2[phase2.find("function QrDebugMarks()"):phase2.find("function QrMarkColor(")]
    if "return false" not in debug:
        fail("magenta QR marks must stay behind a debug flag that is off")
    if 'return "0xFFFFFFF2"' not in phase2 or "0xFF00FFFF" not in phase2:
        fail("QR placeholders are cream unless the debug flag is on")
    badge = phase2[phase2.find("sub BuildBadge("):phase2.find("function BuildBookPane(")]
    if "AddRect(parent," in badge or badge.find("m.badgeMark") > badge.find("group.appendChild(m.badgePoster)"):
        fail("the badge placeholder must sit under the poster, on the badge group")
    book_pane = phase2[phase2.find("function BuildBookPane("):phase2.find("function BuildWifiPane(")]
    if "m.bookQrMark" not in book_pane or book_pane.find("m.bookQrMark") > book_pane.find("pane.appendChild(m.bookQr)"):
        fail("the book poster must be appended after its placeholder")
    detail = phase2[phase2.find("function BuildDetailPane("):phase2.find("sub PaintPhase2(")]
    if "m.detailQrMark" not in detail or detail.find("m.detailQrMark") > detail.find("pane.appendChild(m.detailQr)"):
        fail("the detail poster must be appended after its placeholder")
    if "function DetailQrCardRect(" not in phase2 or "DetailQrCardRect()" not in detail:
        fail("the detail QR card must use one screen rect")
    if "group.translation = [frame.x, frame.y]" not in badge or "BadgeCardColor()" not in badge:
        fail("the badge group must sit at BadgeFrame() on the cream card")
    if "m.badgePoster.translation = [frame.qrX, frame.qrY]" not in badge or "m.badgePoster.width = frame.qr" not in badge:
        fail("the badge QR must take its size and place from BadgeFrame()")
    # Build 33: the cream card always draws; only the QR waits for its bitmap.
    if "m.badgePoster.visible = (show and ready)" not in phase2 or "m.badgeCard.visible = show" not in phase2:
        fail("the badge card must always draw and its QR must wait for the bitmap")
    if "sub ArmBadgeDeadline(" not in phase2 or "BadgeFallbackText()" not in phase2:
        fail("the badge must fall back to no-link text after its deadline")
    if "BadgeCaptionColor()" not in badge or "0x8A5A00FF" not in phase2:
        fail("the badge caption must use the dark gold that clears the cream tile")
    if "QrCaptionFont()" not in badge or "QrCaptionColor()" not in badge:
        fail("the badge caption must use the gold caption style")
    if "Book direct" in badge:
        fail("the Book direct label stays off the corner badge")
    guide = GUIDE_UI_BRS.read_text(encoding="utf-8")
    if "m.buildLabel" in guide or "BuildStampLine()" in guide:
        fail("the build number stays in the startup log, not on Home")
    show = guide[guide.find("sub ShowSection("):guide.find("sub PaintAll(")]
    shell = guide[guide.find("sub BuildShell("):guide.find("sub BuildTiles(")]
    if "RaiseBadge()" not in shell:
        fail("BuildShell must raise the corner badge once, before the first screen")
    if "RaiseBadge()" in show:
        fail("ShowSection must not reparent the corner badge")
    if "LogBadgePlacement()" not in show:
        fail("every screen change must log the corner badge placement")
    if 'shell.id = "shell"' not in shell:
        fail("the shell needs an id so the badge parent is logged")
    detail_open = scene[scene.find("function OpenActivityDetail("):scene.find("function HandleBack(")]
    if "RaiseBadge()" in detail_open:
        fail("opening detail must not reparent the corner badge")
    if "function BadgeNavigateReparents(" not in phase2 or "return false" not in phase2[phase2.find("function BadgeNavigateReparents("):phase2.find("function DetailQrUrl(")]:
        fail("navigation must leave the corner badge on its build 20 node")
    if "This place" in detail:
        fail("the activity detail QR must not keep the This place label")
    if "DetailQrPosterRect()" not in detail:
        fail("the activity detail QR must use the shared poster rect")
    if "function NextNav(" not in guide or "Checkout Instructions" not in guide:
        fail("the rail needs the Things to Do submenu and Checkout Instructions")
    if "font:SmallBoldSystemFont" not in shell:
        fail("nav items need the smaller font so Checkout Instructions fits")
    if "function QrRectText(" not in phase2 or "caption badge rect=" not in phase2:
        fail("caption and Checkout rects must be logged")
    if 'print "Eaglewood: qr ' not in phase2:
        fail("poster loadStatus must be logged for late debug consoles")
    for path in channel_text_files():
        if "cornerRadius" in path.read_text(encoding="utf-8", errors="replace"):
            fail(f"{path.relative_to(ROOT)} sets cornerRadius, which this firmware rejects")
    if 'duration="21600"' not in xml or "duration = 21600" not in scene:
        fail("guide and Wi-Fi refresh must be 21600 seconds")
    # Build 40 (Blake via Captain): Home opens with focus on the rail Home row.
    if 'zone: "rail", section: "home"' not in (ROOT / "channel" / "components" / "GuideUi.brs").read_text(encoding="utf-8"):
        fail("Home must open with focus on the rail Home row")
    if "function WifiJsonUrl(" not in config or "function WifiPngUrl(" not in config:
        fail("Wi-Fi URLs must be built beside the guest URL")
    if 'bookingUrl: "https://book.sunrivertownhome.com"' not in season:
        fail("the corner badge must target the booking host")
    for path in channel_text_files():
        if 'return "sunrivertownhome.com"' in path.read_text(encoding="utf-8", errors="replace"):
            fail(f"{path.relative_to(ROOT)} returns the site domain as a bare literal")
    if (ROOT / "channel" / "data" / "wifi.json").exists() or (ROOT / "channel" / "data" / "wifi.png").exists():
        fail("Wi-Fi credentials must not sit in channel/data")


def main() -> None:
    check_manifest(parse_manifest())
    check_images()
    check_greeting_rules()
    check_render_thread()
    check_greeting_draws()
    check_guest_fetch()
    check_guide()
    check_phase2()
    check_secret_file_is_untracked()
    check_no_secrets()
    check_zip()
    print("validate ok")


if __name__ == "__main__":
    main()
