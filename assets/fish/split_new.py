"""Dev-only: cuts the 1.8 Gemini sticker sheets (raw_sheets/sheetN1..N5.jpg) into one transparent
PNG per new species at assets/fish/<id>.png. Plain-white sheets (N1, N2, N4) reuse
split_sheets.py; sheets drawn as stickers on a white card (N3, N5) are cut quadrant by quadrant
with split_female's sticker-outline removal, taking the biggest blob of each quadrant.
"""
import os
import sys
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import split_sheets as plain
import split_female as sticker

MAX_DIM = 480

PLAIN = {
    "sheetN1": ["peacock_cichlid", "red_zebra_cichlid", "frontosa", "silver_arowana"],
    "sheetN2": ["ocellate_stingray", "pea_puffer", "golden_wonder_killifish", "blue_gularis_killifish"],
    "sheetN4": ["porcupine_puffer", "dogface_puffer", "maxima_clam", "sally_lightfoot_crab"],
}
# sheet -> (card interior crop, [top-left, top-right, bottom-left, bottom-right])
CARDS = {
    "sheetN3": ((80, 215, 955, 850), ["red_tailed_shark", "rainbow_shark", "clown_loach", "blue_crayfish"]),
    "sheetN5": ((24, 20, 975, 995), ["koi", "comet_goldfish", "shubunkin", "golden_orfe"]),
}
# drawn facing left though asked for right; the game wants everything facing right
FLIP = {"silver_arowana", "pea_puffer", "golden_wonder_killifish", "blue_gularis_killifish", "blue_crayfish"}


def biggest_blob(img):
    labels, blobs = sticker.label_blobs(img)
    best = max(range(1, len(blobs)), key=lambda i: blobs[i]["area"])
    x0, y0, x1, y1 = blobs[best]["box"]
    pad = 10
    out = Image.new("RGBA", (x1 - x0 + 1 + pad * 2, y1 - y0 + 1 + pad * 2), (255, 255, 255, 0))
    dst = out.load()
    src = img.load()
    w = img.width
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if labels[y * w + x] == best:
                dst[x - x0 + pad, y - y0 + pad] = src[x, y]
    return out


def save(sprite, species_id):
    scale = MAX_DIM / max(sprite.width, sprite.height)
    sprite = sprite.resize((max(1, round(sprite.width * scale)), max(1, round(sprite.height * scale))), Image.LANCZOS)
    if species_id in FLIP:
        sprite = sprite.transpose(Image.FLIP_LEFT_RIGHT)
    sprite.save(os.path.join(HERE, species_id + ".png"), "PNG")
    print(f"{species_id}.png {sprite.width}x{sprite.height}")


def do_plain():
    plain.FLIP.update(FLIP)
    for sheet, ids in PLAIN.items():
        plain.split_sheet(sheet, ids)


def do_cards():
    for sheet, (box, ids) in CARDS.items():
        card = Image.open(os.path.join(HERE, "raw_sheets", sheet + ".jpg")).convert("RGB").crop(box)
        w, h = card.size
        margin = 14
        quads = [(0, 0), (w // 2, 0), (0, h // 2), (w // 2, h // 2)]
        for (qx, qy), species_id in zip(quads, ids):
            part = card.crop((qx + margin, qy + margin, qx + w // 2 - margin, qy + h // 2 - margin))
            save(biggest_blob(sticker.remove_sticker_background(part)), species_id)


if __name__ == "__main__":
    do_plain()
    do_cards()
    names = [n for ids in PLAIN.values() for n in ids] + [n for _, ids in CARDS.values() for n in ids]
    cell = 260
    sheet = Image.new("RGB", (cell * 5, cell * 4), (40, 110, 150))
    for i, n in enumerate(names):
        s = Image.open(os.path.join(HERE, n + ".png"))
        s.thumbnail((cell - 10, cell - 10))
        sheet.paste(s, ((i % 5) * cell + 5, (i // 5) * cell + 5), s)
    sheet.save(os.path.join(HERE, "..", "..", "builds", "new_species_check.png"))
