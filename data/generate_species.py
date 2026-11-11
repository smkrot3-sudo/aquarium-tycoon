"""Dev-only: writes data/species/<id>.tres for the roster expansion from one table, and stamps
scientific_name / swim_style onto the species files that already existed. Re-runnable.
Not part of the game's runtime.

Numbers are gameplay values, tuned so every species is keepable with the equipment the game
actually has (heaters hold ~24.5-25 C, tap water sits at pH ~7): where a real species wants
it hotter or more alkaline than that, the in-game range is widened and the real preference is
described in the encyclopedia text instead.
"""
import io
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))
SPECIES_DIR = os.path.join(HERE, "species")

PEACEFUL, SEMI, AGGRESSIVE = 0, 1, 2
HERB, OMNI, CARN, DETR = 0, 1, 2, 3

# Already-shipped species: only the two new descriptive fields are added.
EXISTING = {
    "guppy": ("Poecilia reticulata", "cruiser"),
    "platy": ("Xiphophorus maculatus", "cruiser"),
    "molly": ("Poecilia sphenops", "cruiser"),
    "neon_tetra": ("Paracheirodon innesi", "darter"),
    "zebra_danio": ("Danio rerio", "darter"),
    "harlequin_rasbora": ("Trigonostigma heteromorpha", "darter"),
    "betta": ("Betta splendens", "hoverer"),
    "honey_gourami": ("Trichogaster chuna", "hoverer"),
    "cory_catfish": ("Corydoras paleatus", "bottom"),
    "cherry_shrimp": ("Neocaridina davidi", "crawler"),
    "clownfish": ("Amphiprion ocellaris", "waddler"),
    "blue_green_chromis": ("Chromis viridis", "darter"),
    "cleaner_shrimp": ("Lysmata amboinensis", "crawler"),
}


def sp(id, name, sci, style, arche, color, temp, ph, liters, bio, cm, price, sell, tier, *,
       marine=False, diet=OMNI, temper=PEACEFUL, school=1, resist=0.5, maturity=120.0, life=1500.0,
       growth=0.04, breed=None, tags=()):
    """breed = (is_livebearer, pair_required, cooldown_days, fry_min, fry_max, incubation_days, sell_fry)"""
    return dict(id=id, name=name, sci=sci, style=style, arche=arche, color=color, temp=temp, ph=ph,
                liters=liters, bio=bio, cm=cm, price=price, sell=sell, tier=tier, marine=marine,
                diet=diet, temper=temper, school=school, resist=resist, maturity=maturity, life=life,
                growth=growth, breed=breed, tags=tags)


NEW = [
    # ---------------------------------------------------------------- freshwater
    sp("mystery_snail", "Mystery Snail", "Pomacea bridgesii", "snail", "invertebrate", (0.95, 0.75, 0.2),
       (20, 28), (7.0, 8.0), 20, 0.3, 5, 3, 2, 0, diet=HERB, resist=0.8, maturity=60, life=500,
       breed=(False, True, 30, 5, 15, 3.0, 1), tags=("snail",)),
    sp("cardinal_tetra", "Cardinal Tetra", "Paracheirodon axelrodi", "darter", "schooler", (0.9, 0.15, 0.2),
       (23, 29), (4.5, 7.0), 40, 0.4, 5, 7, 5, 1, school=6, resist=0.4, maturity=100, life=1500,
       tags=("schooling",)),
    sp("tiger_barb", "Tiger Barb", "Puntigrus tetrazona", "darter", "schooler", (0.9, 0.7, 0.25),
       (22, 27), (6.0, 7.5), 100, 0.6, 7, 5, 4, 1, temper=SEMI, school=6, resist=0.6, maturity=80, life=2000,
       breed=(False, False, 18, 15, 40, 1.5, 1), tags=("schooling", "fin_nipper")),
    sp("swordtail", "Swordtail", "Xiphophorus hellerii", "cruiser", "livebearer", (0.9, 0.25, 0.15),
       (22, 28), (7.0, 8.3), 100, 0.9, 12, 7, 6, 1, resist=0.6, maturity=80, life=1500, growth=0.07,
       breed=(True, True, 28, 15, 50, 0.0, 1), tags=("livebearer",)),
    sp("kuhli_loach", "Kuhli Loach", "Pangio kuhlii", "eel", "bottom_dweller", (0.9, 0.55, 0.4),
       (23, 28), (5.5, 7.0), 40, 0.4, 10, 8, 5, 1, diet=DETR, school=3, resist=0.5, maturity=150, life=3500,
       tags=("bottom",)),
    sp("amano_shrimp", "Amano Shrimp", "Caridina multidentata", "crawler", "invertebrate", (0.6, 0.7, 0.6),
       (18, 28), (6.5, 7.5), 40, 0.15, 5, 5, 3, 1, diet=DETR, resist=0.7, maturity=120, life=1000,
       tags=("shrimp",)),
    sp("goldfish", "Goldfish", "Carassius auratus", "cruiser", "livebearer", (1.0, 0.55, 0.1),
       (10, 26), (6.5, 8.0), 100, 2.0, 20, 6, 5, 1, resist=0.6, maturity=120, life=5000, growth=0.09,
       breed=(False, True, 30, 10, 30, 2.0, 1), tags=("coldwater",)),
    sp("dwarf_gourami", "Dwarf Gourami", "Trichogaster lalius", "hoverer", "labyrinth", (0.3, 0.7, 0.85),
       (22, 28), (6.0, 7.5), 40, 0.6, 8, 9, 6, 1, resist=0.3, maturity=120, life=1500,
       breed=(False, True, 30, 10, 25, 2.0, 1), tags=("labyrinth",)),
    sp("angelfish", "Angelfish", "Pterophyllum scalare", "hoverer", "tall", (0.8, 0.8, 0.82),
       (24, 30), (6.0, 7.5), 100, 1.5, 15, 18, 12, 2, temper=SEMI, resist=0.5, maturity=180, life=3500, growth=0.06,
       breed=(False, True, 30, 15, 40, 3.0, 2), tags=("cichlid",)),
    sp("bristlenose_pleco", "Bristlenose Pleco", "Ancistrus cirrhosus", "bottom", "bottom_dweller", (0.4, 0.3, 0.2),
       (21, 27), (6.0, 7.8), 100, 1.2, 13, 14, 9, 2, diet=HERB, resist=0.7, maturity=180, life=4000, growth=0.05,
       breed=(False, True, 40, 10, 30, 5.0, 2), tags=("bottom", "algae_eater")),
    sp("pearl_gourami", "Pearl Gourami", "Trichopodus leerii", "hoverer", "labyrinth", (0.8, 0.8, 0.85),
       (23, 28), (6.0, 8.0), 100, 1.0, 12, 15, 10, 2, resist=0.6, maturity=180, life=2500, growth=0.05,
       breed=(False, True, 40, 10, 30, 2.0, 2), tags=("labyrinth",)),
    sp("yellow_lab_cichlid", "Yellow Lab Cichlid", "Labidochromis caeruleus", "cruiser", "livebearer", (1.0, 0.9, 0.1),
       (23, 28), (7.0, 8.6), 100, 1.2, 10, 12, 8, 2, temper=SEMI, resist=0.6, maturity=150, life=3000, growth=0.05,
       breed=(True, True, 35, 10, 25, 0.0, 2), tags=("cichlid", "mouthbrooder")),
    sp("ram_cichlid", "German Blue Ram", "Mikrogeophagus ramirezi", "hoverer", "livebearer", (0.95, 0.8, 0.3),
       (24.5, 30), (5.5, 7.0), 40, 0.6, 6, 20, 13, 3, resist=0.3, maturity=150, life=1000,
       breed=(False, True, 30, 10, 30, 3.0, 2), tags=("cichlid",)),
    sp("boesemani_rainbowfish", "Boeseman's Rainbowfish", "Melanotaenia boesemani", "darter", "schooler", (0.95, 0.6, 0.2),
       (23.5, 28), (7.0, 8.0), 100, 0.9, 10, 16, 11, 3, school=6, resist=0.6, maturity=150, life=2500, growth=0.05,
       breed=(False, False, 20, 10, 30, 7.0, 2), tags=("schooling",)),
    sp("discus", "Discus", "Symphysodon aequifasciatus", "hoverer", "tall", (0.2, 0.6, 0.95),
       (24.5, 30), (5.5, 7.0), 200, 2.0, 18, 60, 40, 4, school=5, resist=0.25, maturity=240, life=3500, growth=0.06,
       breed=(False, True, 45, 10, 30, 3.0, 6), tags=("cichlid",)),
    sp("oscar", "Oscar", "Astronotus ocellatus", "cruiser", "livebearer", (0.9, 0.4, 0.1),
       (22.5, 28), (6.0, 8.0), 200, 4.0, 30, 40, 28, 4, diet=CARN, temper=AGGRESSIVE, resist=0.6, maturity=300, life=5000, growth=0.12,
       breed=(False, True, 60, 20, 60, 3.0, 3), tags=("cichlid", "predator")),
    # ---------------------------------------------------------------- saltwater
    sp("hermit_crab", "Blue-Legged Hermit Crab", "Clibanarius tricolor", "crawler", "invertebrate", (0.2, 0.4, 0.9),
       (22, 28), (7.9, 8.4), 60, 0.1, 3, 8, 5, 2, marine=True, diet=DETR, resist=0.8, life=1500, tags=("cleanup_crew",)),
    sp("firefish_goby", "Firefish Goby", "Nemateleotris magnifica", "hoverer", "schooler", (0.95, 0.4, 0.2),
       (22, 27), (7.9, 8.4), 60, 0.3, 8, 25, 16, 2, marine=True, diet=CARN, resist=0.5, life=1500, tags=("goby",)),
    sp("yellow_watchman_goby", "Yellow Watchman Goby", "Cryptocentrus cinctus", "bottom", "bottom_dweller", (0.95, 0.85, 0.2),
       (22, 27), (7.9, 8.4), 60, 0.4, 10, 22, 14, 2, marine=True, diet=CARN, resist=0.7, life=3000, tags=("goby", "bottom")),
    sp("royal_gramma", "Royal Gramma", "Gramma loreto", "cruiser", "livebearer", (0.7, 0.2, 0.8),
       (22, 27), (7.9, 8.4), 60, 0.4, 8, 30, 20, 3, marine=True, diet=CARN, resist=0.7, life=2000, tags=("basslet",)),
    sp("banggai_cardinalfish", "Banggai Cardinalfish", "Pterapogon kauderni", "hoverer", "tall", (0.85, 0.85, 0.85),
       (23, 27), (7.9, 8.4), 60, 0.5, 8, 28, 18, 3, marine=True, diet=CARN, resist=0.5, maturity=180, life=1500,
       breed=(True, True, 35, 8, 20, 0.0, 4), tags=("mouthbrooder",)),
    sp("fire_shrimp", "Blood Red Fire Shrimp", "Lysmata debelius", "crawler", "invertebrate", (0.8, 0.1, 0.1),
       (23, 27), (7.9, 8.4), 60, 0.15, 5, 30, 19, 3, marine=True, diet=DETR, resist=0.7, life=1200, tags=("shrimp",)),
    sp("seahorse", "Lined Seahorse", "Hippocampus erectus", "seahorse", "tall", (0.95, 0.75, 0.15),
       (22, 26), (7.9, 8.4), 60, 0.6, 15, 85, 55, 4, marine=True, diet=CARN, resist=0.3, maturity=200, life=1500,
       breed=(True, True, 30, 20, 100, 0.0, 8), tags=("seahorse",)),
    sp("flame_angelfish", "Flame Angelfish", "Centropyge loricula", "cruiser", "livebearer", (1.0, 0.3, 0.1),
       (23, 27), (7.9, 8.4), 250, 1.2, 10, 75, 50, 4, marine=True, temper=SEMI, resist=0.5, life=2500, tags=("angelfish",)),
    sp("yellow_tang", "Yellow Tang", "Zebrasoma flavescens", "cruiser", "tall", (1.0, 0.9, 0.1),
       (23, 27), (7.9, 8.4), 250, 2.5, 20, 70, 46, 4, marine=True, diet=HERB, temper=SEMI, resist=0.45, life=7000, growth=0.07, tags=("tang",)),
    sp("blue_tang", "Regal Blue Tang", "Paracanthurus hepatus", "cruiser", "livebearer", (0.15, 0.3, 0.9),
       (23, 27), (7.9, 8.4), 250, 3.0, 30, 80, 52, 5, marine=True, diet=HERB, resist=0.35, life=7000, growth=0.09, tags=("tang",)),
    sp("mandarin_dragonet", "Mandarin Dragonet", "Synchiropus splendidus", "bottom", "bottom_dweller", (0.2, 0.5, 0.9),
       (23, 27), (7.9, 8.4), 250, 0.4, 8, 90, 60, 5, marine=True, diet=CARN, resist=0.8, life=3500, tags=("dragonet",)),
    sp("lionfish", "Red Lionfish", "Pterois volitans", "hoverer", "tall", (0.75, 0.3, 0.25),
       (22, 27), (7.9, 8.4), 250, 3.0, 35, 95, 62, 5, marine=True, diet=CARN, temper=AGGRESSIVE, resist=0.7, life=3500, growth=0.1, tags=("predator", "venomous")),
]


def num(value):
    return repr(float(value))


def write_species(s):
    breed = s["breed"] or (False, False, 0.0, 0, 0, 0.0, 0)
    tags = ", ".join('"%s"' % t for t in s["tags"])
    lines = [
        '[gd_resource type="Resource" script_class="FishSpeciesData" load_steps=2 format=3]',
        '',
        '[ext_resource type="Script" path="res://scripts/resources/FishSpeciesData.gd" id="1"]',
        '',
        '[resource]',
        'script = ExtResource("1")',
        'id = "%s"' % s["id"],
        'display_name = "%s"' % s["name"],
        'scientific_name = "%s"' % s["sci"],
        'swim_style = "%s"' % s["style"],
        'archetype_id = "%s"' % s["arche"],
        'palette_color = Color(%s, %s, %s, 1)' % s["color"],
        'temp_min_c = %s' % num(s["temp"][0]),
        'temp_max_c = %s' % num(s["temp"][1]),
        'ph_min = %s' % num(s["ph"][0]),
        'ph_max = %s' % num(s["ph"][1]),
        'min_tank_liters = %s' % num(s["liters"]),
        'is_marine = %s' % ("true" if s["marine"] else "false"),
        'diet_type = %d' % s["diet"],
        'bioload_factor = %s' % num(s["bio"]),
        'temperament = %d' % s["temper"],
        'compatibility_tags = Array[String]([%s])' % tags,
        'schooling_min_group = %d' % s["school"],
        'disease_resistance = %s' % num(s["resist"]),
        'max_size_cm = %s' % num(s["cm"]),
        'growth_rate_cm_per_sim_day = %s' % num(s["growth"]),
        'maturity_age_sim_days = %s' % num(s["maturity"]),
        'lifespan_sim_days = %s' % num(s["life"]),
        'is_livebearer = %s' % ("true" if breed[0] else "false"),
        'pair_required = %s' % ("true" if breed[1] else "false"),
        'breeding_cooldown_sim_days = %s' % num(breed[2]),
        'fry_per_batch_min = %d' % breed[3],
        'fry_per_batch_max = %d' % breed[4],
        'egg_incubation_sim_days = %s' % num(breed[5]),
        'base_price = %d' % s["price"],
        'sell_price_adult = %d' % s["sell"],
        'sell_price_fry = %d' % breed[6],
        'rarity_tier = %d' % min(s["tier"], 3),
        'unlock_tier = %d' % s["tier"],
        'source_note = "Gameplay values; see data/generate_species.py for how ranges were chosen."',
        '',
    ]
    with io.open(os.path.join(SPECIES_DIR, s["id"] + ".tres"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))


def stamp_existing(species_id, sci, style):
    path = os.path.join(SPECIES_DIR, species_id + ".tres")
    text = io.open(path, encoding="utf-8").read()
    text = re.sub(r'^scientific_name = .*\n', '', text, flags=re.M)
    text = re.sub(r'^swim_style = .*\n', '', text, flags=re.M)
    text = re.sub(r'^(display_name = .*\n)', r'\1scientific_name = "%s"\nswim_style = "%s"\n' % (sci, style), text, count=1, flags=re.M)
    io.open(path, "w", encoding="utf-8", newline="\n").write(text)


if __name__ == "__main__":
    for species in NEW:
        write_species(species)
    for species_id, (sci, style) in EXISTING.items():
        stamp_existing(species_id, sci, style)
    print("wrote %d new species, stamped %d existing" % (len(NEW), len(EXISTING)))
