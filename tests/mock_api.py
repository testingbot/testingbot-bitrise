#!/usr/bin/env python3
"""A stand-in for the TestingBot REST API, used by tests/run.sh.

Implements just enough of https://testingbot.com/support/api to exercise the
Steps offline: basic auth, POST /v1/storage (file and url forms), POST
/v1/storage/<appkey>, and GET /v1/storage/<appkey>.

Shaped to match what the live API actually returns, verified against
api.testingbot.com. Two things here are easy to get wrong from the docs alone:

  - POST returns ONLY {"app_url": "tb://..."} -- no id, type or version. Those
    come from a follow-up GET.
  - The upload is synchronous but the metadata extraction is not. A fresh app
    reports state PROCESSING with a null version for a few seconds, then DONE
    with the version filled in.

`type` is a platform ("ANDROID"/"IOS"/"OTHER"), not a file extension.

An appkey containing "slowmeta" stays PROCESSING for two GETs before going
DONE, and one containing "stuckmeta" never leaves PROCESSING, so the Step's
polling and its give-up path are both exercised without a real upload.
"""

import base64
import json
import re
import socketserver
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

VALID_KEY = "test-key"
VALID_SECRET = "test-secret"

# appkey -> number of GETs served so far, for the PROCESSING simulation.
GETS = {}

SLOW_META_GETS = 2


def app_state(appkey):
    """PROCESSING until the metadata job would have finished."""
    if "stuckmeta" in appkey:
        return "PROCESSING"
    if "slowmeta" in appkey and GETS.get(appkey, 0) <= SLOW_META_GETS:
        return "PROCESSING"
    return "DONE"


def app_payload(appkey):
    """What GET /v1/storage/<appkey> returns, field for field."""
    state = app_state(appkey)
    return {
        "id": 12345,
        "app_url": "tb://%s" % appkey,
        "url": "https://testingbot.example/download/%s" % appkey,
        "filename": "Application-debug.apk",
        "type": "ANDROID",
        # The metadata job populates these, so they are null until it is DONE.
        "version": None if state == "PROCESSING" else "1.4.2",
        "min_device_version": None if state == "PROCESSING" else "9.0",
        "thumb": None if state == "PROCESSING"
        else "https://testingbot.example/thumb/%s.png" % appkey,
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

        # Re-uploading restarts the metadata extraction for that key.
        GETS.pop(appkey, None)

        # The live API answers an upload with the identifier and nothing else.
        self._send(201, {"app_url": "tb://%s" % appkey})

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
        GETS[appkey] = GETS.get(appkey, 0) + 1
        self._send(200, app_payload(appkey))


class Server(HTTPServer):
    """HTTPServer that does not reverse-resolve its own address.

    HTTPServer.server_bind calls socket.getfqdn(host), a reverse DNS lookup,
    and it runs before we get to print the port. On a machine whose resolver is
    slow to answer for 127.0.0.1 -- GitHub's macOS runners are -- that blocks
    for tens of seconds, tests/run.sh gives up waiting, and the whole suite
    fails with an empty error log. Nothing here reads server_name, so skip it.
    """

    def server_bind(self):
        socketserver.TCPServer.server_bind(self)
        self.server_name, self.server_port = self.server_address[:2]


if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 0
    server = Server(("127.0.0.1", port), Handler)
    print(server.server_address[1], flush=True)
    server.serve_forever()
