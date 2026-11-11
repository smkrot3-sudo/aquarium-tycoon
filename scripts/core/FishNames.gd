extends RefCounted
class_name FishNames
## Picks a given name for a newly added fish (GameController/TankController), in whichever
## language is active right now — the name itself is stored on the fish and never re-picked or
## translated later, exactly like a real pet's name doesn't change when you switch languages.
## Separate short lists per sex so bought-male/bought-female fish read as such immediately.

const MALE := {
	"en": ["Bubbles", "Finn", "Nemo", "Splash", "Dash", "Gil", "Marlin", "Bruce", "Oscar", "Zorro", "Blue", "Ziggy", "Rocky", "Jet", "Coral", "Bolt", "Chip", "Flash", "Ripple", "Otto"],
	"he": ["בועה", "פיני", "נמו", "ברק", "זורם", "גילי", "כחלילי", "סופה", "זהבי", "שובב", "קצף", "גל", "לוהט", "זיגי", "חץ", "ברוך", "נחשון", "סילון", "זריז", "מלך"],
}
const FEMALE := {
	"en": ["Bella", "Coral", "Pearl", "Marina", "Dory", "Luna", "Daisy", "Ruby", "Sunny", "Bubbly", "Nala", "Opal", "Misty", "Shelly", "Willow", "Gem", "Ivy", "Sable", "Fiona", "Vera"],
	"he": ["פנינה", "אלמוגית", "מרגלית", "לונה", "שמשונת", "ורדית", "יהלומה", "נועה", "צדפה", "אביבה", "זהרה", "שלולית", "טיפה", "קשתית", "רננה", "דייזי", "ליבי", "ורודה", "קורל", "שיבולת"],
}


static func pick(sex: int, language: String) -> String:
	## sex: FishController.Sex.MALE (0) or FEMALE (1).
	var pool: Dictionary = MALE if sex == 0 else FEMALE
	var names: Array = pool.get(language, pool["en"])
	return names[randi() % names.size()]
