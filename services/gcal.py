#!/usr/bin/env python3
"""Google Calendar backend for hi-shell (Python standard library only).

Commands:
    gcal.py auth                          Sign in with Google in the browser (one-time).
    gcal.py events [--from D] [--to D]    Print events as JSON (dates are YYYY-MM-DD, local time).
    gcal.py logout                        Delete the stored token.

Setup: create an OAuth client of type "Desktop app" in Google Cloud Console
(with the Google Calendar API enabled) and save its JSON as
~/.config/hi-shell/google-client.json. See README.md for the full steps.

`events` always prints one JSON object and exits 0, so the shell can show the state:
    {"status": "ok", "events": [...]}
    {"status": "needs_setup" | "needs_auth" | "error", "message": "..."}

Set HI_SHELL_GCAL_DEMO=1 to get sample events without a Google account.
"""

import argparse
import base64
import hashlib
import http.server
import json
import os
import secrets
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import webbrowser
from concurrent.futures import ThreadPoolExecutor
from datetime import date, datetime, timedelta
from pathlib import Path

CONFIG_HOME = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
STATE_HOME = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state"))
CLIENT_FILE = CONFIG_HOME / "hi-shell/google-client.json"
TOKEN_FILE = STATE_HOME / "hi-shell/google-token.json"

SCOPE = "https://www.googleapis.com/auth/calendar.readonly"
API = "https://www.googleapis.com/calendar/v3"
TIMEOUT = 15


class NeedsSetup(Exception):
    pass


class NeedsAuth(Exception):
    pass


# ---------------------------------------------------------------- OAuth

def load_client() -> dict:
    try:
        data = json.loads(CLIENT_FILE.read_text())
    except FileNotFoundError:
        raise NeedsSetup(f"OAuth client file not found: {CLIENT_FILE}")
    except ValueError:
        raise NeedsSetup(f"OAuth client file is not valid JSON: {CLIENT_FILE}")
    client = data.get("installed")
    if not client:
        raise NeedsSetup('OAuth client must be of type "Desktop app" (no "installed" section found)')
    return client


def post_form(url: str, fields: dict) -> dict:
    req = urllib.request.Request(url, data=urllib.parse.urlencode(fields).encode(), method="POST")
    req.add_header("Content-Type", "application/x-www-form-urlencoded")
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
            return json.load(resp)
    except urllib.error.HTTPError as e:
        try:
            body = json.load(e)
        except ValueError:
            body = {"error": f"HTTP {e.code}"}
        return body


def save_token(token: dict) -> None:
    TOKEN_FILE.parent.mkdir(parents=True, exist_ok=True)
    TOKEN_FILE.parent.chmod(0o700)
    fd = os.open(TOKEN_FILE, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as f:
        json.dump(token, f)


def auth() -> int:
    client = load_client()
    verifier = secrets.token_urlsafe(64)
    challenge = base64.urlsafe_b64encode(hashlib.sha256(verifier.encode()).digest()).rstrip(b"=").decode()
    state = secrets.token_urlsafe(16)
    result: dict = {}

    class Handler(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            query = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
            if query.get("state", [None])[0] != state:
                self.send_response(400)
                self.end_headers()
                return
            result.update({k: v[0] for k, v in query.items()})
            ok = "code" in result
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.end_headers()
            msg = "hi-shell is connected to Google Calendar. You can close this tab." if ok \
                else f"Sign-in failed: {result.get('error', 'unknown error')}"
            self.wfile.write(f"<html><body style='font-family:sans-serif;padding:3em'><h2>{msg}</h2></body></html>".encode())

        def log_message(self, *args):
            pass

    server = http.server.HTTPServer(("127.0.0.1", 0), Handler)
    redirect_uri = f"http://127.0.0.1:{server.server_port}"
    url = client.get("auth_uri", "https://accounts.google.com/o/oauth2/auth") + "?" + urllib.parse.urlencode({
        "client_id": client["client_id"],
        "redirect_uri": redirect_uri,
        "response_type": "code",
        "scope": SCOPE,
        "code_challenge": challenge,
        "code_challenge_method": "S256",
        "access_type": "offline",
        "prompt": "consent",
        "state": state,
    })
    print(f"Opening the browser for Google sign-in. If it does not open, visit:\n{url}", file=sys.stderr)
    webbrowser.open(url)

    server.timeout = 300
    deadline = time.time() + 300
    while not result and time.time() < deadline:
        server.handle_request()
    server.server_close()

    if "code" not in result:
        print(f"Sign-in failed: {result.get('error', 'timed out')}", file=sys.stderr)
        return 1

    token = post_form(client.get("token_uri", "https://oauth2.googleapis.com/token"), {
        "code": result["code"],
        "client_id": client["client_id"],
        "client_secret": client.get("client_secret", ""),
        "redirect_uri": redirect_uri,
        "grant_type": "authorization_code",
        "code_verifier": verifier,
    })
    if "refresh_token" not in token:
        print(f"Token exchange failed: {token.get('error_description') or token.get('error')}", file=sys.stderr)
        return 1

    token["expires_at"] = time.time() + token.get("expires_in", 3600)
    save_token(token)
    print("Connected to Google Calendar.", file=sys.stderr)
    return 0


def access_token() -> str:
    client = load_client()
    try:
        token = json.loads(TOKEN_FILE.read_text())
    except (OSError, ValueError):
        raise NeedsAuth("Not signed in to Google")

    if token.get("access_token") and token.get("expires_at", 0) > time.time() + 60:
        return token["access_token"]

    fresh = post_form(client.get("token_uri", "https://oauth2.googleapis.com/token"), {
        "client_id": client["client_id"],
        "client_secret": client.get("client_secret", ""),
        "refresh_token": token.get("refresh_token", ""),
        "grant_type": "refresh_token",
    })
    if "access_token" not in fresh:
        if fresh.get("error") == "invalid_grant":
            raise NeedsAuth("Google sign-in expired; please reconnect")
        raise RuntimeError(f"Token refresh failed: {fresh.get('error_description') or fresh.get('error')}")

    token.update(access_token=fresh["access_token"], expires_at=time.time() + fresh.get("expires_in", 3600))
    save_token(token)
    return token["access_token"]


# ---------------------------------------------------------------- API

def api_get(path: str, token: str, params: dict | None = None) -> dict:
    url = f"{API}{path}" + ("?" + urllib.parse.urlencode(params) if params else "")
    req = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}"})
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT) as resp:
            return json.load(resp)
    except urllib.error.HTTPError as e:
        if e.code == 401:
            raise NeedsAuth("Google rejected the stored sign-in; please reconnect")
        try:
            msg = json.load(e)["error"]["message"]
        except (ValueError, KeyError, TypeError):
            msg = f"HTTP {e.code}"
        raise RuntimeError(f"Google Calendar API: {msg}")


def parse_time(t: dict) -> tuple[datetime, bool]:
    """Return (local naive datetime, all_day) for an event start/end object."""
    if "date" in t:
        return datetime.fromisoformat(t["date"]), True
    return datetime.fromisoformat(t["dateTime"]).astimezone().replace(tzinfo=None), False


def event_days(start: datetime, end: datetime, all_day: bool) -> list[str]:
    # End is exclusive for all-day events; a timed event ending at 00:00 doesn't cover that day.
    last = (end - timedelta(seconds=1)).date() if end > start else start.date()
    days, d = [], start.date()
    while d <= last and len(days) < 62:
        days.append(d.isoformat())
        d += timedelta(days=1)
    return days


def convert(item: dict, calendar: dict) -> dict | None:
    if item.get("status") == "cancelled":
        return None
    for a in item.get("attendees", []):
        if a.get("self") and a.get("responseStatus") == "declined":
            return None
    start, all_day = parse_time(item["start"])
    end, _ = parse_time(item.get("end", item["start"]))
    return {
        "id": item.get("id", ""),
        "title": item.get("summary") or "(No title)",
        "start": start.isoformat(timespec="minutes"),
        "end": end.isoformat(timespec="minutes"),
        "allDay": all_day,
        "days": event_days(start, end, all_day),
        "calendar": calendar.get("summaryOverride") or calendar.get("summary", ""),
        "color": item.get("backgroundColor") or calendar.get("backgroundColor", ""),
        "location": item.get("location", ""),
        "link": item.get("htmlLink", ""),
        "meet": item.get("hangoutLink", ""),
    }


def fetch_events(start: date, end: date) -> list[dict]:
    token = access_token()
    calendars = [c for c in api_get("/users/me/calendarList", token).get("items", [])
                 if c.get("selected", False) and not c.get("hidden", False)]
    tz = datetime.now().astimezone().tzinfo
    params = {
        "timeMin": datetime.combine(start, datetime.min.time(), tz).isoformat(),
        "timeMax": datetime.combine(end + timedelta(days=1), datetime.min.time(), tz).isoformat(),
        "singleEvents": "true",
        "orderBy": "startTime",
        "maxResults": "250",
    }

    def one(cal: dict) -> list[dict]:
        items = api_get(f"/calendars/{urllib.parse.quote(cal['id'], safe='')}/events", token, params).get("items", [])
        return [e for e in (convert(i, cal) for i in items) if e]

    with ThreadPoolExecutor(max_workers=6) as pool:
        events = [e for batch in pool.map(one, calendars) for e in batch]
    events.sort(key=lambda e: (e["start"], not e["allDay"], e["title"]))
    return events


def demo_events(start: date, end: date) -> list[dict]:
    today = date.today()
    samples = [
        (0, "09:30", "10:00", "Standup", "#4285f4", "Google Meet"),
        (0, "13:00", "14:00", "Lunch with Alex", "#33b679", "Cafe"),
        (0, "17:00", "18:30", "hi-shell review", "#8e24aa", ""),
        (1, None, None, "Day off", "#f6bf26", ""),
        (2, "11:00", "12:00", "Dentist", "#e67c73", "Main St 12"),
        (5, "19:00", "21:00", "Concert", "#039be5", "Arena"),
    ]
    events = []
    for offset, s, e, title, color, location in samples:
        d = today + timedelta(days=offset)
        if s:
            st = datetime.fromisoformat(f"{d}T{s}")
            en = datetime.fromisoformat(f"{d}T{e}")
        else:
            st, en = datetime.combine(d, datetime.min.time()), datetime.combine(d + timedelta(days=1), datetime.min.time())
        events.append({"id": title, "title": title, "start": st.isoformat(timespec="minutes"),
                       "end": en.isoformat(timespec="minutes"), "allDay": s is None,
                       "days": event_days(st, en, s is None), "calendar": "Demo", "color": color,
                       "location": location, "link": "", "meet": ""})
    return [ev for ev in events if start.isoformat() <= ev["days"][0] <= end.isoformat()]


def events_cmd(args) -> int:
    start = date.fromisoformat(args.start) if args.start else date.today()
    end = date.fromisoformat(args.end) if args.end else start + timedelta(days=30)
    try:
        events = demo_events(start, end) if os.environ.get("HI_SHELL_GCAL_DEMO") else fetch_events(start, end)
        out = {"status": "ok", "events": events}
    except NeedsSetup as e:
        out = {"status": "needs_setup", "message": str(e)}
    except NeedsAuth as e:
        out = {"status": "needs_auth", "message": str(e)}
    except (urllib.error.URLError, TimeoutError) as e:
        out = {"status": "error", "message": f"Network error: {getattr(e, 'reason', e)}"}
    except Exception as e:  # noqa: BLE001 - always report something the UI can show
        out = {"status": "error", "message": str(e)}
    print(json.dumps(out))
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("auth", help="sign in with Google")
    ev = sub.add_parser("events", help="print events as JSON")
    ev.add_argument("--from", dest="start", help="first day, YYYY-MM-DD (default: today)")
    ev.add_argument("--to", dest="end", help="last day, YYYY-MM-DD (default: +30 days)")
    sub.add_parser("logout", help="delete the stored token")
    args = ap.parse_args()

    if args.cmd == "auth":
        try:
            return auth()
        except NeedsSetup as e:
            print(e, file=sys.stderr)
            return 2
    if args.cmd == "events":
        return events_cmd(args)
    if args.cmd == "logout":
        TOKEN_FILE.unlink(missing_ok=True)
        print("Signed out.", file=sys.stderr)
        return 0
    return 1


if __name__ == "__main__":
    sys.exit(main())
