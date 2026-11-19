#!/usr/bin/env python3
"""hi-shell's installer window (GTK 4 + libadwaita).

    python3 installer/gui.py [--script path/to/install.sh]

Pick the parts, press Install: the sudo password is asked once (and checked), then install.sh runs in a
pseudo-terminal with --yes and exactly those parts. The window answers sudo's prompt (marked with
SUDO_PROMPT) with the password, shows the step and the log, and keeps the log in ~/.cache/hi-shell/install.log.
"""
import argparse
import codecs
import fcntl
import os
import signal
import subprocess
import sys
import termios
import threading
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import logic  # noqa: E402

import gi  # noqa: E402

gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
from gi.repository import Adw, GLib, Gtk, Pango  # noqa: E402

APP_ID = "io.github.imu_useful.HiShellInstaller"
LOG_PATH = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "hi-shell" / "install.log"
LOG_LIMIT = 4000          # lines kept in the window (the file has all of them)
PASSWORD_TRIES = 2        # sudo prompts the window answers by itself; more means something's off
ASK_USER = "\x00ask-password"  # passed to on_line when sudo asks again and the person has to answer


def check_password(password: str) -> bool:
    """Whether sudo takes this password (it also refreshes sudo's timestamp, which the install doesn't rely on)."""
    try:
        r = subprocess.run(["sudo", "-S", "-k", "-p", "", "-v"], input=password + "\n", text=True,
                           capture_output=True, timeout=30)
    except (OSError, subprocess.TimeoutExpired):
        return False
    return r.returncode == 0


def sudo_without_password() -> bool:
    try:
        return subprocess.run(["sudo", "-n", "true"], capture_output=True, timeout=10).returncode == 0
    except (OSError, subprocess.TimeoutExpired):
        return False


def list_parts(script: Path) -> list:
    r = subprocess.run(["bash", str(script), "--list"], capture_output=True, text=True, timeout=30)
    if r.returncode != 0:
        raise RuntimeError(r.stderr.strip() or f"install.sh --list exited with {r.returncode}")
    return logic.parse_list(r.stdout)


class Install:
    """install.sh in a pseudo-terminal: output goes to on_line / on_partial, the exit to on_exit."""

    def __init__(self, script: Path, args: list, password, on_line, on_partial, on_exit):
        self.password = password
        self.answers = 0
        self.on_line, self.on_partial, self.on_exit = on_line, on_partial, on_exit
        self.term = logic.Terminal()
        self.decoder = codecs.getincrementaldecoder("utf-8")(errors="replace")
        master, slave = os.openpty()
        attrs = termios.tcgetattr(slave)
        attrs[1] &= ~termios.ONLCR  # keep "\n" as it is, so "\r" only means pacman's progress bars
        termios.tcsetattr(slave, termios.TCSANOW, attrs)
        env = dict(os.environ, SUDO_PROMPT=logic.SUDO_PROMPT, TERM="xterm-256color", COLUMNS="100",
                   PACMAN_COLOR="never")

        def own_terminal():  # the pty becomes the controlling terminal: sudo and `read </dev/tty` use it
            os.setsid()
            fcntl.ioctl(0, termios.TIOCSCTTY, 0)

        self.proc = subprocess.Popen(["bash", str(script), *args], stdin=slave, stdout=slave, stderr=slave,
                                     env=env, preexec_fn=own_terminal, close_fds=True)
        os.close(slave)
        self.master = master
        os.set_blocking(master, False)
        self.watch = GLib.unix_fd_add_full(GLib.PRIORITY_DEFAULT, master, GLib.IOCondition.IN | GLib.IOCondition.HUP
                                           | GLib.IOCondition.ERR, self._readable)

    def _readable(self, _fd, condition):
        try:
            data = os.read(self.master, 65536)
        except BlockingIOError:
            return True
        except OSError:  # EIO: every writer closed the pty
            data = b""
        if data:
            for line in self.term.feed(self.decoder.decode(data)):
                self.on_line(line)
            self.on_partial(self.term.line)
            if self.term.asks_password():
                self._answer()
            return True
        if condition & (GLib.IOCondition.HUP | GLib.IOCondition.ERR) or not data:
            self._finish()
            return False
        return True

    def _answer(self):
        if self.password is None or self.answers >= PASSWORD_TRIES:
            self.on_line(self.term.line)
            self.term.line = ""
            self.on_partial("")
            self.on_line(ASK_USER)
            return
        self.answers += 1
        self.write(self.password + "\n")
        self.term.line = ""  # the prompt is answered: don't show it as an unanswered question
        self.on_partial("")

    def write(self, text: str):
        try:
            os.write(self.master, text.encode())
        except OSError:
            pass

    def stop(self):
        if self.proc.poll() is None:
            try:
                os.killpg(self.proc.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass

    def _finish(self):
        if self.term.line:
            self.on_line(self.term.line)
        code = self.proc.wait()
        os.close(self.master)
        self.password = None
        self.on_exit(code)


class Window(Adw.ApplicationWindow):
    def __init__(self, app, script: Path):
        super().__init__(application=app, title="hi-shell", default_width=640, default_height=720)
        self.lang = logic.language()
        self.script = script
        self.install = None
        self.cancelled = False
        self.current_step = None
        self.switches = {}
        self.listed = []
        self.log_file = None
        self.stack = Gtk.Stack(transition_type=Gtk.StackTransitionType.SLIDE_LEFT_RIGHT)
        self.set_content(self.stack)
        self.connect("close-request", self._on_close_request)
        try:
            self.listed = list_parts(script)
        except (OSError, RuntimeError, subprocess.TimeoutExpired) as e:
            self._show_result(False, logic.tr(self.lang, "done.fail"), str(e))
            return
        self.stack.add_named(self._choose_page(), "choose")
        self.stack.add_named(self._progress_page(), "progress")
        self.stack.add_named(self._result_page(), "result")
        self.stack.set_visible_child_name("choose")

    def t(self, key, **values):
        return logic.tr(self.lang, key, **values)

    # --- What to install ---
    def _choose_page(self):
        view = Adw.ToolbarView()
        view.add_top_bar(Adw.HeaderBar(title_widget=Adw.WindowTitle(title=self.t("title"))))
        page = Adw.PreferencesPage(description=self.t("intro"))
        groups = {}
        for row in logic.rows(self.lang, self.listed):
            group = groups.get(row["group"])
            if group is None:
                group = groups[row["group"]] = Adw.PreferencesGroup(title=self.t("group." + row["group"]))
                page.add(group)
            switch = Adw.SwitchRow(title=row["title"], subtitle=row["subtitle"], active=row["on"])
            self.switches[row["name"]] = switch
            group.add(switch)
        updates = Adw.PreferencesGroup(title=self.t("channel"))
        self.channel = Adw.ComboRow(title=self.t("channel"), subtitle=self.t("channel.sub"),
                                    model=Gtk.StringList.new([self.t("channel.release"), self.t("channel.git")]))
        updates.add(self.channel)
        page.add(updates)
        view.set_content(page)
        button = Gtk.Button(label=self.t("install"), halign=Gtk.Align.CENTER, margin_top=12, margin_bottom=12)
        button.add_css_class("suggested-action")
        button.add_css_class("pill")
        button.connect("clicked", lambda _b: self._start())
        view.add_bottom_bar(button)
        return view

    def selected(self):
        return [name for name, switch in self.switches.items() if switch.get_active()]

    def _start(self):
        selected = self.selected()
        if logic.needs_sudo(selected) and not sudo_without_password():
            self._ask_password(selected)
        else:
            self._run(selected, None)

    def _ask_password(self, selected):
        dialog = Adw.AlertDialog(heading=self.t("password.title"), body=self.t("password.body"))
        entry = Gtk.PasswordEntry(show_peek_icon=True, activates_default=True,
                                  placeholder_text=self.t("password.placeholder"))
        error = Gtk.Label(visible=False, wrap=True)
        error.add_css_class("error")
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        box.append(entry)
        box.append(error)
        dialog.set_extra_child(box)
        dialog.add_response("cancel", self.t("password.cancel"))
        dialog.add_response("ok", self.t("password.ok"))
        dialog.set_response_appearance("ok", Adw.ResponseAppearance.SUGGESTED)
        dialog.set_default_response("ok")
        dialog.set_close_response("cancel")
        dialog.set_response_enabled("ok", False)
        entry.connect("changed", lambda e: dialog.set_response_enabled("ok", bool(e.get_text())))
        # The dialog stays open on a wrong password: "ok" is handled by hand, not by the response.
        dialog.set_prefer_wide_layout(True)

        def on_response(_d, response):
            if response != "ok":
                return
            password = entry.get_text()

            def checked(ok):  # back on the main thread
                if ok:
                    entry.set_text("")
                    self._run(selected, password)
                else:
                    retry()
                return False

            # sudo waits a couple of seconds after a wrong password: off the main thread, so the window doesn't freeze
            threading.Thread(target=lambda: GLib.idle_add(checked, check_password(password)), daemon=True).start()

        def retry():
            entry.set_text("")
            error.set_label(self.t("password.wrong"))
            error.set_visible(True)
            dialog.present(self)
            entry.grab_focus()
            return False

        dialog.connect("response", on_response)
        dialog.present(self)
        entry.grab_focus()

    # --- Installing ---
    def _progress_page(self):
        view = Adw.ToolbarView()
        header = Adw.HeaderBar(title_widget=Adw.WindowTitle(title=self.t("progress.title")),
                               show_end_title_buttons=False)
        self.stop_button = Gtk.Button(label=self.t("stop"))
        self.stop_button.add_css_class("destructive-action")
        self.stop_button.connect("clicked", lambda _b: self._confirm_stop())
        header.pack_end(self.stop_button)
        view.add_top_bar(header)
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12, margin_top=18, margin_bottom=18,
                      margin_start=18, margin_end=18)
        self.step_label = Gtk.Label(label=self.t("progress.starting"), xalign=0)
        self.step_label.add_css_class("title-3")
        self.bar = Gtk.ProgressBar(show_text=False)
        self.partial_label = Gtk.Label(xalign=0, ellipsize=Pango.EllipsizeMode.END, selectable=True)
        self.partial_label.add_css_class("dim-label")
        self.partial_label.add_css_class("monospace")
        self.log_view = Gtk.TextView(editable=False, cursor_visible=False, monospace=True,
                                     wrap_mode=Gtk.WrapMode.WORD_CHAR, top_margin=6, bottom_margin=6,
                                     left_margin=8, right_margin=8)
        self.log_buffer = self.log_view.get_buffer()
        self.log_end = self.log_buffer.create_mark(None, self.log_buffer.get_end_iter(), False)
        scroller = Gtk.ScrolledWindow(child=self.log_view, vexpand=True, min_content_height=260)
        scroller.add_css_class("card")
        self.input = Gtk.Entry(placeholder_text=self.t("input.placeholder"))
        self.input.connect("activate", self._send_input)
        details = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        details.append(scroller)
        details.append(self.input)
        self.expander = Gtk.Expander(label=self.t("log"), child=details, vexpand=True)
        for w in (self.step_label, self.bar, self.partial_label, self.expander):
            box.append(w)
        view.set_content(box)
        return view

    def _run(self, selected, password):
        args = logic.install_args(selected, [n for n, _ in self.listed],
                                  "git" if self.channel.get_selected() == 1 else "release")
        self.expected = logic.expected_steps(selected)
        self.started = "start" in selected
        LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
        self.log_file = open(LOG_PATH, "w", encoding="utf-8")
        self._line("$ install.sh " + " ".join(args))
        self.stack.set_visible_child_name("progress")
        self.pulse = GLib.timeout_add(120, self._pulse)
        try:
            self.install = Install(self.script, args, password, self._line, self._partial, self._exited)
        except OSError as e:
            self._line(str(e))
            self._exited(127)

    def _pulse(self):
        if self.current_step is None:
            self.bar.pulse()
        return self.install is not None

    def _line(self, line: str):
        if self.log_file:
            self.log_file.write(line + "\n")
            self.log_file.flush()
        if line == ASK_USER:
            line = self.t("sudo.again")
            self.expander.set_expanded(True)
            self.input.set_visibility(False)
            self.input.grab_focus()
        heading = logic.step_heading(line)
        if heading:
            self.current_step = heading
            self.step_label.set_label(logic.step_text(self.lang, heading))
            self.bar.set_fraction(logic.progress(heading, self.expected))
        buf = self.log_buffer
        buf.insert(buf.get_end_iter(), line + "\n")
        extra = buf.get_line_count() - LOG_LIMIT
        if extra > 0:
            _, cut = buf.get_iter_at_line(extra)
            buf.delete(buf.get_start_iter(), cut)
        self.log_view.scroll_mark_onscreen(self.log_end)

    def _partial(self, text: str):
        self.partial_label.set_label(text.strip())

    def _send_input(self, entry):
        if self.install:
            self.install.write(entry.get_text() + "\n")
        entry.set_text("")
        entry.set_visibility(True)

    def _confirm_stop(self):
        dialog = Adw.AlertDialog(heading=self.t("cancel.title"), body=self.t("cancel.body"))
        dialog.add_response("keep", self.t("cancel.keep"))
        dialog.add_response("stop", self.t("cancel.stop"))
        dialog.set_response_appearance("stop", Adw.ResponseAppearance.DESTRUCTIVE)
        dialog.set_close_response("keep")

        def on_response(_d, response):
            if response == "stop" and self.install:
                self.cancelled = True
                self.install.stop()

        dialog.connect("response", on_response)
        dialog.present(self)

    def _exited(self, code: int):
        self.install = None
        if self.log_file:
            self.log_file.write(f"exit code: {code}\n")
            self.log_file.close()
            self.log_file = None
        if self.cancelled:
            self._show_result(False, self.t("done.cancelled"), self.t("done.cancelled.body", log=LOG_PATH))
        elif code == 0:
            self.bar.set_fraction(1.0)
            self._show_result(True, self.t("done.ok"), self.t("done.ok.body" if self.started else "done.ok.nostart"))
        else:
            self._show_result(False, self.t("done.fail"), self.t("done.fail.body", code=code, log=LOG_PATH))

    # --- Done ---
    def _result_page(self):
        view = Adw.ToolbarView()
        view.add_top_bar(Adw.HeaderBar(title_widget=Adw.WindowTitle(title=self.t("title"))))
        self.status = Adw.StatusPage()
        close = Gtk.Button(label=self.t("close"), halign=Gtk.Align.CENTER)
        close.add_css_class("pill")
        close.connect("clicked", lambda _b: self.close())
        self.status.set_child(close)
        view.set_content(self.status)
        return view

    def _show_result(self, ok: bool, title: str, body: str):
        if self.stack.get_child_by_name("result") is None:
            self.stack.add_named(self._result_page(), "result")
        self.status.set_icon_name("emblem-ok-symbolic" if ok else "dialog-error-symbolic")
        self.status.set_title(title)
        self.status.set_description(GLib.markup_escape_text(body))
        self.stack.set_visible_child_name("result")

    def _on_close_request(self, _w):
        if self.install:  # closing the window while it installs means "stop?"
            self._confirm_stop()
            return True
        return False


def main(argv=None):
    parser = argparse.ArgumentParser(description="hi-shell's installer window")
    parser.add_argument("--script", default=str(Path(__file__).resolve().parent.parent / "install.sh"),
                        help="the install.sh to run (default: the one next to this folder)")
    args, rest = parser.parse_known_args(argv)
    script = Path(args.script).resolve()
    if os.geteuid() == 0:
        print("Run the installer as your user, not root (it asks for sudo itself).", file=sys.stderr)
        return 1
    if not script.is_file():
        print(logic.tr(logic.language(), "error.script", path=script), file=sys.stderr)
        return 1
    app = Adw.Application(application_id=APP_ID)
    app.connect("activate", lambda a: Window(a, script).present())
    return app.run([sys.argv[0], *rest])


if __name__ == "__main__":
    sys.exit(main())
