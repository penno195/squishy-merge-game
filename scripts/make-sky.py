#!/usr/bin/env python3
"""Draws a skybox that puts the whole map inside an enormous big top.

Every face is computed from the direction each pixel looks along rather than
drawn as a picture, which is what makes the six of them line up: a stripe is
decided by the compass bearing of the ray, so it continues across a face edge
because both sides are asking the same question. The stripes converge overhead
because that is what bearings do at the zenith, so the tent gets its peak for
free.

Run with a Pillow on PYTHONPATH:
    PYTHONPATH=<dir with PIL> python3 scripts/make-sky.py <out dir>
"""
import math
import os
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


def main(out_dir):
    os.makedirs(out_dir, exist_ok=True)
    for name in FACES:
        print("wrote", face(name, out_dir))


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else ".")
