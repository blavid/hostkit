#!/usr/bin/env python3
"""Write channel/components/secrets.brs without printing the path key.

The live key is read from GUEST_PATH_KEY. A development stub URL is read from
GUEST_STUB_URL. Neither value is placed on this process's argv.
"""

from __future__ import annotations

import argparse
import os
import re
import sys
from pathlib import Path

KEY_PATTERN = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._~-]{0,199}$")


def fail(message: str) -> None:
    print(message, file=sys.stderr)
    raise SystemExit(2)


def validate_key(key: str) -> str:
    if ".." in key or KEY_PATTERN.fullmatch(key) is None:
        fail(
            "GUEST_PATH_KEY cannot be embedded. It must be one URL path segment "
            "(letters, digits, and . _ ~ -) with no slash or quote."
        )
    return key


def validate_stub(url: str) -> str:
    if len(url) < 8 or len(url) > 400:
        fail("The stub URL must be an http or https address without spaces, quotes, or backslashes.")
    if not (url.startswith("http://") or url.startswith("https://")):
        fail("The stub URL must be an http or https address without spaces, quotes, or backslashes.")
    if any(ord(ch) < 32 or ch in ' "\\' for ch in url):
        fail("The stub URL must be an http or https address without spaces, quotes, or backslashes.")
    return url


def source(key: str, stub: str) -> str:
    return (
        "' Generated at package time. Do not commit this file.\n"
        "function GuestPathKey() as string\n"
        f'    return "{key}"\n'
        "end function\n"
        "\n"
        "function GuestStubUrl() as string\n"
        f'    return "{stub}"\n'
        "end function\n"
    )


def write_file(dest: Path, key: str, stub: str) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_text(source(key, stub), encoding="utf-8")
    os.chmod(dest, 0o644)


def main() -> None:
    parser = argparse.ArgumentParser(description="Write the gitignored guest secrets file.")
    parser.add_argument("--dest", required=True, type=Path)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--no-guest", action="store_true")
    mode.add_argument("--key-from-env", action="store_true")
    mode.add_argument("--stub-from-env", action="store_true")
    mode.add_argument("--ensure-empty", action="store_true")
    args = parser.parse_args()

    if args.ensure_empty:
        if args.dest.is_file():
            return
        write_file(args.dest, "", "")
        print("Guest secrets file created empty for compile.")
        return

    if args.no_guest:
        write_file(args.dest, "", "")
        print("Guest fetch: off (--no-guest).")
        return

    if args.stub_from_env:
        stub = os.environ.get("GUEST_STUB_URL", "").strip()
        if not stub:
            fail("The stub URL is empty. Pass --stub with an http or https guest.json address.")
        write_file(args.dest, "", validate_stub(stub))
        print("Guest fetch: development stub.")
        return

    key = os.environ.get("GUEST_PATH_KEY", "").strip()
    if not key:
        fail(
            "GUEST_PATH_KEY is not set.\n"
            "Export that path key to package a live guest URL, or pass --no-guest, "
            "or pass --stub with the stub guest.json URL."
        )
    write_file(args.dest, validate_key(key), "")
    print("Guest fetch: live.")


if __name__ == "__main__":
    main()
