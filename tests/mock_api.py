#!/usr/bin/env python3
"""A stand-in for the TestingBot REST API, used by tests/run.sh.

Implements just enough of https://testingbot.com/support/api to exercise the
Steps offline: basic auth, POST /v1/storage (file and url forms), POST
/v1/storage/<appkey>, and GET /v1/storage/<appkey> with a PROCESSING -> READY
transition so the polling loop is genuinely exercised.
"""

import base64
import json
import re
import sys
import threading
from http.server import BaseHTTPRequestHandler, HTTPServer

VALID_KEY = "test-key"
VALID_SECRET = "test-secret"

# Number of GET /v1/storage/<key> polls that report PROCESSING before READY.
POLLS_BEFORE_READY = 2

state_lock = threading.Lock()
poll_counts = {}


def app_payload(appkey, state):
    return {
        "id": 12345,
        "app_url": "tb://%s" % appkey,
        "url": "https://testingbot.example/download/%s" % appkey,
        "filename": "Application-debug.apk",
        "type": "apk",
        "version": "1.4.2" if state == "READY" else "",
        "min_device_version": "9.0",
        "thumb": "https://testingbot.example/thumb/%s.png" % appkey,
        "created_at": "2026-07-31T10:30:42.000Z",
        "state": state,
        "sim_only": False,
    }


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt, *args):  # keep test output readable
        pass

    def _send(self, code, payload):
        body = json.dumps(payload).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _authed(self):
        header = self.headers.get("Authorization", "")
        if not header.startswith("Basic "):
            return False
        try:
            decoded = base64.b64decode(header[6:]).decode()
        except Exception:
            return False
        return decoded == "%s:%s" % (VALID_KEY, VALID_SECRET)

    def _drain_body(self):
        length = int(self.headers.get("Content-Length") or 0)
        return self.rfile.read(length) if length else b""

    def do_POST(self):
        body = self._drain_body()
        if not self._authed():
            self._send(401, {"error": "Authentication required"})
            return

        # Simulate the documented read-only-account failure.
        if b"readonly" in body:
            self._send(403, {"error": "Account is read only"})
            return

        m = re.match(r"^/v1/storage/([^/?]+)$", self.path)
        appkey = m.group(1) if m else "generatedappkey123"

        if not m and b"url=" not in body and b"filename=" not in body and not body:
            self._send(400, {"error": "No file or url given"})
            return

        with state_lock:
            poll_counts[appkey] = 0
        self._send(201, app_payload(appkey, "PROCESSING"))

    def do_GET(self):
        self._drain_body()
        if not self._authed():
            self._send(401, {"error": "Authentication required"})
            return

        m = re.match(r"^/v1/storage/([^/?]+)$", self.path)
        if not m:
            self._send(404, {"error": "Not found"})
            return

        appkey = m.group(1)
        with state_lock:
            count = poll_counts.get(appkey, POLLS_BEFORE_READY) + 1
            poll_counts[appkey] = count
        state = "READY" if count > POLLS_BEFORE_READY else "PROCESSING"
        self._send(200, app_payload(appkey, state))


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 0
    server = HTTPServer(("127.0.0.1", port), Handler)
    print(server.server_address[1], flush=True)
    server.serve_forever()
