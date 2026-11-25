#!/usr/bin/env python3
"""Draws the made-up posters and backdrops the store screenshots show.

Writes Apps/Shared/Debug/StoreArt-<source>-<kind>-<number>-<poster|backdrop>.jpg
for the scripted movies and series of the shelf UI tests (UITestingShelf),
and copies the pictures of the titles the App Review demo server lists to
Web/review/art/<movie|series>-<id>-<poster|backdrop>.jpg, so the reviewer sees
the art the screenshots show (scripts/make-review-xtream.py). Every picture is abstract shapes from the formulas below: no title, person,
logo or brand, and no third-party picture is ever committed. The Release
build leaves the files out (Config/Shared.xcconfig).

Run from the repository root: python3 scripts/make-store-art.py
Needs ffmpeg for the JPEG step; set FFMPEG to use another binary.
"""

import math
import os
import pathlib
import shutil
import subprocess
import tempfile
import zlib

OUT = pathlib.Path("Apps/Shared/Debug")
REVIEW_OUT = pathlib.Path("Web/review/art")
FFMPEG = os.environ.get("FFMPEG", "ffmpeg")

# (source, kind, number, style, top colour, bottom colour, accent colour)
TITLES = [
    ("cabin", "vod", 1, "harbor", (16, 28, 58), (220, 120, 70), (255, 214, 150)),
    ("cabin", "vod", 2, "rings", (40, 12, 44), (200, 60, 90), (255, 190, 120)),
    ("cabin", "vod", 3, "dunes", (90, 60, 40), (240, 180, 110), (255, 236, 200)),
    ("cabin", "vod", 4, "city", (20, 24, 40), (70, 90, 140), (250, 210, 120)),
    ("cabin", "vod", 5, "bands", (14, 40, 40), (40, 150, 130), (230, 240, 200)),
    ("cabin", "vod", 6, "rings", (10, 30, 30), (60, 170, 120), (220, 255, 210)),
    ("office", "vod", 1, "harbor", (8, 12, 30), (40, 70, 130), (200, 220, 255)),
    ("office", "vod", 2, "peaks", (120, 150, 200), (235, 240, 250), (255, 255, 255)),
    ("office", "vod", 3, "dunes", (60, 30, 20), (190, 110, 60), (250, 200, 140)),
    ("cabin", "series", 1, "aurora", (6, 12, 30), (20, 40, 70), (90, 240, 170)),
    ("cabin", "series", 2, "city", (30, 14, 30), (120, 50, 80), (255, 170, 90)),
    ("cabin", "series", 3, "bands", (50, 40, 70), (170, 140, 200), (255, 240, 220)),
    ("office", "series", 1, "peaks", (30, 50, 90), (180, 200, 230), (250, 250, 255)),
]

# (source, kind, number) of a title above: its name on the review server
REVIEW = {
    ("cabin", "vod", 1): "movie-101",
    ("cabin", "vod", 3): "movie-102",
    ("cabin", "vod", 4): "movie-103",
    ("cabin", "vod", 5): "movie-104",
    ("cabin", "vod", 6): "movie-105",
    ("cabin", "series", 2): "series-201",
}

SIZES = {"poster": (400, 600), "backdrop": (1280, 720)}


def mix(a, b, t):
    t = min(1.0, max(0.0, t))
    return tuple(x + (y - x) * t for x, y in zip(a, b))


def shade(c, f):
    return tuple(x * f for x in c)


def pixel(style, u, v, aspect, top, bottom, accent, seed):
    """The colour at u, v (0 to 1 across and down) for one style."""
    sky = mix(top, bottom, v**1.4)
    if style == "harbor":
        sun = math.hypot((u - 0.62) * aspect, v - 0.5)
        glow = mix(sky, accent, 0.35 * math.exp(-sun * 6))
        colour = mix(accent, glow, (sun - 0.07) * 40)
        for row, depth in ((0.6, 0.55), (0.7, 0.35), (0.82, 0.18)):
            wave = row + 0.015 * math.sin(u * 18 * aspect + seed + row * 9)
            if v > wave:
                colour = shade(top, 0.6 + depth)
        return colour
    if style == "rings":
        r = math.hypot((u - 0.5) * aspect, v - 0.42)
        band = 0.5 + 0.5 * math.cos(r * 38 + seed)
        return mix(sky, accent, band * math.exp(-r * 2.2))
    if style == "dunes":
        colour = sky
        for i in range(4):
            crest = 0.45 + i * 0.13 + 0.06 * math.sin(u * (4 + i) * aspect + seed + i * 2)
            if v > crest:
                colour = shade(mix(bottom, top, i / 3), 1.0 - 0.12 * i)
        sun = math.hypot((u - 0.3) * aspect, v - 0.25)
        return mix(accent, colour, (sun - 0.06) * 30) if sun < 0.09 else colour
    if style == "city":
        column = int(u * 22 * aspect)
        height = 0.45 + 0.35 * (((column * 37 + seed * 11) % 13) / 13)
        if v > height:
            lit = (int(v * 60) + column * 7 + seed) % 9 == 0 and int(u * 22 * aspect * 4) % 4 != 0
            return accent if lit else shade(top, 0.8)
        moon = math.hypot((u - 0.75) * aspect, v - 0.18)
        return mix(accent, sky, (moon - 0.04) * 40) if moon < 0.05 else sky
    if style == "bands":
        d = u * aspect * 0.8 + v
        band = int(d * 9 + seed) % 3
        return [sky, mix(sky, accent, 0.25), shade(sky, 0.75)][band]
    if style == "peaks":
        colour = sky
        for i, (centre, width, height) in enumerate(((0.3, 0.35, 0.35), (0.7, 0.4, 0.45), (0.5, 0.5, 0.6))):
            ridge = height + abs(u - centre) * aspect / width * 0.3
            if v > ridge:
                colour = shade(mix(top, bottom, 0.3 * i), 0.7 + 0.1 * i)
                if v < ridge + 0.015:
                    colour = accent
        return colour
    if style == "aurora":
        curtain = 0.3 + 0.08 * math.sin(u * 7 * aspect + seed) + 0.04 * math.sin(u * 19 * aspect)
        glow = math.exp(-abs(v - curtain) * 14) * (0.6 + 0.4 * math.sin(u * 40 * aspect))
        colour = mix(sky, accent, glow)
        if v > 0.78 + 0.02 * math.sin(u * 5 * aspect):
            colour = shade(top, 0.7)
        return colour
    raise ValueError(style)


def png(width, height, rows):
    def chunk(tag, data):
        return len(data).to_bytes(4, "big") + tag + data + zlib.crc32(tag + data).to_bytes(4, "big")

    raw = b"".join(b"\x00" + bytes(row) for row in rows)
    header = width.to_bytes(4, "big") + height.to_bytes(4, "big") + bytes([8, 2, 0, 0, 0])
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")


def draw(style, size, top, bottom, accent, seed):
    width, height = size
    aspect = width / height
    rows = []
    for y in range(height):
        row = []
        for x in range(width):
            colour = pixel(style, x / width, y / height, aspect, top, bottom, accent, seed)
            row.extend(max(0, min(255, int(c))) for c in colour)
        rows.append(row)
    return png(width, height, rows)


def main():
    REVIEW_OUT.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as scratch:
        for source, kind, number, style, top, bottom, accent in TITLES:
            for shape, size in SIZES.items():
                name = f"StoreArt-{source}-{kind}-{number}-{shape}.jpg"
                source_png = pathlib.Path(scratch) / "art.png"
                source_png.write_bytes(draw(style, size, top, bottom, accent, number * 3 + len(source)))
                subprocess.run(
                    [FFMPEG, "-hide_banner", "-loglevel", "error", "-y", "-i", str(source_png), "-q:v", "4",
                     "-pix_fmt", "yuvj420p", "-fflags", "+bitexact", "-flags", "+bitexact", "-map_metadata", "-1",
                     str(OUT / name)],
                    check=True)
                review = REVIEW.get((source, kind, number))
                if review:
                    shutil.copyfile(OUT / name, REVIEW_OUT / f"{review}-{shape}.jpg")


if __name__ == "__main__":
    main()
