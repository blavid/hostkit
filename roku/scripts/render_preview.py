#!/usr/bin/env python3
"""Draw 1920x1080 layout previews from the packaged assets and greeting rules.

These are not Roku captures. The typeface is Inter Bold standing in for
font:LargeBoldSystemFont. The dark bar uses the same width, bottom edge,
padding, and size ladder as the channel.
"""

from __future__ import annotations

import re
import shutil
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
from greeting import (  # noqa: E402
    BAR_BOTTOM,
    BAR_PAD,
    FONT_SIZES,
    LABEL_WIDTH,
    bar_box,
    build_greeting,
    wrap_measured,
)

SCENE = ROOT / "channel" / "components" / "MainScene.xml"
RULES = ROOT / "channel" / "components" / "GuestRules.brs"
IMAGES = ROOT / "channel" / "images"
OUT = ROOT / "docs" / "screenshots"
ARTIFACTS = Path("/opt/cursor/artifacts/screenshots")
FONT = "/usr/share/fonts/truetype/macos/Inter-Bold.ttf"
BADGE_FONT = "/usr/share/fonts/truetype/macos/Inter-SemiBold.ttf"

LONG_FIRST = "Alexandria Bartholomew Constantine"
LONG_LAST = "Worthington Montgomery-Smythe"


def parse_tag(xml: str, tag: str, node_id: str) -> dict[str, str]:
    match = re.search(rf'<{tag}\s+id="{node_id}"([^>]*)/?>', xml)
    if match is None:
        raise SystemExit(f"{tag} {node_id} not found")
    return dict(re.findall(r'(\w+)="([^"]*)"', match.group(1)))


def color(value: str) -> tuple[int, int, int, int]:
    hex_digits = value.removeprefix("0x")
    if len(hex_digits) != 8:
        raise SystemExit(f"expected RRGGBBAA color, got {value}")
    return tuple(int(hex_digits[index : index + 2], 16) for index in range(0, 8, 2))  # type: ignore[return-value]


def font_sizes() -> tuple[int, ...]:
    source = RULES.read_text(encoding="utf-8")
    match = re.search(r"return \[([0-9, ]+)\]", source)
    if match is None:
        raise SystemExit("greeting font sizes are not set in GuestRules.brs")
    sizes = tuple(int(part) for part in match.group(1).split(",") if part.strip())
    if sizes != FONT_SIZES:
        raise SystemExit(f"font ladder {sizes} does not match scripts/greeting.py")
    return sizes


def line_height(font: ImageFont.FreeTypeFont, size: int) -> int:
    ascent, descent = font.getmetrics()
    return ascent + descent + max(2, size // 8)


def fit(text: str, sizes: tuple[int, ...]) -> tuple[int, list[str], int, int]:
    chosen = sizes[-1]
    lines = [text]
    chosen_height = line_height(ImageFont.truetype(FONT, chosen), chosen)
    for size in sizes:
        font = ImageFont.truetype(FONT, size)
        fitted = wrap_measured(text, LABEL_WIDTH, font.getlength)
        if 1 <= len(fitted) <= 2 and "overflow" not in fitted:
            chosen = size
            lines = fitted
            chosen_height = line_height(font, size)
            break
    top, height = bar_box(min(2, len(lines)), chosen_height)
    return chosen, lines[:2], top, height


def render(greeting: str, badge: str, sizes: tuple[int, ...]) -> Image.Image:
    xml = SCENE.read_text(encoding="utf-8")
    backing = parse_tag(xml, "Rectangle", "greetingBacking")
    greeting_attrs = parse_tag(xml, "Label", "greeting")
    size, lines, top, height = fit(greeting, sizes)
    font = ImageFont.truetype(FONT, size)
    step = line_height(font, size)
    block = step * len(lines)

    background = Image.open(IMAGES / "background.jpg").convert("RGBA")
    scrim = Image.open(IMAGES / "scrim.png").convert("RGBA").resize(background.size, Image.Resampling.BILINEAR)
    image = Image.alpha_composite(background, scrim)
    draw = ImageDraw.Draw(image)
    draw.rectangle((0, top, 1920, top + height), fill=color(backing["color"]))
    text_top = top + (height - block) / 2
    fill = color(greeting_attrs["color"])
    for index, line in enumerate(lines):
        bbox = font.getbbox(line)
        text_w = bbox[2] - bbox[0]
        x = 80 + (LABEL_WIDTH - text_w) / 2 - bbox[0]
        y = text_top + index * step
        draw.text((x, y), line, font=font, fill=fill)
    draw_badge(image, f"{badge} · {size}px · {len(lines)} line{'s' if len(lines) != 1 else ''}")
    if top + height != BAR_BOTTOM:
        raise SystemExit("greeting bar is not anchored to y=960")
    if height < 160:
        raise SystemExit("greeting bar is shorter than 160px")
    if text_top < top or text_top + block > top + height + 1:
        raise SystemExit("greeting text does not sit inside the bar")
    return image.convert("RGB")


def draw_badge(image: Image.Image, label: str) -> None:
    draw = ImageDraw.Draw(image)
    font = ImageFont.truetype(BADGE_FONT, 22)
    text = "PREVIEW — not a device capture · " + label
    left, top, right, bottom = font.getbbox(text)
    text_w = right - left
    text_h = bottom - top
    x, y = 36, 32
    pad_x, pad_y = 16, 10
    rect = (x, y, x + text_w + pad_x * 2, y + text_h + pad_y * 2)
    draw.rounded_rectangle(rect, radius=8, fill=(245, 196, 81, 235))
    draw.text((x + pad_x, y + pad_y - top), text, font=font, fill=(26, 20, 12, 255))


def save(image: Image.Image, name: str) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    ARTIFACTS.mkdir(parents=True, exist_ok=True)
    path = OUT / name
    image.save(path, format="JPEG", quality=92, optimize=True, progressive=False, subsampling=0)
    shutil.copyfile(path, ARTIFACTS / name)
    print(f"{path} {path.stat().st_size} bytes")


def main() -> None:
    sizes = font_sizes()
    fallback = build_greeting("", "")
    named = build_greeting("Mary-Jane", "O'Brien")
    long_name = build_greeting(LONG_FIRST, LONG_LAST)
    long_size, long_lines, long_top, long_height = fit(long_name, sizes)
    if len(long_lines) < 2 and long_size == sizes[0]:
        raise SystemExit("long name did not wrap or shrink")
    if long_height <= 160 and len(long_lines) > 1:
        raise SystemExit("two-line greeting did not grow the bar")
    save(render(fallback, "fallback greeting", sizes), "welcome-fallback-preview.jpg")
    save(render(named, 'named greeting "Mary-Jane O\'Brien"', sizes), "welcome-named-preview.jpg")
    save(
        render(long_name, "long name", sizes),
        "welcome-long-name-preview.jpg",
    )
    print(
        f"long name layout size={long_size} lines={len(long_lines)} "
        f"top={long_top} height={long_height} pad={BAR_PAD}"
    )


if __name__ == "__main__":
    main()
