"""Dev-only: cuts Gemini "sticker sheets" of FEMALE fish (raw_sheets/sheetF*.jpg, a white card
with four stickers) into one transparent PNG per fish at assets/fish/<species_id>_f.png.

Unlike split_sheets.py these stickers have a white border and a thin grey outline, which is
removed too: flood the plain white outside, grow that by a few pixels to swallow the outline,
then flood the white ring that was inside the outline up to the animal's own edge.
"""
import os
import sys
from collections import deque
from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
MAX_DIM = 480
WHITE = 236

# sheet -> (crop box of the card interior, [top-left, top-right, bottom-left, bottom-right])
SHEETS = {
    "sheetF1": ((66, 148, 960, 852), ["guppy", "swordtail", "betta", "molly"]),
    "sheetF2": ((66, 148, 960, 852), ["platy", "ram_cichlid", "boesemani_rainbowfish", "yellow_lab_cichlid"]),
}


def remove_sticker_background(img):
    img = img.convert("RGB")
    w, h = img.size
    data = img.tobytes()
    bright = [min(data[i], data[i + 1], data[i + 2]) for i in range(0, len(data), 3)]
    bg = bytearray(w * h)

    def flood(seeds):
        queue = deque(seeds)
        for idx in seeds:
            bg[idx] = 1
        while queue:
            idx = queue.popleft()
            x, y = idx % w, idx // w
            for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if 0 <= nx < w and 0 <= ny < h:
                    n = ny * w + nx
                    if not bg[n] and bright[n] >= WHITE:
                        bg[n] = 1
                        queue.append(n)

    border = [x for x in range(w)] + [(h - 1) * w + x for x in range(w)] + [y * w for y in range(h)] + [y * w + w - 1 for y in range(h)]
    flood([i for i in border if bright[i] >= WHITE])
    # grow the white outside a few pixels so the thin grey outline of the sticker is swallowed
    frontier = [i for i in range(w * h) if bg[i]]
    grown = bytearray(bg)
    layer = frontier
    for _ in range(4):
        nxt = []
        for idx in layer:
            x, y = idx % w, idx // w
            for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if 0 <= nx < w and 0 <= ny < h:
                    n = ny * w + nx
                    if not grown[n]:
                        grown[n] = 1
                        nxt.append(n)
        layer = nxt
    bg[:] = grown
    flood([i for i in range(w * h) if bg[i]])
    alpha = Image.frombytes("L", (w, h), bytes(0 if bg[i] else 255 for i in range(w * h)))
    alpha = alpha.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.8))
    out = img.convert("RGBA")
    out.putalpha(alpha)
    return out


def label_blobs(img):
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
                x0, x1, y0, y1 = min(x0, x), max(x1, x), min(y0, y), max(y1, y)
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if 0 <= nx < w and 0 <= ny < h and not labels[ny * w + nx] and alpha[nx, ny] >= 40:
                        labels[ny * w + nx] = label
                        queue.append((nx, ny))
            blobs.append({"area": area, "box": (x0, y0, x1, y1), "cx": sum_x / area, "cy": sum_y / area})
    return labels, blobs


def split(sheet):
    box, ids = SHEETS[sheet]
    img = remove_sticker_background(Image.open(os.path.join(HERE, "raw_sheets", sheet + ".jpg")).crop(box))
    w, h = img.size
    labels, blobs = label_blobs(img)
    order = sorted(range(1, len(blobs)), key=lambda i: -blobs[i]["area"])[:4]
    quarter = lambda i: (1 if blobs[i]["cx"] > w / 2 else 0) + (2 if blobs[i]["cy"] > h / 2 else 0)
    by_quarter = {quarter(i): i for i in order}
    if len(by_quarter) != 4:
        print("!! animals did not land one per quarter", [quarter(i) for i in order])
        return
    src = img.load()
    for q, species_id in enumerate(ids):
        b = blobs[by_quarter[q]]
        x0, y0, x1, y1 = b["box"]
        pad = 10
        out = Image.new("RGBA", (x1 - x0 + 1 + pad * 2, y1 - y0 + 1 + pad * 2), (255, 255, 255, 0))
        dst = out.load()
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                if labels[y * w + x] == by_quarter[q]:
                    dst[x - x0 + pad, y - y0 + pad] = src[x, y]
        scale = MAX_DIM / max(out.width, out.height)
        out = out.resize((round(out.width * scale), round(out.height * scale)), Image.LANCZOS)
        out.save(os.path.join(HERE, species_id + "_f.png"), "PNG")
        print(f"{sheet} q{q} -> {species_id}_f.png {out.width}x{out.height}")


if __name__ == "__main__":
    for name in (sys.argv[1:] or SHEETS.keys()):
        split(name)
