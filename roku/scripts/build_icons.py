#!/usr/bin/env python3
"""Build 34: white 48x48 rail icons, one per menu type (drawn with Pillow).

The rail tints them with Poster.blendColor, so one white file serves the
focused (dark ink on amber) and plain states.
"""
from pathlib import Path
from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parents[1] / "channel" / "images"
S = 192  # draw at 4x, downsample to 48
W = (255, 255, 255, 255)

def canvas():
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0)); return im, ImageDraw.Draw(im)

def home(d):
    d.polygon([(96, 22), (172, 92), (150, 92), (150, 168), (42, 168), (42, 92), (20, 92)], fill=W)
    d.rectangle([80, 116, 112, 168], fill=(0, 0, 0, 0))

def wifi(d):
    for r, w in [(80, 18), (54, 18), (28, 18)]:
        d.arc([96 - r, 128 - r, 96 + r, 128 + r], 225, 315, fill=W, width=w)
    d.ellipse([84, 140, 108, 164], fill=W)

def todo(d):  # mountains + sun
    d.polygon([(10, 166), (74, 64), (114, 126), (134, 96), (182, 166)], fill=W)
    d.ellipse([132, 26, 168, 62], fill=W)

def rules(d):  # clipboard list
    d.rounded_rectangle([40, 28, 152, 170], 14, outline=W, width=14)
    d.rectangle([72, 18, 120, 42], fill=W)
    for y in (72, 104, 136):
        d.ellipse([62, y - 7, 76, y + 7], fill=W); d.rectangle([88, y - 6, 132, y + 6], fill=W)

def fixes(d):  # wrench
    d.line([(52, 150), (124, 78)], fill=W, width=26)
    d.ellipse([100, 26, 170, 96], fill=W)
    d.polygon([(132, 30), (160, 30), (148, 62), (120, 58)], fill=(0, 0, 0, 0))
    d.ellipse([34, 132, 70, 168], fill=W)

def book(d):  # tag
    d.polygon([(20, 96), (96, 20), (172, 20), (172, 96), (96, 172)], fill=W)
    d.ellipse([132, 44, 152, 64], fill=(0, 0, 0, 0))

def checkout(d):  # door with arrow
    d.rectangle([40, 24, 112, 170], outline=W, width=14)
    d.line([(98, 98), (170, 98)], fill=W, width=16)
    d.polygon([(150, 72), (182, 98), (150, 124)], fill=W)

for name, fn in [("home", home), ("wifi", wifi), ("todo", todo), ("rules", rules), ("fixes", fixes), ("book", book), ("checkout", checkout)]:
    im, d = canvas(); fn(d)
    im.resize((48, 48), Image.LANCZOS).save(OUT / f"icon-{name}.png", optimize=True)
print("icons ok")
