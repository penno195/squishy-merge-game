#!/usr/bin/env python3
"""Turn a Meshy AI texture into one Roblox will actually take.

Meshy hands you a file named `.png` that is really a **WebP**, 2048 square,
with the unused parts of the UV atlas left transparent over black. Roblox
rejects WebP, caps textures at 1024, and mipmaps the atlas -- so that black
bleeds out of the padding and rims every UV island with a dark halo.

So: decode, dilate the island colours out into the padding, drop the alpha,
resize, write a real PNG.

    python3 scripts/prep-texture.py assets/source/Thing/Thing.webp

Needs Pillow, which this machine has no pip for. Fetch the wheel and unzip it
with Python the same way tests/README.md does for the Luau binary:

    curl -sSfL -o /tmp/pillow.whl <the cp314 manylinux x86_64 wheel from PyPI>
    python3 -c "import zipfile; zipfile.ZipFile('/tmp/pillow.whl').extractall('/tmp/py')"
    PYTHONPATH=/tmp/py python3 scripts/prep-texture.py ...
"""

import sys
from pathlib import Path

from PIL import Image, ImageFilter

SIZE = 1024
# Padding pixels to fill. Enough that the lowest mip a prop is ever seen at
# still samples island colour rather than padding.
DILATE = 24


def dilate(im: Image.Image) -> Image.Image:
    """Grow the opaque colours outward over the transparent padding.

    The padding is black, i.e. the minimum in every channel, so a max filter
    pulls the neighbouring island colour into it. Only transparent pixels are
    ever written back, so the islands themselves come through untouched.
    """
    rgb, alpha = im.convert("RGB"), im.getchannel("A")
    for _ in range(DILATE):
        grown = rgb.filter(ImageFilter.MaxFilter(3))
        rgb = Image.composite(rgb, grown, alpha)
        alpha = alpha.filter(ImageFilter.MaxFilter(3))
    return rgb


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__)
        return 2
    src = Path(sys.argv[1])
    im = Image.open(src)
    print(f"{src.name}: {im.format} {im.size[0]}x{im.size[1]} {im.mode}")

    if im.mode == "RGBA":
        im = dilate(im)
    else:
        im = im.convert("RGB")
    if im.size != (SIZE, SIZE):
        im = im.resize((SIZE, SIZE), Image.LANCZOS)

    out = src.with_suffix(".png")
    im.save(out, "PNG", optimize=True)
    print(f"-> {out.name}: PNG {SIZE}x{SIZE} RGB, {out.stat().st_size // 1024} KB")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
