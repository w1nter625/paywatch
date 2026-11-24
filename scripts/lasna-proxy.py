#!/usr/bin/env python3
"""Tiny JSON-RPC forwarder that adds a browser User-Agent.

Some environments get HTTP 403 from https://lasna-rpc.rnk.dev/ when the
client (e.g. foundry's cast/forge) sends no User-Agent. Bind this on
localhost and point LASNA_RPC at it:

    python3 scripts/lasna-proxy.py
    export LASNA_RPC=http://127.0.0.1:8549
"""
from __future__ import annotations

import http.server
import os
import sys
import urllib.error
import urllib.request

UPSTREAM = os.environ.get("LASNA_UPSTREAM", "https://lasna-rpc.rnk.dev/")
HOST = os.environ.get("LASNA_PROXY_HOST", "127.0.0.1")
PORT = int(os.environ.get("LASNA_PROXY_PORT", "8549"))
UA = os.environ.get(
    "LASNA_PROXY_UA",
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
)


class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, fmt: str, *args) -> None:
        sys.stderr.write("lasna-proxy: " + (fmt % args) + "\n")

    def do_POST(self) -> None:
        length = int(self.headers.get("Content-Length", "0"))
        body = self.rfile.read(length) if length else b""
        req = urllib.request.Request(
            UPSTREAM,
            data=body,
            method="POST",
            headers={
                "Content-Type": self.headers.get("Content-Type", "application/json"),
                "User-Agent": UA,
                "Accept": "application/json",
            },
        )
        try:
            with urllib.request.urlopen(req, timeout=60) as res:
                payload = res.read()
                self.send_response(res.status)
                self.send_header("Content-Type", res.headers.get("Content-Type", "application/json"))
                self.send_header("Content-Length", str(len(payload)))
                self.end_headers()
                self.wfile.write(payload)
        except urllib.error.HTTPError as e:
            payload = e.read()
            self.send_response(e.code)
            self.send_header("Content-Type", e.headers.get("Content-Type", "text/plain"))
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
        except Exception as e:
            msg = str(e).encode()
            self.send_response(502)
            self.send_header("Content-Type", "text/plain")
            self.send_header("Content-Length", str(len(msg)))
            self.end_headers()
            self.wfile.write(msg)

    def do_GET(self) -> None:
        self.send_response(200)
        body = b'{"ok":true,"upstream":"%s"}\n' % UPSTREAM.encode()
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


if __name__ == "__main__":
    http.server.ThreadingHTTPServer((HOST, PORT), Handler).serve_forever()
