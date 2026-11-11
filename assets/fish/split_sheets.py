"""Dev-only one-off: cuts Gemini-generated 2x2 "sticker sheets" (raw_sheets/sheetN.jpg, four
animals on a white background) into one transparent PNG sprite per species at
res://assets/fish/<species_id>.png. Not part of the game's runtime.

Each sheet is background-removed (flood fill from the image edges, so white inside an animal
survives), split into connected blobs, and the four biggest blobs are matched to the species
list by which quarter of the sheet their centre falls in (top-left, top-right, bottom-left,
bottom-right). Small stray blobs (a detached antenna tip) are attached to the nearest animal.
"""
import os
import sys
from collections import deque
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
WHITE_THRESHOLD = 236
FEATHER = 30
MAX_DIM = 480

# sheet -> [top-left, top-right, bottom-left, bottom-right]
SHEETS = {
    "sheet1": ["angelfish", "discus", "tiger_barb", "swordtail"],
    "sheet2": ["kuhli_loach", "bristlenose_pleco", "pearl_gourami", "goldfish"],
    "sheet3": ["ram_cichlid", "oscar", "amano_shrimp", "mystery_snail"],
    "sheet4": ["boesemani_rainbowfish", "yellow_lab_cichlid", "royal_gramma", "yellow_tang"],
    "sheet5": ["blue_tang", "firefish_goby", "banggai_cardinalfish", "mandarin_dragonet"],
    "sheet6": ["flame_angelfish", "yellow_watchman_goby", "fire_shrimp", "hermit_crab"],
    "sheet7": ["seahorse", "cardinal_tetra", "dwarf_gourami", "lionfish"],
}
# Drawn facing left despite the prompt; the game expects every sprite to face right.
FLIP = {"mystery_snail"}


def remove_white_background(img):
    img = img.convert("RGBA")
    w, h = img.size
    px = img.load()
    visited = bytearray(w * h)
    stack = [(x, 0) for x in range(w)] + [(x, h - 1) for x in range(w)]
    stack += [(0, y) for y in range(h)] + [(w - 1, y) for y in range(h)]
    floor = 255 - WHITE_THRESHOLD
    while stack:
        x, y = stack.pop()
        if x < 0 or x >= w or y < 0 or y >= h:
            continue
        idx = y * w + x
        if visited[idx]:
            continue
        r, g, b, _a = px[x, y]
        if r < WHITE_THRESHOLD or g < WHITE_THRESHOLD or b < WHITE_THRESHOLD:
            continue
        visited[idx] = 1
        dist = 255 - min(r, g, b)
        alpha = 0 if dist < floor else min(255, int((dist - floor) / FEATHER * 255))
        px[x, y] = (r, g, b, alpha)
        stack.extend([(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)])
    return img


def label_blobs(img):
    """Returns (labels bytearray-like list, blobs) where blobs[i] = dict(area, box, cx, cy)."""
    w, h = img.size
    alpha = img.getchannel("A").load()
    labels = [0] * (w * h)
    blobs = [None]
    for sy in range(h):
        for sx in range(w):
            if labels[sy * w + sx] or alpha[sx, sy] < 40:
                continue
            label = len(blobs)
            queue = deque([(sx, sy)])
            labels[sy * w + sx] = label
            area = 0
            sum_x = sum_y = 0
            x0 = x1 = sx
            y0 = y1 = sy
            while queue:
                x, y = queue.popleft()
                area += 1
                sum_x += x
                sum_y += y
                x0 = min(x0, x)
                x1 = max(x1, x)
                y0 = min(y0, y)
                y1 = max(y1, y)
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if 0 <= nx < w and 0 <= ny < h and not labels[ny * w + nx] and alpha[nx, ny] >= 40:
                        labels[ny * w + nx] = label
                        queue.append((nx, ny))
            blobs.append({"area": area, "box": (x0, y0, x1, y1), "cx": sum_x / area, "cy": sum_y / area})
    return labels, blobs


def box_distance(a, b):
    dx = max(a[0] - b[2], b[0] - a[2], 0)
    dy = max(a[1] - b[3], b[1] - a[3], 0)
    return (dx * dx + dy * dy) ** 0.5


def split_sheet(sheet, species_ids):
    path = os.path.join(HERE, "raw_sheets", sheet + ".jpg")
    img = remove_white_background(Image.open(path))
    w, h = img.size
    labels, blobs = label_blobs(img)
    order = sorted(range(1, len(blobs)), key=lambda i: -blobs[i]["area"])
    animals = order[:4]
    owner = {i: i for i in animals}
    for i in order[4:]:
        if blobs[i]["area"] < 12:
            continue
        nearest = min(animals, key=lambda a: box_distance(blobs[i]["box"], blobs[a]["box"]))
        if box_distance(blobs[i]["box"], blobs[nearest]["box"]) <= 30:
            owner[i] = nearest

    def quarter(i):
        return (1 if blobs[i]["cx"] > w / 2 else 0) + (2 if blobs[i]["cy"] > h / 2 else 0)

    by_quarter = {quarter(i): i for i in animals}
    if len(by_quarter) != 4:
        print(f"!! {sheet}: animals did not land one per quarter: {[quarter(i) for i in animals]}")
        return
    src = img.load()
    for q, species_id in enumerate(species_ids):
        animal = by_quarter[q]
        members = [i for i, o in owner.items() if o == animal]
        x0 = min(blobs[i]["box"][0] for i in members)
        y0 = min(blobs[i]["box"][1] for i in members)
        x1 = max(blobs[i]["box"][2] for i in members)
        y1 = max(blobs[i]["box"][3] for i in members)
        pad = 12
        out = Image.new("RGBA", (x1 - x0 + 1 + pad * 2, y1 - y0 + 1 + pad * 2), (255, 255, 255, 0))
        dst = out.load()
        member_set = set(members)
        for y in range(y0, y1 + 1):
            row = y * w
            for x in range(x0, x1 + 1):
                if labels[row + x] in member_set:
                    dst[x - x0 + pad, y - y0 + pad] = src[x, y]
        scale = MAX_DIM / max(out.width, out.height)
        out = out.resize((round(out.width * scale), round(out.height * scale)), Image.LANCZOS)
        if species_id in FLIP:
            out = out.transpose(Image.FLIP_LEFT_RIGHT)
        out.save(os.path.join(HERE, species_id + ".png"), "PNG")
        print(f"{sheet} q{q} -> {species_id}.png {out.width}x{out.height}")


def contact_sheet(out_path):
    ids = [s for names in SHEETS.values() for s in names]
    cell = 240
    cols = 7
    rows = (len(ids) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * cell, rows * cell), (40, 90, 130))
    for n, species_id in enumerate(ids):
        sprite = Image.open(os.path.join(HERE, species_id + ".png"))
        sprite.thumbnail((cell - 16, cell - 16))
        x = (n % cols) * cell + (cell - sprite.width) // 2
        y = (n // cols) * cell + (cell - sprite.height) // 2
        sheet.paste(sprite, (x, y), sprite)
    sheet.save(out_path)


if __name__ == "__main__":
    for sheet_name, names in SHEETS.items():
        split_sheet(sheet_name, names)
    if len(sys.argv) > 1:
        contact_sheet(sys.argv[1])
