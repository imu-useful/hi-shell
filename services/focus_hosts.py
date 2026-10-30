#!/usr/bin/env python3
"""Focus Mode site blocking (run as root through pkexec by services/FocusBlocker.qml).

    focus_hosts.py start --user NAME --fifo PATH --page PATH --state PATH DOMAIN...
    focus_hosts.py restore

start: backs up /etc/hosts to /etc/hosts.hi-shell.bak, adds a marked block sending the
domains (and their www. / m. names) to 127.0.0.1 and ::1, and serves the "Focus Mode"
page on port 80 of both. The server process drops to the user right after opening the
port; the root process only waits, then daemonizes and exits 0 so the caller knows it
worked. It reads one-word commands from the FIFO (owned by the user):
    unblock  take the block out (a Pomodoro break), the server keeps running
    block    put it back
    stop     take it out and quit
and also takes the block out when the server dies or on SIGTERM / SIGHUP (shutdown).
restore: takes a leftover block out (after a crash or a power cut).

Only lines between the markers are ever touched; the rest of /etc/hosts stays as it is.
"""

import os
import pwd
import re
import select
import shutil
import signal
import socket
import sys
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HOSTS = "/etc/hosts"
BACKUP = "/etc/hosts.hi-shell.bak"
BEGIN = "# >>> hi-shell focus mode (temporary, removed when the session ends) >>>"
END = "# <<< hi-shell focus mode <<<"
DOMAIN = re.compile(r"^(?=.{1,253}$)([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$")


def strip_block(text):
    out, inside = [], False
    for line in text.splitlines(keepends=True):
        if line.strip() == BEGIN:
            inside = True
        elif line.strip() == END:
            inside = False
        elif not inside:
            out.append(line)
    return "".join(out)


def write_hosts(text):
    # Atomic, keeping the usual owner and mode.
    tmp = HOSTS + ".hi-shell.tmp"
    with open(tmp, "w") as f:
        f.write(text)
    os.chmod(tmp, 0o644)
    os.rename(tmp, HOSTS)


def set_block(domains, on):
    with open(HOSTS) as f:
        text = strip_block(f.read())
    if on:
        if not text.endswith("\n"):
            text += "\n"
        names = []
        for d in domains:
            for n in (d, "www." + d, "m." + d):
                if n not in names:
                    names.append(n)
        lines = [BEGIN] + [f"127.0.0.1 {n}\n::1 {n}" for n in names] + [END]
        text += "\n".join(lines) + "\n"
    write_hosts(text)


def serve(user, page_path, state_path):
    """Opens port 80 (v4 and v6 loopback) as root, then becomes the user and serves."""

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            if self.path.startswith("/__focus/state"):
                body, kind = read(state_path, b"{}"), "application/json"
            else:
                body, kind = read(page_path, b"Focus Mode"), "text/html; charset=utf-8"
            self.send_response(200)
            self.send_header("Content-Type", kind)
            self.send_header("Cache-Control", "no-store")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        do_HEAD = do_GET

        def log_message(self, *args):
            pass

    class Server6(ThreadingHTTPServer):
        address_family = socket.AF_INET6

    servers = []
    for cls, addr in ((ThreadingHTTPServer, "127.0.0.1"), (Server6, "::1")):
        try:
            servers.append(cls((addr, 80), Handler))
        except OSError as e:
            print(f"focus_hosts: can't serve on {addr}:80: {e}", file=sys.stderr)

    pw = pwd.getpwnam(user)
    os.setgroups([])
    os.setgid(pw.pw_gid)
    os.setuid(pw.pw_uid)

    if not servers:
        signal.pause()
    for s in servers[1:]:
        threading.Thread(target=s.serve_forever, daemon=True).start()
    servers[0].serve_forever()


def read(path, fallback):
    try:
        with open(path, "rb") as f:
            return f.read()
    except OSError:
        return fallback


def start(args):
    user, fifo, page, state = args.user, args.fifo, args.page, args.state
    domains = sorted({d.strip().lower() for d in args.domains if DOMAIN.match(d.strip().lower())})
    if not domains:
        print("focus_hosts: no valid domains", file=sys.stderr)
        return 2
    pw = pwd.getpwnam(user)

    if not os.path.exists(BACKUP) or BEGIN not in open(HOSTS).read():
        shutil.copy2(HOSTS, BACKUP)
    set_block(domains, True)

    if os.path.exists(fifo):
        os.unlink(fifo)
    os.mkfifo(fifo, 0o600)
    os.chown(fifo, pw.pw_uid, pw.pw_gid)

    # Daemonize: the caller (pkexec) returns, the rest runs on.
    if os.fork() > 0:
        return 0
    os.setsid()
    if os.fork() > 0:
        os._exit(0)
    devnull = os.open(os.devnull, os.O_RDWR)
    for fd in (0, 1, 2):
        os.dup2(devnull, fd)

    server = os.fork()
    if server == 0:
        try:
            serve(user, page, state)
        finally:
            os._exit(0)

    done = False

    def finish(*_):
        nonlocal done
        done = True

    signal.signal(signal.SIGTERM, finish)
    signal.signal(signal.SIGHUP, finish)
    signal.signal(signal.SIGINT, finish)

    # O_RDWR: never sees EOF when a writer goes away.
    fd = os.open(fifo, os.O_RDWR | os.O_NONBLOCK)
    buf = b""
    try:
        while not done:
            if os.waitpid(server, os.WNOHANG) != (0, 0):
                server = 0
                break
            try:
                ready, _, _ = select.select([fd], [], [], 1.0)
            except InterruptedError:
                continue
            if not ready:
                continue
            buf += os.read(fd, 1024)
            while b"\n" in buf:
                line, buf = buf.split(b"\n", 1)
                cmd = line.decode(errors="ignore").strip()
                if cmd == "unblock":
                    set_block(domains, False)
                elif cmd == "block":
                    set_block(domains, True)
                elif cmd == "stop":
                    done = True
    finally:
        set_block(domains, False)
        if server:
            try:
                os.kill(server, signal.SIGTERM)
                os.waitpid(server, 0)
            except OSError:
                pass
        os.close(fd)
        try:
            os.unlink(fifo)
        except OSError:
            pass
    return 0


def main():
    import argparse

    if os.geteuid() != 0:
        print("focus_hosts: needs root (run through pkexec)", file=sys.stderr)
        return 1
    p = argparse.ArgumentParser()
    sub = p.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("start")
    s.add_argument("--user", required=True)
    s.add_argument("--fifo", required=True)
    s.add_argument("--page", required=True)
    s.add_argument("--state", required=True)
    s.add_argument("domains", nargs="+")
    sub.add_parser("restore")
    args = p.parse_args()
    if args.cmd == "restore":
        set_block([], False)
        return 0
    return start(args)


if __name__ == "__main__":
    sys.exit(main())
