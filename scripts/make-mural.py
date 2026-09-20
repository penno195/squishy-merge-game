#!/usr/bin/env python3
"""Draws the candy-land mural papered round the inside of the map's wall.

It is generated rather than painted so it can be regenerated at any size, and so
it tiles: the wall is a circle about 1500 studs round showing the same image a
dozen times, and a join that doesn't meet would show a dozen times too. Anything
with a horizontal position is drawn three times -- at x, x - width and x + width
-- so whatever crosses the seam comes back in on the other side, and the hills
are sine waves with a whole number of periods across the image for the same
reason.

Run with a Pillow on PYTHONPATH:
    PYTHONPATH=<dir with PIL> python3 scripts/make-mural.py <out.png>
"""
import math
import sys
from PIL import Image, ImageDraw

W, H = 1024, 576
SKY_TOP = (150, 214, 255)
SKY_LOW = (255, 214, 232)
FAR_HILL = (186, 228, 196)
MID_HILL = (146, 212, 160)
NEAR_HILL = (118, 196, 132)
CLOUD = (255, 252, 255)
CANDY = [(255, 150, 200), (255, 235, 140), (150, 215, 255), (205, 170, 255), (255, 175, 150)]


def wrapped(draw, fn, x, *args):
    """Draw something at x, and again either side, so the seam joins up."""
    for shift in (-W, 0, W):
        fn(draw, x + shift, *args)


def sky(image):
    px = image.load()
    for y in range(H):
        t = (y / (H - 1)) ** 0.7
        row = tuple(round(SKY_TOP[i] + (SKY_LOW[i] - SKY_TOP[i]) * t) for i in range(3))
        for x in range(W):
            px[x, y] = row


def cloud(draw, x, y, scale):
    for dx, dy, r in ((0, 0, 1.0), (-0.75, 0.2, 0.7), (0.8, 0.25, 0.62), (0.2, -0.4, 0.66)):
        rr = r * scale
        draw.ellipse([x + dx * scale - rr, y + dy * scale - rr, x + dx * scale + rr, y + dy * scale + rr], fill=CLOUD)


def hill(draw, base, amp, periods, colour, phase=0.0):
    points = [(x, base + amp * math.sin(2 * math.pi * periods * x / W + phase)) for x in range(W + 1)]
    draw.polygon(points + [(W, H), (0, H)], fill=colour)


def lollipop(draw, x, ground, scale, colour):
    stick = (255, 252, 250)
    draw.rectangle([x - scale * 0.09, ground - scale * 1.6, x + scale * 0.09, ground], fill=stick)
    draw.ellipse([x - scale * 0.62, ground - scale * 2.6, x + scale * 0.62, ground - scale * 1.36], fill=colour)
    draw.ellipse([x - scale * 0.26, ground - scale * 2.24, x + scale * 0.26, ground - scale * 1.72], fill=stick)


def candycane(draw, x, ground, scale):
    white, red = (255, 252, 250), (228, 58, 68)
    draw.rectangle([x - scale * 0.13, ground - scale * 2.0, x + scale * 0.13, ground], fill=white)
    for i in range(5):
        y = ground - scale * 2.0 + i * scale * 0.4
        draw.rectangle([x - scale * 0.13, y, x + scale * 0.13, y + scale * 0.2], fill=red)


def main(out):
    image = Image.new("RGB", (W, H))
    sky(image)
    draw = ImageDraw.Draw(image)

    for x, y, s in ((120, 120, 42), (430, 78, 34), (700, 140, 48), (910, 96, 30)):
        wrapped(draw, lambda d, px, py, ps: cloud(d, px, py, ps), x, y, s)

    hill(draw, H * 0.62, 26, 2, FAR_HILL, 0.6)
    hill(draw, H * 0.72, 20, 3, MID_HILL, 2.1)

    for index, x in enumerate(range(60, W, 128)):
        ground = H * 0.72 + 20 * math.sin(2 * math.pi * 3 * x / W + 2.1) + 6
        wrapped(draw, lambda d, px, py, ps, c: lollipop(d, px, py, ps, c), x, ground, 34, CANDY[index % len(CANDY)])

    hill(draw, H * 0.84, 14, 2, NEAR_HILL, 4.0)

    for x in range(20, W, 170):
        ground = H * 0.84 + 14 * math.sin(2 * math.pi * 2 * x / W + 4.0) + 10
        wrapped(draw, lambda d, px, py, ps: candycane(d, px, py, ps), x, ground, 30)

    for index, x in enumerate(range(0, W, 46)):
        ground = H * 0.84 + 14 * math.sin(2 * math.pi * 2 * x / W + 4.0) + 30
        r = 7 + (index % 3) * 3
        colour = CANDY[(index * 2) % len(CANDY)]
        wrapped(
            draw,
            lambda d, px, py, pr, c: d.ellipse([px - pr, py - pr, px + pr, py + pr], fill=c),
            x, ground, r, colour,
        )

    image.save(out, "PNG")
    print(f"wrote {out} ({W}x{H})")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "mural.png")
