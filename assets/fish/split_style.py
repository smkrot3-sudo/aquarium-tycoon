"""Dev-only (1.8.1): cuts the style-unification sheets (raw_sheets/sheetS1..S4.jpg) into the
transparent sprites that replace the old flat-cartoon ones, so every fish shares one painterly
field-guide style. Reuses split_new's helpers."""
import os
import sys
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import split_new as sn
import split_sheets as plain
import split_female as sticker

PLAIN = {"sheetS3": ["royal_gramma", "discus", "harlequin_rasbora", "neon_tetra"]}
CARDS = {
    "sheetS1": ((61, 143, 965, 875), ["platy", "molly", "swordtail", "betta"]),
    "sheetS2": ((80, 158, 947, 875), ["clownfish", "blue_green_chromis", "blue_tang", "yellow_tang"]),
    "sheetS4": ((53, 124, 973, 907), ["tiger_barb", "goldfish", "ocellate_stingray", "cardinal_tetra"]),
}
FLIP = {"molly", "betta", "yellow_tang"}
sn.FLIP = FLIP


def main():
    plain.FLIP.update(FLIP)
    for sheet, ids in PLAIN.items():
        plain.split_sheet(sheet, ids)
    for sheet, (box, ids) in CARDS.items():
        sticker.WHITE = 222 if sheet == "sheetS4" else 236  # S4's card is slightly bluish
        card = Image.open(os.path.join(HERE, "raw_sheets", sheet + ".jpg")).convert("RGB").crop(box)
        w, h = card.size
        margin = 14
        quads = [(0, 0), (w // 2, 0), (0, h // 2), (w // 2, h // 2)]
        for (qx, qy), species_id in zip(quads, ids):
            part = card.crop((qx + margin, qy + margin, qx + w // 2 - margin, qy + h // 2 - margin))
            sn.save(sn.biggest_blob(sticker.remove_sticker_background(part)), species_id)
    names = [n for ids in PLAIN.values() for n in ids] + [n for _, ids in CARDS.values() for n in ids]
    cell = 260
    sheet = Image.new("RGB", (cell * 4, cell * 4), (40, 110, 150))
    for i, n in enumerate(names):
        s = Image.open(os.path.join(HERE, n + ".png"))
        s.thumbnail((cell - 10, cell - 10))
        sheet.paste(s, ((i % 4) * cell + 5, (i // 4) * cell + 5), s)
    sheet.save(os.path.join(HERE, "..", "..", "builds", "style_check.png"))


if __name__ == "__main__":
    main()
