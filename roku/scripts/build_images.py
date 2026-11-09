#!/usr/bin/env python3
"""Rebuild the packaged images from the public-domain Mt. Bachelor photograph.

The committed JPEGs and the scrim are what the channel ships. Re-run this only
when the crop or the icon wordmark should change.

Title: Mt. Bachelor, Oregon, early morning
Author: Bonnie Moreland
Flickr: https://www.flickr.com/photos/icetsarina/51934339709/
         Public Domain Mark 1.0 (license id 10), confirmed on the photo page
Commons: https://commons.wikimedia.org/wiki/File:Mt._Bachelor,_Oregon,_early_morning_-_Flickr_-_Bonnie_Moreland_(free_images).jpg
         Template PD-author-FlickrPDM, reviewed by Ruthven on 2022-04-19
         AttributionRequired: false
"""

from __future__ import annotations

import argparse
import urllib.request
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "channel" / "images"
SOURCE_URL = (
    "https://upload.wikimedia.org/wikipedia/commons/d/dc/"
    "Mt._Bachelor%2C_Oregon%2C_early_morning_-_Flickr_-_Bonnie_Moreland_%28free_images%29.jpg"
)
EXPECTED_SIZE = (5167, 2951)
USER_AGENT = "EaglewoodRoku/1.0 (vacation-rental welcome screen; image rebuild)"

# Scrim matches the poster in MainScene.xml: strongest behind the greeting,
# then easing off so the lit foreground at the bottom of the frame stays visible.
SCRIM_Y0 = 680
SCRIM_Y1 = 800
SCRIM_Y2 = 940
SCRIM_MAX_ALPHA = 120
SCRIM_BOTTOM_ALPHA = 24
SCRIM_RGB = (8, 6, 5)

ICON_FONT_CANDIDATES = (
    "/usr/share/fonts/truetype/macos/Inter-SemiBold.ttf",
    "/usr/share/fonts/truetype/inter/Inter-SemiBold.ttf",
    "/usr/share/fonts/truetype/noto/NotoSans-Bold.ttf",
    "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
)


def download(dest: Path) -> None:
    request = urllib.request.Request(SOURCE_URL, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=60) as response:
        dest.write_bytes(response.read())


def smooth(t: float) -> float:
    return t * t * (3.0 - 2.0 * t)


def scrim_alpha(y: int, height: int = 1080) -> int:
    if y < SCRIM_Y0:
        return 0
    if y < SCRIM_Y1:
        t = (y - SCRIM_Y0) / (SCRIM_Y1 - SCRIM_Y0)
        return int(round(SCRIM_MAX_ALPHA * smooth(t)))
    if y < SCRIM_Y2:
        return SCRIM_MAX_ALPHA
    t = (y - SCRIM_Y2) / (height - SCRIM_Y2)
    return int(round(SCRIM_MAX_ALPHA + (SCRIM_BOTTOM_ALPHA - SCRIM_MAX_ALPHA) * smooth(t)))


def make_scrim() -> Image.Image:
    image = Image.new("RGBA", (4, 1080), (0, 0, 0, 0))
    pixels = image.load()
    for y in range(1080):
        color = (*SCRIM_RGB, scrim_alpha(y))
        for x in range(4):
            pixels[x, y] = color
    return image


def hero_crop(source: Image.Image) -> Image.Image:
    width, height = source.size
    crop_h = round(width * 9 / 16)
    if crop_h > height:
        raise SystemExit(f"source {width}x{height} is too narrow for a 16:9 crop")
    top = (height - crop_h) // 2
    cropped = source.crop((0, top, width, top + crop_h))
    return cropped.resize((1920, 1080), Image.Resampling.LANCZOS)


def save_jpeg(image: Image.Image, path: Path, quality: int, subsampling: int = 2) -> None:
    image.convert("RGB").save(
        path,
        format="JPEG",
        quality=quality,
        optimize=True,
        progressive=False,
        subsampling=subsampling,
    )


def composite_scrim(hero: Image.Image, scrim: Image.Image) -> Image.Image:
    scaled = scrim.resize(hero.size, Image.Resampling.BILINEAR)
    return Image.alpha_composite(hero.convert("RGBA"), scaled)


def icon_font() -> ImageFont.FreeTypeFont:
    for candidate in ICON_FONT_CANDIDATES:
        path = Path(candidate)
        if path.is_file():
            return ImageFont.truetype(str(path), 42)
    raise SystemExit("no bold sans font found for the icon wordmark")


def make_icon(hero: Image.Image, size: tuple[int, int]) -> Image.Image:
    height = hero.height
    crop_w = int(round(height * 4 / 3))
    left = (hero.width - crop_w) // 2
    icon = hero.crop((left, 0, left + crop_w, height)).resize(size, Image.Resampling.LANCZOS)
    icon = icon.convert("RGBA")
    pixels = icon.load()
    fade_start = int(size[1] * 0.70)
    for y in range(fade_start, size[1]):
        t = (y - fade_start) / (size[1] - fade_start)
        alpha = int(160 * smooth(t))
        keep = 1.0 - alpha / 255.0
        for x in range(size[0]):
            red, green, blue, _ = pixels[x, y]
            pixels[x, y] = (
                int(red * keep + SCRIM_RGB[0] * (1 - keep)),
                int(green * keep + SCRIM_RGB[1] * (1 - keep)),
                int(blue * keep + SCRIM_RGB[2] * (1 - keep)),
                255,
            )
    draw = ImageDraw.Draw(icon)
    label = "Eaglewood"
    font = icon_font()
    # Scale the 42px font with the icon height (405px master).
    if size[1] != 405:
        font = ImageFont.truetype(font.path, max(16, round(42 * size[1] / 405)))
    text_width = font.getlength(label)
    x = (size[0] - text_width) / 2
    y = size[1] * 0.78
    draw.text((x + 1, y + 1), label, font=font, fill=(0, 0, 0, 170))
    draw.text((x, y), label, font=font, fill=(247, 244, 239, 255))
    return icon.convert("RGB")


def sd_splash(splashed: Image.Image) -> Image.Image:
    # 720x480 is 3:2. Keep the peak, crop the sides, then scale.
    crop_w = int(round(splashed.height * 1.5))
    left = (splashed.width - crop_w) // 2
    cropped = splashed.crop((left, 0, left + crop_w, splashed.height))
    return cropped.resize((720, 480), Image.Resampling.LANCZOS)


def build(source_path: Path) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    with Image.open(source_path) as opened:
        source = opened.convert("RGB")
    if source.size != EXPECTED_SIZE:
        raise SystemExit(f"expected {EXPECTED_SIZE}, got {source.size}")
    hero = hero_crop(source)
    scrim = make_scrim()
    splashed = composite_scrim(hero, scrim)

    save_jpeg(hero, OUT / "background.jpg", quality=90)
    save_jpeg(splashed, OUT / "splash_fhd.jpg", quality=86)
    save_jpeg(splashed.resize((1280, 720), Image.Resampling.LANCZOS), OUT / "splash_hd.jpg", quality=82)
    save_jpeg(sd_splash(splashed), OUT / "splash_sd.jpg", quality=80)
    save_jpeg(make_icon(hero, (540, 405)), OUT / "icon_fhd.jpg", quality=90, subsampling=0)
    save_jpeg(make_icon(hero, (290, 218)), OUT / "icon_hd.jpg", quality=88, subsampling=0)
    scrim.save(OUT / "scrim.png", format="PNG", optimize=True)

    for path in sorted(OUT.iterdir()):
        print(f"{path.name:20} {path.stat().st_size:8d} bytes")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--source",
        type=Path,
        help="local original JPEG; omit to download the Commons file",
    )
    args = parser.parse_args()
    if args.source:
        build(args.source)
        return
    dest = Path("/tmp/eaglewood-mt-bachelor-original.jpg")
    download(dest)
    build(dest)


if __name__ == "__main__":
    main()
