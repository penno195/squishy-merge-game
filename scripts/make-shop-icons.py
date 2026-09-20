#!/usr/bin/env python3
"""Draws an icon for every game pass and developer product.

Roblox wants an image with each one, and a shop where nine cards share one
picture reads as a shop that hasn't been finished. These are deliberately plain:
a candy gradient and one bold shape, because the icon is seen at the size of a
thumbnail and anything finer than this turns to mush there.

Run with a Pillow on PYTHONPATH:
    PYTHONPATH=<dir with PIL> python3 scripts/make-shop-icons.py <out dir>
"""
import math
import os
import sys
from PIL import Image, ImageDraw

SIZE = 512
WHITE = (255, 252, 250)
DARK = (74, 42, 86)


def background(draw, top, bottom):
    for y in range(SIZE):
        t = y / (SIZE - 1)
        draw.line([(0, y), (SIZE, y)], fill=tuple(round(top[i] + (bottom[i] - top[i]) * t) for i in range(3)))


def disc(draw, cx, cy, r, fill, outline=None, width=10):
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=fill, outline=outline, width=width)


def star(draw, cx, cy, r, points, fill, inner=0.45):
    pts = []
    for i in range(points * 2):
        radius = r if i % 2 == 0 else r * inner
        a = -math.pi / 2 + i * math.pi / points
        pts.append((cx + math.cos(a) * radius, cy + math.sin(a) * radius))
    draw.polygon(pts, fill=fill)


def coin(draw, cx, cy, r):
    disc(draw, cx, cy, r, (255, 214, 92), DARK, 12)
    disc(draw, cx, cy, r * 0.62, (255, 233, 150), DARK, 8)


def gem(draw, cx, cy, r, fill):
    draw.polygon([(cx, cy - r), (cx + r * 0.8, cy - r * 0.15), (cx, cy + r), (cx - r * 0.8, cy - r * 0.15)], fill=fill)
    draw.polygon([(cx, cy - r), (cx + r * 0.8, cy - r * 0.15), (cx, cy - r * 0.05), (cx - r * 0.8, cy - r * 0.15)],
                 fill=tuple(min(255, c + 40) for c in fill))


def arrow_up(draw, cx, cy, r, fill):
    draw.polygon([(cx, cy - r), (cx + r * 0.78, cy), (cx + r * 0.34, cy), (cx + r * 0.34, cy + r * 0.8),
                  (cx - r * 0.34, cy + r * 0.8), (cx - r * 0.34, cy), (cx - r * 0.78, cy)], fill=fill)


def bolt(draw, cx, cy, r, fill):
    draw.polygon([(cx + r * 0.2, cy - r), (cx - r * 0.55, cy + r * 0.12), (cx - r * 0.05, cy + r * 0.12),
                  (cx - r * 0.25, cy + r), (cx + r * 0.58, cy - r * 0.18), (cx + r * 0.06, cy - r * 0.18)], fill=fill)


def clover(draw, cx, cy, r, fill):
    for dx, dy in ((-0.42, -0.42), (0.42, -0.42), (-0.42, 0.42), (0.42, 0.42)):
        disc(draw, cx + dx * r, cy + dy * r, r * 0.52, fill)
    draw.rectangle([cx - r * 0.07, cy, cx + r * 0.07, cy + r * 1.15], fill=(120, 170, 96))


def crown(draw, cx, cy, r, fill):
    draw.polygon([(cx - r, cy + r * 0.55), (cx - r, cy - r * 0.5), (cx - r * 0.5, cy + r * 0.05),
                  (cx, cy - r * 0.75), (cx + r * 0.5, cy + r * 0.05), (cx + r, cy - r * 0.5),
                  (cx + r, cy + r * 0.55)], fill=fill)
    draw.rectangle([cx - r, cy + r * 0.55, cx + r, cy + r * 0.85], fill=fill)


def gift(draw, cx, cy, r, fill, ribbon):
    draw.rounded_rectangle([cx - r, cy - r * 0.62, cx + r, cy + r], radius=26, fill=fill)
    draw.rectangle([cx - r * 0.16, cy - r * 0.62, cx + r * 0.16, cy + r], fill=ribbon)
    draw.rectangle([cx - r, cy - r * 0.2, cx + r, cy + r * 0.12], fill=ribbon)
    disc(draw, cx - r * 0.36, cy - r * 0.72, r * 0.33, ribbon)
    disc(draw, cx + r * 0.36, cy - r * 0.72, r * 0.33, ribbon)


def squares(draw, cx, cy, r, fill, second):
    draw.rounded_rectangle([cx - r, cy - r * 0.7, cx - r * 0.06, cy + r * 0.7], radius=20, fill=fill)
    draw.rounded_rectangle([cx + r * 0.06, cy - r * 0.7, cx + r, cy + r * 0.7], radius=20, fill=second)


def merge(draw, cx, cy, r, fill, second):
    disc(draw, cx - r * 0.42, cy + r * 0.1, r * 0.5, fill)
    disc(draw, cx + r * 0.42, cy + r * 0.1, r * 0.5, second)
    arrow_up(draw, cx, cy - r * 0.55, r * 0.4, WHITE)


def wider(draw, cx, cy, r, fill):
    draw.rounded_rectangle([cx - r * 0.45, cy - r * 0.55, cx + r * 0.45, cy + r * 0.55], radius=18, fill=fill)
    for side in (-1, 1):
        x = cx + side * r
        draw.polygon([(x, cy), (x - side * r * 0.32, cy - r * 0.3), (x - side * r * 0.32, cy + r * 0.3)], fill=WHITE)


def clock(draw, cx, cy, r, fill):
    disc(draw, cx, cy, r, WHITE, DARK, 12)
    draw.line([(cx, cy), (cx, cy - r * 0.55)], fill=fill, width=16)
    draw.line([(cx, cy), (cx + r * 0.45, cy + r * 0.18)], fill=fill, width=16)


def coins(draw, cx, cy, r, count):
    for i in range(count):
        coin(draw, cx, cy + r * 0.62 - i * r * 0.52, r * 0.78)


ICONS = {
    # passes
    "StarterPack": ((255, 168, 205), (236, 106, 160), lambda d: gift(d, 256, 262, 150, WHITE, (236, 106, 160))),
    "DoubleCash": ((255, 224, 150), (245, 168, 74), lambda d: coins(d, 256, 250, 150, 3)),
    "AutoMerge": ((186, 226, 255), (120, 164, 240), lambda d: merge(d, 256, 268, 160, WHITE, (255, 214, 92))),
    "FastSpawn": ((255, 232, 150), (255, 166, 86), lambda d: bolt(d, 256, 256, 165, WHITE)),
    "LuckCharm": ((186, 244, 196), (104, 196, 134), lambda d: clover(d, 256, 232, 150, WHITE)),
    "AutoCollect": ((206, 196, 255), (140, 124, 230), lambda d: clock(d, 256, 256, 150, (140, 124, 230))),
    "CraftSlot": ((255, 206, 232), (226, 130, 190), lambda d: squares(d, 256, 256, 160, WHITE, (255, 214, 92))),
    "Admin": ((255, 196, 206), (222, 84, 108), lambda d: crown(d, 256, 262, 155, (255, 214, 92))),
    "BiggerGarden": ((198, 240, 200), (118, 196, 132), lambda d: wider(d, 256, 256, 165, WHITE)),
    # products
    "CashSmall": ((255, 236, 186), (246, 194, 104), lambda d: coins(d, 256, 262, 130, 2)),
    "CashLarge": ((255, 226, 140), (240, 160, 60), lambda d: coins(d, 256, 250, 150, 4)),
    "UnitBoost": ((255, 196, 224), (228, 104, 170), lambda d: arrow_up(d, 256, 256, 165, WHITE)),
    "GemPack": ((196, 232, 255), (96, 168, 232), lambda d: gem(d, 256, 256, 170, (120, 226, 255))),
}


def main(out_dir):
    os.makedirs(out_dir, exist_ok=True)
    for name, (top, bottom, draw_shape) in ICONS.items():
        image = Image.new("RGB", (SIZE, SIZE))
        draw = ImageDraw.Draw(image)
        background(draw, top, bottom)
        star(draw, 96, 96, 46, 6, tuple(min(255, c + 26) for c in top))
        star(draw, 424, 428, 34, 6, tuple(min(255, c + 26) for c in top))
        draw_shape(draw)
        path = os.path.join(out_dir, f"shop-{name}.png")
        image.save(path, "PNG")
        print("wrote", path)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else ".")
