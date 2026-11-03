#!/usr/bin/env python3
"""Adult-site filter: the domains of services/adult_domains.txt in /etc/hosts (run as root through pkexec
by services/AdultFilter.qml).

    adult_filter.py on LIST     put the domains of LIST (and their www. names) into /etc/hosts, between markers
    adult_filter.py off         take the block out

Only the lines between the markers are ever touched; the rest of /etc/hosts stays as it is. The block is
written to a temporary file next to /etc/hosts and moved over it, so a failure leaves the old file.
"""

import os
import shutil
import sys
import tempfile
from pathlib import Path

HOSTS = Path("/etc/hosts")
BEGIN = "# >>> hi-shell adult filter (services/adult_filter.py) >>>"
END = "# <<< hi-shell adult filter <<<"


def strip(text: str) -> str:
    out, inside = [], False
    for line in text.splitlines(keepends=True):
        if line.strip() == BEGIN:
            inside = True
        elif line.strip() == END:
            inside = False
        elif not inside:
            out.append(line)
    return "".join(out)


def domains(listing: Path) -> list[str]:
    names = []
    for line in listing.read_text(encoding="utf-8").splitlines():
        name = line.strip().lower()
        if name and not name.startswith("#"):
            names.append(name)
    return sorted(set(names))


def write(text: str) -> None:
    fd, tmp = tempfile.mkstemp(dir=HOSTS.parent, prefix=".hosts-hi-shell-")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(text)
        shutil.copymode(HOSTS, tmp)
        os.replace(tmp, HOSTS)
    except BaseException:
        Path(tmp).unlink(missing_ok=True)
        raise


def main(argv: list[str]) -> int:
    if os.geteuid() != 0:
        print("adult_filter: needs root (pkexec)", file=sys.stderr)
        return 1
    if len(argv) < 2 or argv[1] not in ("on", "off"):
        print(__doc__, file=sys.stderr)
        return 2
    base = strip(HOSTS.read_text(encoding="utf-8"))
    if not base.endswith("\n") and base:
        base += "\n"
    if argv[1] == "off":
        write(base)
        return 0
    if len(argv) < 3:
        print("adult_filter: on needs the domain list", file=sys.stderr)
        return 2
    lines = [BEGIN]
    for name in domains(Path(argv[2])):
        lines.append(f"0.0.0.0 {name}")
        lines.append(f"0.0.0.0 www.{name}")
    lines.append(END)
    write(base + "\n".join(lines) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
