#!/usr/bin/env python3
"""Flag guest strings that would ellipsize in a Label.

ScrollableText is not a Label. Long troubleshooting steps and activity
descriptions are reported as scroll range instead.

Live guide.json and activities.json are fetched with the channel user agent.
A failed fetch is an error, not a pass.
"""

from __future__ import annotations

import json
import sys
import urllib.request

GUIDE_URL = "https://sunrivertownhome.com/data/guide.json"
ACTIVITIES_URL = "https://sunrivertownhome.com/data/activities.json"
UA = "EaglewoodQrCheck/26"


def pessimistic(size: int) -> int:
    base = max(1, (size * 3) // 4)
    return max(base + 1, (base * 115 + 99) // 100)


def line_box(size: int) -> int:
    return size + 13


def wrap(text: str, width: int, char_width: int) -> list[str]:
    if not text:
        return []
    lines: list[str] = []
    current = ""
    for word in text.split(" "):
        trial = word if not current else current + " " + word
        if len(trial) * char_width <= width:
            current = trial
            continue
        if current:
            lines.append(current)
        while len(word) * char_width > width:
            count = max(1, width // char_width)
            lines.append(word[:count])
            word = word[count:]
        current = word
    if current:
        lines.append(current)
    return lines


def longest_word(text: str, char_width: int) -> int:
    words = [word for word in text.split(" ") if word]
    if not words:
        return 0
    return max(len(word) for word in words) * char_width


def fails(text: str, width: int, size: int, max_lines: int, height: int, do_wrap: bool) -> str:
    if not text:
        return ""
    char_width = pessimistic(size)
    if not do_wrap:
        if len(text) * char_width > width:
            return f"nowrap {len(text) * char_width}px > {width}px"
        return ""
    if longest_word(text, char_width) > width:
        return "word wider than the label"
    lines = wrap(text, width, char_width)
    if len(lines) > max_lines:
        return f"{len(lines)} lines > maxLines {max_lines}"
    if len(lines) * line_box(size) > height:
        return f"line box {len(lines) * line_box(size)}px > height {height}px"
    return ""


def fetch(url: str) -> dict:
    request = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)


def paragraphs(text: str, width: int = 1068) -> int:
    count = 0
    for part in text.split("\n"):
        wrapped = wrap(part, width, pessimistic(30))
        count += max(1, len(wrapped)) if part else 1
    return count


def main() -> int:
    try:
        guide = fetch(GUIDE_URL)
        activities = fetch(ACTIVITIES_URL)
    except Exception as exc:
        print(f"FAIL could not fetch live JSON: {exc}", file=sys.stderr)
        return 1

    problems: list[str] = []

    def check(name: str, text: str, width: int, size: int, max_lines: int, height: int, do_wrap: bool = True) -> None:
        reason = fails(text or "", width, size, max_lines, height, do_wrap)
        if reason:
            problems.append(f"{name}: {reason}")

    menu_labels = {
        "Home": (288, 2, 88),
        "Wi-Fi": (288, 2, 88),
        "Things to Do": (288, 2, 88),
        "House Rules": (288, 2, 88),
        "Quick Fixes": (288, 2, 88),
        "Book Direct": (288, 2, 88),
        "Checkout": (332, 1, 44),
    }
    for label, (width, max_lines, height) in menu_labels.items():
        check(f"rail {label}", label, width, 27, max_lines, height)

    issues = guide.get("troubleshooting") or []
    visible = []
    for issue in issues:
        title = str(issue.get("issue") or "")
        lower = title.lower()
        if "wifi" in lower or "wi-fi" in lower or "wi fi" in lower:
            continue
        visible.append(issue)
        check(f"fix title {title}", title, 300, 27, 4, 160)

    for rule in guide.get("houseRules") or []:
        if isinstance(rule, str):
            check(f"rule {rule[:24]}", rule, 620, 30, 3, 120)

    book = guide.get("bookDirect") or {}
    if isinstance(book.get("body"), str):
        check("book body", book["body"], 1097, 30, 4, 168)  # build 40: full-width body, BookBodyRect()
    if isinstance(book.get("savingsText"), str):
        check("book savings", book["savingsText"], 1097, 30, 2, 84)  # build 40: BookSavingsRect()
    for perk in book.get("perks") or []:
        if isinstance(perk, str):
            check(f"perk {perk[:24]}", "Outdoors" if perk.lower() == "outdoor adventures" else perk, 192, 26, 1, 56)
    check("detail qr caption", "Scan for info", 280, 20, 1, 34, False)
    check("badge domain", "sunrivertownhome.com", 520, 20, 1, 44, False)
    check("home badge domain", "sunrivertownhome.com", 520, 28, 1, 40, False)
    fallback = "Wi-Fi details couldn't load right now. Please check your booking welcome message or contact your host (see Quick Fixes)."
    # Build 28 status panel body: 416 wide at 28px, 9 lines in 376.
    check("wifi fallback", fallback, 416, 28, 9, 376)
    check("wifi status heading", "Wi-Fi details didn't load", 416, 34, 2, 96)

    items = []
    for block in activities.get("activitySections") or []:
        for item in block.get("activities") or []:
            item = dict(item)
            item["_section"] = block.get("id")
            items.append(item)
    for item in items:
        name = item.get("name") or ""
        # Build 30: cards pre-break at 0.6 em (18px at 30, 15px at 24) and
        # the photo shrinks 38px per title line past 3 (420px card).
        name_lines = wrap(name, 332, 18)
        meta_lines = wrap(item.get("distance") or "", 332, 15)
        photo = 200 - 38 * max(0, len(name_lines) - 3)
        bottom = 5 + photo + 16 + max(1, len(name_lines)) * 38 + 12 + len(meta_lines) * 32
        if bottom > 415 or photo < 124 or len(meta_lines) > 2:
            problems.append(f"card {name}: bottom={bottom} photo={photo}")
        check(f"season {name}", item.get("seasonLabel") or "", 332, 20, 3, 99)

    if problems:
        print(f"ellipsis failures={len(problems)}")
        for problem in problems:
            print(problem)
        return 1

    # Build 29: DetailScroll lines are 30px at a 42px pitch.
    def scroll_report(label: str, text: str, viewport: int, width: int) -> None:
        lines = paragraphs(text, width)
        content_h = lines * (30 + 12)
        span = max(0, content_h - viewport)
        print(
            f"scroll {label} lines={lines} contentH={content_h} viewport={viewport} range={span}"
        )

    def fix_body(issue: dict) -> str:
        parts = [str(issue.get("issue") or "")]
        for index, step in enumerate(issue.get("steps") or []):
            parts.append(f"{index + 1}. {step}")
        return "\n".join(parts)

    longest_fix = max(visible, key=lambda issue: paragraphs(fix_body(issue), 1016))
    # Panel y 234-960, 32px padding, hint row: 614px of text.
    scroll_report("fixes", fix_body(longest_fix), 614, 1016)
    print(f"scroll fixes title={longest_fix.get('issue')}")

    dining = [item for item in items if item.get("_section") == "dining"]

    def dining_body(item: dict) -> str:
        text = item.get("description") or ""
        tip = item.get("tip") or ""
        if tip:
            text = text + "\nTip: " + tip
        return text

    longest_dining = max(dining, key=lambda item: paragraphs(dining_body(item), 972))
    # Detail body y 625-940, 16px padding, hint row: 219px (5 lines).
    scroll_report("dining", dining_body(longest_dining), 219, 972)
    print(f"scroll dining title={longest_dining.get('name')}")
    print("ellipsis failures=0")
    return 0


if __name__ == "__main__":
    sys.exit(main())
