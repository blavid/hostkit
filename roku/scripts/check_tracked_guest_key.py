#!/usr/bin/env python3
"""Fail if a tracked file contains a concrete guest path key.

The documentation placeholder uses angle brackets, so it does not match.
Matching lines are not printed.
"""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# A real /tv/<segment>/guest.json. The placeholder uses <GUEST_PATH_KEY>.
URL_PATTERN = r"sunrivertownhome\.com/tv/[A-Za-z0-9._~-]+/guest\.json"
# A returned token with the shape of a path key. A short word of only letters
# (for example a checkout decision) is not a key. A Roku color is 0x plus
# eight hex digits and nothing else. Any other shape, including hex without
# that prefix or a longer token, is still a key. The matching line is not printed.
LITERAL_PATTERN = r'return "[A-Za-z0-9._~-]{8,}"'
LITERAL_TOKEN = re.compile(r'return "([A-Za-z0-9._~-]{8,})"')
ROKU_COLOR = re.compile(r"0x[0-9A-Fa-f]{8}")


def git(*args: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["git", *args],
        cwd=ROOT,
        check=False,
        capture_output=True,
        text=True,
    )


def fail(message: str, names: str = "") -> None:
    print(message, file=sys.stderr)
    cleaned = names.strip()
    if cleaned:
        print(cleaned, file=sys.stderr)
    raise SystemExit(1)


def require_clean(pattern: str, description: str, *paths: str) -> None:
    result = git("grep", "-E", "-I", "-l", pattern, "--", *paths)
    if result.returncode == 0:
        fail(description, result.stdout)
    if result.returncode != 1:
        detail = result.stderr.strip() or f"git grep exited {result.returncode}"
        fail(detail)


def token_is_key_like(token: str) -> bool:
    if ROKU_COLOR.fullmatch(token):
        return False
    if re.fullmatch(r"[A-Za-z]+", token) and len(token) < 16:
        return False
    return True


def offending_paths(grep_output: str) -> list[str]:
    files: list[str] = []
    for line in grep_output.splitlines():
        match = LITERAL_TOKEN.search(line)
        if match is None or not token_is_key_like(match.group(1)):
            continue
        path = line.split(":", 1)[0]
        if path not in files:
            files.append(path)
    return files


def require_no_key_literal() -> None:
    result = git("grep", "-E", "-I", "-n", LITERAL_PATTERN, "--", "channel")
    if result.returncode == 1:
        return
    if result.returncode != 0:
        detail = result.stderr.strip() or f"git grep exited {result.returncode}"
        fail(detail)
    files = offending_paths(result.stdout)
    if files:
        fail(
            "A tracked channel file returns a key-like literal. Keep that value out of git.",
            "\n".join(files),
        )


def main() -> None:
    tracked = git("ls-files", "--", "channel/components/secrets.brs", "channel/source/secrets.brs")
    if tracked.returncode != 0:
        fail(tracked.stderr.strip() or "git ls-files failed")
    if tracked.stdout.strip():
        fail("secrets.brs is tracked. It is generated at package time and must stay gitignored.", tracked.stdout)

    require_clean(
        URL_PATTERN,
        "A tracked file contains a guest path key. Remove it. The key is supplied at package time.",
        ".",
    )
    require_no_key_literal()
    print("tracked guest-key check ok")


if __name__ == "__main__":
    main()
