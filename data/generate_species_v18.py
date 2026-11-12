"""Dev-only: writes data/species/<id>.tres for the 1.8 species batch (20 species: African cichlids,
arowana, stingray, puffers, killifish, sharks, loaches, crayfish, marine puffers / clam / crab, and
the pond fish). Re-runnable. `unlock_tier` is the LEVEL (see Levels.gd), `habitat` is 0 = aquarium
only, 1 = pond only, 2 = either.

Run from the project root:  python data/generate_species_v18.py
"""
import io
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import generate_species as g
from generate_species import sp, PEACEFUL, SEMI, AGGRESSIVE, HERB, OMNI, CARN, DETR

# breed = (is_livebearer, pair_required, cooldown_days, fry_min, fry_max, incubation_days, sell_fry)
V18 = [
    # ---------------------------------------------------------------- freshwater, tropical
    dict(hab=0, dim=True, s=sp("golden_wonder_killifish", "Golden Wonder Killifish", "Aplocheilus lineatus", "cruiser", "schooler", (0.95, 0.8, 0.25),
       (21, 27), (6.0, 7.8), 40, 0.5, 10, 9, 6, 12, temper=SEMI, diet=CARN, resist=0.6, maturity=120, life=1500,
       breed=(False, True, 20, 10, 30, 2.0, 1), tags=("killifish", "surface"))),
    dict(hab=0, dim=False, s=sp("pea_puffer", "Pea Puffer", "Carinotetraodon travancoricus", "hoverer", "livebearer", (0.8, 0.85, 0.3),
       (24, 28), (6.5, 7.8), 40, 0.5, 3, 12, 8, 13, temper=SEMI, diet=CARN, resist=0.55, maturity=150, life=1500,
       breed=(False, True, 30, 5, 15, 5.0, 2), tags=("puffer",))),
    dict(hab=0, dim=False, s=sp("blue_crayfish", "Electric Blue Crayfish", "Procambarus alleni", "crawler", "invertebrate", (0.15, 0.45, 0.95),
       (18, 27), (7.0, 8.2), 60, 0.8, 12, 14, 9, 17, temper=SEMI, resist=0.7, maturity=150, life=1500,
       breed=(False, True, 40, 20, 60, 14.0, 1), tags=("crayfish",))),
    dict(hab=0, dim=True, s=sp("blue_gularis_killifish", "Blue Gularis Killifish", "Fundulopanchax sjostedti", "cruiser", "schooler", (0.2, 0.5, 0.95),
       (21, 26), (6.0, 7.5), 60, 0.6, 12, 18, 12, 20, temper=SEMI, diet=CARN, resist=0.5, maturity=150, life=1000,
       breed=(False, True, 25, 10, 30, 14.0, 2), tags=("killifish", "surface"))),
    dict(hab=0, dim=False, s=sp("red_tailed_shark", "Red-Tailed Black Shark", "Epalzeorhynchus bicolor", "cruiser", "bottom_dweller", (0.1, 0.1, 0.12),
       (22, 27), (6.5, 7.8), 120, 1.0, 15, 12, 8, 22, temper=SEMI, resist=0.65, maturity=240, life=3500, growth=0.05,
       tags=("shark", "territorial"))),
    dict(hab=0, dim=False, s=sp("rainbow_shark", "Rainbow Shark", "Epalzeorhynchus frenatus", "cruiser", "bottom_dweller", (0.35, 0.35, 0.4),
       (22, 27), (6.5, 7.8), 120, 1.0, 15, 12, 8, 23, temper=SEMI, resist=0.65, maturity=240, life=3500, growth=0.05,
       tags=("shark", "territorial"))),
    dict(hab=0, dim=True, s=sp("peacock_cichlid", "Peacock Cichlid", "Aulonocara nyassae", "cruiser", "livebearer", (0.2, 0.55, 0.95),
       (23, 28), (7.2, 8.6), 150, 1.4, 13, 26, 17, 22, temper=SEMI, diet=CARN, resist=0.6, maturity=200, life=3000, growth=0.05,
       breed=(True, True, 35, 10, 30, 0.0, 3), tags=("cichlid", "mouthbrooder"))),
    dict(hab=0, dim=True, s=sp("red_zebra_cichlid", "Red Zebra Cichlid", "Maylandia estherae", "cruiser", "livebearer", (1.0, 0.45, 0.2),
       (23, 28), (7.2, 8.6), 150, 1.3, 12, 20, 13, 23, temper=SEMI, resist=0.65, maturity=180, life=3000, growth=0.05,
       breed=(True, True, 35, 10, 30, 0.0, 3), tags=("cichlid", "mouthbrooder"))),
    dict(hab=0, dim=False, s=sp("clown_loach", "Clown Loach", "Chromobotia macracanthus", "bottom", "bottom_dweller", (1.0, 0.55, 0.1),
       (24, 30), (6.0, 7.5), 200, 2.2, 30, 28, 18, 25, school=3, diet=OMNI, resist=0.55, maturity=360, life=7000, growth=0.07,
       tags=("loach", "bottom", "schooling"))),
    dict(hab=0, dim=False, s=sp("frontosa", "Frontosa Cichlid", "Cyphotilapia frontosa", "hoverer", "tall", (0.85, 0.85, 0.95),
       (23, 28), (7.0, 8.8), 450, 4.5, 35, 90, 60, 34, temper=SEMI, diet=CARN, resist=0.6, maturity=450, life=7000, growth=0.09,
       breed=(True, True, 60, 10, 40, 0.0, 6), tags=("cichlid", "mouthbrooder"))),
    dict(hab=0, dim=False, s=sp("silver_arowana", "Silver Arowana", "Osteoglossum bicirrhosum", "cruiser", "tall", (0.85, 0.88, 0.92),
       (24, 30), (6.0, 7.5), 600, 6.0, 80, 160, 105, 40, temper=AGGRESSIVE, diet=CARN, resist=0.65, maturity=500, life=7000, growth=0.15,
       tags=("predator", "surface"))),
    dict(hab=0, dim=False, s=sp("ocellate_stingray", "Ocellate River Stingray", "Potamotrygon motoro", "bottom", "bottom_dweller", (0.65, 0.5, 0.3),
       (24, 29), (6.0, 7.5), 800, 5.0, 45, 240, 160, 43, diet=CARN, resist=0.5, maturity=500, life=7000, growth=0.12,
       breed=(True, True, 90, 2, 6, 0.0, 25), tags=("ray", "bottom"))),
    # ---------------------------------------------------------------- saltwater
    dict(hab=0, dim=False, s=sp("sally_lightfoot_crab", "Sally Lightfoot Crab", "Percnon gibbesi", "crawler", "invertebrate", (0.9, 0.3, 0.15),
       (22, 27), (7.9, 8.4), 120, 0.4, 8, 25, 16, 34, marine=True, diet=HERB, temper=SEMI, resist=0.7, life=2500, tags=("crab", "algae_eater"))),
    dict(hab=0, dim=False, s=sp("maxima_clam", "Maxima Clam", "Tridacna maxima", "snail", "invertebrate", (0.2, 0.45, 0.85),
       (24, 28), (8.0, 8.4), 250, 0.8, 25, 70, 45, 38, marine=True, diet=HERB, resist=0.45, maturity=500, life=7000, growth=0.04,
       tags=("clam", "photosynthetic"))),
    dict(hab=0, dim=False, s=sp("porcupine_puffer", "Porcupine Puffer", "Diodon holocanthus", "cruiser", "tall", (0.85, 0.75, 0.45),
       (24, 28), (7.9, 8.4), 400, 3.5, 30, 100, 66, 42, marine=True, diet=CARN, temper=SEMI, resist=0.55, maturity=300, life=5000, growth=0.12,
       tags=("puffer", "predator"))),
    dict(hab=0, dim=False, s=sp("dogface_puffer", "Dogface Puffer", "Arothron nigropunctatus", "cruiser", "tall", (0.55, 0.55, 0.45),
       (24, 28), (7.9, 8.4), 400, 3.5, 33, 120, 78, 44, marine=True, diet=CARN, temper=SEMI, resist=0.5, maturity=300, life=5000, growth=0.12,
       tags=("puffer", "predator"))),
    # ---------------------------------------------------------------- pond (cold water, outdoors)
    dict(hab=1, dim=False, s=sp("comet_goldfish", "Comet Goldfish", "Carassius auratus (comet)", "cruiser", "livebearer", (1.0, 0.45, 0.1),
       (2, 28), (6.5, 8.2), 300, 1.6, 30, 8, 5, 14, resist=0.8, maturity=200, life=7000, growth=0.12,
       breed=(False, True, 45, 20, 80, 3.0, 1), tags=("pond", "coldwater"))),
    dict(hab=1, dim=False, s=sp("shubunkin", "Shubunkin", "Carassius auratus (shubunkin)", "cruiser", "livebearer", (0.35, 0.55, 0.9),
       (2, 28), (6.5, 8.2), 400, 1.8, 30, 12, 8, 16, resist=0.8, maturity=220, life=7000, growth=0.12,
       breed=(False, True, 45, 20, 80, 3.0, 1), tags=("pond", "coldwater"))),
    dict(hab=1, dim=False, s=sp("golden_orfe", "Golden Orfe", "Leuciscus idus", "darter", "schooler", (1.0, 0.65, 0.15),
       (2, 25), (6.8, 8.2), 800, 1.5, 40, 25, 16, 24, school=3, resist=0.8, maturity=300, life=7000, growth=0.12,
       breed=(False, True, 60, 20, 80, 4.0, 2), tags=("pond", "coldwater", "schooling"))),
    dict(hab=1, dim=True, s=sp("koi", "Koi", "Cyprinus rubrofuscus", "cruiser", "livebearer", (0.95, 0.4, 0.15),
       (2, 28), (6.8, 8.2), 2000, 3.5, 70, 110, 75, 30, resist=0.75, maturity=400, life=9000, growth=0.16,
       breed=(False, True, 90, 20, 100, 4.0, 4), tags=("pond", "coldwater"))),
]


def main():
    for entry in V18:
        s = entry["s"]
        g.write_species(s)
        path = os.path.join(g.SPECIES_DIR, s["id"] + ".tres")
        text = io.open(path, encoding="utf-8").read()
        extra = "habitat = %d\n" % entry["hab"]
        if entry["dim"]:
            extra += "dimorphic = true\n"
        text = text.replace("base_price = ", extra + "base_price = ", 1)
        io.open(path, "w", encoding="utf-8", newline="\n").write(text)
    print("wrote %d species" % len(V18))


if __name__ == "__main__":
    main()
