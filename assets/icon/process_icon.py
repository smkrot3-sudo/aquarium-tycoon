"""Dev-only one-off script: turns the raw Gemini-generated app icon JPG (icon/raw/app_icon.jpg,
a rounded-blue-square composition on a white canvas) into the three icon files Godot's Android
export expects: a flattened main icon, and adaptive foreground/background layers.
"""
import os
from PIL import Image, ImageDraw

HERE = os.path.dirname(__file__)
WHITE_THRESHOLD = 235


def crop_to_content(img: Image.Image, padding: int = 2) -> Image.Image:
    img = img.convert("RGB")
    # Find the bounding box of non-white content by diffing against pure white.
    gray = img.convert("L")
    mask = gray.point(lambda p: 255 if p < WHITE_THRESHOLD else 0)
    bbox = mask.getbbox()
    if bbox is None:
        return img
    left, top, right, bottom = bbox
    left = max(0, left - padding)
    top = max(0, top - padding)
    right = min(img.width, right + padding)
    bottom = min(img.height, bottom + padding)
    # Force a square crop (centered) so the icon isn't stretched when resized.
    w, h = right - left, bottom - top
    size = max(w, h)
    cx, cy = (left + right) // 2, (top + bottom) // 2
    half = size // 2
    left, right = max(0, cx - half), min(img.width, cx + half)
    top, bottom = max(0, cy - half), min(img.height, cy + half)
    return img.crop((left, top, right, bottom))


def make_gradient_background(size: int, top_color, bottom_color) -> Image.Image:
    img = Image.new("RGB", (size, size))
    draw = ImageDraw.Draw(img)
    for y in range(size):
        t = y / max(size - 1, 1)
        r = round(top_color[0] + (bottom_color[0] - top_color[0]) * t)
        g = round(top_color[1] + (bottom_color[1] - top_color[1]) * t)
        b = round(top_color[2] + (bottom_color[2] - top_color[2]) * t)
        draw.line([(0, y), (size, y)], fill=(r, g, b))
    return img


def main():
    raw_path = os.path.join(HERE, "raw", "app_icon.jpg")
    img = Image.open(raw_path)
    content = crop_to_content(img)

    main_icon = content.resize((192, 192), Image.LANCZOS)
    main_icon.save(os.path.join(HERE, "main_192.png"))

    foreground = content.resize((432, 432), Image.LANCZOS)
    foreground.save(os.path.join(HERE, "adaptive_foreground_432.png"))

    background = make_gradient_background(432, (120, 210, 240), (20, 120, 200))
    background.save(os.path.join(HERE, "adaptive_background_432.png"))

    print("Wrote main_192.png, adaptive_foreground_432.png, adaptive_background_432.png")


if __name__ == "__main__":
    main()
