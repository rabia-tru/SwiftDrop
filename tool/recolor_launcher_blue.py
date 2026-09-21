"""Recolor SwiftDrop launcher PNGs from the legacy orange palette to blue.

Reads the ORIGINAL legacy ic_launcher.png raster (orange palette + white
artwork), hue-rotates all opaque pixels into the blue family, and writes the
blue result to:
  - mipmap-*/ic_launcher.png          (full-bleed blue raster)
  - mipmap-*/ic_launcher_round.png    (transparent outside the mask circle)

Originals are preserved in tool/_launcher_orange_backup/.
"""
import os
import shutil
import colorsys

from PIL import Image

RES = os.path.join("android", "app", "src", "main", "res")
BACKUP = os.path.join("tool", "_launcher_orange_backup")

# Original legacy orange tones (from the source raster) -> mapped by hue.
# White artwork (S/V ~ 1.0/1.0, H near 0 with high lightness) is preserved.
HUE_ORANGE = 26.0   # degrees, legacy brand tone
HUE_BLUE = 210.0    # degrees, new brand tone

DENSITIES = {
    "mdpi": 48,
    "hdpi": 72,
    "xhdpi": 96,
    "xxhdpi": 144,
    "xxxhdpi": 192,
}


def is_orange(hue_deg: float) -> bool:
    # Orange hues wrap around 0/360, accept 345..375 and 0..60
    return hue_deg >= 345 or hue_deg <= 60


def recolor(im: Image.Image) -> Image.Image:
    im = im.convert("RGBA")
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            hh, ss, vv = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
            hue = hh * 360.0
            if is_orange(hue):
                # Shift orange hues into blue; yellows become cyan-blue so
                # mid-tones stay saturated instead of going muddy.
                if hue <= 60:
                    delta = (60.0 - hue) / 60.0  # 1 at red, 0 at yellow
                    new_hue = 260.0 + 50.0 * delta  # 260 (violet-blue)..210
                else:
                    delta = (hue - 345.0) / 15.0   # 0 at 345, 1 at 360
                    new_hue = 260.0 + 50.0 * delta
                # Floor on value so deep oranges don't collapse to black
                vv = max(vv, 0.55)
                nr, ng, nb = colorsys.hsv_to_rgb(new_hue / 360.0, ss, vv)
                px[x, y] = (
                    round(nr * 255.0),
                    round(ng * 255.0),
                    round(nb * 255.0),
                    a,
                )
    return im


def main() -> None:
    os.makedirs(BACKUP, exist_ok=True)

    src = os.path.join(RES, "mipmap-xxxhdpi", "ic_launcher.png")
    base = Image.open(src)

    for density, size in DENSITIES.items():
        d = os.path.join(RES, f"mipmap-{density}")
        os.makedirs(d, exist_ok=True)

        # Back up originals once
        for name in ("ic_launcher.png", "ic_launcher_round.png"):
            bak = os.path.join(BACKUP, f"{density}-{name}")
            if not os.path.exists(bak):
                shutil.copy2(os.path.join(d, name), bak)

        im = base.resize((size, size), Image.LANCZOS)
        blue = recolor(im)

        # Full-bleed raster for the square launcher icon
        blue.save(os.path.join(d, "ic_launcher.png"))

        # Round variant: transparent outside the mask circle
        round_im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        mask = Image.new("L", (size, size), 0)
        mpx = mask.load()
        cx = cy = size / 2.0
        rad = size * (80.0 / 192.0)
        for yy in range(size):
            for xx in range(size):
                dx = xx + 0.5 - cx
                dy = yy + 0.5 - cy
                dist2 = dx * dx + dy * dy
                if dist2 <= rad * rad:
                    mpx[xx, yy] = 255
        round_im.paste(blue, (0, 0), mask)
        round_im.save(os.path.join(d, "ic_launcher_round.png"))

        print(f"wrote mipmap-{density} ({size}px)")


if __name__ == "__main__":
    main()
