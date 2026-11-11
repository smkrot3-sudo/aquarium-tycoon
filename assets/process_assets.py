"""Dev-only one-off script: turns raw Gemini-generated JPGs (<category>/raw/*.jpg, white
background) into transparent, cropped PNG sprites the game loads at
res://assets/<category>/<id>.png. Not part of the game's runtime. Generalized version of
fish/process_sprites.py, usable for decor/equipment/food too.
"""
import os
import sys
from PIL import Image

HERE = os.path.dirname(__file__)
WHITE_THRESHOLD = 235  # a pixel this close to white (on all channels) counts as background
FEATHER = 30  # soft alpha falloff band just inside the threshold, avoids a hard cutout edge


def remove_white_background(img: Image.Image) -> Image.Image:
    img = img.convert("RGBA")
    w, h = img.size
    px = img.load()

    # Flood fill from the four edges only, so white PIXELS INSIDE the subject (e.g. a light
    # fixture's glow, food flake highlights) are never touched.
    visited = bytearray(w * h)
    stack = []
    for x in range(w):
        stack.append((x, 0))
        stack.append((x, h - 1))
    for y in range(h):
        stack.append((0, y))
        stack.append((w - 1, y))

    def is_bg(r, g, b):
        return r >= WHITE_THRESHOLD and g >= WHITE_THRESHOLD and b >= WHITE_THRESHOLD

    while stack:
        x, y = stack.pop()
        if x < 0 or x >= w or y < 0 or y >= h:
            continue
        idx = y * w + x
        if visited[idx]:
            continue
        r, g, b, a = px[x, y]
        if not is_bg(r, g, b):
            continue
        visited[idx] = 1
        dist = 255 - min(r, g, b)
        alpha = 0 if dist < (255 - WHITE_THRESHOLD) else min(255, int((dist - (255 - WHITE_THRESHOLD)) / FEATHER * 255))
        px[x, y] = (r, g, b, alpha)
        stack.extend([(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)])

    return img


def crop_to_content(img: Image.Image, padding: int = 10) -> Image.Image:
    bbox = img.getbbox()
    if bbox is None:
        return img
    left, top, right, bottom = bbox
    left = max(0, left - padding)
    top = max(0, top - padding)
    right = min(img.width, right + padding)
    bottom = min(img.height, bottom + padding)
    return img.crop((left, top, right, bottom))


def downscale(img: Image.Image, max_dim: int) -> Image.Image:
    scale = max_dim / max(img.width, img.height)
    if scale >= 1:
        return img
    new_size = (round(img.width * scale), round(img.height * scale))
    return img.resize(new_size, Image.LANCZOS)


def process_category(category: str, max_dim: int) -> None:
    raw_dir = os.path.join(HERE, category, "raw")
    out_dir = os.path.join(HERE, category)
    if not os.path.isdir(raw_dir):
        print(f"skip {category}: no raw/ dir")
        return
    for fname in sorted(os.listdir(raw_dir)):
        if not fname.lower().endswith((".jpg", ".jpeg", ".png")):
            continue
        asset_id = os.path.splitext(fname)[0]
        img = Image.open(os.path.join(raw_dir, fname))
        img = remove_white_background(img)
        img = crop_to_content(img)
        img = downscale(img, max_dim)
        out_path = os.path.join(out_dir, f"{asset_id}.png")
        img.save(out_path, "PNG")
        print(f"{category}/{asset_id}: {img.width}x{img.height} -> {out_path}")


if __name__ == "__main__":
    process_category("decor", max_dim=360)
    process_category("equipment", max_dim=256)
    process_category("food", max_dim=200)
