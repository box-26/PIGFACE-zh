#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""Turn miss.log into a translation work sheet.

    python tools/collect_missing.py --miss "D:/path/to/BepInEx/PigfaceCN/miss.log"

Writes (or updates) `待翻译.tsv` in the repo root:

    编号 <TAB> 英文原文 <TAB> 出现位置 <TAB> 译文（你来填）

Existing rows and anything you already translated are kept, so it is safe to
run this after every play session.
"""
import argparse
import io
import os
import re
import sys

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WS = re.compile(r"\s+")


def norm(s):
    s = s.replace("\\n", "\n").replace("\\r", "\r")
    return WS.sub(" ", s).strip().lower()


def looks_technical(s):
    t = s.strip()
    if not t:
        return True
    if re.match(r"^\d+(\.\d+)?\s+\d+\s*bit$", t):
        return True
    if re.match(r"^\d+\s*[x\u00d7]\s*\d+\s*\d+\s*Hz$", t):
        return True
    letters = [c for c in t if c.isalpha()]
    return len(letters) >= 2 and all(c.isupper() for c in letters) and len(t) <= 12


def load_dict(path):
    known = set()
    if not os.path.exists(path):
        return known
    with io.open(path, encoding="utf-8") as fh:
        for line in fh:
            if "\t" in line:
                known.add(norm(line.split("\t", 1)[0]))
    return known


def load_allow(path):
    allow = set()
    if not os.path.exists(path):
        return allow
    with io.open(path, encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if line and not line.startswith("#"):
                allow.add(norm(line))
    return allow


def read_sheet(path):
    rows = []
    if not os.path.exists(path):
        return rows
    with io.open(path, encoding="utf-8-sig") as fh:
        for line in fh:
            parts = line.rstrip("\n").split("\t")
            if len(parts) < 3 or not parts[0].isdigit():
                continue
            while len(parts) < 4:
                parts.append("")
            rows.append(parts)
    return rows


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--miss", required=True)
    ap.add_argument("--dict", default=os.path.join(HERE, "dict", "zh_master.tsv"))
    ap.add_argument("--allow", default=os.path.join(HERE, "dict", "allow.txt"))
    ap.add_argument("--out", default=os.path.join(HERE, "待翻译.tsv"))
    args = ap.parse_args()

    if not os.path.exists(args.miss):
        sys.exit("miss.log not found: %s" % args.miss)

    known = load_dict(args.dict)
    allow = load_allow(args.allow)
    rows = read_sheet(args.out)
    by_text = {norm(r[1]): r for r in rows}
    next_id = max([int(r[0]) for r in rows], default=0) + 1

    added = 0
    with io.open(args.miss, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            parts = line.rstrip("\n").split("\t")
            if len(parts) < 2:
                continue
            path, text = parts[0], parts[1].replace("\\n", "\n").replace("\\r", "\r")
            if not text.strip():
                continue
            key = norm(text)
            if not key or key in known or key in allow:
                continue
            if looks_technical(text):
                continue
            if key in by_text:
                continue
            by_text[key] = [str(next_id), text, path, ""]
            rows.append(by_text[key])
            next_id += 1
            added += 1

    rows.sort(key=lambda r: int(r[0]))
    with io.open(args.out, "w", encoding="utf-8-sig", newline="") as fh:
        fh.write("编号\t英文原文\t出现位置\t译文\n")
        for r in rows:
            fh.write("\t".join([r[0], r[1].replace("\n", "\\n").replace("\t", " "), r[2], r[3]]) + "\n")

    todo = sum(1 for r in rows if not r[3].strip())
    print("new entries : %d" % added)
    print("sheet total : %d (still untranslated: %d)" % (len(rows), todo))
    print("written to  : %s" % args.out)


if __name__ == "__main__":
    main()
