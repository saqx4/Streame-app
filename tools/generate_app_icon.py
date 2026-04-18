from __future__ import annotations

import math
import os
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "assets" / "icon"
OUT_PNG = OUT_DIR / "icon.png"


def _lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def _lerp_color(c1: tuple[int, int, int], c2: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    return (
        int(_lerp(c1[0], c2[0], t)),
        int(_lerp(c1[1], c2[1], t)),
        int(_lerp(c1[2], c2[2], t)),
    )


def _radial_gradient(size: int, inner: tuple[int, int, int], outer: tuple[int, int, int]) -> Image.Image:
    img = Image.new("RGB", (size, size), outer)
    px = img.load()

    cx = size * 0.35
    cy = size * 0.25
    max_r = math.sqrt((size - cx) ** 2 + (size - cy) ** 2)

    for y in range(size):
        for x in range(size):
            r = math.sqrt((x - cx) ** 2 + (y - cy) ** 2)
            t = min(1.0, r / max_r)
            px[x, y] = _lerp_color(inner, outer, t)

    return img


def _rounded_mask(size: int, radius: int) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size - 1, size - 1), radius=radius, fill=255)
    return mask


def _drop_shadow(alpha: Image.Image, blur: float, offset: tuple[int, int], color: tuple[int, int, int, int]) -> Image.Image:
    sh = Image.new("RGBA", alpha.size, (0, 0, 0, 0))
    sh.putalpha(alpha)
    sh = sh.filter(ImageFilter.GaussianBlur(radius=blur))
    colored = Image.new("RGBA", alpha.size, color)
    colored.putalpha(sh.split()[-1])
    out = Image.new("RGBA", alpha.size, (0, 0, 0, 0))
    out.alpha_composite(colored, offset)
    return out


def _draw_play_filled(size: int) -> Image.Image:
    glyph = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(glyph)

    cx = size * 0.52
    cy = size * 0.52
    s = size * 0.34

    p1 = (cx - s * 0.55, cy - s * 0.70)
    p2 = (cx - s * 0.55, cy + s * 0.70)
    p3 = (cx + s * 0.78, cy)
    d.polygon([p1, p2, p3], fill=(247, 245, 255, 255))

    alpha = glyph.split()[-1]
    shadow = _drop_shadow(
        alpha,
        blur=size * 0.020,
        offset=(int(size * 0.01), int(size * 0.02)),
        color=(0, 0, 0, 120),
    )

    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.alpha_composite(shadow)
    out.alpha_composite(glyph)
    return out


def _draw_streame_s(size: int) -> Image.Image:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    w = int(size * 0.11)
    pad = size * 0.28

    top = (pad, size * 0.24, size - pad, size * 0.56)
    bot = (pad, size * 0.44, size - pad, size * 0.76)

    d.arc(top, start=200, end=20, fill=(247, 245, 255, 255), width=w)
    d.arc(bot, start=20, end=200, fill=(247, 245, 255, 255), width=w)
    d.line(
        [(size * 0.64, size * 0.44), (size * 0.36, size * 0.56)],
        fill=(247, 245, 255, 255),
        width=w,
    )

    alpha = img.split()[-1]
    shadow = _drop_shadow(
        alpha,
        blur=size * 0.018,
        offset=(int(size * 0.008), int(size * 0.018)),
        color=(0, 0, 0, 110),
    )
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.alpha_composite(shadow)
    out.alpha_composite(img)
    return out


def _draw_film_frame(size: int) -> Image.Image:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    margin = int(size * 0.26)
    frame = (margin, margin, size - margin, size - margin)
    r = int(size * 0.07)

    d.rounded_rectangle(frame, radius=r, outline=(247, 245, 255, 255), width=int(size * 0.06))

    hole_r = int(size * 0.018)
    hole_x1 = margin + int(size * 0.05)
    hole_x2 = size - margin - int(size * 0.05)
    for y in [margin + int(size * 0.10), size - margin - int(size * 0.10)]:
        d.ellipse((hole_x1 - hole_r, y - hole_r, hole_x1 + hole_r, y + hole_r), fill=(247, 245, 255, 255))
        d.ellipse((hole_x2 - hole_r, y - hole_r, hole_x2 + hole_r, y + hole_r), fill=(247, 245, 255, 255))

    alpha = img.split()[-1]
    shadow = _drop_shadow(
        alpha,
        blur=size * 0.018,
        offset=(int(size * 0.008), int(size * 0.018)),
        color=(0, 0, 0, 110),
    )
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.alpha_composite(shadow)
    out.alpha_composite(img)
    return out


def _base_bg(size: int) -> Image.Image:
    bg = _radial_gradient(size, inner=(166, 92, 255), outer=(12, 10, 24)).convert("RGBA")
    sheen = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    sd = ImageDraw.Draw(sheen)
    sd.ellipse(
        (
            int(size * -0.15),
            int(size * -0.25),
            int(size * 0.95),
            int(size * 0.65),
        ),
        fill=(255, 255, 255, 22),
    )
    sheen = sheen.filter(ImageFilter.GaussianBlur(radius=size * 0.06))
    bg.alpha_composite(sheen)
    return bg


def generate(option: int, size: int = 1024) -> Image.Image:
    bg = _base_bg(size)

    if option == 1:
        glyph = _draw_play_filled(size)
    elif option == 2:
        glyph = _draw_streame_s(size)
    elif option == 3:
        glyph = _draw_film_frame(size)
    else:
        raise ValueError("option must be 1, 2, or 3")

    bg.alpha_composite(glyph)

    mask = _rounded_mask(size, radius=int(size * 0.24))
    bg.putalpha(mask)

    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.alpha_composite(bg)
    return canvas


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    option_files = {
        1: OUT_DIR / "icon_option_1_minimal_play.png",
        2: OUT_DIR / "icon_option_2_streame_s.png",
        3: OUT_DIR / "icon_option_3_film_frame.png",
    }

    for opt, path in option_files.items():
        img = generate(opt, 1024)
        img.save(path, format="PNG", optimize=True)
        print(f"Wrote: {path.relative_to(ROOT)}")

    selected = int(os.environ.get("STREAME_ICON_OPTION", "1"))
    img = generate(selected, 1024)
    img.save(OUT_PNG, format="PNG", optimize=True)
    print(f"Selected option {selected} -> {OUT_PNG.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
