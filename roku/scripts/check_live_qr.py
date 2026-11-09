#!/usr/bin/env python3
"""Fetch live activity QR PNGs and check the PNG header.

Requests https://sunrivertownhome.com/data/activities.json, then every
activity qrUrl with ?v=rgb2. Each image must be HTTP 200, a PNG, and the
IHDR bit depth and color type are reported.
"""

from __future__ import annotations

import json
import sys
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed

ACTIVITIES = "https://sunrivertownhome.com/data/activities.json"
PNG_SIG = b"\x89PNG\r\n\x1a\n"
TIMEOUT = 30


def versioned(url: str) -> str:
    if "/data/qr/" not in url:
        return url
    if "?v=rgb2" in url or "&v=rgb2" in url:
        return url
    if "?" in url:
        return url + "&v=rgb2"
    return url + "?v=rgb2"


def activities(doc: object) -> list[dict]:
    rows: list[dict] = []
    if isinstance(doc, dict):
        sections = doc.get("activitySections")
        if isinstance(sections, list):
            for section in sections:
                if isinstance(section, dict) and isinstance(section.get("activities"), list):
                    rows.extend(item for item in section["activities"] if isinstance(item, dict))
        if isinstance(doc.get("activities"), list):
            rows.extend(item for item in doc["activities"] if isinstance(item, dict))
    return rows


def fetch(url: str) -> tuple[int, bytes, str]:
    request = urllib.request.Request(
        url,
        headers={
            "Accept": "image/png,application/json",
            "User-Agent": "EaglewoodQrCheck/20",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=TIMEOUT) as response:
            return response.status, response.read(), ""
    except urllib.error.HTTPError as err:
        body = err.read() if err.fp is not None else b""
        return err.code, body, str(err)
    except urllib.error.URLError as err:
        return 0, b"", str(err.reason)


def ihdr(blob: bytes) -> tuple[int, int] | str:
    if len(blob) < 26 or blob[:8] != PNG_SIG:
        return "not-png"
    if blob[12:16] != b"IHDR":
        return "no-ihdr"
    return blob[24], blob[25]


def main() -> int:
    status, body, error = fetch(ACTIVITIES)
    print(f"activities status={status} bytes={len(body)} error={error or 'none'}")
    if status != 200:
        return 1
    rows = activities(json.loads(body.decode("utf-8")))
    targets: list[tuple[str, str]] = []
    missing = 0
    for item in rows:
        raw = item.get("qrUrl")
        if not isinstance(raw, str) or raw == "":
            missing += 1
            continue
        targets.append((str(item.get("id", "")), versioned(raw)))
    print(f"activities={len(rows)} withQr={len(targets)} withoutQr={missing}")
    failures: list[str] = []
    color_counts: dict[str, int] = {}

    def one(pair: tuple[str, str]) -> tuple[str, str, int, str]:
        item_id, url = pair
        code, blob, err = fetch(url)
        header = ihdr(blob) if code == 200 else "skipped"
        if code != 200 or isinstance(header, str):
            why = header if isinstance(header, str) else "bad"
            if err:
                why = f"{why} {err}"
            return item_id, url, code, why
        bit, color = header
        return item_id, url, code, f"bit={bit} color={color} bytes={len(blob)}"

    with ThreadPoolExecutor(max_workers=8) as pool:
        futures = [pool.submit(one, pair) for pair in targets]
        for future in as_completed(futures):
            item_id, url, code, detail = future.result()
            ok = detail.startswith("bit=")
            if ok:
                color_counts[detail.split(" bytes=")[0]] = color_counts.get(detail.split(" bytes=")[0], 0) + 1
            else:
                failures.append(f"id={item_id} status={code} {detail} url={url}")

    print("ihdr=" + ", ".join(f"{key} n={color_counts[key]}" for key in sorted(color_counts)))
    print(f"checked={len(targets)} ok={len(targets) - len(failures)} failed={len(failures)}")
    for line in failures:
        print("FAIL " + line)
    return 1 if failures or status != 200 else 0


if __name__ == "__main__":
    sys.exit(main())
