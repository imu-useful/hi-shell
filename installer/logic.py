"""The installer window's logic, without GTK: the parts, the install.sh arguments, reading its output.

The window (installer/gui.py) runs install.sh in a pseudo-terminal with `--yes` and the parts picked, so the
install itself stays in one place; this module turns the picks into arguments and the output into progress.
"""
import os
import re

# The part names come from `install.sh --list`; this adds the group, the default and the Russian text.
# A part install.sh has that isn't here still shows up (in "Other", with install.sh's English text).
GROUPS = ("system", "terminal", "apps", "other")
PARTS = {
    "deps": {"group": "system", "on": True, "sudo": True,
             "ru": ("Пакеты", "Всё, что нужно hi-shell: из репозиториев и AUR (pacman, paru / yay)"),
             "en": ("Packages", "Everything hi-shell needs, from the repositories and the AUR (pacman, paru / yay)")},
    "hypr": {"group": "system", "on": True,
             "ru": ("Hyprland", "Скопировать клавиши и правила hi-shell в ~/.config/hypr/hi-shell и подключить их"),
             "en": ("Hyprland", "Copy hi-shell's keys and rules to ~/.config/hypr/hi-shell and load them")},
    "start": {"group": "system", "on": True,
              "ru": ("Запустить hi-shell", "Сразу после установки"),
              "en": ("Start hi-shell", "Right after the install")},
    "fish": {"group": "terminal", "on": True,
             "ru": ("fish", "Приглашение и сокращения"), "en": ("fish", "Prompt and aliases")},
    "kitty": {"group": "terminal", "on": True,
              "ru": ("kitty", "Цвета меняются вместе с обоями"), "en": ("kitty", "Colors follow the wallpaper")},
    "fastfetch": {"group": "terminal", "on": True,
                  "ru": ("fastfetch", "Сведения о системе в терминале"), "en": ("fastfetch", "System info in the terminal")},
    "btop": {"group": "terminal", "on": True,
             "ru": ("btop", "Цвета меняются вместе с обоями"), "en": ("btop", "Colors follow the wallpaper")},
    "dolphin": {"group": "terminal", "on": True,
                "ru": ("Dolphin", "Шрифт списка файлов: Google Sans Flex"), "en": ("Dolphin", "Google Sans Flex as the file list font")},
    "zen": {"group": "apps", "on": False, "sudo": True, "ru": ("Zen Browser", "Браузер"), "en": ("Zen Browser", "Browser")},
    "telegram": {"group": "apps", "on": False, "sudo": True, "ru": ("Telegram", "Мессенджер"), "en": ("Telegram", "Messenger")},
    "vesktop": {"group": "apps", "on": False, "sudo": True, "ru": ("Vesktop", "Discord"), "en": ("Vesktop", "Discord")},
    "osu": {"group": "apps", "on": False, "sudo": True, "ru": ("osu!lazer", "Ритм-игра"), "en": ("osu!lazer", "Rhythm game")},
    "steam": {"group": "apps", "on": False, "sudo": True,
              "ru": ("Steam", "Нужен репозиторий [multilib]"), "en": ("Steam", "Needs the [multilib] repository")},
    "spotify": {"group": "apps", "on": False, "sudo": True, "ru": ("Spotify", "Музыка"), "en": ("Spotify", "Music")},
    "neovim": {"group": "apps", "on": False, "sudo": True, "ru": ("Neovim", "Редактор"), "en": ("Neovim", "Editor")},
}

# What changes on another system than Arch: the parts' texts and the window's ones, by distro().
DISTRO_PARTS = {
    "alt": {
        "deps": {"ru": ("Пакеты", "Всё, что нужно hi-shell, из Sisyphus (apt-get) и шрифт иконок с GitHub Google"),
                 "en": ("Packages", "Everything hi-shell needs, from Sisyphus (apt-get), and the icon font from Google's GitHub")},
        "steam": {"ru": ("Steam", "Ставится через epm play"), "en": ("Steam", "Installed with epm play")},
    },
}
DISTRO_TEXT = {
    "alt": {
        "ru": {"password.body": "Пакеты ставит apt-get, ему нужны права администратора. Пароль нужен только на эту установку и нигде не сохраняется.",
               "password.wrong": "Пароль не подошёл. Если он верный, sudo выключен: включите его от root командой control sudowheel enabled"},
        "en": {"password.body": "apt-get installs the packages and needs administrator rights. The password is only used for this install and isn't saved.",
               "password.wrong": "The password didn't work. If it's right, sudo is off: turn it on as root with control sudowheel enabled"},
    },
}


def distro(env=None, root="/") -> str:
    """"arch", "alt" (ALT Linux) or "nixos", like install.sh decides it (HI_SHELL_DISTRO wins)."""
    env = os.environ if env is None else env
    if env.get("HI_SHELL_DISTRO"):
        return env["HI_SHELL_DISTRO"]
    etc = os.path.join(root, "etc")
    if os.path.exists(os.path.join(etc, "NIXOS")):
        return "nixos"
    if os.path.exists(os.path.join(etc, "altlinux-release")):
        return "alt"
    try:
        with open(os.path.join(etc, "os-release"), encoding="utf-8") as f:
            if any(line.strip().replace('"', "") == "ID=altlinux" for line in f):
                return "alt"
    except OSError:
        pass
    return "arch"


DISTRO = distro()

# The headings install.sh prints (":: Packages"), in order, and the part or group each one belongs to
# (None: printed on every run).
STEPS = (("Packages", "deps"), ("Optional apps", "apps"), ("Source", None), ("Link", None),
         ("Hyprland", None), ("Terminal configs", "terminal"), ("Dolphin", "dolphin"), ("Start", "start"))
STEP_TEXT = {
    "ru": {"Packages": "Пакеты", "Optional apps": "Программы", "Source": "Файлы hi-shell", "Link": "Ссылки",
           "Hyprland": "Hyprland", "Terminal configs": "Настройки терминала", "Dolphin": "Dolphin", "Start": "Запуск"},
}

# What sudo shows when it wants the password (install.sh's sudo and the AUR helper's both read SUDO_PROMPT),
# so the window answers it and nothing else.
SUDO_PROMPT = "[hi-shell-installer] sudo password: "

TEXT = {
    "ru": {
        "title": "Установка hi-shell",
        "intro": "Выберите, что установить. Файлы hi-shell ставятся всегда.",
        "group.system": "Основное", "group.terminal": "Настройки терминала и программ",
        "group.apps": "Программы", "group.other": "Другое",
        "channel": "Обновления", "channel.release": "Релизы", "channel.git": "Git (main)",
        "channel.sub": "Релизы проверены и меняются реже; main — самое новое, иногда ломается",
        "install": "Установить", "close": "Закрыть",
        "password.title": "Нужен пароль sudo",
        "password.body": "Пакеты ставит pacman, ему нужны права администратора. Пароль нужен только на эту установку и нигде не сохраняется.",
        "password.placeholder": "Пароль", "password.wrong": "Неверный пароль, попробуйте ещё раз",
        "password.ok": "Продолжить", "password.cancel": "Отмена",
        "progress.title": "Установка…", "progress.starting": "Запуск",
        "log": "Подробности", "input.placeholder": "Ответ установщику (если он что-то спросил) и Enter",
        "stop": "Остановить",
        "done.ok": "hi-shell установлен", "done.ok.body": "Нажмите Super, чтобы открыть меню приложений, или Super+Escape для настроек.",
        "done.ok.nostart": "hi-shell запустится при следующем входе в Hyprland (или: qs -c hi-shell -d).",
        "done.fail": "Установка не удалась", "done.fail.body": "Код выхода {code}. Журнал: {log}",
        "done.cancelled": "Установка остановлена", "done.cancelled.body": "Уже установленное осталось на месте. Журнал: {log}",
        "cancel.title": "Остановить установку?", "cancel.body": "Уже установленное останется на месте.",
        "cancel.stop": "Остановить", "cancel.keep": "Продолжить установку",
        "sudo.again": "sudo снова спросил пароль: введите его в поле под журналом",
        "error.script": "Не найден install.sh: {path}",
    },
    "en": {
        "title": "Install hi-shell",
        "intro": "Choose what to install. hi-shell's own files are always installed.",
        "group.system": "Main", "group.terminal": "Terminal and app configs",
        "group.apps": "Apps", "group.other": "Other",
        "channel": "Updates", "channel.release": "Releases", "channel.git": "Git (main)",
        "channel.sub": "Releases are tested and change less often; main is the newest and breaks now and then",
        "install": "Install", "close": "Close",
        "password.title": "sudo password needed",
        "password.body": "pacman installs the packages and needs administrator rights. The password is only used for this install and isn't saved.",
        "password.placeholder": "Password", "password.wrong": "Wrong password, try again",
        "password.ok": "Continue", "password.cancel": "Cancel",
        "progress.title": "Installing…", "progress.starting": "Starting",
        "log": "Details", "input.placeholder": "An answer for the installer (if it asked something), then Enter",
        "stop": "Stop",
        "done.ok": "hi-shell is installed", "done.ok.body": "Tap Super for the app launcher, Super+Escape for settings.",
        "done.ok.nostart": "hi-shell starts the next time you log in to Hyprland (or: qs -c hi-shell -d).",
        "done.fail": "The install failed", "done.fail.body": "Exit code {code}. Log: {log}",
        "done.cancelled": "The install was stopped", "done.cancelled.body": "What's installed already stays. Log: {log}",
        "cancel.title": "Stop the install?", "cancel.body": "What's installed already stays.",
        "cancel.stop": "Stop", "cancel.keep": "Keep installing",
        "sudo.again": "sudo asked for the password again: type it in the field under the log",
        "error.script": "install.sh not found: {path}",
    },
}


def language(env=None) -> str:
    """"ru" when the locale is Russian, "en" otherwise (LC_ALL wins over LC_MESSAGES over LANG, like gettext)."""
    env = os.environ if env is None else env
    for key in ("LC_ALL", "LC_MESSAGES", "LANG"):
        value = env.get(key, "")
        if value:
            return "ru" if value.lower().startswith("ru") else "en"
    return "en"


def tr(lang: str, key: str, distro_id=None, **values) -> str:
    own = DISTRO_TEXT.get(distro_id or DISTRO, {})
    text = own.get(lang, own.get("en", {})).get(key) or TEXT.get(lang, TEXT["en"]).get(key) or TEXT["en"][key]
    return text.format(**values) if values else text


def step_text(lang: str, heading: str) -> str:
    return STEP_TEXT.get(lang, {}).get(heading, heading)


def parse_list(output: str) -> list:
    """`install.sh --list` -> [(name, description)], in its order."""
    parts = []
    for line in output.splitlines():
        m = re.match(r"^\s+([a-z0-9_-]+)\s+(.+?)\s*$", line)
        if m:
            parts.append((m.group(1), m.group(2)))
    return parts


def describe(lang: str, name: str, fallback: str, distro_id=None) -> dict:
    """The row of one part: title, subtitle, group, default and whether it needs sudo."""
    meta = PARTS.get(name)
    if meta is None:
        return {"name": name, "title": name, "subtitle": fallback, "group": "other", "on": True, "sudo": False}
    texts = {**meta, **DISTRO_PARTS.get(distro_id or DISTRO, {}).get(name, {})}
    title, subtitle = texts.get(lang, texts["en"])
    return {"name": name, "title": title, "subtitle": subtitle, "group": meta["group"],
            "on": meta["on"], "sudo": meta.get("sudo", False)}


def rows(lang: str, listed: list, distro_id=None) -> list:
    """The parts install.sh offers, described, grouped in GROUPS order (each group keeps install.sh's order)."""
    described = [describe(lang, name, text, distro_id) for name, text in listed]
    return sorted(described, key=lambda r: GROUPS.index(r["group"]))


def install_args(selected, listed_names, channel: str) -> list:
    """The arguments for install.sh: no questions, exactly the parts picked, the update channel.

    An empty --only means "every part" to install.sh, so nothing picked is a --skip of every part instead.
    """
    if channel not in ("git", "release"):
        raise ValueError(f"unknown channel: {channel}")
    chosen = set(selected)
    picked = [n for n in listed_names if n in chosen]
    args = ["--yes", f"--channel={channel}"]
    if picked:
        args.append("--only=" + ",".join(picked))
    elif listed_names:
        args.append("--skip=" + ",".join(listed_names))
    return args


def needs_sudo(selected) -> bool:
    return any(PARTS.get(n, {}).get("sudo") for n in selected)


def expected_steps(selected) -> list:
    """The headings install.sh will print for these parts, to show the progress as a fraction."""
    chosen = set(selected)
    groups = {PARTS[n]["group"] for n in chosen if n in PARTS}
    return [heading for heading, part in STEPS if part is None or part in chosen or part in groups]


def progress(current, expected: list) -> float:
    """How far the install is (0..0.95; the rest is for the exit), from the heading printed last."""
    if not expected or current not in expected:
        return 0.02
    # The step that is running counts as half done.
    return min(0.95, (expected.index(current) + 0.5) / len(expected))


ANSI = re.compile(r"\x1b\[[0-9;?]*[ -/]*[@-~]|\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)|\x1b[()][0-9A-Za-z]|\x1b[=>78]")


def strip_ansi(text: str) -> str:
    return ANSI.sub("", text)


STEP = re.compile(r"^:: (.+?)\s*$")
HEADINGS = {h for h, _ in STEPS}


def step_heading(line: str):
    """":: Packages" -> "Packages" for install.sh's own headings; None for anything else (pacman's ":: Proceed..." too)."""
    m = STEP.match(line)
    if not m:
        return None
    heading = m.group(1)
    if heading.startswith("Packages"):  # ":: Packages (NixOS)", ":: Packages (ALT Linux)"
        heading = "Packages"
    return heading if heading in HEADINGS else None


class Terminal:
    """Turns a terminal's output into lines: "\\r" starts the line over (pacman's progress bars), ANSI goes.

    feed() returns the lines this chunk finished; `line` is the one still being written. An escape sequence
    cut in two by the chunks is kept until the rest arrives.
    """

    def __init__(self):
        self.line = ""
        self._overwrite = False  # a "\r" came: the next text replaces the line, a "\n" keeps it
        self._held = ""          # the start of an escape sequence at the end of the last chunk

    def feed(self, text: str) -> list:
        text = self._held + text
        self._held = ""
        cut = text.rfind("\x1b")
        if cut != -1 and not ANSI.match(text, cut) and len(text) - cut < 32:
            text, self._held = text[:cut], text[cut:]
        done = []
        for piece in re.split(r"(\r|\n)", strip_ansi(text)):
            if piece == "\n":
                done.append(self.line)
                self.line = ""
                self._overwrite = False
            elif piece == "\r":
                self._overwrite = True
            elif piece:
                if self._overwrite:
                    self.line = ""
                    self._overwrite = False
                self.line += piece.replace("\b", "")
        return done

    def asks_password(self) -> bool:
        return self.line.rstrip().endswith(SUDO_PROMPT.rstrip())
