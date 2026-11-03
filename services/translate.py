#!/usr/bin/env python3
"""Translate hi-shell's interface into another language with an AI model.

    translate.py --code de --name Deutsch --out FILE --provider claude --model sonnet
    translate.py --code fr --name Français --out FILE --provider openai --url https://api.openai.com/v1 --model gpt-4o-mini

Collects every Translation.tr("...") and Translation.trn("...", "...") string of the shell (in the
repo this script lives in), asks the model for each batch, and writes {English: translation} to FILE.
The key comes from the environment (HI_AI_KEY), never from the command line. Prints "progress N M"
lines while it works and "done N" at the end; errors go to stderr with exit code 1.
"""

import argparse
import json
import os
import re
import subprocess
import sys
import urllib.error
import urllib.request
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SCAN = ["modules", "services", "common", "wait-mode", "shell.qml"]
BATCH = 60
# Translation.tr("...") and Translation.trn("one", "many"), with the escapes QML uses.
TR = re.compile(r'Translation\.tr\(\s*"((?:[^"\\]|\\.)*)"\s*\)')
TRN = re.compile(r'Translation\.trn\(\s*"((?:[^"\\]|\\.)*)"\s*,\s*"((?:[^"\\]|\\.)*)"')


def unescape(raw: str) -> str:
    return json.loads('"' + raw + '"')


def collect() -> list[str]:
    found: set[str] = set()
    for part in SCAN:
        path = REPO / part
        files = [path] if path.is_file() else sorted(path.rglob("*.qml")) + sorted(path.rglob("*.js"))
        for f in files:
            text = f.read_text(encoding="utf-8", errors="replace")
            found.update(unescape(m) for m in TR.findall(text))
            for one, many in TRN.findall(text):
                found.add(unescape(one))
                found.add(unescape(many))
    return sorted(found)


def ask_claude(prompt: str, model: str) -> str:
    cmd = ["claude", "-p", "--output-format", "text"] + (["--model", model] if model else []) + [prompt]
    out = subprocess.run(cmd, capture_output=True, text=True, timeout=900)
    if out.returncode != 0:
        raise RuntimeError(out.stderr.strip() or f"claude exited with code {out.returncode}")
    return out.stdout


def ask_compat(url: str, key: str, model: str, prompt: str) -> str:
    body = json.dumps({"model": model, "messages": [{"role": "user", "content": prompt}], "temperature": 0.2}).encode()
    req = urllib.request.Request(f"{url.rstrip('/')}/chat/completions", data=body, method="POST")
    req.add_header("Content-Type", "application/json")
    if key:
        req.add_header("Authorization", f"Bearer {key}")
    try:
        with urllib.request.urlopen(req, timeout=300) as resp:
            data = json.loads(resp.read())
    except urllib.error.HTTPError as e:
        raise RuntimeError(f"HTTP {e.code}: {e.read()[:200].decode(errors='replace')}") from e
    return data["choices"][0]["message"]["content"]


def prompt_for(strings: list[str], name: str, code: str) -> str:
    return (
        f"Translate these interface strings of a desktop shell from English to {name} (language code {code}).\n"
        "They are short labels and sentences. Keep placeholders like %1 and %2 exactly, keep punctuation, "
        "keep brand and program names (Hyprland, Spotify, Telegram, matugen, Wallhaven, Claude). "
        "Answer with only one JSON object that maps each English string to its translation, nothing else.\n\n"
        + json.dumps(strings, ensure_ascii=False)
    )


def parse(answer: str) -> dict:
    start, end = answer.find("{"), answer.rfind("}")
    if start < 0 or end < start:
        raise ValueError("no JSON object in the answer")
    return json.loads(answer[start:end + 1])


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--code", required=True)
    ap.add_argument("--name", required=True)
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--provider", required=True)
    ap.add_argument("--url", default="")
    ap.add_argument("--model", default="")
    args = ap.parse_args()
    key = os.environ.get("HI_AI_KEY", "")

    strings = collect()
    result: dict[str, str] = {}
    failures = 0
    for i in range(0, len(strings), BATCH):
        batch = strings[i:i + BATCH]
        prompt = prompt_for(batch, args.name, args.code)
        print(f"progress {min(i + BATCH, len(strings))} {len(strings)}", flush=True)
        for attempt in range(2):
            try:
                answer = ask_claude(prompt, args.model) if args.provider == "claude" else ask_compat(args.url, key, args.model, prompt)
                translated = parse(answer)
                result.update({k: v for k, v in translated.items() if k in batch and isinstance(v, str) and v.strip()})
                break
            except (RuntimeError, ValueError, KeyError, OSError, json.JSONDecodeError) as e:
                if attempt == 1:
                    failures += 1
                    print(f"batch {i // BATCH + 1} failed: {e}", file=sys.stderr, flush=True)
    if not result:
        print("the model translated nothing", file=sys.stderr)
        return 1
    args.out.parent.mkdir(parents=True, exist_ok=True)
    tmp = args.out.with_suffix(".tmp")
    tmp.write_text(json.dumps(result, ensure_ascii=False, indent=4) + "\n", encoding="utf-8")
    tmp.replace(args.out)
    print(f"done {len(result)} of {len(strings)}" + (f", {failures} batch(es) failed" if failures else ""), flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
