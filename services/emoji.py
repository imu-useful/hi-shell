#!/usr/bin/env python3
"""Write the emoji list for the launcher's ":" search: [[emoji, name], ...] as JSON.

Usage: emoji.py OUTPUT
"""

import json
import sys
import unicodedata

RANGES = [(0x1F300, 0x1F5FF), (0x1F600, 0x1F64F), (0x1F680, 0x1F6FF), (0x1F900, 0x1F9FF),
          (0x1FA70, 0x1FAFF), (0x2600, 0x26FF), (0x2700, 0x27BF), (0x1F1E6, 0x1F1FF)]


def main() -> int:
    out = []
    for start, end in RANGES:
        for cp in range(start, end + 1):
            try:
                name = unicodedata.name(chr(cp))
            except ValueError:
                continue
            out.append([chr(cp), name.lower()])
    with open(sys.argv[1], "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False)
    return 0


if __name__ == "__main__":
    sys.exit(main())
