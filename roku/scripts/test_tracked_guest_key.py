#!/usr/bin/env python3
"""Both sides of the tracked guest-key guard.

A Roku color and a short letter word are not keys. A path-key shaped
literal is, including hex that is not exactly 0x plus eight hex digits.
Failure text names the case, not the literal.
"""

from __future__ import annotations

import importlib.util
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def load_checker():
    path = ROOT / "scripts" / "check_tracked_guest_key.py"
    spec = importlib.util.spec_from_file_location("check_tracked_guest_key", path)
    if spec is None or spec.loader is None:
        sys.stderr.write("FAIL could not load the guest-key checker\n")
        raise SystemExit(1)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def fail(message: str) -> None:
    sys.stderr.write("FAIL " + message + "\n")
    raise SystemExit(1)


def expect(got: bool, key_like: bool, label: str) -> None:
    if got != key_like:
        fail(label)


def main() -> None:
    checker = load_checker()
    # (label, token, key_like). Tokens are fixtures, not live secrets.
    cases = (
        ("roku amber color", "0xF2A93BFF", False),
        ("roku white", "0xFFFFFFFF", False),
        ("roku mute color", "0xD5DBE8FF", False),
        ("roku ink on amber", "0x1C1408FF", False),
        ("roku glass color", "0x1A2438D0", False),
        ("roku tile color", "0x243044C8", False),
        ("roku color lowercase hex", "0xffffffff", False),
        ("short letter word", "Checkout", False),
        ("letter word under 16", "Troubleshooting", False),
        ("checkout decision word", "unreadable", False),
        ("16 letter token", "abcdefghijklmnop", True),
        ("8 char mixed token", "abcd1234", True),
        ("hex without 0x prefix", "F2A93BFF", True),
        ("0X prefix is not a roku color", "0XF2A93BFF", True),
        ("longer than a roku color", "0xF2A93BFFAA", True),
        ("shorter than eight hex digits", "0xF2A93B", True),
        ("non-hex in the color slot", "0xF2A93BFG", True),
        ("color with a suffix", "0xF2A93BFF.x", True),
        ("path key shape", "k3f8a1b0c9d2e4aa", True),
        ("dotted path segment", "guest.key_1", True),
    )
    for label, token, key_like in cases:
        expect(checker.token_is_key_like(token), key_like, label)
        print("ok " + label)

    color_line = 'channel/components/GuideUi.brs:48:    return "0xF2A93BFF"'
    word_line = 'channel/components/GuideUi.brs:82:    if section = "fixes" then return "Troubleshooting"'
    key_line = 'channel/components/GuideUi.brs:99:    return "abcd1234ef"'
    if checker.offending_paths(color_line + "\n" + word_line):
        fail("benign GuideUi returns were flagged")
    print("ok benign returns")
    flagged = checker.offending_paths(color_line + "\n" + key_line)
    if flagged != ["channel/components/GuideUi.brs"]:
        fail("a key-like return beside a color was not flagged")
    print("ok key-like return is flagged")

    guide = (ROOT / "channel" / "components" / "GuideUi.brs").read_text(encoding="utf-8")
    returned = checker.LITERAL_TOKEN.findall(guide)
    if not returned:
        fail("GuideUi.brs has no returned literals to classify")
    if any(checker.token_is_key_like(token) for token in returned):
        fail("GuideUi.brs still returns a key-like literal")
    if "0xF2A93BFF" not in returned:
        fail("GuideUi.brs no longer returns the amber color literal")
    print("ok GuideUi.brs returns are colors or short words")

    mutated = guide.replace('return "0xF2A93BFF"', 'return "abcd1234ef"', 1)
    if mutated == guide:
        fail("could not plant a key-like literal in GuideUi text")
    if not any(checker.token_is_key_like(token) for token in checker.LITERAL_TOKEN.findall(mutated)):
        fail("a planted key-like literal in GuideUi text was ignored")
    print("ok planted key-like literal is still detected")

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
    print("ok tracked channel passes the guard")
    print("tracked guest-key cases ok")


if __name__ == "__main__":
    main()
