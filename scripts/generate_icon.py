#!/usr/bin/env python3
"""Generate 1024x1024 app icon for Chinese Character Writing Practice.

Concept: Warm orange gradient background with faint rice-grid (米字格)
guidelines and the character 写 ("to write") rendered in bold white serif.
"""

from PIL import Image, ImageDraw, ImageFont

SIZE = 1024


def lerp_color(c1, c2, t):
    """Linearly interpolate between two RGB colors."""
    return tuple(int(a + (b - a) * t) for a, b in zip(c1, c2))


def make_gradient():
    """Create warm orange gradient background."""
    img = Image.new("RGBA", (SIZE, SIZE))
    draw = ImageDraw.Draw(img)
    top = (255, 149, 0)
    bottom = (255, 94, 58)
    for y in range(SIZE):
        color = lerp_color(top, bottom, y / SIZE)
        draw.line([(0, y), (SIZE, y)], fill=(*color, 255))
    return img


def make_grid():
    """Draw rice-grid (米字格) on a transparent layer for proper alpha compositing."""
    layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)

    cx, cy = SIZE // 2, SIZE // 2
    margin = 140
    line_color = (255, 255, 255, 255)  # white, full alpha — we'll blend the whole layer

    # Outer square
    draw.rectangle([(margin, margin), (SIZE - margin, SIZE - margin)],
                   outline=line_color, width=2)
    # Cross
    draw.line([(margin, cy), (SIZE - margin, cy)], fill=line_color, width=2)
    draw.line([(cx, margin), (cx, SIZE - margin)], fill=line_color, width=2)
    # Diagonals
    draw.line([(margin, margin), (SIZE - margin, SIZE - margin)], fill=line_color, width=2)
    draw.line([(SIZE - margin, margin), (margin, SIZE - margin)], fill=line_color, width=2)

    # Reduce layer opacity to make grid very subtle
    layer.putalpha(layer.getchannel("A").point(lambda a: int(a * 0.12)))
    return layer


def make_character():
    """Draw 写 on a transparent layer."""
    layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)

    fonts_to_try = [
        "/usr/share/fonts/opentype/noto/NotoSerifCJK-Bold.ttc",
        "/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc",
        "/usr/share/fonts/noto-cjk/NotoSansCJK-Bold.ttc",
    ]

    font = None
    for path in fonts_to_try:
        try:
            font = ImageFont.truetype(path, 580)
            break
        except (OSError, IOError):
            continue

    if font is None:
        print("Warning: No CJK font found")
        return layer

    char = "\u5199"  # 写
    bbox = draw.textbbox((0, 0), char, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    x = (SIZE - tw) // 2 - bbox[0]
    y = (SIZE - th) // 2 - bbox[1] + 10

    # Warm-toned shadow
    draw.text((x + 4, y + 4), char, fill=(120, 40, 10, 70), font=font)
    # White character
    draw.text((x, y), char, fill=(255, 255, 255, 255), font=font)

    return layer


def main():
    bg = make_gradient()
    grid = make_grid()
    char = make_character()

    # Composite layers
    img = Image.alpha_composite(bg, grid)
    img = Image.alpha_composite(img, char)

    # iOS icons must be opaque RGB
    rgb = img.convert("RGB")
    out = "ChineseWriting/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
    rgb.save(out, "PNG")
    print(f"Saved icon to {out}")


if __name__ == "__main__":
    main()
