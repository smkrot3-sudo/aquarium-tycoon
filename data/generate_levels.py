"""Applies the 50-level progression to the game data (re-runnable): the level each species and
piece of equipment unlocks at, realistic minimum tank sizes for the early species, and the full
ladder of purchasable tanks. `unlock_tier` in the .tres files means "level" (see Levels.gd).

Run from the project root:  python data/generate_levels.py
"""
import io
import json
import re

# species id: (level, min_tank_liters, bioload_factor or None)
SPECIES = {
    "guppy": (1, 10, None), "cherry_shrimp": (1, 8, None), "mystery_snail": (2, 10, None),
    "zebra_danio": (3, 20, 0.3), "platy": (4, 25, None), "betta": (4, 15, None),
    "neon_tetra": (5, 20, 0.2), "harlequin_rasbora": (7, 25, 0.25), "cory_catfish": (8, 40, 0.5),
    "molly": (9, 60, None), "honey_gourami": (10, 40, None), "amano_shrimp": (11, 40, None),
    "swordtail": (12, 80, None), "kuhli_loach": (13, 40, None), "dwarf_gourami": (14, 40, None),
    "cardinal_tetra": (15, 40, 0.25), "goldfish": (16, 100, None), "tiger_barb": (17, 80, 0.4),
    "angelfish": (18, 100, None), "pearl_gourami": (19, 100, None), "bristlenose_pleco": (20, 100, None),
    "yellow_lab_cichlid": (21, 100, None), "boesemani_rainbowfish": (24, 100, None),
    "ram_cichlid": (26, 40, None), "discus": (30, 200, None), "oscar": (32, 200, None),
    "clownfish": (28, 60, None), "blue_green_chromis": (29, 60, None), "cleaner_shrimp": (30, 60, None),
    "hermit_crab": (31, 60, None), "firefish_goby": (32, 60, None), "yellow_watchman_goby": (33, 60, None),
    "royal_gramma": (35, 60, None), "banggai_cardinalfish": (36, 60, None), "fire_shrimp": (37, 60, None),
    "flame_angelfish": (39, 250, None), "seahorse": (41, 60, None), "yellow_tang": (43, 250, None),
    "mandarin_dragonet": (45, 250, None), "blue_tang": (47, 250, None), "lionfish": (49, 250, None),
}

EQUIPMENT = {
    "basic_filter": 1, "basic_light": 1, "digital_test_kit": 2, "basic_heater": 2, "air_stone": 3,
    "led_light": 9, "canister_filter": 11, "pro_heater": 14, "powerhead": 27, "protein_skimmer": 28,
}

# id, english name, hebrew name, price, level, liters, type (0 fresh, 1 salt), english blurb, hebrew blurb
TANKS = [
    ("tank_25", "Small Freshwater Tank", "אקווריום מים מתוקים קטן", 30, 3, 25, 0, "A little more water than your first tank: room for a small school.", "קצת יותר מים מהאקווריום הראשון: מקום ללהקה קטנה."),
    ("tank_40", "Freshwater Tank", "אקווריום מים מתוקים", 70, 6, 40, 0, "The classic starter size. Gouramis, corydoras and tetras feel at home.", "הגודל הקלאסי למתחילים. גורמי, קורי וטטרות מרגישים בו בבית."),
    ("tank_60", "Medium Freshwater Tank", "אקווריום מים מתוקים בינוני", 130, 9, 60, 0, "Enough room for mollies and a real community.", "מספיק מקום למולי ולקהילה אמיתית."),
    ("tank_80", "Family Freshwater Tank", "אקווריום מים מתוקים משפחתי", 220, 12, 80, 0, "A long tank with space for swordtails to cruise.", "אקווריום ארוך שיש בו מקום לסייפנים לשוט."),
    ("large_freshwater_tank", "Large Freshwater Tank", "אקווריום מים מתוקים גדול", 330, 15, 100, 0, "A second, much bigger freshwater tank: room for big schools, goldfish and a lot more breeding.", "אקווריום גדול בהרבה: מקום ללהקות גדולות, לדגי זהב ולהתרבות רחבה."),
    ("tank_150", "Big Freshwater Tank", "אקווריום מים מתוקים ענק", 520, 19, 150, 0, "Cichlids and big gouramis finally have space to claim territories.", "ציקלידים וגורמי גדולים מקבלים סוף סוף מקום לטריטוריה."),
    ("huge_freshwater_tank", "Show Freshwater Tank", "אקווריום תצוגה למים מתוקים", 800, 23, 200, 0, "A 200-litre showpiece. The only home big enough for discus and oscars.", "אקווריום תצוגה של 200 ליטר. הבית היחיד שגדול מספיק לדיסקוסים ולאוסקרים."),
    ("tank_300", "Grand Freshwater Tank", "אקווריום מים מתוקים מפואר", 1300, 28, 300, 0, "A piece of furniture. A whole shoal of discus can live here.", "פריט ריהוט של ממש. להקה שלמה של דיסקוסים יכולה לחיות כאן."),
    ("tank_450", "Giant Freshwater Tank", "אקווריום מים מתוקים עצום", 2200, 33, 450, 0, "Several communities side by side in one huge tank.", "כמה קהילות זו לצד זו באקווריום ענק אחד."),
    ("tank_600", "Hall Freshwater Tank", "אקווריום מים מתוקים לאולם", 3500, 38, 600, 0, "Made for a lobby or a restaurant: guests will stop and stare.", "נבנה ללובי או למסעדה: האורחים יעצרו להסתכל."),
    ("tank_800", "Display Freshwater Tank", "אקווריום תצוגה ענק", 5500, 43, 800, 0, "Almost a wall of water. Needs a strong filter.", "כמעט קיר של מים. דורש מסנן חזק."),
    ("tank_1000", "Public Aquarium Tank", "מיכל לאקווריום ציבורי", 8000, 48, 1000, 0, "A thousand litres: the centrepiece of a public aquarium.", "אלף ליטר: לב ליבו של אקווריום ציבורי."),
    ("pond_500", "Garden Pond", "בריכת גן", 220, 14, 500, 2, "A small pond in the garden. Comet goldfish and shubunkins love it: the weather outside decides the water temperature.", "בריכה קטנה בגינה. דגי זהב שביט ושובונקין אוהבים אותה: מזג האוויר בחוץ קובע את טמפרטורת המים."),
    ("pond_1500", "Large Garden Pond", "בריכת גן גדולה", 700, 22, 1500, 2, "Deep enough for golden orfe to shoal and for the fish to wait out the winter below the ice.", "עמוקה מספיק לאורפות זהובות שיצורו להקה ולדגים שימתינו לחורף מתחת לקרח."),
    ("pond_4000", "Koi Pond", "בריכת קוי", 2000, 30, 4000, 2, "Four thousand litres: the first pond big enough for koi. Add a net, or the heron will visit.", "ארבעת אלפים ליטר: הבריכה הראשונה שגדולה מספיק לקוי. הוסף רשת, אחרת האנפה תבקר."),
    ("pond_8000", "Estate Pond", "בריכת אחוזה", 5200, 40, 8000, 2, "A pond to be proud of: a whole shoal of koi in a tended garden.", "בריכה להתגאות בה: להקה שלמה של קוי בגינה מטופחת."),
    ("marine_reef_tank", "Saltwater Tank", "אקווריום מים מלוחים", 500, 27, 60, 1, "Your first saltwater tank: home for clownfish, gobies, cardinalfish, shrimp and seahorses.", "אקווריום המים המלוחים הראשון שלך: בית לדגי ליצן, גובי, קרדינל, שרימפס וסוסוני ים."),
    ("marine_120", "Medium Saltwater Tank", "אקווריום מים מלוחים בינוני", 1100, 31, 120, 1, "More stable water and room for a few more colourful fish.", "מים יציבים יותר ומקום לעוד כמה דגים צבעוניים."),
    ("large_marine_tank", "Large Saltwater Tank", "אקווריום מים מלוחים גדול", 2200, 35, 250, 1, "A big saltwater tank with room to swim: needed for tangs, the flame angelfish, the mandarin and the lionfish.", "אקווריום מים מלוחים גדול עם מקום לשחות: נחוץ לטנגים, לדג המלאך הלהבה, למנדרין ולאריה."),
    ("marine_400", "Big Saltwater Tank", "אקווריום מים מלוחים ענק", 3800, 40, 400, 1, "A proper show tank for the larger marine fish.", "אקווריום תצוגה אמיתי לדגים הימיים הגדולים."),
    ("marine_600", "Grand Saltwater Tank", "אקווריום מים מלוחים מפואר", 6000, 45, 600, 1, "Enough water for a whole marine community.", "מספיק מים לקהילה ימית שלמה."),
    ("marine_1000", "Public Saltwater Tank", "מיכל מים מלוחים לאקווריום ציבורי", 11000, 49, 1000, 1, "The crown of the collection: a thousand litres of sea.", "כתר האוסף: אלף ליטר של ים."),
]
OLD_TANK_STRING_IDS = {"large_freshwater_tank", "huge_freshwater_tank", "marine_reef_tank", "large_marine_tank"}


def set_field(text, key, value):
    pattern = re.compile(r'^%s = .*$' % re.escape(key), re.M)
    assert pattern.search(text), key
    return pattern.sub(lambda m: '%s = %s' % (key, value), text, count=1)


for sid, (level, min_liters, bioload) in SPECIES.items():
    path = 'data/species/%s.tres' % sid
    text = io.open(path, encoding='utf-8').read()
    text = set_field(text, 'unlock_tier', level)
    text = set_field(text, 'min_tank_liters', '%.1f' % min_liters)
    if bioload is not None:
        text = set_field(text, 'bioload_factor', '%.2f' % bioload)
    io.open(path, 'w', encoding='utf-8', newline='\n').write(text)

for eid, level in EQUIPMENT.items():
    path = 'data/equipment/%s.tres' % eid
    text = io.open(path, encoding='utf-8').read()
    text = set_field(text, 'unlock_tier', level)
    io.open(path, 'w', encoding='utf-8', newline='\n').write(text)

HEADER = '''[gd_resource type="Resource" script_class="TankPresetData" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/resources/TankPresetData.gd" id="1"]

[resource]
script = ExtResource("1")
'''
new_strings = []
for tid, en, he, price, level, liters, ttype, en_desc, he_desc in TANKS:
    body = 'id = "%s"\ndisplay_name = "%s (%dL)"\nprice = %d\nunlock_tier = %d\ntank_liters = %.1f\ntank_type = %d\nambient_temp_base_c = %.1f\n' % (
        tid, en, liters, price, level, liters, ttype, 24.0 if ttype == 1 else 22.0)
    io.open('data/tanks/%s.tres' % tid, 'w', encoding='utf-8', newline='\n').write(HEADER + body)
    if tid not in OLD_TANK_STRING_IDS:
        new_strings.append('\t"tank_%s": [%s, %s],' % (tid, json.dumps(en, ensure_ascii=False), json.dumps(he, ensure_ascii=False)))
        new_strings.append('\t"desc_tank_%s": [%s, %s],' % (tid, json.dumps(en_desc, ensure_ascii=False), json.dumps(he_desc, ensure_ascii=False)))

# the strings live in GameStrings between two markers so this script can be re-run
path = 'scripts/core/GameStrings.gd'
text = io.open(path, encoding='utf-8').read()
begin = '\t# ---- generated tank names (data/generate_levels.py) begin\n'
end = '\t# ---- generated tank names end\n'
block = begin + '\n'.join(new_strings) + '\n' + end
if begin in text:
    a = text.index(begin)
    b = text.index(end) + len(end)
    text = text[:a] + block + text[b:]
else:
    text = text.replace('\t"advice_ok":', block + '\t"advice_ok":', 1)
io.open(path, 'w', encoding='utf-8', newline='\n').write(text)
print('species', len(SPECIES), 'equipment', len(EQUIPMENT), 'tanks', len(TANKS))
