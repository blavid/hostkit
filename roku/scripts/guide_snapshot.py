#!/usr/bin/env python3
"""Package-time guide snapshots, and the sanitized files committed in git.

The live guide contains the host phone and a few troubleshooting sentences
that are access details. Those stay out of this public repository.

--write-sanitized   download the live files and write scrubbed copies to
                    channel/data/ (the committed fallback).
--into-stage DIR    download the live files and overwrite DIR/data/*.json
                    with the unmodified bodies so the zip matches the site.
                    On any failure, leave the sanitized copies already in
                    the stage. Also write the bytes that will ship to
                    --snapshot-dir (gitignored) plus a one-word source file.
--check             parse the committed files and refuse phone numbers,
                    password lines, and combinations.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "channel" / "data"
GUIDE_URL = "https://sunrivertownhome.com/data/guide.json"
CHECKOUT_URL = "https://sunrivertownhome.com/data/checkout.json"
ACTIVITIES_URL = "https://sunrivertownhome.com/data/activities.json"
SAVINGS_PHRASE = "up to about 10% less"
FALL_DINING = (
    "Hot Lava Bakery",
    "Sparrow Bakery",
    "Rio Sol at Sunriver Marina",
    "El Caporal",
    "Blondie's Pizza",
    "Village Bar & Grill",
    "The Wallow",
    "Campfire Cucina",
    "Century Common Taps & Trucks",
    "Josie K's Deli",
)
FALL_HIKING = (
    "Smith Rock State Park",
    "Green Lakes Trail",
    "Tam McArthur Rim",
    "Deschutes River Trail",
    "Tumalo Falls",
    "Lava Butte & Lava Lands",
    "Benham Falls",
    "Todd Lake Loop",
)

PHONE = re.compile(r"\b\d{3}[-. ]\d{3}[-. ]\d{4}\b")
PIN_DASH = re.compile(r"\b\d(?:-\d){3,}\b")
PASSWORD_LINE = re.compile(r"(?i)\b(?:password|passcode)\b")
COMBINATION_LINE = re.compile(r"(?i)\bcombination\b")
PIN_WORD = re.compile(r"(?i)\bpin\b")

KITCHEN_NOTE = "See the note on the wall in the kitchen."
GARAGE_NOTE = "See the note in the garage."
HOUSE_NOTE = "See the note in the house."


def fail(message: str) -> None:
    print(message, file=sys.stderr)
    raise SystemExit(1)


def download(url: str) -> bytes:
    request = urllib.request.Request(
        url,
        headers={
            "Accept": "application/json",
            "User-Agent": "eaglewood-roku-package",
        },
    )
    with urllib.request.urlopen(request, timeout=8) as response:
        status = getattr(response, "status", 200)
        if status != 200:
            raise RuntimeError(f"HTTP {status}")
        body = response.read()
    if not body:
        raise RuntimeError("empty body")
    return body


def load_object(body: bytes) -> dict:
    parsed = json.loads(body.decode("utf-8"))
    if not isinstance(parsed, dict):
        raise RuntimeError("JSON root is not an object")
    return parsed


def is_guide(payload: dict) -> bool:
    return isinstance(payload.get("houseRules"), list) and isinstance(
        payload.get("troubleshooting"), list
    )


def is_checkout(payload: dict) -> bool:
    return isinstance(payload.get("steps"), list) and isinstance(payload.get("summary"), str)


def is_activities(payload: dict) -> bool:
    if not isinstance(payload.get("version"), int) or payload["version"] < 4:
        return False
    sections = payload.get("activitySections")
    if not isinstance(sections, list) or not sections:
        return False
    saw_tv = False
    for section in sections:
        if not isinstance(section, dict):
            return False
        rows = section.get("activities")
        if not isinstance(rows, list):
            return False
        for row in rows:
            if not isinstance(row, dict):
                return False
            tv = row.get("imageTvUrl")
            if isinstance(tv, str) and "/images/tv/" in tv and tv.endswith(".jpg"):
                saw_tv = True
    return saw_tv


def book_direct_ok(payload: dict) -> bool:
    block = payload.get("bookDirect")
    if not isinstance(block, dict):
        return False
    savings = block.get("savingsText")
    qr = block.get("qrImageUrl")
    booking = block.get("bookingQrImageUrl")
    photo = block.get("photoTvUrl")
    if not isinstance(savings, str) or SAVINGS_PHRASE not in savings:
        return False
    if not isinstance(qr, str) or not qr.endswith("/data/qr/book-direct-site.png"):
        return False
    if not isinstance(booking, str) or not booking.endswith("/data/qr/book-direct-booking.png"):
        return False
    if not isinstance(photo, str) or not photo.endswith("/images/tv/book-direct-living.jpg"):
        return False
    return True


def keep_richer_book(sanitized: dict, previous: dict | None) -> dict:
    if book_direct_ok(sanitized):
        return sanitized
    if isinstance(previous, dict) and book_direct_ok(previous):
        sanitized["bookDirect"] = json.loads(json.dumps(previous["bookDirect"]))
        version = sanitized.get("version")
        if not isinstance(version, int) or version < 3:
            sanitized["version"] = 3
    return sanitized


def season_rank(activity: dict, season: str) -> int:
    ranks = activity.get("seasonRank")
    if not isinstance(ranks, dict):
        return 10**9
    value = ranks.get(season)
    if isinstance(value, bool) or not isinstance(value, int) or value < 1:
        return 10**9
    return value


def ordered_names(payload: dict, section_id: str, season: str) -> list[str]:
    ranked = []
    index = 0
    for section in payload.get("activitySections") or []:
        if not isinstance(section, dict):
            continue
        rows = section.get("activities") or []
        if not isinstance(rows, list):
            continue
        for activity in rows:
            if isinstance(activity, dict) and section.get("id") == section_id:
                name = activity.get("name")
                ranked.append((season_rank(activity, season), index, name if isinstance(name, str) else ""))
            index += 1
    ranked.sort()
    return [name for _, _, name in ranked]


def activity_rows(payload: dict) -> list[tuple[str, dict]]:
    rows = []
    for section in payload.get("activitySections") or []:
        if not isinstance(section, dict):
            continue
        section_id = section.get("id")
        label = section_id if isinstance(section_id, str) else ""
        activities = section.get("activities") or []
        if not isinstance(activities, list):
            continue
        for activity in activities:
            if isinstance(activity, dict):
                rows.append((label, activity))
    return rows


def scrub_text(text: str) -> str:
    text = PHONE.sub("", text)
    text = PIN_DASH.sub("", text)
    return text


def step_note(issue: str) -> str:
    lowered = issue.lower()
    if "wifi" in lowered or "wi-fi" in lowered or "wi fi" in lowered:
        return KITCHEN_NOTE
    if "lock" in lowered and "bike" in lowered:
        return GARAGE_NOTE
    return HOUSE_NOTE


def redact_step(issue: str, index: int, step: str) -> str:
    lowered_issue = issue.lower()
    wifi = "wifi" in lowered_issue or "wi-fi" in lowered_issue or "wi fi" in lowered_issue
    lock = "lock" in lowered_issue and "bike" in lowered_issue
    secret = (
        PASSWORD_LINE.search(step)
        or COMBINATION_LINE.search(step)
        or PIN_WORD.search(step)
        or PHONE.search(step)
        or PIN_DASH.search(step)
    )
    # The published schema puts the access detail on the second step of the
    # Wi-Fi and bike-lock issues. Drop that step even if the sentence changes.
    positional = (wifi or lock) and index == 1
    if secret or positional:
        return step_note(issue)
    return scrub_text(step)


def sanitize_guide(payload: dict) -> dict:
    guide = json.loads(json.dumps(payload))
    site = guide.get("siteConfig")
    if isinstance(site, dict):
        host = site.get("host")
        if isinstance(host, dict):
            host["phone"] = None
        else:
            site["host"] = {"phone": None}
    issues = guide.get("troubleshooting")
    if isinstance(issues, list):
        for entry in issues:
            if not isinstance(entry, dict):
                continue
            issue = entry.get("issue")
            issue_text = issue if isinstance(issue, str) else ""
            steps = entry.get("steps")
            if not isinstance(steps, list):
                continue
            entry["steps"] = [
                redact_step(issue_text, index, step if isinstance(step, str) else "")
                for index, step in enumerate(steps)
            ]
    return scrub_tree(guide)


def scrub_tree(value):
    if isinstance(value, dict):
        scrubbed = {}
        for key, item in value.items():
            if key == "phone":
                scrubbed[key] = None
            else:
                scrubbed[key] = scrub_tree(item)
        return scrubbed
    if isinstance(value, list):
        return [scrub_tree(item) for item in value]
    if isinstance(value, str):
        return scrub_text(value)
    return value


def sanitize_checkout(payload: dict) -> dict:
    return scrub_tree(json.loads(json.dumps(payload)))


def dump(payload: dict) -> str:
    return json.dumps(payload, indent=2, ensure_ascii=False) + "\n"


def write_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def committed_paths() -> tuple[Path, Path, Path]:
    return DATA / "guide.json", DATA / "checkout.json", DATA / "activities.json"


def secret_hits(text: str) -> list[str]:
    hits = []
    if PHONE.search(text):
        hits.append("phone number")
    if PASSWORD_LINE.search(text):
        hits.append("password line")
    if COMBINATION_LINE.search(text):
        hits.append("combination")
    if PIN_WORD.search(text):
        hits.append("pin")
    if PIN_DASH.search(text):
        hits.append("dash combination")
    return hits


def check_committed() -> None:
    guide_path, checkout_path, activities_path = committed_paths()
    for name in ("wifi.json", "wifi.png"):
        secret_path = DATA / name
        if secret_path.exists():
            fail(f"{secret_path.relative_to(ROOT)} must not be committed")
    for path in (guide_path, checkout_path, activities_path):
        if not path.is_file():
            fail(f"missing {path.relative_to(ROOT)}")
        text = path.read_text(encoding="utf-8")
        hits = secret_hits(text)
        if hits:
            fail(f"{path.relative_to(ROOT)} still has: {', '.join(hits)}")
        try:
            payload = json.loads(text)
        except json.JSONDecodeError as exc:
            fail(f"{path.relative_to(ROOT)} is not JSON ({exc})")
        if not isinstance(payload, dict):
            fail(f"{path.relative_to(ROOT)} root is not an object")
    guide = json.loads(guide_path.read_text(encoding="utf-8"))
    checkout = json.loads(checkout_path.read_text(encoding="utf-8"))
    activities = json.loads(activities_path.read_text(encoding="utf-8"))
    if not is_guide(guide):
        fail("committed guide.json is missing houseRules or troubleshooting")
    if not is_checkout(checkout):
        fail("committed checkout.json is missing summary or steps")
    if not is_activities(activities):
        fail("committed activities.json must be version 4 with /images/tv JPEG urls")
    if not book_direct_ok(guide):
        fail("committed guide.json bookDirect is missing the TV contract")
    phone = guide.get("siteConfig", {}).get("host", {}).get("phone", "missing")
    if phone not in (None, ""):
        fail("committed guide.json host.phone must be null")
    rows = activity_rows(activities)
    ids = [row.get("id") for _, row in rows]
    if ids.count("viator-ebike-tour") != 2:
        fail("activities.json must keep both Electric Bike Tour cards")
    missing_url = 0
    with_qr = 0
    for _, row in rows:
        url = row.get("url")
        qr = row.get("qrUrl")
        has_url = isinstance(url, str) and url != ""
        has_qr = isinstance(qr, str) and qr != ""
        if has_url:
            if not has_qr:
                fail(f"activity {row.get('id')!r} has url but no qrUrl")
            with_qr += 1
        else:
            if has_qr:
                fail(f"activity {row.get('id')!r} has qrUrl without url")
            missing_url += 1
    if missing_url != 12 or with_qr != 54 or len(rows) != 66:
        fail(f"activity counts total={len(rows)} qr={with_qr} no-url={missing_url}")
    if tuple(ordered_names(activities, "dining", "fall")) != FALL_DINING:
        fail("fall dining order does not match seasonRank")
    if tuple(ordered_names(activities, "hiking", "fall")) != FALL_HIKING:
        fail("fall hiking order does not match seasonRank")
    rules = guide["houseRules"]
    issues = guide["troubleshooting"]
    steps = checkout["steps"]
    print(
        f"snapshot check ok rules={len(rules)} issues={len(issues)} "
        f"steps={len(steps)} phone=null activities={len(rows)} qr={with_qr}"
    )


def write_sanitized() -> None:
    try:
        guide_body = download(GUIDE_URL)
        checkout_body = download(CHECKOUT_URL)
        guide = load_object(guide_body)
        checkout = load_object(checkout_body)
    except (OSError, urllib.error.URLError, RuntimeError, json.JSONDecodeError, UnicodeError) as exc:
        fail(f"could not download the live guide ({exc.__class__.__name__})")
    if not is_guide(guide) or not is_checkout(checkout):
        fail("live guide or checkout did not match the expected shape")
    guide_path, checkout_path, activities_path = committed_paths()
    previous = None
    if guide_path.is_file():
        try:
            previous = json.loads(guide_path.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            previous = None
    merged = keep_richer_book(sanitize_guide(guide), previous if isinstance(previous, dict) else None)
    if not book_direct_ok(merged):
        fail("sanitized guide has no bookDirect block to keep")
    write_text(guide_path, dump(merged))
    write_text(checkout_path, dump(sanitize_checkout(checkout)))
    try:
        activities = load_object(download(ACTIVITIES_URL))
    except (OSError, urllib.error.URLError, RuntimeError, json.JSONDecodeError, UnicodeError) as exc:
        print(f"activities snapshot: kept committed file ({exc.__class__.__name__})", file=sys.stderr)
        activities = None
    if isinstance(activities, dict) and is_activities(activities):
        write_text(activities_path, dump(scrub_tree(activities)))
    else:
        print("activities snapshot: kept committed v4 file", file=sys.stderr)
    check_committed()
    print("wrote sanitized channel/data fallback")


def stage_live(stage: Path, snapshot_dir: Path | None) -> None:
    data = stage / "data"
    data.mkdir(parents=True, exist_ok=True)
    guide_path = data / "guide.json"
    checkout_path = data / "checkout.json"
    activities_path = data / "activities.json"
    if not guide_path.is_file() or not checkout_path.is_file() or not activities_path.is_file():
        fail("stage is missing the sanitized guide fallback")
    for name in ("wifi.json", "wifi.png"):
        secret_path = data / name
        if secret_path.exists():
            secret_path.unlink()
    source = "sanitized-fallback"
    try:
        guide_body = download(GUIDE_URL)
        checkout_body = download(CHECKOUT_URL)
        guide = load_object(guide_body)
        checkout = load_object(checkout_body)
        if not is_guide(guide) or not is_checkout(checkout):
            raise RuntimeError("unexpected shape")
        # Live bytes stay unmodified. A guide without bookDirect is still
        # shipped; the channel fills the default Book Direct copy.
        guide_path.write_bytes(guide_body if guide_body.endswith(b"\n") else guide_body + b"\n")
        checkout_path.write_bytes(
            checkout_body if checkout_body.endswith(b"\n") else checkout_body + b"\n"
        )
        source = "live"
    except (OSError, urllib.error.URLError, RuntimeError, json.JSONDecodeError, UnicodeError) as exc:
        print(
            f"guide snapshot: sanitized fallback ({exc.__class__.__name__})",
            file=sys.stderr,
        )
    else:
        print("guide snapshot: live")
    try:
        activities_body = download(ACTIVITIES_URL)
        activities = load_object(activities_body)
        if not is_activities(activities):
            raise RuntimeError("older activities file")
        activities_path.write_bytes(
            activities_body if activities_body.endswith(b"\n") else activities_body + b"\n"
        )
        print("activities snapshot: live")
    except (OSError, urllib.error.URLError, RuntimeError, json.JSONDecodeError, UnicodeError) as exc:
        print(
            f"activities snapshot: kept packaged v4 ({exc})",
            file=sys.stderr,
        )
    if snapshot_dir is not None:
        snapshot_dir.mkdir(parents=True, exist_ok=True)
        (snapshot_dir / "guide.json").write_bytes(guide_path.read_bytes())
        (snapshot_dir / "checkout.json").write_bytes(checkout_path.read_bytes())
        (snapshot_dir / "activities.json").write_bytes(activities_path.read_bytes())
        (snapshot_dir / "source.txt").write_text(source + "\n", encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description="Fetch or check the Eaglewood guide snapshot.")
    parser.add_argument("--write-sanitized", action="store_true")
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--into-stage", default="")
    parser.add_argument("--snapshot-dir", default="")
    args = parser.parse_args()
    selected = sum(1 for flag in (args.write_sanitized, args.check, bool(args.into_stage)) if flag)
    if selected != 1:
        fail("Choose one of --write-sanitized, --check, or --into-stage.")
    if args.check:
        check_committed()
        return
    if args.write_sanitized:
        write_sanitized()
        return
    snapshot = Path(args.snapshot_dir) if args.snapshot_dir else None
    stage_live(Path(args.into_stage), snapshot)


if __name__ == "__main__":
    main()
