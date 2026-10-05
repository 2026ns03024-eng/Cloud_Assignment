#!/usr/bin/env python3
"""Render a terminal transcript as a PNG for assignment proof."""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


def main() -> None:
    if len(sys.argv) != 3:
        print("usage: terminal_to_png.py input.txt output.png", file=sys.stderr)
        sys.exit(1)
    text = Path(sys.argv[1]).read_text(encoding="utf-8")
    out = Path(sys.argv[2])

    font_size = 14
    try:
        font = ImageFont.truetype("/System/Library/Fonts/Menlo.ttc", font_size)
    except OSError:
        font = ImageFont.load_default()

    lines = text.splitlines() or [""]
    line_height = font_size + 4
    padding = 16
    max_width = max(font.getlength(line) for line in lines) if lines else 200
    width = int(max_width) + padding * 2
    height = line_height * len(lines) + padding * 2

    img = Image.new("RGB", (width, height), (28, 28, 28))
    draw = ImageDraw.Draw(img)
    y = padding
    for line in lines:
        draw.text((padding, y), line, fill=(220, 220, 220), font=font)
        y += line_height

    out.parent.mkdir(parents=True, exist_ok=True)
    img.save(out)
    print(out)


if __name__ == "__main__":
    main()
