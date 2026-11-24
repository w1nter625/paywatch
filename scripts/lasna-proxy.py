#!/usr/bin/env python3
"""Tiny JSON-RPC forwarder that adds a browser User-Agent.

Cloudflare in front of https://lasna-rpc.rnk.dev/ often 403s Python
urllib / foundry. This proxy shells out to curl, which is accepted.

    python3 scripts/lasna-proxy.py
    export LASNA_RPC=http://127.0.0.1:8549
"""
from __future__ import annotations

import os
import subprocess
import sys
import tempfile
import traceback
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

UPSTREAM = os.environ.get("LASNA_UPSTREAM", "https://lasna-rpc.rnk.dev/")
HOST = os.environ.get("LASNA_PROXY_HOST", "127.0.0.1")
PORT = int(os.environ.get("LASNA_PROXY_PORT", "8549"))
UA = os.environ.get(
    "LASNA_PROXY_UA",
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
)
LOG = os.environ.get("LASNA_PROXY_LOG", "/tmp/lasna-proxy.log")


def log(msg: str) -> None:
    line = msg.rstrip() + "\n"
    sys.stderr.write(line)
    sys.stderr.flush()
    try:
        with open(LOG, "a") as f:
            f.write(line)
    except Exception:
        pass


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.0"

    def log_message(self, fmt: str, *args) -> None:
        log("lasna-proxy: " + (fmt % args))

    def _send(self, code: int, body: bytes, content_type: str = "application/json") -> None:
        try:
            self.send_response(code)
            self.send_header("Content-Type", content_type)
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Connection", "close")
            self.end_headers()
            self.wfile.write(body)
            self.wfile.flush()
        except Exception:
            log("send failed:\n" + traceback.format_exc())

    def do_GET(self) -> None:
        self._send(200, ('{"ok":true,"upstream":"%s"}\n' % UPSTREAM).encode())

    def do_POST(self) -> None:
        try:
            length = int(self.headers.get("Content-Length") or "0")
            req_body = self.rfile.read(length) if length else b"{}"
            with tempfile.NamedTemporaryFile(prefix="lasna-rpc-", suffix=".json", delete=False) as tmp:
                tmp.write(req_body)
                tmp_path = tmp.name
            try:
                proc = subprocess.run(
                    [
                        "curl", "-sS", "--max-time", "45",
                        "-A", UA,
                        "-H", "Content-Type: application/json",
                        "-H", "Accept: application/json",
                        "--data-binary", f"@{tmp_path}",
                        "-w", "\n__HTTPSTATUS__:%{http_code}",
                        UPSTREAM,
                    ],
                    capture_output=True,
                    check=False,
                )
            finally:
                try:
                    os.unlink(tmp_path)
                except OSError:
                    pass
            if proc.returncode != 0:
                err = proc.stderr or proc.stdout or b"curl failed"
                log(f"curl rc={proc.returncode}: {err[:500]!r}")
                self._send(502, err, "text/plain")
                return
            raw = proc.stdout or b""
            marker = b"\n__HTTPSTATUS__:"
            idx = raw.rfind(marker)
            if idx == -1:
                payload, status = raw, 200
            else:
                payload = raw[:idx]
                try:
                    status = int(raw[idx + len(marker) :].decode().strip())
                except ValueError:
                    status = 200
            self._send(status, payload)
        except Exception:
            tb = traceback.format_exc()
            log("POST failed:\n" + tb)
            self._send(502, tb.encode(), "text/plain")


if __name__ == "__main__":
    ThreadingHTTPServer.allow_reuse_address = True
    httpd = ThreadingHTTPServer((HOST, PORT), Handler)
    log(f"listening on {HOST}:{PORT} -> {UPSTREAM}")
    try:
        httpd.serve_forever()
    finally:
        httpd.server_close()
