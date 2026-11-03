#!/usr/bin/env python3
"""Add the domains of a blocklist file to services/adult_domains.txt (the content filter's list).

    merge_adult_domains.py BLOCKLIST

Accepts plain lists (one domain per line), hosts files ("0.0.0.0 domain") and comments (#, !).
Keeps only well-formed domain names, drops duplicates and what the list already has, and appends
them in order. The result is printed as a count; the domains themselves are not printed.
"""

import re
import sys
from pathlib import Path

LIST = Path(__file__).resolve().parent / "adult_domains.txt"
NAME = re.compile(r"^(?=.{4,253}$)([a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$")


def names(text: str) -> list[str]:
    out = []
    for raw in text.splitlines():
        line = raw.split("#", 1)[0].split("!", 1)[0].strip().lower()
        parts = line.split()
        if not parts:
            continue
        # A hosts line: "0.0.0.0 domain"; a plain list line: "domain".
        name = parts[-1] if len(parts) > 1 else parts[0]
        if name.startswith("www."):
            name = name[4:]
        if NAME.match(name):
            out.append(name)
    return out


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print(__doc__, file=sys.stderr)
        return 2
    have = [l.strip().lower() for l in LIST.read_text(encoding="utf-8").splitlines() if l.strip() and not l.startswith("#")]
    seen = set(have)
    added = []
    for name in names(Path(argv[1]).read_text(encoding="utf-8", errors="replace")):
        if name not in seen:
            seen.add(name)
            added.append(name)
    if added:
        with LIST.open("a", encoding="utf-8") as f:
            f.write("\n".join(added) + "\n")
    print(f"added {len(added)} domains; the list has {len(seen)} now")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
