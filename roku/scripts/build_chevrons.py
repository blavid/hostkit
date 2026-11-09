"""Build 39: 24x12 #F2A93B chevrons (down and up) baked 1:1 for the For You row hints.
Build 40: 12x24 left and right chevrons for the row side arrows."""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]


def chevron(up: bool) -> Image.Image:
    scale = 8
    im = Image.new("RGBA", (24 * scale, 12 * scale), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    pts = [(2, 2), (12, 10), (22, 2)] if not up else [(2, 10), (12, 2), (22, 10)]
    d.line([(x * scale, y * scale) for x, y in pts], fill=(0xF2, 0xA9, 0x3B, 255), width=3 * scale, joint="curve")
    return im.resize((24, 12), Image.LANCZOS)


if __name__ == "__main__":
    for name, up in (("down", False), ("up", True)):
        chevron(up).save(ROOT / "channel" / "images" / f"chevron-{name}-24.png", optimize=True)
    down = chevron(False)
    down.rotate(-90, expand=True).save(ROOT / "channel" / "images" / "chevron-left-24.png", optimize=True)
    down.rotate(90, expand=True).save(ROOT / "channel" / "images" / "chevron-right-24.png", optimize=True)
    print("wrote chevron-down-24.png, chevron-up-24.png, chevron-left-24.png, chevron-right-24.png")
