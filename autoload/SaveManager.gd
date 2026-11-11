extends Node
## Versioned hand-written JSON save (plan Section 8: chosen over native Resource
## serialization because it's robust across script refactors and human-inspectable).
## Also drives offline-progress catch-up on load.

const SCHEMA_VERSION := 1
const SAVE_DIR := "user://saves/"
const SAVE_PATH := SAVE_DIR + "slot_1.json"
const TEMP_PATH := SAVE_DIR + "slot_1.tmp"
const BACKUP_PATH := SAVE_DIR + "slot_1.bak"
const CORRUPT_PATH := SAVE_DIR + "slot_1.corrupt"
const AUTOSAVE_INTERVAL_SEC := 60.0

## Nothing is written until the game has loaded (or decided there is nothing to load). A save
## triggered by the app being paused or losing focus during start-up used to be able to
## overwrite the real save with a blank new game.
var saving_enabled: bool = false

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
	for path in [SAVE_PATH, TEMP_PATH, BACKUP_PATH, CORRUPT_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(BACKUP_PATH)


## Written to a temporary file first and only then moved over the real save, with the previous
## good save kept as a backup: a crash or a kill in the middle of a write can no longer leave a
## half-written save behind (which loaded as "nothing" and was then overwritten by a new game).
func save_game() -> void:
	if not saving_enabled:
		return
	var data := {
		"schema_version": SCHEMA_VERSION,
		"saved_at_unix": Time.get_unix_time_from_system(),
		"economy": EconomyManager.to_save_dict(),
		"game_state": GameState.to_save_dict(),
		"progress": Progress.to_save_dict(),
		"market": Market.to_save_dict(),
		"history": History.to_save_dict(),
		"time": {
			"sim_minutes_total": TimeManager.sim_minutes_total,
			"current_season": TimeManager.current_season,
		},
		"tanks": _collect_tank_saves(),
		"settings": {"volume": AudioManager.master_volume, "music_volume": AudioManager.music_volume, "sfx_volume": AudioManager.sfx_volume, "language": Localization.current_language},
	}
	var text := JSON.stringify(data)
	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: failed to open %s for writing" % TEMP_PATH)
		return
	file.store_string(text)
	file.flush()
	file.close()
	## Only a temp file that reads back as a valid save may replace the current one.
	if not _is_valid_save_file(TEMP_PATH):
		push_error("SaveManager: the new save did not verify, keeping the old one")
		return
	if FileAccess.file_exists(SAVE_PATH):
		## Never let a damaged current save replace a good backup.
		if _is_valid_save_file(SAVE_PATH):
			DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE_PATH), ProjectSettings.globalize_path(BACKUP_PATH))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	var err := DirAccess.rename_absolute(ProjectSettings.globalize_path(TEMP_PATH), ProjectSettings.globalize_path(SAVE_PATH))
	if err != OK:
		push_error("SaveManager: could not move the new save into place (%s)" % error_string(err))


static func _read_save_file(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var text := file.get_as_text()
	file.close()
	if text.length() < 2:
		return null
	var parsed = JSON.parse_string(text)
	return parsed if typeof(parsed) == TYPE_DICTIONARY else null


static func _is_valid_save_file(path: String) -> bool:
	var parsed = _read_save_file(path)
	return parsed != null and parsed.has("economy") and parsed.has("tanks")


## Loads the save, falling back to the backup if the main file is damaged. Returns false when
## there is nothing usable (a damaged file is moved aside, not deleted).
func load_game() -> bool:
	var parsed = _read_save_file(SAVE_PATH)
	if parsed == null:
		if FileAccess.file_exists(SAVE_PATH):
			push_error("SaveManager: the save file is damaged, trying the backup")
			DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE_PATH), ProjectSettings.globalize_path(CORRUPT_PATH))
		parsed = _read_save_file(BACKUP_PATH)
	if parsed == null:
		return false

	var data: Dictionary = _migrate(parsed)

	GameState.from_save_dict(data.get("game_state", {}))
	EconomyManager.from_save_dict(data.get("economy", {}))
	EconomyManager.apply_mode()
	Progress.from_save_dict(data.get("progress", {}))
	Market.from_save_dict(data.get("market", {}))
	History.from_save_dict(data.get("history", {}))
	TimeManager.reset_speed()
	var time_data: Dictionary = data.get("time", {})
	TimeManager.sim_minutes_total = time_data.get("sim_minutes_total", 0.0)
	TimeManager.current_season = time_data.get("current_season", 0) as TimeManager.Season

	## The collection facts are re-recorded from the saved fish below; nothing is paid for them.
	Progress.loading = true
	_apply_tank_saves(data.get("tanks", {}))
	Progress.loading = false
	var settings: Dictionary = data.get("settings", {})
	AudioManager.master_volume = settings.get("volume", AudioManager.master_volume)
	AudioManager.music_volume = settings.get("music_volume", AudioManager.music_volume)
	AudioManager.sfx_volume = settings.get("sfx_volume", AudioManager.sfx_volume)
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
