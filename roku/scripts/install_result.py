#!/usr/bin/env python3
"""Classify a Roku /plugin_install response.

stdin: response body
argv[1]: HTTP status code (000 when curl never got a status)

Exit 0 only when the body reports Install Success and not Install Failure.
The password is never part of this response; nothing here prints the environment.
"""

from __future__ import annotations

import re
import sys


def main() -> int:
    code = sys.argv[1] if len(sys.argv) > 1 else ""
    body = sys.stdin.read()
    if code in ("", "000"):
        print("Could not reach the TV. Check the IP, the LAN, and that developer mode is enabled.")
        return 1
    if code == "401":
        print("Authentication failed (HTTP 401). Check ROKUPASS and that developer mode is enabled.")
        return 1
    success = re.search(r"Install Success", body, re.IGNORECASE) is not None
    failure = re.search(r"Install Failure", body, re.IGNORECASE) is not None
    if success and not failure and code.startswith("2"):
        print("Install Success")
        return 0
    reason = _reason(body)
    if code.startswith("2"):
        print(reason)
    else:
        print(f"Installer returned HTTP {code}. {reason}")
    return 1


def _reason(body: str) -> str:
    match = re.search(r"Install Failure:?\s*([^<]{0,240})", body, re.IGNORECASE)
    if match:
        return re.sub(r"\s+", " ", match.group(0)).strip()
    text_match = re.search(
        r'"type"\s*:\s*"error".{0,160}?"text"\s*:\s*"([^"\\]+)"',
        body,
        re.IGNORECASE | re.DOTALL,
    )
    if text_match:
        return text_match.group(1).strip()
    text = re.sub(r"<[^>]+>", " ", body)
    text = re.sub(r"\s+", " ", text).strip()
    if not text:
        return "The device did not report Install Success."
    return text[:300]


if __name__ == "__main__":
    sys.exit(main())
