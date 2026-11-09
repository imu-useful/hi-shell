"""Shared helpers for the tests: paths, running the JS schema through node, a fake `qs` for the CLI."""
import json
import os
import shutil
import stat
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CLI = ROOT / "sh" / "hi-shell"


def node_eval(js_file: Path, expression: str):
    """Load a `.pragma library` JS file in node and return the JSON of `expression` (evaluated after it)."""
    source = js_file.read_text().replace(".pragma library", "")
    script = source + f"\n;process.stdout.write(JSON.stringify({expression}));"
    out = subprocess.run(["node", "-e", script], capture_output=True, text=True, check=True)
    return json.loads(out.stdout)


class FakeQs:
    """A `qs` on PATH that logs what it was called with and says the shell is running.

    `qs -c hi-shell ipc call <args>` -> one line per call in `calls` (arguments joined with \\x1f).
    """

    def __init__(self):
        self.dir = Path(tempfile.mkdtemp(prefix="hi-test-"))
        self.log = self.dir / "calls.log"
        self.home = self.dir / "home"
        self.home.mkdir()
        qs = self.dir / "qs"
        qs.write_text(
            "#!/bin/sh\n"
            'if [ "$3" = list ]; then echo "Process ID: 1"; exit 0; fi\n'
            f'printf "%s\\037" "$@" >> "{self.log}"; printf "\\n" >> "{self.log}"\n'
            "exit 0\n"
        )
        qs.chmod(qs.stat().st_mode | stat.S_IEXEC)

    def run(self, *args, check=False):
        env = dict(os.environ, PATH=f"{self.dir}:{os.environ['PATH']}", HOME=str(self.home), XDG_CONFIG_HOME=str(self.home / ".config"))
        return subprocess.run(["sh", str(CLI), *args], capture_output=True, text=True, env=env, check=check)

    @property
    def calls(self):
        if not self.log.exists():
            return []
        return [line.rstrip("\x1f").split("\x1f") for line in self.log.read_text().split("\n") if line]

    def close(self):
        shutil.rmtree(self.dir, ignore_errors=True)
