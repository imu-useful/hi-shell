#!/usr/bin/env python3
"""Spotify Web API backend for hi-shell (Python standard library only).

    spotify.py auth                Sign in with Spotify in the browser (one-time).
    spotify.py queue               Print the playback queue as JSON.
    spotify.py search QUERY        Print track search results as JSON.
    spotify.py add URI             Add a track (spotify:track:...) to the queue.
    spotify.py logout              Delete the stored token.

Setup: create an app at https://developer.spotify.com/dashboard with the redirect URI
http://127.0.0.1:8888/callback and the Web API, and put its Client ID in
Settings > Services > Spotify (config.json: spotify.clientId). Login uses the
authorization code flow with PKCE, so no client secret is needed or stored.

Every command prints one JSON object with "status": ok | needs_setup | needs_auth | error
(and "message" for the last two); `auth` prints progress on stderr instead and exits 0
on success. The token is kept in ~/.local/state/hi-shell/spotify-token.json (mode 600).
Queue management needs a Spotify Premium account (the API says so with HTTP 403).
"""

import argparse
import base64
import hashlib
import json
import os
import secrets
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
import webbrowser
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

CONFIG_HOME = Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config")
STATE_HOME = Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local/state")
CONFIG_FILE = CONFIG_HOME / "hi-shell/config.json"
TOKEN_FILE = STATE_HOME / "hi-shell/spotify-token.json"

PORT = 8888
REDIRECT = f"http://127.0.0.1:{PORT}/callback"
SCOPE = "user-read-playback-state user-modify-playback-state"
AUTH_URL = "https://accounts.spotify.com/authorize"
TOKEN_URL = "https://accounts.spotify.com/api/token"
API = "https://api.spotify.com/v1"
LOGIN_TIMEOUT = 180


class NeedsAuth(Exception):
    pass


class ApiError(Exception):
    def __init__(self, message, status=0):
        super().__init__(message)
        self.status = status


def client_id():
    try:
        return json.loads(CONFIG_FILE.read_text()).get("spotify", {}).get("clientId", "").strip()
    except (OSError, ValueError):
        return ""


def out(obj):
    print(json.dumps(obj, ensure_ascii=False))


def post_form(url, data):
    body = urllib.parse.urlencode(data).encode()
    req = urllib.request.Request(url, body, {"Content-Type": "application/x-www-form-urlencoded"})
    try:
        with urllib.request.urlopen(req, timeout=15) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        try:
            detail = json.load(e)
        except ValueError:
            detail = {}
        raise ApiError(detail.get("error_description") or detail.get("error") or f"HTTP {e.code}", e.code)
    except urllib.error.URLError as e:
        raise ApiError(f"Can't reach Spotify: {e.reason}")


# --- Token ---
def save_token(token, old_refresh=None):
    TOKEN_FILE.parent.mkdir(parents=True, exist_ok=True)
    data = {
        "access_token": token["access_token"],
        # A refresh reply may leave out the refresh token: keep the one we have.
        "refresh_token": token.get("refresh_token") or old_refresh,
        "expires_at": int(time.time()) + int(token.get("expires_in", 3600)) - 60,
    }
    tmp = TOKEN_FILE.with_suffix(".tmp")
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as f:
        json.dump(data, f)
    os.replace(tmp, TOKEN_FILE)


def access_token(cid):
    try:
        token = json.loads(TOKEN_FILE.read_text())
    except (OSError, ValueError):
        raise NeedsAuth("Not signed in to Spotify")
    if time.time() < token.get("expires_at", 0):
        return token["access_token"]
    if not token.get("refresh_token"):
        raise NeedsAuth("Spotify sign-in expired; please reconnect")
    try:
        fresh = post_form(TOKEN_URL, {
            "grant_type": "refresh_token",
            "refresh_token": token["refresh_token"],
            "client_id": cid,
        })
    except ApiError as e:
        if e.status in (400, 401):
            raise NeedsAuth("Spotify sign-in expired; please reconnect")
        raise
    save_token(fresh, token["refresh_token"])
    return fresh["access_token"]


def api(method, path, cid, params=None):
    url = API + path + ("?" + urllib.parse.urlencode(params) if params else "")
    for attempt in (0, 1):
        req = urllib.request.Request(url, method=method, headers={"Authorization": "Bearer " + access_token(cid)})
        if method == "POST":
            req.data = b""
        try:
            with urllib.request.urlopen(req, timeout=15) as r:
                body = r.read()
                return json.loads(body) if body else None
        except urllib.error.HTTPError as e:
            if e.code == 401 and attempt == 0:
                # Token rejected: drop the expiry so the next try refreshes it.
                t = json.loads(TOKEN_FILE.read_text())
                t["expires_at"] = 0
                TOKEN_FILE.write_text(json.dumps(t))
                continue
            try:
                err = json.load(e).get("error", {})
            except ValueError:
                err = {}
            message = err.get("message") if isinstance(err, dict) else str(err)
            if e.code == 403 and "premium" in (message or "").lower():
                message = "Spotify Premium is needed to manage the queue"
            elif e.code == 404:
                message = "No active Spotify player: start playing something first"
            raise ApiError(message or f"HTTP {e.code}", e.code)
        except urllib.error.URLError as e:
            raise ApiError(f"Can't reach Spotify: {e.reason}")


def track(t):
    if not t:
        return None
    images = (t.get("album") or {}).get("images") or []
    return {
        "name": t.get("name", ""),
        "artists": ", ".join(a.get("name", "") for a in t.get("artists", [])),
        "uri": t.get("uri", ""),
        "art": images[-1]["url"] if images else "",
    }


# --- Login (authorization code with PKCE) ---
def auth(cid):
    verifier = secrets.token_urlsafe(64)
    challenge = base64.urlsafe_b64encode(hashlib.sha256(verifier.encode()).digest()).rstrip(b"=").decode()
    state = secrets.token_urlsafe(16)
    result = {}

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            url = urllib.parse.urlparse(self.path)
            if url.path != "/callback":
                self.send_error(404)
                return
            q = urllib.parse.parse_qs(url.query)
            ok = q.get("state", [""])[0] == state and "code" in q
            result["code"] = q.get("code", [""])[0] if ok else None
            result["error"] = None if ok else (q.get("error", ["Sign-in was cancelled or failed"])[0])
            page = ("hi-shell is connected to Spotify. You can close this tab." if ok
                    else f"Spotify sign-in failed: {result['error']}. You can close this tab and try again.")
            body = f"<!doctype html><meta charset=utf-8><title>hi-shell</title><body style='font-family:sans-serif;padding:3em'><h2>{page}</h2>".encode()
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            threading.Thread(target=self.server.shutdown, daemon=True).start()

        def log_message(self, *args):
            pass

    try:
        server = HTTPServer(("127.0.0.1", PORT), Handler)
    except OSError as e:
        raise ApiError(f"Can't listen on port {PORT} for the Spotify sign-in: {e.strerror}")
    server.timeout = LOGIN_TIMEOUT

    url = AUTH_URL + "?" + urllib.parse.urlencode({
        "client_id": cid,
        "response_type": "code",
        "redirect_uri": REDIRECT,
        "scope": SCOPE,
        "state": state,
        "code_challenge_method": "S256",
        "code_challenge": challenge,
    })
    # No browser or no display: say where to go instead of failing.
    opened = False
    try:
        opened = webbrowser.open(url)
    except Exception:
        pass
    print("Opened the browser for Spotify sign-in." if opened
          else f"Open this address in a browser to sign in to Spotify:\n{url}", file=sys.stderr)

    deadline = threading.Timer(LOGIN_TIMEOUT, server.shutdown)
    deadline.daemon = True
    deadline.start()
    server.serve_forever()
    deadline.cancel()
    server.server_close()

    if "code" not in result:
        raise ApiError("Spotify sign-in timed out; try Connect again")
    if not result["code"]:
        raise ApiError(result["error"] or "Spotify sign-in failed")
    token = post_form(TOKEN_URL, {
        "grant_type": "authorization_code",
        "code": result["code"],
        "redirect_uri": REDIRECT,
        "client_id": cid,
        "code_verifier": verifier,
    })
    save_token(token)
    print("Connected to Spotify.", file=sys.stderr)


def main():
    p = argparse.ArgumentParser()
    sub = p.add_subparsers(dest="cmd", required=True)
    sub.add_parser("auth")
    sub.add_parser("queue")
    sub.add_parser("logout")
    s = sub.add_parser("search")
    s.add_argument("query")
    a = sub.add_parser("add")
    a.add_argument("uri")
    args = p.parse_args()

    if args.cmd == "logout":
        try:
            TOKEN_FILE.unlink()
        except OSError:
            pass
        out({"status": "ok"})
        return 0

    cid = client_id()
    if not cid:
        out({"status": "needs_setup", "message": "Put the Spotify Client ID in Settings › Services"})
        return 0

    try:
        if args.cmd == "auth":
            auth(cid)
            return 0
        if args.cmd == "queue":
            data = api("GET", "/me/player/queue", cid) or {}
            out({"status": "ok", "playing": track(data.get("currently_playing")),
                 "queue": [track(t) for t in data.get("queue", [])[:20]]})
        elif args.cmd == "search":
            data = api("GET", "/search", cid, {"q": args.query, "type": "track", "limit": 6}) or {}
            out({"status": "ok", "tracks": [track(t) for t in data.get("tracks", {}).get("items", [])]})
        elif args.cmd == "add":
            if not args.uri.startswith("spotify:track:"):
                out({"status": "error", "message": "Not a Spotify track"})
                return 0
            api("POST", "/me/player/queue", cid, {"uri": args.uri})
            out({"status": "ok"})
    except NeedsAuth as e:
        if args.cmd == "auth":
            print(str(e), file=sys.stderr)
            return 1
        out({"status": "needs_auth", "message": str(e)})
    except ApiError as e:
        if args.cmd == "auth":
            print(str(e), file=sys.stderr)
            return 1
        out({"status": "error", "message": str(e)})
    return 0


if __name__ == "__main__":
    sys.exit(main())
