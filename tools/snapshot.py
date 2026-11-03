# -*- coding: utf-8 -*-
"""Snapshot the dictionaries + plugin source into history/<timestamp>/.

This project has no git (the machine has none installed), so this is the
lightweight substitute: every time the dictionary or the plugin changes, run

    python tools/snapshot.py "what changed"

It copies dict/ and src/ into history/<YYYYmmdd-HHMMSS>/ and prepends a line
to CHANGELOG.md.
"""
import io
import os
import shutil
import sys
import time


def main():
    here = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    note = " ".join(sys.argv[1:]).strip() or "(no note)"
    stamp = time.strftime("%Y%m%d-%H%M%S")
    dest = os.path.join(here, "history", stamp)
    os.makedirs(dest, exist_ok=True)
    for sub in ("dict", "src"):
        src = os.path.join(here, sub)
        if os.path.isdir(src):
            shutil.copytree(src, os.path.join(dest, sub))
    line = "- %s  %s\n" % (stamp, note)
    path = os.path.join(here, "CHANGELOG.md")
    old = io.open(path, encoding="utf-8").read() if os.path.exists(path) else "# CHANGELOG\n\n"
    head, _, body = old.partition("\n\n") if old.startswith("# CHANGELOG") else ("# CHANGELOG", "", old)
    io.open(path, "w", encoding="utf-8", newline="").write(head + "\n\n" + line + (body or ""))
    print("snapshot ->", dest)


if __name__ == "__main__":
    main()
