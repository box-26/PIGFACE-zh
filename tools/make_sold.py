#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""Draw the replacement badge for the shop's "SOLD OUT" sprite.

The original texture is 256x128 (DXT5, not readable at runtime). Its red band
occupies x 21..231, y 34..91 and the glyphs are about 30 px tall, so the
replacement has to keep exactly that geometry - a full-bleed red canvas looks
"bigger" in game and covers the buttons next to it.

    pip install pillow
    python tools/make_sold.py --out sold.png --text 售罄
"""
import argparse

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


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="sold.png")
    ap.add_argument("--text", default="售罄")
    args = ap.parse_args()

    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([BAND[0], BAND[1], BAND[2] - 1, BAND[3] - 1], fill=RED + (255,))

    font = pick_font()
    box = d.textbbox((0, 0), args.text, font=font)
    tw, th = box[2] - box[0], box[3] - box[1]
    x = BAND[0] + (BAND[2] - BAND[0] - tw) / 2 - box[0]
    y = BAND[1] + (BAND[3] - BAND[1] - th) / 2 - box[1]
    d.text((x, y), args.text, font=font, fill=(0, 0, 0, 255))

    img.save(args.out)
    print("wrote %s (%dx%d)" % (args.out, W, H))


if __name__ == "__main__":
    main()
