#!/usr/bin/env python3
"""Build 34: render the lower-left Book Direct ads (one full-bleed PNG each).

Each ad is 438x214, drawn 1:1 in the on-screen slot, with the text baked in:
house photo, the build 40 text "Book Direct & Save!! About 10% less than
Airbnb or VRBO" on four lines, the site QR and
sunrivertownhome.com under the QR in a second palette color. Photos are the
house photos from the site (/workspace/bookdirect/site). Free tools only:
Pillow + qrcode. The list the channel rotates is channel/data/ads.json.
"""
from __future__ import annotations
import json, sys
from pathlib import Path
import qrcode
from PIL import Image, ImageChops, ImageDraw, ImageFont, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
_ARGS = [a for a in sys.argv[1:] if not a.startswith("--")]
PHOTOS = Path(_ARGS[0] if _ARGS else "/workspace/bookdirect/site")
W, H = 438, 214
SITE = "https://sunrivertownhome.com"
BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
REG = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
# Build 40 (Blake via Captain): exactly this text, broken over four lines.
AD_TEXT = "Book Direct & Save!! About 10% less than Airbnb or VRBO"
HEAD = ["Book Direct", "& Save!!"]
SUB = ["About 10% less", "than Airbnb or VRBO"]  # build 41: >= 16px clear of the QR
assert " ".join(HEAD + SUB) == AD_TEXT
ADS = [
    {"id": "living", "photo": "living-room-1.jpg", "bg": (27, 42, 68), "accent": (242, 169, 59), "ease": True},
    {"id": "exterior", "photo": "exterior-front-1.jpg", "bg": (32, 58, 46), "accent": (232, 194, 122)},
    {"id": "kitchen", "photo": "kitchen-dining.jpg", "bg": (58, 38, 26), "accent": (242, 169, 59)},
]

def qr_img(size: int) -> Image.Image:
    q = qrcode.QRCode(border=2, box_size=10, error_correction=qrcode.constants.ERROR_CORRECT_M)
    q.add_data(SITE); q.make(fit=True)
    return q.make_image(fill_color="black", back_color="white").convert("RGB").resize((size, size), Image.NEAREST)

def luminance(rgb) -> float:
    def ch(v):
        v /= 255
        return v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4
    r, g, b = rgb[:3]
    return 0.2126 * ch(r) + 0.7152 * ch(g) + 0.0722 * ch(b)


def worst_contrast(bg: Image.Image, font, text: str, xy, rgb) -> float:
    """Lowest WCAG contrast between the text color and any backdrop pixel
    inside the text's ink box."""
    from PIL import ImageFilter
    box = ImageDraw.Draw(bg).textbbox(xy, text, font=font)
    lt = luminance(rgb)
    worst = 21.0
    # Blur 2px: single bright photo pixels don't decide legibility, areas do.
    for px in bg.filter(ImageFilter.GaussianBlur(2)).crop(box).getdata():
        lb = luminance(px)
        hi, lo = max(lt, lb), min(lt, lb)
        worst = min(worst, (hi + 0.05) / (lo + 0.05))
    return worst


def render(ad: dict) -> Image.Image:
    """Build 35: baked 1:1 at 438x214 (FHD x 96-534, y 758-972).

    Pixel review: headline 30px bold #FFFFFF, subline 24px #F4EFE3, domain
    24px bold #F2A93B, QR >= 150px on white. The photo is full bleed under a
    panel-colored scrim so the text keeps contrast."""
    photo = Image.open(PHOTOS / ad["photo"]).convert("RGB")
    ratio = max(W / photo.width, H / photo.height)
    photo = photo.resize((int(photo.width * ratio) + 1, int(photo.height * ratio) + 1), Image.LANCZOS)
    left = (photo.width - W) // 2; top = (photo.height - H) // 2
    im = photo.crop((left, top, left + W, top + H))
    ease = ad.get("ease", False)
    if ease:
        # Build 38 (Pixel b37 P3): the living-room photo is dark, so lift it.
        from PIL import ImageEnhance
        im = ImageEnhance.Brightness(im).enhance(1.35)
    # Build 37 (Blake: a real house photo filling the card): the photo shows
    # through. A dark gradient sits only behind the text column and the
    # domain band, and every text run is checked for >= 4.5:1 contrast below.
    scrim = Image.new("L", (W, H), 0); d = ImageDraw.Draw(scrim)
    for x in range(W):
        d.line([(x, 0), (x, H)], fill=int(max(50, 205 - 155 * max(0.0, (x - 270) / 100))))
    for y in range(160, H):
        d.line([(0, y), (W, y)], fill=200)
    if ease:
        # Build 38: a lighter column (alpha 120, fading to 30) plus a soft dark
        # halo only around each text run, so the photo shows between lines.
        scrim = Image.new("L", (W, H), 0); d = ImageDraw.Draw(scrim)
        for x in range(W):
            d.line([(x, 0), (x, H)], fill=int(max(30, 120 - 90 * max(0.0, (x - 170) / 100))))
        halo = Image.new("L", (W, H), 0); hd = ImageDraw.Draw(halo)
        fb = ImageFont.truetype(BOLD, 30); fr = ImageFont.truetype(REG, 22); fd = ImageFont.truetype(BOLD, 24)
        dom_x = W - 14 - hd.textlength("sunrivertownhome.com", font=fd)
        for text, font, xy in [(HEAD[0], fb, (14, 14)), (HEAD[1], fb, (14, 52)), (SUB[0], fr, (14, 98)),
                               (SUB[1], fr, (14, 128)), ("sunrivertownhome.com", fd, (dom_x, 174))]:
            b = hd.textbbox(xy, text, font=font)
            hd.rounded_rectangle([b[0] - 10, b[1] - 8, b[2] + 10, b[3] + 8], 10, fill=230)
        halo = halo.filter(ImageFilter.GaussianBlur(6))
        scrim = ImageChops.lighter(scrim, halo)
    im = Image.composite(Image.new("RGB", (W, H), (12, 16, 26)), im, scrim)
    bg_only = im.copy()
    dr = ImageDraw.Draw(im)
    qs = 152
    qx, qy = W - qs - 14, 10
    im.paste(qr_img(qs), (qx, qy))
    tx = 14  
    f1 = ImageFont.truetype(BOLD, 30); f2 = ImageFont.truetype(REG, 22); f3 = ImageFont.truetype(BOLD, 24)  # build 41: subline 22px for the 16px QR gap
    dr.text((tx, 14), HEAD[0], font=f1, fill=(255, 255, 255))
    dr.text((tx, 52), HEAD[1], font=f1, fill=(255, 255, 255))
    dr.text((tx, 98), SUB[0], font=f2, fill=(0xF4, 0xEF, 0xE3))
    dr.text((tx, 128), SUB[1], font=f2, fill=(0xF4, 0xEF, 0xE3))
    dom = "sunrivertownhome.com"
    dw = dr.textlength(dom, font=f3)
    dx = W - 14 - dw
    dr.text((dx, 174), dom, font=f3, fill=(0xF2, 0xA9, 0x3B))
    # Build 41 (Pixel b40): every text line's ink ends >= 16px before the QR's white square.
    ink_right = max(dr.textbbox((tx, y), t, font=f)[2] for t, f, y in [(HEAD[0], f1, 14), (HEAD[1], f1, 52), (SUB[0], f2, 98), (SUB[1], f2, 128)])
    gap = qx - ink_right
    print(f"  {ad['id']}: text-to-QR gap {gap}px")
    assert gap >= 16, f"{ad['id']}: text ends {gap}px from the QR, want >= 16"
    assert dx >= tx and 174 + 30 <= H, "domain does not fit"
    for text, font, xy, rgb in [(HEAD[0], f1, (tx, 14), (255, 255, 255)), (HEAD[1], f1, (tx, 52), (255, 255, 255)),
                                (SUB[0], f2, (tx, 98), (0xF4, 0xEF, 0xE3)), (SUB[1], f2, (tx, 128), (0xF4, 0xEF, 0xE3)),
                                (dom, f3, (dx, 174), (0xF2, 0xA9, 0x3B))]:
        ratio = worst_contrast(bg_only, font, text, xy, rgb)
        print(f"  {ad['id']}: '{text}' contrast {ratio:.1f}:1")
        assert ratio >= 4.5, f"{ad['id']}: '{text}' under 4.5:1"
    mask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, W - 1, H - 1], 12, fill=255)
    out = im.convert("RGBA"); out.putalpha(mask)
    return out

def shadow() -> Image.Image:
    pad = 24
    sh = Image.new("RGBA", (W + pad * 2, H + pad * 2), (0, 0, 0, 0))
    ImageDraw.Draw(sh).rounded_rectangle([pad, pad + 6, pad + W, pad + H + 6], 12, fill=(0, 0, 0, 150))
    return sh.filter(ImageFilter.GaussianBlur(10))

def main() -> None:
    shadow().save(ROOT / "channel" / "images" / "ad-shadow.png", optimize=True)
    entries = []
    for ad in ADS:
        out = ROOT / "channel" / "images" / f"ad-{ad['id']}.png"
        render(ad).save(out, optimize=True)
        entries.append({"id": ad["id"], "image": f"pkg:/images/ad-{ad['id']}.png", "alt": AD_TEXT + " sunrivertownhome.com"})
    data = {"version": 1, "rotateSeconds": 50, "fadeSeconds": 1, "ads": entries}
    (ROOT / "channel" / "data" / "ads.json").write_text(json.dumps(data, indent=2) + "\n")
    print("wrote", len(entries), "ads")

def check() -> None:
    """Build 38 suite gate: render every ad in memory and run the 4.5:1 asserts; write nothing."""
    for ad in ADS:
        render(ad)
    print("ad contrast ok", len(ADS), "ads")


if __name__ == "__main__":
    if "--check" in sys.argv:
        sys.argv.remove("--check")
        check()
    else:
        main()
