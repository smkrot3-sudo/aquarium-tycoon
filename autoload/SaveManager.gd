extends Node
## Versioned hand-written JSON save (plan Section 8: chosen over native Resource
## serialization because it's robust across script refactors and human-inspectable).
## Also drives offline-progress catch-up on load.

const SCHEMA_VERSION := 1
const SAVE_DIR := "user://saves/"
const SAVE_PATH := SAVE_DIR + "slot_1.json"
const AUTOSAVE_INTERVAL_SEC := 60.0

var _autosave_timer: Timer


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	_autosave_timer = Timer.new()
	_autosave_timer.wait_time = AUTOSAVE_INTERVAL_SEC
	_autosave_timer.autostart = true
	_autosave_timer.timeout.connect(save_game)
	add_child(_autosave_timer)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()


func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> void:
	var data := {
		"schema_version": SCHEMA_VERSION,
		"saved_at_unix": Time.get_unix_time_from_system(),
		"economy": EconomyManager.to_save_dict(),
		"time": {
			"sim_minutes_total": TimeManager.sim_minutes_total,
			"current_season": TimeManager.current_season,
		},
		"tanks": _collect_tank_saves(),
		"settings": {"volume": AudioManager.master_volume, "language": Localization.current_language},
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: failed to open %s for writing" % SAVE_PATH)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()


func load_game() -> bool:
	if not has_save():
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("SaveManager: corrupt save file")
		return false

	var data: Dictionary = _migrate(parsed)

	EconomyManager.from_save_dict(data.get("economy", {}))
	var time_data: Dictionary = data.get("time", {})
	TimeManager.sim_minutes_total = time_data.get("sim_minutes_total", 0.0)
	TimeManager.current_season = time_data.get("current_season", 0) as TimeManager.Season

	_apply_tank_saves(data.get("tanks", {}))
	var settings: Dictionary = data.get("settings", {})
	AudioManager.master_volume = settings.get("volume", AudioManager.master_volume)
	Localization.set_language(settings.get("language", Localization.current_language))

	var saved_at: float = data.get("saved_at_unix", Time.get_unix_time_from_system())
	var elapsed_real_seconds: float = max(0.0, Time.get_unix_time_from_system() - saved_at)
	var capped_days := TimeManager.apply_offline_progress(elapsed_real_seconds)
	if capped_days > 0.0:
		TankRegistry.apply_offline_catch_up(capped_days)
	return true


func _migrate(data: Dictionary) -> Dictionary:
	## Placeholder migration chain. Add `if data.get("schema_version", 0) < N: ...` steps here
	## as the schema evolves, so old saves keep loading across refactors.
	return data


## Iterates every tank *node* in the scene (the "tank_nodes" group), not just the ones
## currently active in TankRegistry — a purchasable-but-still-locked tank slot (e.g. Tank2
## before it's bought) must still round-trip its locked/unlocked state through a save.
func _collect_tank_saves() -> Dictionary:
	var out := {}
	for tank in get_tree().get_nodes_in_group("tank_nodes"):
		if is_instance_valid(tank) and tank.has_method("to_save_dict"):
			out[tank.name] = tank.to_save_dict()
	return out


func _apply_tank_saves(tank_saves: Dictionary) -> void:
	for tank in get_tree().get_nodes_in_group("tank_nodes"):
		if is_instance_valid(tank) and tank.has_method("from_save_dict") and tank_saves.has(tank.name):
			tank.from_save_dict(tank_saves[tank.name])
