# -*- coding: utf-8 -*-
"""Build the runtime dictionaries (zh.tsv / frag.tsv) from the master files.

Usage:  python tools/build_dict.py <out_dir>

Master files are the single source of truth:
  dict/zh_master.tsv    <english key>\\t<chinese>
  dict/frag_master.tsv  <substring>\\t<replacement>

Duplicate keys are collapsed (last one wins, same as the game runtime), the result is
sorted for stable diffs, and a summary is printed.
"""
import io
import os
import sys


def read(path):
    out = []
    if not os.path.exists(path):
        return out
    for line in io.open(path, encoding="utf-8"):
        line = line.rstrip("\n")
        if not line:
            continue
        parts = line.split("\t")
        if len(parts) < 2:
            continue
        out.append((parts[0], parts[1]))
    return out


def main():
    here = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out_dir = sys.argv[1] if len(sys.argv) > 1 else os.path.join(here, "out")
    os.makedirs(out_dir, exist_ok=True)

    for name in ("zh", "frag"):
        pairs = read(os.path.join(here, "dict", name + "_master.tsv"))
        merged = {}
        dupes = 0
        for k, v in pairs:
            if k in merged and merged[k] != v:
                dupes += 1
            merged[k] = v
        keys = sorted(merged)
        path = os.path.join(out_dir, name + ".tsv")
        with io.open(path, "w", encoding="utf-8", newline="") as f:
            for k in keys:
                f.write(k + "\t" + merged[k] + "\n")
        print("%s: %d entries (%d duplicate keys collapsed) -> %s"
              % (name, len(keys), dupes, path))


if __name__ == "__main__":
    main()
