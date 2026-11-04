#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""Draw the replacement badge for the shop's "SOLD OUT" sprite.

Geometry was measured from the original 256x128 texture (DXT5, not readable at
runtime): the red band sits at x 21..231, y 34..91 and the glyphs are ~30 px
tall. A full-bleed red canvas reads as "bigger" in game and covers the buttons
next to it, so keep these numbers unless the original texture changes.

The wording comes from the dictionary, so changing it is a one-line edit:

    python tools/make_sold.py --dict dict/zh_master.tsv --out sold.png
    python tools/make_sold.py --text 售罄 --out sold.png
"""
import argparse
import io

from PIL import Image, ImageDraw, ImageFont

W, H = 256, 128
BAND = (21, 34, 231, 91)      # left, top, right, bottom (exclusive on right/bottom)
TEXT_H = 30
RED = (255, 8, 8)
FONT_CANDIDATES = [
    r"C:\Windows\Fonts\simhei.ttf",
    r"C:\Windows\Fonts\msyh.ttc",
    r"C:\Windows\Fonts\msyhbd.ttc",
]


def pick_font():
    for path in FONT_CANDIDATES:
        try:
            return ImageFont.truetype(path, TEXT_H)
        except OSError:
            continue
    raise SystemExit("no CJK font found; install simhei.ttf or pass a path")


def text_from_dict(path, key="sold out"):
    with io.open(path, encoding="utf-8") as fh:
        for line in fh:
            if "\t" not in line:
                continue
            k, v = line.rstrip("\n").split("\t", 1)
            if k.strip().lower() == key:
                return v.replace("\\n", " ")
    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="sold.png")
    ap.add_argument("--text", default=None)
    ap.add_argument("--dict", dest="dict_path", default=None)
    ap.add_argument("--band", default=None, help="l,t,r,b override")
    ap.add_argument("--size", default=None, help="WxH override")
    args = ap.parse_args()

    global W, H, BAND
    if args.size:
        W, H = [int(x) for x in args.size.lower().split("x")]
    if args.band:
        BAND = tuple(int(x) for x in args.band.split(","))

    text = args.text
    if not text and args.dict_path:
        text = text_from_dict(args.dict_path)
    if not text:
        text = "售罄"

    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([BAND[0], BAND[1], BAND[2] - 1, BAND[3] - 1], fill=RED + (255,))

    font = pick_font()
    box = d.textbbox((0, 0), text, font=font)
    tw, th = box[2] - box[0], box[3] - box[1]
    x = BAND[0] + (BAND[2] - BAND[0] - tw) / 2 - box[0]
    y = BAND[1] + (BAND[3] - BAND[1] - th) / 2 - box[1]
    d.text((x, y), text, font=font, fill=(0, 0, 0, 255))

    img.save(args.out)
    print("wrote %s (%dx%d) text=%s" % (args.out, W, H, text))


if __name__ == "__main__":
    main()