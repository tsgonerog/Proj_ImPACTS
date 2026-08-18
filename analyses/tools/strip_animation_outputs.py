#!/usr/bin/env python3
"""Strip oversized animation payloads from Jupyter notebooks, keeping static figures.

Matplotlib's ``anim.to_jshtml()`` embeds every frame of an animation as a
separate base64 PNG inside one ``text/html`` output. A few hundred frames turn a
notebook into hundreds of megabytes, which is what pushed several notebooks in
this repository past GitHub's hard 100 MB per-file limit.

This script removes only those bulky payloads. Static ``image/png`` figures are
left untouched, so the notebooks still render their plots on GitHub. Each
stripped output is replaced by a short text/plain note saying how to get it back.

Usage
-----
    python3 strip_animation_outputs.py [paths ...] [--threshold-mb N] [--dry-run]

With no paths, walks the analyses/ tree next to this script. Directories are
searched recursively; ``.ipynb_checkpoints`` is always skipped.

Exit status is 0 on success, 1 if any notebook failed to parse.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

# MIME types that carry animation payloads. Static image/png is deliberately
# absent: those are the figures we want to keep.
HEAVY_MIMES = (
    "text/html",
    "image/gif",
    "video/mp4",
    "application/javascript",
    "application/vnd.plotly.v1+json",
)

DEFAULT_THRESHOLD = 1_000_000  # bytes of serialised JSON
SKIP_DIRS = {".ipynb_checkpoints", ".git", "__pycache__"}


def payload_size(value) -> int:
    """Serialised size of one MIME payload, which may be a str or list of str."""
    if isinstance(value, str):
        return len(value)
    if isinstance(value, list):
        return sum(len(chunk) for chunk in value if isinstance(chunk, str))
    return len(json.dumps(value))


def strip_notebook(path: Path, threshold: int, dry_run: bool) -> tuple[int, int, int]:
    """Return (bytes_before, bytes_after, outputs_stripped) for one notebook."""
    before = path.stat().st_size
    with path.open(encoding="utf-8") as fh:
        nb = json.load(fh)

    stripped = 0
    for cell in nb.get("cells", []):
        for output in cell.get("outputs", []):
            data = output.get("data")
            if not isinstance(data, dict):
                continue
            for mime in list(data):
                if mime not in HEAVY_MIMES:
                    continue
                if payload_size(data[mime]) < threshold:
                    continue
                size = payload_size(data[mime])
                del data[mime]
                stripped += 1
                # Leave a visible breadcrumb, so a reader on GitHub can tell an
                # animation used to be here rather than seeing a bare repr.
                note = (f"[{mime} animation output ({size/1048576:.1f} MB) stripped "
                        f"to keep this notebook pushable - re-run this cell to regenerate]")
                existing = data.get("text/plain")
                if existing is None:
                    data["text/plain"] = [note]
                else:
                    if isinstance(existing, str):
                        existing = [existing]
                    data["text/plain"] = existing + ["\n", note]

    if stripped and not dry_run:
        # newline at EOF matches what Jupyter itself writes
        with path.open("w", encoding="utf-8") as fh:
            json.dump(nb, fh, indent=1, ensure_ascii=False)
            fh.write("\n")

    after = path.stat().st_size if not dry_run else before
    return before, after, stripped


def collect(paths: list[str], root: Path) -> list[Path]:
    targets = [Path(p) for p in paths] if paths else [root]
    found: list[Path] = []
    for target in targets:
        if target.is_file() and target.suffix == ".ipynb":
            found.append(target)
        elif target.is_dir():
            for nb in sorted(target.rglob("*.ipynb")):
                if SKIP_DIRS.isdisjoint(nb.parts):
                    found.append(nb)
    return found


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("paths", nargs="*", help="notebooks or directories (default: analyses/)")
    parser.add_argument("--threshold-mb", type=float, default=DEFAULT_THRESHOLD / 1e6,
                        help="strip payloads larger than this (default: 1 MB)")
    parser.add_argument("--dry-run", action="store_true", help="report without writing")
    args = parser.parse_args()

    threshold = int(args.threshold_mb * 1e6)
    root = Path(__file__).resolve().parent.parent
    notebooks = collect(args.paths, root)
    if not notebooks:
        print("no notebooks found", file=sys.stderr)
        return 1

    total_before = total_after = total_stripped = 0
    failures = 0
    for nb_path in notebooks:
        try:
            before, after, stripped = strip_notebook(nb_path, threshold, args.dry_run)
        except (json.JSONDecodeError, UnicodeDecodeError) as exc:
            print(f"  SKIP  {nb_path}: {exc}", file=sys.stderr)
            failures += 1
            continue
        total_before += before
        total_after += after
        total_stripped += stripped
        if stripped:
            print(f"  {before/1048576:8.1f} -> {after/1048576:7.1f} MB  "
                  f"({stripped} stripped)  {nb_path}")

    verb = "would save" if args.dry_run else "saved"
    print(f"\n{len(notebooks)} notebooks scanned, {total_stripped} outputs stripped, "
          f"{verb} {(total_before - total_after)/1048576:.0f} MB "
          f"({total_before/1048576:.0f} -> {total_after/1048576:.0f} MB)")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
