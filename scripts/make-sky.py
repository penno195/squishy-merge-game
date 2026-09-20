#!/usr/bin/env python3
"""Draws a skybox: a big top seen from the inside, or a night sky.

Every face is computed from the direction each pixel looks along rather than
drawn as a picture, which is what makes the six of them line up: a stripe is
decided by the compass bearing of the ray, so it continues across a face edge
because both sides are asking the same question. The stripes converge overhead
because that is what bearings do at the zenith, so the tent gets its peak for
free.

The night sky is seamless for the same reason by a different route: the stars
are points in space, so each one is projected onto whichever faces it falls on
rather than drawn per-face, and a star sitting on an edge lands on both sides of
it at the same place.

Run with a Pillow on PYTHONPATH:
    PYTHONPATH=<dir with PIL> python3 scripts/make-sky.py <out dir> [tent|night]
"""
import math
import os
import random
import sys
from PIL import Image

SIZE = 512
GORES = 24
CANVAS_A = (243, 170, 205)
CANVAS_B = (255, 248, 246)
# The canvas darkens towards the eaves the way real canvas does, because the
# light comes in at the peak and from under the hem, not through the middle.
SHADE_AT_HORIZON = 0.72
# A band of bunting round the eaves, hiding the join between tent and ground.
BUNTING = (255, 214, 92)
BUNTING_LOW, BUNTING_HIGH = -0.06, 0.02

# Roblox's faces, and the direction a pixel in each one looks along. u and v run
# -1..1 left to right and top to bottom.
FACES = {
    "Rt": lambda u, v: (1.0, -v, -u),
    "Lf": lambda u, v: (-1.0, -v, u),
    "Up": lambda u, v: (u, 1.0, v),
    "Dn": lambda u, v: (u, -1.0, -v),
    "Ft": lambda u, v: (u, -v, -1.0),
    "Bk": lambda u, v: (-u, -v, 1.0),
}


def colour(d):
    x, y, z = d
    length = math.sqrt(x * x + y * y + z * z)
    x, y, z = x / length, y / length, z / length

    # Height up the dome, 0 at the horizon and 1 at the peak.
    up = max(0.0, y)

    if BUNTING_LOW < y < BUNTING_HIGH:
        return BUNTING

    bearing = math.atan2(z, x)
    gore = int((bearing + math.pi) / (2 * math.pi) * GORES) % 2
    base = CANVAS_A if gore == 0 else CANVAS_B

    # Dark at the eaves, full colour at the peak, and a soft glow right at the
    # crown where the light comes in.
    shade = SHADE_AT_HORIZON + (1 - SHADE_AT_HORIZON) * (up ** 0.55)
    glow = max(0.0, (up - 0.93) / 0.07) * 0.35
    return tuple(min(255, round(c * shade + (255 - c * shade) * glow)) for c in base)


# --- night ---------------------------------------------------------------
NIGHT_ZENITH = (14, 12, 38)
NIGHT_HORIZON = (72, 44, 96)
# A wash of colour along the horizon, so the candy carries on after dark.
NIGHT_GLOW = (150, 80, 130)
STARS = 1500
MOON_DIR = (0.42, 0.46, -0.78)
MOON_RADIUS = 0.055

# Which way each face looks, as the axis it faces and the two directions its u
# and v run along. The same six faces as above, written so a point in space can
# be turned into a pixel rather than the other way round.
BASIS = {
    "Rt": ((1, 0, 0), (0, 0, -1), (0, -1, 0)),
    "Lf": ((-1, 0, 0), (0, 0, 1), (0, -1, 0)),
    "Up": ((0, 1, 0), (1, 0, 0), (0, 0, 1)),
    "Dn": ((0, -1, 0), (1, 0, 0), (0, 0, -1)),
    "Ft": ((0, 0, -1), (1, 0, 0), (0, -1, 0)),
    "Bk": ((0, 0, 1), (-1, 0, 0), (0, -1, 0)),
}


def dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def night_background(d):
    x, y, z = d
    length = math.sqrt(x * x + y * y + z * z)
    y /= length
    t = max(0.0, min(1.0, (y + 0.25) / 1.25))
    base = tuple(NIGHT_HORIZON[i] + (NIGHT_ZENITH[i] - NIGHT_HORIZON[i]) * (t ** 0.8) for i in range(3))
    # The glow sits in a band just above the horizon and fades out of it.
    glow = max(0.0, 1 - abs(y - 0.02) / 0.3) ** 2 * 0.55
    return tuple(min(255, round(base[i] + (NIGHT_GLOW[i] - base[i]) * glow)) for i in range(3))


def place(image, name, direction, radius, colour, softness=1.0):
    """Put a round thing in the sky, on whichever face it falls on."""
    axis, u_dir, v_dir = BASIS[name]
    length = math.sqrt(dot(direction, direction))
    d = tuple(c / length for c in direction)
    towards = dot(d, axis)
    if towards <= 0.05:
        return
    point = tuple(c / towards for c in d)
    u, v = dot(point, u_dir), dot(point, v_dir)
    # A margin, so anything overlapping an edge is drawn on both sides of it.
    reach = radius / towards * 2 + 0.02
    if abs(u) > 1 + reach or abs(v) > 1 + reach:
        return
    cx, cy = (u + 1) / 2 * SIZE, (v + 1) / 2 * SIZE
    px_radius = max(0.6, radius / towards * SIZE / 2)
    px = image.load()
    lo_x, hi_x = int(cx - px_radius - 1), int(cx + px_radius + 2)
    lo_y, hi_y = int(cy - px_radius - 1), int(cy + px_radius + 2)
    for j in range(max(0, lo_y), min(SIZE, hi_y)):
        for i in range(max(0, lo_x), min(SIZE, hi_x)):
            dist = math.hypot(i + 0.5 - cx, j + 0.5 - cy) / px_radius
            if dist > 1:
                continue
            alpha = (1 - dist) ** softness
            under = px[i, j]
            px[i, j] = tuple(min(255, round(under[k] + (colour[k] - under[k]) * alpha)) for k in range(3))


def night_face(name, out_dir):
    fn = FACES[name]
    image = Image.new("RGB", (SIZE, SIZE))
    px = image.load()
    for j in range(SIZE):
        v = (j + 0.5) / SIZE * 2 - 1
        for i in range(SIZE):
            u = (i + 0.5) / SIZE * 2 - 1
            px[i, j] = night_background(fn(u, v))

    # Fixed seed: the six faces are drawn in six passes and every one of them
    # has to agree about where the stars are.
    rng = random.Random(20260920)
    for _ in range(STARS):
        while True:
            d = (rng.gauss(0, 1), rng.gauss(0, 1), rng.gauss(0, 1))
            if dot(d, d) > 1e-6:
                break
        # Thinner towards the ground, where the wall and the scenery cover it.
        length = math.sqrt(dot(d, d))
        if d[1] / length < -0.15 and rng.random() < 0.8:
            continue
        size = rng.choice((0.0022, 0.0026, 0.0032, 0.0040, 0.0055))
        warmth = rng.random()
        tint = (255, 250, 245) if warmth < 0.6 else ((215, 225, 255) if warmth < 0.85 else (255, 220, 235))
        bright = 0.6 + rng.random() * 0.4
        colour = tuple(round(NIGHT_ZENITH[k] + (tint[k] - NIGHT_ZENITH[k]) * bright) for k in range(3))
        place(image, name, d, size, colour, softness=0.8)

    place(image, name, MOON_DIR, MOON_RADIUS * 2.6, (120, 96, 150), softness=2.6)
    place(image, name, MOON_DIR, MOON_RADIUS, (255, 248, 235), softness=0.35)

    path = os.path.join(out_dir, f"night-sky-{name}.png")
    image.save(path, "PNG")
    return path


def face(name, out_dir):
    fn = FACES[name]
    image = Image.new("RGB", (SIZE, SIZE))
    px = image.load()
    for j in range(SIZE):
        v = (j + 0.5) / SIZE * 2 - 1
        for i in range(SIZE):
            u = (i + 0.5) / SIZE * 2 - 1
            px[i, j] = colour(fn(u, v))
    path = os.path.join(out_dir, f"tent-sky-{name}.png")
    image.save(path, "PNG")
    return path


def main(out_dir, style):
    os.makedirs(out_dir, exist_ok=True)
    draw = night_face if style == "night" else face
    for name in FACES:
        print("wrote", draw(name, out_dir))


if __name__ == "__main__":
    main(
        sys.argv[1] if len(sys.argv) > 1 else ".",
        sys.argv[2] if len(sys.argv) > 2 else "tent",
    )
