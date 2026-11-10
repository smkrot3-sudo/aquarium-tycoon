extends Node
## Hand-rolled Hebrew/English string table. Deliberately NOT using Godot's built-in
## TranslationServer/auto-translate: almost every player-facing string here mixes translated
## item names with live data (prices, tiers, readings), so GameController always builds the
## final text explicitly via t() rather than relying on Control auto-translation. This also
## keeps language switching fully headless-testable (no asset-import/.csv pipeline involved).

signal language_changed(lang: String)

var current_language: String = "he"

## key -> {"en": "...", "he": "..."}
var _strings: Dictionary = {
	"ui_title": {"en": "Aquarium Tycoon", "he": "אקווריום טייקון"},
	"lang_toggle_to_en": {"en": "English", "he": "English"},
	"lang_toggle_to_he": {"en": "עברית", "he": "עברית"},

	"section_equipment": {"en": "Equipment", "he": "ציוד"},
	"section_fish": {"en": "Fish", "he": "דגים"},
	"section_actions": {"en": "Actions", "he": "פעולות"},
	"section_debug": {"en": "Debug", "he": "דיבוג"},
	"section_buy_tank": {"en": "Buy 2nd Tank", "he": "קניית אקווריום שני"},

	"action_feed": {"en": "Feed Tank", "he": "האכל אקווריום"},
	"action_water_change": {"en": "Water Change (25%)", "he": "החלפת מים (25%)"},
	"action_treat_disease": {"en": "Treat Disease ($%d)", "he": "טפל במחלה ($%d)"},
	"action_sell_one": {"en": "Sell One Fish", "he": "מכור דג אחד"},
	"action_fast_forward": {"en": "Fast-forward 1 day", "he": "קדם יום אחד"},

	"tab_tank1": {"en": "Tank 1: Freshwater", "he": "אקווריום 1: מים מתוקים"},
	"tab_tank2_locked": {"en": "Tank 2 (locked)", "he": "אקווריום 2 (נעול)"},
	"tab_tank2_fresh": {"en": "Tank 2: Freshwater", "he": "אקווריום 2: מים מתוקים"},
	"tab_tank2_salt": {"en": "Tank 2: Saltwater", "he": "אקווריום 2: מים מלוחים"},

	"status_cash": {"en": "Cash: $%d", "he": "מזומן: $%d"},
	"status_day": {"en": "Day %d - %s", "he": "יום %d - %s"},
	"status_fish": {"en": "Fish: %d", "he": "דגים: %d"},
	"status_temp": {"en": "Temp: %.1f C", "he": "טמפ׳: %.1f מעלות"},
	"status_ammonia_known": {"en": "Ammonia: %.2f ppm", "he": "אמוניה: %.2f ppm"},
	"status_ammonia_unknown": {"en": "Ammonia: unknown (need test kit)", "he": "אמוניה: לא ידוע (צריך ערכת בדיקה)"},
	"status_nitrite_known": {"en": "Nitrite: %.2f ppm", "he": "ניטריט: %.2f ppm"},
	"status_nitrite_unknown": {"en": "Nitrite: unknown (need test kit)", "he": "ניטריט: לא ידוע (צריך ערכת בדיקה)"},
	"status_nitrate_known": {"en": "Nitrate: %.1f ppm", "he": "ניטרט: %.1f ppm"},
	"status_nitrate_unknown": {"en": "Nitrate: unknown (need test kit)", "he": "ניטרט: לא ידוע (צריך ערכת בדיקה)"},
	"status_oxygen_known": {"en": "Oxygen: %.1f ppm", "he": "חמצן: %.1f ppm"},
	"status_water_quality_rough": {"en": "Water quality looks: %s", "he": "איכות המים נראית: %s"},
	"water_good": {"en": "Good", "he": "טובה"},
	"water_fair": {"en": "Fair", "he": "סבירה"},
	"water_poor": {"en": "Poor", "he": "גרועה"},
	"status_salinity": {"en": "Salinity (SG): %.3f", "he": "מליחות (SG): %.3f"},
	"status_filter": {"en": "Filter maturity: %d%%", "he": "בשלות מסנן: %d%%"},
	"status_sick": {"en": "Sick fish: %d", "he": "דגים חולים: %d"},

	"season_0": {"en": "Spring", "he": "אביב"},
	"season_1": {"en": "Summer", "he": "קיץ"},
	"season_2": {"en": "Autumn", "he": "סתיו"},
	"season_3": {"en": "Winter", "he": "חורף"},

	"btn_buy_item": {"en": "Buy %s ($%d)", "he": "קנה %s ($%d)"},
	"btn_buy_item_tier": {"en": "Buy %s ($%d) [Tier %d]", "he": "קנה %s ($%d) [שכבה %d]"},
	"btn_buy_item_marine": {"en": "Buy %s ($%d) [Tier %d, marine]", "he": "קנה %s ($%d) [שכבה %d, ים]"},
	"btn_tank_option": {"en": "%s ($%d) [Tier %d]", "he": "%s ($%d) [שכבה %d]"},

	"alert_not_enough_cash": {"en": "Not enough cash.", "he": "אין מספיק כסף."},
	"alert_not_enough_cash_for_food": {"en": "Not enough cash for food.", "he": "אין מספיק כסף למזון."},
	"alert_not_enough_cash_for_medication": {"en": "Not enough cash for medication.", "he": "אין מספיק כסף לתרופה."},
	"alert_no_fish_to_feed": {"en": "No fish to feed yet.", "he": "אין עדיין דגים להאכיל."},
	"alert_no_fish_to_sell": {"en": "No fish to sell.", "he": "אין דגים למכור."},
	"alert_no_sick_fish": {"en": "No sick fish right now.", "he": "אין כרגע דגים חולים."},
	"alert_item_locked_tier": {"en": "%s is locked until you earn more.", "he": "%s נעול עד שתרוויח יותר."},
	"alert_tank_too_small": {"en": "Tank too small (%d L needed, %d L available)", "he": "האקווריום קטן מדי (נדרשים %d ל׳, יש %d ל׳)"},
	"alert_needs_heater": {"en": "Needs a heater to reach %.0f-%.0f°C", "he": "דרוש חימום כדי להגיע ל-%.0f-%.0f מעלות"},
	"alert_marine_needs_saltwater": {"en": "%s is a marine species — needs a saltwater/reef tank", "he": "%s הוא מין ימי — דורש אקווריום מים מלוחים/ריף"},
	"alert_freshwater_in_saltwater": {"en": "%s is a freshwater species — won't survive in a saltwater tank", "he": "%s הוא מין מים מתוקים — לא ישרוד באקווריום מים מלוחים"},
	"alert_tank2_already_setup": {"en": "Tank 2 is already set up.", "he": "אקווריום 2 כבר מוגדר."},
	"alert_tank_at_capacity": {"en": "Tank is at capacity — sell or upgrade before adding more fish.", "he": "האקווריום בקיבולת מלאה — מכור או שדרג לפני הוספת דגים נוספים."},

	"sp_guppy": {"en": "Guppy", "he": "גופי"},
	"sp_cherry_shrimp": {"en": "Cherry Shrimp", "he": "שרימפס דובדבן"},
	"sp_neon_tetra": {"en": "Neon Tetra", "he": "טטרה ניאון"},
	"sp_zebra_danio": {"en": "Zebra Danio", "he": "דניו זברה"},
	"sp_platy": {"en": "Platy", "he": "פלאטי"},
	"sp_betta": {"en": "Betta", "he": "בטא (דג לוחם)"},
	"sp_molly": {"en": "Molly", "he": "מולי"},
	"sp_cory_catfish": {"en": "Cory Catfish", "he": "קורי קטפיש"},
	"sp_harlequin_rasbora": {"en": "Harlequin Rasbora", "he": "רסבורה הרלקין"},
	"sp_honey_gourami": {"en": "Honey Gourami", "he": "גוראמי דבש"},
	"sp_clownfish": {"en": "Clownfish", "he": "דג ליצן"},
	"sp_blue_green_chromis": {"en": "Blue-Green Chromis", "he": "כרומיס כחול-ירוק"},
	"sp_cleaner_shrimp": {"en": "Cleaner Shrimp", "he": "שרימפס מנקה"},

	"eq_basic_heater": {"en": "Heater", "he": "חימום בסיסי"},
	"eq_basic_filter": {"en": "Filter", "he": "מסנן בסיסי"},
	"eq_basic_light": {"en": "Light", "he": "תאורה בסיסית"},
	"eq_air_stone": {"en": "Air Stone", "he": "אבן אוויר"},
	"eq_digital_test_kit": {"en": "Test Kit", "he": "ערכת בדיקה דיגיטלית"},
	"eq_pro_heater": {"en": "Pro Heater", "he": "חימום מקצועי"},
	"eq_canister_filter": {"en": "Canister Filter", "he": "מסנן קניסטר"},
	"eq_led_light": {"en": "LED Light", "he": "תאורת LED"},
	"eq_protein_skimmer": {"en": "Protein Skimmer", "he": "סקימר חלבונים"},
	"eq_powerhead": {"en": "Powerhead", "he": "משאבת זרימה"},

	"tank_large_freshwater_tank": {"en": "Large Freshwater Tank (100L)", "he": "אקווריום מים מתוקים גדול (100 ל׳)"},
	"tank_marine_reef_tank": {"en": "Marine Reef Tank (60L)", "he": "אקווריום ריף ים (60 ל׳)"},

	"alert_ammonia_danger": {"en": "Ammonia is dangerously high — do a water change.", "he": "רמת האמוניה גבוהה מסוכנת — בצעו החלפת מים."},

	"event_algae_bloom": {"en": "Strong light and built-up nutrients have triggered an algae bloom.", "he": "אור חזק וחומרים מזינים שהצטברו גרמו לפריחת אצות."},
	"event_disease_outbreak": {"en": "Stress and poor conditions have let an illness take hold in the tank. Treat it before it spreads further.", "he": "לחץ ותנאים ירודים אפשרו למחלה להשתלט על האקווריום. טפלו בה לפני שתתפשט עוד."},
	"event_overfeeding_ammonia_spike": {"en": "The water smells off — uneaten food has rotted and ammonia is spiking. Do a water change soon.", "he": "משהו לא בסדר במים — מזון שלא נאכל נרקב והאמוניה מזנקת. בצעו החלפת מים בקרוב."},
	"event_seasonal_heater_strain": {"en": "The heater has failed under the winter cold. Replace it soon or the tank will chill.", "he": "החימום התקלקל תחת קור החורף. החליפו אותו בקרוב אחרת האקווריום יתקרר."},
	"event_temperature_swing": {"en": "A sudden draft or room-temperature swing has pushed the tank's temperature off target.", "he": "פרץ אוויר פתאומי או תנודת טמפרטורת חדר הזיזו את טמפרטורת האקווריום מהיעד."},

	"desc_sp_betta": {"en": "A flamboyant, aggressive, solitary fish. Beautiful, but incompatible with most tankmates — keep it alone.", "he": "דג ראוותני ותוקפני שחי לבד. יפהפה, אך לא מתאים לרוב השותפים לאקווריום — עדיף להחזיק אותו לבדו."},
	"desc_sp_blue_green_chromis": {"en": "A hardy, inexpensive reef schooling fish, bright blue-green and always active mid-water. A classic 'starter school' for a new reef tank.", "he": "דג ריף להק עמיד וזול, בצבע כחול-ירוק בוהק ותמיד פעיל באמצע המים. להק קלאסי למתחילים באקווריום ריף חדש."},
	"desc_sp_cherry_shrimp": {"en": "A tiny, hardy, prolifically breeding freshwater shrimp. A great second income source alongside guppies.", "he": "שרימפס מים מתוקים זעיר, עמיד ומתרבה בקלות רבה. מקור הכנסה משני מצוין לצד הגופי."},
	"desc_sp_cleaner_shrimp": {"en": "A reef-safe scavenger that picks up leftover food and detritus. A cheap, reliable second income source for a marine tank, same role cherry shrimp play in freshwater.", "he": "אספסוף בטוח לריף שאוסף שאריות מזון ולכלוך. מקור הכנסה משני זול ואמין לאקווריום ימי, בדיוק כמו תפקיד שרימפס הדובדבן במים מתוקים."},
	"desc_sp_clownfish": {"en": "A hardy, iconic reef fish that pairs up and lays eggs on rock near its chosen shelter. The easiest marine species to start with.", "he": "דג ריף איקוני ועמיד שמזדווג ומטיל ביצים על סלע ליד המסתור שבחר. המין הימי הקל ביותר להתחיל איתו."},
	"desc_sp_cory_catfish": {"en": "A peaceful, armored bottom-dweller that scavenges leftover food. Happiest in a group of its own kind and lays eggs it sticks to the glass.", "he": "דג קרקעית שלו ומשוריין שאוסף שאריות מזון. הכי מאושר בקבוצה של בני מינו, ומטיל ביצים שהוא מדביק לזכוכית."},
	"desc_sp_guppy": {"en": "A tiny, colorful, famously easy-to-breed livebearer. The classic first aquarium fish.", "he": "דג ילדן זעיר וצבעוני, ידוע בקלות ההתרבות שלו. דג האקווריום הראשון הקלאסי."},
	"desc_sp_harlequin_rasbora": {"en": "A tight-schooling soft-water fish with a copper body and a dark wedge patch. Scatters eggs under broad leaves rather than giving live birth.", "he": "דג להק צמוד למים רכים, עם גוף נחושתי וכתם שחור בצורת טריז. מפזר ביצים מתחת לעלים רחבים במקום ללדת חי."},
	"desc_sp_honey_gourami": {"en": "A calm labyrinth fish that breathes surface air and builds a bubble nest for its eggs. Does best in quiet, lightly-flowing water.", "he": "דג מבוך רגוע שנושם אוויר מפני המים ובונה קן בועות לביציו. הכי טוב לו במים שקטים עם זרימה קלה."},
	"desc_sp_molly": {"en": "A larger, hardier livebearer that wants more swimming room and harder water than a guppy — a natural tank-upgrade fish.", "he": "דג ילדן גדול ועמיד יותר, שזקוק ליותר מקום שחייה ולמים קשים יותר מהגופי — דג טבעי לשדרוג האקווריום."},
	"desc_sp_neon_tetra": {"en": "A small, vividly striped schooling fish. Looks best — and feels calmest — in a group of six or more.", "he": "דג להק קטן עם פסים בוהקים. נראה הכי טוב — ומרגיש הכי רגוע — בקבוצה של שישה ומעלה."},
	"desc_sp_platy": {"en": "A cheerful, chunky livebearer that comes in many colors. A slightly bigger step up from the guppy.", "he": "דג ילדן שמנמן ועליז שמגיע בהרבה צבעים. צעד קטן למעלה מהגופי."},
	"desc_sp_zebra_danio": {"en": "A hardy, fast, active schooling fish with bold stripes. A known fin-nipper — keep it away from long-finned tankmates.", "he": "דג להק עמיד, מהיר ופעיל עם פסים בולטים. ידוע כנושך סנפירים — הרחק אותו משותפים בעלי סנפירים ארוכים."},

	"desc_eq_basic_heater": {"en": "Keeps the tank at a steady target temperature. Essential for most tropical fish.", "he": "שומר על טמפרטורה קבועה באקווריום. חיוני לרוב דגי המים הטרופיים."},
	"desc_eq_basic_filter": {"en": "Filters debris and hosts the beneficial bacteria that break down ammonia and nitrite.", "he": "מסנן לכלוכים ומארח את החיידקים המועילים שמפרקים אמוניה וניטריט."},
	"desc_eq_basic_light": {"en": "Basic lighting for viewing the tank and supporting any live plants.", "he": "תאורה בסיסית לצפייה באקווריום ותמיכה בצמחים חיים."},
	"desc_eq_air_stone": {"en": "Adds extra oxygen to the water via a stream of fine bubbles — helps during heat waves or overcrowding.", "he": "מוסיף חמצן למים דרך זרם בועות דקות — עוזר בגלי חום או בצפיפות יתר."},
	"desc_eq_digital_test_kit": {"en": "Reveals exact ammonia/nitrite/nitrate/oxygen readings instead of a rough water-quality guess.", "he": "חושף קריאות מדויקות של אמוניה/ניטריט/ניטרט/חמצן במקום הערכה גסה של איכות המים."},
	"desc_eq_pro_heater": {"en": "A stronger, more reliable heater — pulls temperature to target faster and fails less often.", "he": "חימום חזק ואמין יותר — מגיע לטמפרטורת היעד מהר יותר ומתקלקל פחות."},
	"desc_eq_canister_filter": {"en": "A high-capacity filter with much stronger flow and biological processing power.", "he": "מסנן בעל קיבולת גבוהה עם זרימה חזקה בהרבה וכוח סינון ביולוגי משופר."},
	"desc_eq_led_light": {"en": "Brighter, more efficient lighting — better for live plants and coral color.", "he": "תאורה חזקה ויעילה יותר — טובה יותר לצמחים חיים ולצבעי אלמוגים."},
	"desc_eq_protein_skimmer": {"en": "Pulls dissolved organic waste out of marine water before it breaks down — essential for a healthy reef tank.", "he": "שואב פסולת אורגנית מומסת מהמים לפני שהיא מתפרקת — חיוני לאקווריום ריף בריא."},
	"desc_eq_powerhead": {"en": "A compact water pump that adds strong current — many reef species need the extra flow.", "he": "משאבת מים קומפקטית שמוסיפה זרימה חזקה — מינים רבים בריף זקוקים לזרימה נוספת."},

	"food_basic_flakes": {"en": "Basic Flake Food", "he": "מזון פתיתים בסיסי"},
	"food_shrimp_pellets": {"en": "Shrimp Pellets", "he": "כדורי שרימפס"},
	"desc_food_basic_flakes": {"en": "Everyday flake food suitable for most herbivores and omnivores.", "he": "מזון פתיתים יומיומי, מתאים לרוב הצמחונים והאוכלי-כל."},
	"desc_food_shrimp_pellets": {"en": "Sinking pellets favored by bottom-dwellers and shrimp.", "he": "כדורים שוקעים שאהובים על דגי קרקעית ושרימפס."},

	"nav_guide": {"en": "Guide", "he": "מדריך"},
	"guide_title": {"en": "Aquarium Guide", "he": "מדריך האקווריום"},
	"guide_tab_fish": {"en": "Fish", "he": "דגים"},
	"guide_tab_equipment": {"en": "Equipment", "he": "ציוד"},
	"guide_tab_food": {"en": "Food", "he": "מזון"},
	"guide_close": {"en": "Close", "he": "סגור"},
	"guide_stat_temp": {"en": "Temperature: %.0f-%.0f°C", "he": "טמפרטורה: %.0f-%.0f מעלות"},
	"guide_stat_ph": {"en": "pH: %.1f-%.1f", "he": "pH: %.1f-%.1f"},
	"guide_stat_gh": {"en": "Hardness (GH): %.0f-%.0f", "he": "קשיות (GH): %.0f-%.0f"},
	"guide_stat_sg": {"en": "Specific gravity: %.3f-%.3f", "he": "מליחות (SG): %.3f-%.3f"},
	"guide_stat_diet": {"en": "Diet: %s", "he": "תזונה: %s"},
	"guide_stat_temperament": {"en": "Temperament: %s", "he": "אופי: %s"},
	"guide_stat_tank_size": {"en": "Min tank size: %d L", "he": "גודל אקווריום מינימלי: %d ל׳"},
	"guide_stat_price": {"en": "Price: $%d", "he": "מחיר: $%d"},
	"guide_stat_tier": {"en": "Unlocks at tier %d", "he": "נפתח בשכבה %d"},
	"guide_stat_schooling": {"en": "Keep in groups of %d+", "he": "להחזיק בקבוצות של %d ומעלה"},
	"guide_stat_marine": {"en": "Marine species", "he": "מין ימי"},
	"guide_stat_freshwater": {"en": "Freshwater species", "he": "מין מים מתוקים"},
	"guide_stat_max_size": {"en": "Max size: %.0f cm", "he": "גודל מקסימלי: %.0f ס״מ"},
	"guide_stat_lifespan": {"en": "Lifespan: ~%d days", "he": "תוחלת חיים: כ-%d ימים"},
	"guide_eq_stat_heater": {"en": "Target temp: %.0f°C | Power: %.1fx", "he": "טמפרטורת יעד: %.0f מעלות | עוצמה: %.1fx"},
	"guide_eq_stat_filter": {"en": "Flow: %.0f L/h | Bio capacity: %.1fx", "he": "זרימה: %.0f ל׳/שעה | קיבולת ביולוגית: %.1fx"},
	"guide_eq_stat_light": {"en": "Intensity: %.1fx", "he": "עוצמה: %.1fx"},
	"guide_eq_stat_air": {"en": "Oxygen boost: +%.1f", "he": "תוספת חמצן: +%.1f"},
	"guide_eq_stat_testkit": {"en": "Reveals exact water readings", "he": "חושף קריאות מים מדויקות"},

	"diet_0": {"en": "Herbivore", "he": "צמחוני"},
	"diet_1": {"en": "Omnivore", "he": "אוכל כל"},
	"diet_2": {"en": "Carnivore", "he": "טורף"},
	"diet_3": {"en": "Detritivore", "he": "אוכל פסולת"},
	"temperament_0": {"en": "Peaceful", "he": "שליו"},
	"temperament_1": {"en": "Semi-aggressive", "he": "תוקפני למחצה"},
	"temperament_2": {"en": "Aggressive", "he": "תוקפני"},

	"settings_volume": {"en": "Volume", "he": "עוצמת קול"},
}


func t(key: String, args: Array = []) -> String:
	var entry: Dictionary = _strings.get(key, {})
	var template: String = entry.get(current_language, entry.get("en", key))
	if args.is_empty():
		return template
	return template % args


func set_language(lang: String) -> void:
	if lang == current_language or (lang != "en" and lang != "he"):
		return
	current_language = lang
	language_changed.emit(lang)


func other_language() -> String:
	return "en" if current_language == "he" else "he"
