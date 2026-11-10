"""Dev-only one-off script: turns the raw Gemini-generated JPGs (assets/fish/raw/*.jpg,
white background) into transparent, cropped PNG sprites the game loads at
res://assets/fish/<species_id>.png. Not part of the game's runtime.
"""
import os
from PIL import Image

RAW_DIR = os.path.join(os.path.dirname(__file__), "raw")
OUT_DIR = os.path.dirname(__file__)
MAX_DIM = 480
WHITE_THRESHOLD = 235  # a pixel this close to white (on all channels) counts as background
FEATHER = 30  # soft alpha falloff band just inside the threshold, to avoid a hard cutout edge


def remove_white_background(img: Image.Image) -> Image.Image:
    img = img.convert("RGBA")
    w, h = img.size
    px = img.load()

    # Flood fill from the four edges only, so white PIXELS INSIDE the fish
    # (e.g. clownfish bands, shrimp antennae) are never touched.
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
        # distance from pure white controls alpha, so the fish's own edge anti-aliasing
        # (pixels blended toward white) fades out smoothly instead of leaving a white fringe.
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


def main():
    for fname in sorted(os.listdir(RAW_DIR)):
        if not fname.lower().endswith((".jpg", ".jpeg", ".png")):
            continue
        species_id = os.path.splitext(fname)[0]
        src_path = os.path.join(RAW_DIR, fname)
        img = Image.open(src_path)
        img = remove_white_background(img)
        img = crop_to_content(img)
        img = downscale(img, MAX_DIM)
        out_path = os.path.join(OUT_DIR, f"{species_id}.png")
        img.save(out_path, "PNG")
        print(f"{species_id}: {img.width}x{img.height} -> {out_path}")


if __name__ == "__main__":
    main()
