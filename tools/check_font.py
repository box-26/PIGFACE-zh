#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""Check that every character used by the dictionary exists in font.ttf.

The bundled font is a subset: it only contains the glyphs that the dictionary
used at build time. Add a translation with a new character and forget to
rebuild the font, and that character renders as a blank box in game.

    python tools/check_font.py --font path/to/font.ttf
"""
import argparse
import io
import os
import sys

from fontTools.ttLib import TTFont

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def dict_chars(paths):
    chars = set()
    for path in paths:
        if not os.path.exists(path):
            continue
        with io.open(path, encoding="utf-8") as fh:
            for line in fh:
                if "\t" not in line:
                    continue
                value = line.rstrip("\n").split("\t", 1)[1]
                for ch in value:
                    if ch not in "\r\n\t":
                        chars.add(ch)
    chars.discard(" ")
    return chars


def src_chars(paths):
    chars = set()
    for path in paths:
        if not os.path.exists(path):
            continue
        with io.open(path, encoding="utf-8", errors="ignore") as fh:
            data = fh.read()
        for ch in data:
            if ord(ch) > 127:
                chars.add(ch)
    return chars


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--font", default=os.path.join(HERE, "out", "font.ttf"))
    ap.add_argument("--dict", nargs="*",
                    default=[os.path.join(HERE, "out", "zh.tsv"),
                             os.path.join(HERE, "out", "frag.tsv")])
    ap.add_argument("--src", nargs="*",
                    default=[os.path.join(HERE, "src", "Plugin.cs")])
    args = ap.parse_args()

    if not os.path.exists(args.font):
        sys.exit("font not found: %s\nrun tools/make_font.py first, or pass --font" % args.font)

    wanted = dict_chars(args.dict) | src_chars(args.src)
    font = TTFont(args.font, fontNumber=0)
    have = set()
    for table in font["cmap"].tables:
        have.update(chr(c) for c in table.cmap.keys())
    font.close()

    missing = sorted(c for c in wanted if c not in have)
    print("dict chars: %d, font chars: %d" % (len(wanted), len(have)))
    if not missing:
        print("OK - every dictionary character exists in the font")
        return

    print("MISSING %d character(s): %s" % (len(missing), "".join(missing)))
    print("\nrebuild the font so these glyphs exist:")
    print("  python tools/make_font.py --font <full CJK otf> --out out/font.ttf")
    sys.exit(1)


if __name__ == "__main__":
    main()
