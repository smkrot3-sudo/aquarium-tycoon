extends Node
## Rolls random events once per sim-day per tank (plan Section 5). Kept deliberately cheap:
## events are evaluated daily, not every hour.

signal event_triggered(tank: TankController, event: RandomEventData)

var event_catalog: Array[RandomEventData] = []


func _ready() -> void:
	_load_events("res://data/events/")
	TimeManager.sim_day_elapsed.connect(_on_sim_day)


func _load_events(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_warning("EventManager: could not open %s" % dir_path)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var res: RandomEventData = load(dir_path + file_name)
			if res != null:
				event_catalog.append(res)
		file_name = dir.get_next()


func _on_sim_day(_day: int) -> void:
	for tank in TankRegistry.tanks:
		if not is_instance_valid(tank):
			continue
		_roll_events_for_tank(tank)


func _roll_events_for_tank(tank: TankController) -> void:
	var neglect: float = tank.get_neglect_score()
	var season: TimeManager.Season = TimeManager.current_season
	for event in event_catalog:
		if event.trigger_season_tags.size() > 0 and season not in event.trigger_season_tags:
			continue
		var multiplier: float = 1.0 + neglect * (event.neglect_multiplier_max - 1.0)
		var chance: float = event.base_probability_per_day * multiplier
		if randf() < chance:
			tank.apply_event(event)
			event_triggered.emit(tank, event)
