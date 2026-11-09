#!/usr/bin/env python3
"""Serve a sample guest.json for a TV on the LAN.

Package the channel with the stub flag so the device requests this process
instead of the live path. The request target is not logged.

    python3 scripts/stub-guest.py
    ./scripts/deploy.sh --stub "http://<lan-ip>:8765/guest.json"
"""

from __future__ import annotations

import argparse
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


SAMPLE = {
    "firstName": "Alex",
    "lastName": "Rivera",
    "checkout": "2037-01-01T18:00:00Z",
}


class GuestHandler(BaseHTTPRequestHandler):
    payload = b"{}"

    def do_GET(self) -> None:  # noqa: N802
        body = self.payload
        self.send_response(200)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt: str, *args: object) -> None:
        sys_stderr = __import__("sys").stderr
        sys_stderr.write("guest stub request\n")


def main() -> None:
    parser = argparse.ArgumentParser(description="Serve a sample guest.json.")
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--first", default=SAMPLE["firstName"])
    parser.add_argument("--last", default=SAMPLE["lastName"])
    parser.add_argument("--checkout", default=SAMPLE["checkout"])
    parser.add_argument("--empty", action="store_true", help="Respond with {}.")
    args = parser.parse_args()

    if args.empty:
        document: dict[str, str] = {}
    else:
        document = {
            "firstName": args.first,
            "lastName": args.last,
            "checkout": args.checkout,
        }
    GuestHandler.payload = json.dumps(document).encode("utf-8")
    server = ThreadingHTTPServer((args.host, args.port), GuestHandler)
    print(f"guest stub listening on port {args.port}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print()
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
