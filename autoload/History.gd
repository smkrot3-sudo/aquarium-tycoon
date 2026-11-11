extends Node
## A rolling record of each owned tank's water and population (and the player's cash), one
## sample per sim-day, for the graphs in the Stats panel and the advisor.

const MAX_SAMPLES := 60

## tank node name -> Array of {day, ammonia, nitrite, nitrate, temp, ph, fish, algae, mulm}
var tank_series: Dictionary = {}
## Array of {day, cash}
var cash_series: Array = []


func _ready() -> void:
	## After TankRegistry (autoload order), so a tank has already ticked its own day.
	TimeManager.sim_day_elapsed.connect(_on_day)


func reset() -> void:
	tank_series.clear()
	cash_series.clear()


func _on_day(day: int) -> void:
	for tank in TankRegistry.tanks:
		if not is_instance_valid(tank):
			continue
		var list: Array = tank_series.get(tank.name, [])
		list.append({
			"day": day, "ammonia": tank.ammonia, "nitrite": tank.nitrite, "nitrate": tank.nitrate,
			"temp": tank.temperature, "ph": tank.ph, "fish": tank.get_fish().size(),
			"algae": tank.algae_level(), "mulm": tank.mulm_level(),
		})
		while list.size() > MAX_SAMPLES:
			list.pop_front()
		tank_series[tank.name] = list
	if not GameState.is_sandbox():
		cash_series.append({"day": day, "cash": EconomyManager.cash})
		while cash_series.size() > MAX_SAMPLES:
			cash_series.pop_front()


## Values of one field for a tank, oldest first. Empty until the first day has passed.
func values(tank_name: String, field: String) -> Array:
	var out: Array = []
	for sample in tank_series.get(tank_name, []):
		out.append(float(sample.get(field, 0.0)))
	return out


func cash_values() -> Array:
	var out: Array = []
	for sample in cash_series:
		out.append(float(sample["cash"]))
	return out


func to_save_dict() -> Dictionary:
	return {"tanks": tank_series, "cash": cash_series}


func from_save_dict(d: Dictionary) -> void:
	tank_series = d.get("tanks", {})
	cash_series = d.get("cash", [])
