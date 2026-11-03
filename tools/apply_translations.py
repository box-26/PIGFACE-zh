#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""Merge the filled-in work sheet back into the dictionary.

    python tools/apply_translations.py

Reads 待翻译.tsv, takes every row whose 译文 column is filled, writes the pair
into dict/zh_master.tsv (updating the key if it already exists), then rebuilds
out/zh.tsv + out/frag.tsv.
"""
import argparse
import io
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--sheet", default=os.path.join(HERE, "待翻译.tsv"))
    ap.add_argument("--dict", default=os.path.join(HERE, "dict", "zh_master.tsv"))
    args = ap.parse_args()

    if not os.path.exists(args.sheet):
        sys.exit("work sheet not found: %s (run tools/collect_missing.py first)" % args.sheet)

    pairs = []
    with io.open(args.sheet, encoding="utf-8-sig") as fh:
        for line in fh:
            parts = line.rstrip("\n").split("\t")
            if len(parts) < 4 or not parts[0].isdigit():
                continue
            key, value = parts[1].strip(), parts[3].strip()
            if not key or not value:
                continue
            value = value.replace("\r\n", "\n").replace("\r", "\n").replace("\n", "\\n")
            pairs.append((key, value))

    if not pairs:
        sys.exit("no translated rows found - fill the 译文 column first")

    existing = {}
    order = []
    if os.path.exists(args.dict):
        with io.open(args.dict, encoding="utf-8") as fh:
            for line in fh:
                line = line.rstrip("\n")
                if "\t" not in line:
                    continue
                k, v = line.split("\t", 1)
                if k not in existing:
                    order.append(k)
                existing[k] = v

    updated = added = 0
    for key, value in pairs:
        if key in existing:
            if existing[key] != value:
                updated += 1
            existing[key] = value
        else:
            existing[key] = value
            order.append(key)
            added += 1

    with io.open(args.dict, "w", encoding="utf-8", newline="") as fh:
        for k in order:
            fh.write(k + "\t" + existing[k] + "\n")

    print("dict: +%d new, %d updated, total %d" % (added, updated, len(order)))

    rc = subprocess.call([sys.executable, os.path.join(HERE, "tools", "build_dict.py")])
    if rc != 0:
        sys.exit("build_dict.py failed")

    print("\nnext: regenerate the font if new characters appeared,")
    print("      then rebuild the dll and repackage (see docs/release.md).")


if __name__ == "__main__":
    main()
