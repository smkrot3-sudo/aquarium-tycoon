extends Node
## The weather outside, for the garden pond. Indoor tanks ignore it completely. A new kind of
## weather is rolled once per in-game day, weighted by the season; it shifts the outdoor
## temperature, and the room view draws it over the garden (clouds, rain, snow).
##
## A pond's water follows `pond_ambient_c()` slowly (TankController.ambient_temp). Under ice the
## water never gets colder than a few degrees, like a real pond, and never hotter than a hot
## summer's day can push it — so hardy pond fish live through winter and summer if the player
## keeps the water clean and aerated.

enum Kind { SUNNY, CLOUDY, RAIN, STORM, HEAT, SNOW }

signal changed

## Keys are TimeManager.Season values: 0 spring, 1 summer, 2 autumn, 3 winter.
const BASE_C := {
	0: 13.0,
	1: 22.0,
	2: 12.0,
	3: 3.0,
}
## Offsets to the seasonal base per kind of weather.
const KIND_SHIFT := {
	Kind.SUNNY: 1.5, Kind.CLOUDY: -0.5, Kind.RAIN: -1.5, Kind.STORM: -2.0, Kind.HEAT: 6.0, Kind.SNOW: -2.0,
}
## Odds per season, in the order of Kind: sunny, cloudy, rain, storm, heat, snow.
const ODDS := {
	0: [0.34, 0.26, 0.28, 0.12, 0.0, 0.0],
	1: [0.46, 0.18, 0.12, 0.08, 0.16, 0.0],
	2: [0.2, 0.32, 0.34, 0.14, 0.0, 0.0],
	3: [0.2, 0.3, 0.1, 0.0, 0.0, 0.4],
}
const NAME_KEYS := ["weather_sunny", "weather_cloudy", "weather_rain", "weather_storm", "weather_heat", "weather_snow"]

var kind: int = Kind.SUNNY


func _ready() -> void:
	TimeManager.sim_day_elapsed.connect(_on_day)


func _on_day(_day: int) -> void:
	roll()


func roll() -> void:
	var odds: Array = ODDS.get(int(TimeManager.current_season), ODDS[0])
	var pick: float = randf()
	var next_kind: int = Kind.SUNNY
	var total: float = 0.0
	for i in range(odds.size()):
		total += float(odds[i])
		if pick <= total:
			next_kind = i
			break
	set_kind(next_kind)


func set_kind(new_kind: int) -> void:
	if new_kind == kind:
		return
	kind = new_kind
	changed.emit()


func name_key() -> String:
	return NAME_KEYS[clampi(kind, 0, NAME_KEYS.size() - 1)]


## The air temperature outside right now: season, weather, and a day/night swing.
func outdoor_c() -> float:
	var base: float = BASE_C.get(int(TimeManager.current_season), 13.0)
	var hour: float = TimeManager.current_hour_of_day()
	var swing: float = sin((hour - 9.0) / 24.0 * TAU) * 2.5
	return base + float(KIND_SHIFT.get(kind, 0.0)) + swing


## Where a pond's water is heading. Water holds heat: it is smoothed and clamped, and under a
## winter ice lid it never drops below a couple of degrees.
func pond_ambient_c() -> float:
	return clampf(outdoor_c(), 2.5, 31.0)


func is_wet() -> bool:
	return kind == Kind.RAIN or kind == Kind.STORM


func to_save_dict() -> Dictionary:
	return {"kind": kind}


func from_save_dict(d: Dictionary) -> void:
	kind = clampi(int(d.get("kind", Kind.SUNNY)), 0, Kind.SNOW)
	changed.emit()
