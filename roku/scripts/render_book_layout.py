#!/usr/bin/env python3
"""Draw the Book Direct rectangles at FHD so the layout can be checked off-device."""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

OUT = Path("/opt/cursor/artifacts/book-direct-layout.png")

# Same numbers BookQrSlot() computes: card 1296,292 360x280, poster 220x180.
CARD_X, CARD_Y, CARD_W, CARD_H = 1296, 292, 360, 280
QR_W, QR_H = 220, 180
QR_X = CARD_X + (CARD_W - QR_W) // 2
QR_Y = CARD_Y + (CARD_H - QR_H) // 2
LABEL = (CARD_X, CARD_Y + 4, CARD_W, 40)
DOMAIN = (CARD_X, CARD_Y + CARD_H - 48, CARD_W, 40)

BLUE = (26, 36, 56, 255)
CARD = (36, 48, 68, 255)
GOLD = (242, 169, 59, 255)
CREAM = (255, 255, 242, 255)
INK = (28, 20, 8, 255)
PHOTO = (90, 110, 130, 255)


def box(draw, xywh, fill, outline=None):
    x, y, w, h = xywh
    draw.rectangle([x, y, x + w - 1, y + h - 1], fill=fill, outline=outline)


def main() -> None:
    image = Image.new("RGBA", (1920, 1080), (16, 14, 12, 255))
    draw = ImageDraw.Draw(image)
    font = ImageFont.load_default()
    box(draw, (192, 120, 372, 792), (26, 36, 56, 210))
    box(draw, (540, 36, 1320, 1000), BLUE)
    for index, line in enumerate(("Love our home?", "Want to come back?", "Like saving money?")):
        box(draw, (588, 64 + index * 44, 1100, 44), BLUE)
        draw.text((596, 76 + index * 44), line, fill=CREAM, font=font)
    box(draw, (588, 214, 620, 64), GOLD)
    draw.text((760, 236), "Book direct and save!", fill=INK, font=font)
    box(draw, (588, 292, 680, 200), PHOTO)
    draw.text((600, 370), "living room photo", fill=CREAM, font=font)
    box(draw, (CARD_X, CARD_Y, CARD_W, CARD_H), CARD)
    box(draw, LABEL, CARD)
    draw.text((CARD_X + 140, CARD_Y + 16), "Scan me!", fill=CREAM, font=font)
    box(draw, (QR_X, QR_Y, QR_W, QR_H), CREAM, outline=GOLD)
    draw.text((QR_X + 70, QR_Y + 80), "QR", fill=INK, font=font)
    box(draw, DOMAIN, CARD)
    draw.text((CARD_X + 70, DOMAIN[1] + 12), "sunrivertownhome.com", fill=GOLD, font=font)
    box(draw, (588, 500, 680, 160), BLUE)
    draw.text((596, 508), "body: full website sentence", fill=CREAM, font=font)
    box(draw, (588, 668, 680, 112), BLUE)
    draw.text((596, 676), "savings: up to about 10% less, full sentence", fill=CREAM, font=font)
    for index in range(5):
        color = GOLD if index % 2 == 0 else CARD
        box(draw, (588 + index * 226, 788, 214, 88), color)
    box(draw, (1380, 832, 520, 200), CREAM)
    box(draw, (1380 + 196, 832 + 12, 128, 128), (40, 40, 40, 255))
    draw.text((1392, 832 + 156), "sunrivertownhome.com", fill=(138, 90, 0, 255), font=font)
    left = QR_X - CARD_X
    right = CARD_X + CARD_W - QR_X - QR_W
    top = QR_Y - CARD_Y
    bottom = CARD_Y + CARD_H - QR_Y - QR_H
    if left != right or top != bottom:
        raise SystemExit(f"QR not centered: gaps {left} {right} {top} {bottom}")
    OUT.parent.mkdir(parents=True, exist_ok=True)
    image.convert("RGB").save(OUT)
    print(f"wrote {OUT} qr={QR_X},{QR_Y} gaps={left},{top}")


if __name__ == "__main__":
    main()
