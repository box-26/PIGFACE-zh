# -*- coding: utf-8 -*-
"""Sanity-check the master dictionaries before building or shipping.

Usage:  python tools/check.py

Checks: duplicate keys with different values, empty values, stray tabs,
unbalanced rich-text tags, translation keys that already contain Chinese,
and suspicious length ratios (Chinese should not be 3x longer than English).
Exit code 1 means at least one error was found.
"""
import io
import os
import re
import sys

TAGS = ("b", "i", "u", "color", "sprite", "size", "br")


def read(path):
    out = []
    for line in io.open(path, encoding="utf-8"):
        line = line.rstrip("\n")
        if not line:
            continue
        parts = line.split("\t")
        out.append((parts[0], parts[1] if len(parts) > 1 else None, len(parts)))
    return out


def main():
    here = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    errors, warnings = [], []

    for name in ("zh", "frag"):
        path = os.path.join(here, "dict", name + "_master.tsv")
        rows = read(path)
        seen = {}
        for key, val, ncol in rows:
            if ncol != 2:
                errors.append("%s: %r has %d columns" % (name, key, ncol))
                continue
            if not key.strip():
                errors.append("%s: empty key" % name)
            if val is None or not val.strip():
                errors.append("%s: %r has an empty translation" % (name, key))
                continue
            if key in seen and seen[key] != val:
                warnings.append("%s: duplicate key %r (%r vs %r)" % (name, key, seen[key], val))
            seen[key] = val

            if re.search(r"[\u4e00-\u9fff]", key):
                errors.append("%s: key already contains Chinese: %r" % (name, key))

            # A scene path in the value means a spreadsheet edit slipped an
            # extra column ("where it was found") into the translation.
            if re.search(r"(cutscene/|PLAYER CONTROLLER/|/hud/|/canvas/|/dialogue$)", val):
                errors.append("%s: %r has a scene path as translation: %r" % (name, key, val))

            for tag in TAGS:
                # <sprite name="..."> is self-closing in TMP text, so it has no </sprite>.
                if tag in ("br", "sprite"):
                    continue
                opens = len(re.findall(r"<%s[ >]" % tag, key))
                closes = len(re.findall(r"</%s>" % tag, key))
                if opens != closes:
                    warnings.append("%s: unbalanced <%s> in key %r" % (name, tag, key))

            if name == "zh" and len(key) > 12 and len(val) > len(key) * 2.2:
                warnings.append("%s: translation looks long for %r" % (name, key[:40]))

        print("%s: %d rows" % (name, len(rows)))

    for w in warnings:
        print("WARN " + w)
    for e in errors:
        print("ERROR " + e)
    print("----")
    print("%d error(s), %d warning(s)" % (len(errors), len(warnings)))
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
