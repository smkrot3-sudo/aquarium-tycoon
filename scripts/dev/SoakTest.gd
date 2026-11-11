extends Node
## Dev-only soak test: plays a long game the way a restless player would — random actions,
## every panel opened and refreshed, every tool used, orders / auctions / shows, speed changes,
## tank purchases and repeated save/load round trips — and then reports every script error the
## engine logged. Pass SOAK_SEED and SOAK_DAYS in the environment to vary it. Not shipped.

var _failures: int = 0
var _main: GameController


func _check(what: String, ok: bool) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", what])


func _ready() -> void:
	var seed_value := int(OS.get_environment("SOAK_SEED")) if OS.get_environment("SOAK_SEED") != "" else 1
	var days := int(OS.get_environment("SOAK_DAYS")) if OS.get_environment("SOAK_DAYS") != "" else 80
	seed(seed_value)
	ErrorLog.clear()
	_main = load("res://scenes/main/Main.tscn").instantiate()
	add_child(_main)
	await get_tree().process_frame
	_main.begin_new_game(GameState.Mode.CAREER, GameState.Difficulty.NORMAL)
	EconomyManager.earn(3000, "soak funds")
	_main.buy_equipment("basic_filter")
	_main.buy_equipment("basic_heater")
	_main.buy_equipment("basic_light")
	_main.buy_fish("guppy", FishController.Sex.MALE)
	_main.buy_fish("guppy", FishController.Sex.FEMALE)
	_main.buy_fish("platy", FishController.Sex.MALE)
	_main.buy_fish("platy", FishController.Sex.FEMALE)
	_main.buy_fish("cherry_shrimp")

	for day in range(days):
		for i in range(randi_range(2, 6)):
			await _random_action()
		TimeManager.debug_fast_forward_days(1.0)
		for f in range(3):
			await get_tree().process_frame
		if day % 9 == 8:
			_save_and_reload()
	_check("The soak game survived %d days" % days, true)

	var report: String = ErrorLog.report(6000)
	var error_lines := 0
	for line in report.split("
"):
		if line.begins_with("["):
			error_lines += 1
	print("--- error log (%d entries) ---" % error_lines)
	print(report)
	_check("No script or engine errors were logged", error_lines == 0)

	## The deliberate corruption in this last check logs errors on purpose, hence it runs after.
	_legacy_load_check()
	SaveManager.delete_save()
	print("=== Soak test finished: %s ===" % ("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit()


func _random_action() -> void:
	var tank := _main.current_tank()
	var roll := randi() % 24
	match roll:
		0:
			_main.feed(true)
		1:
			_main.water_change()
		2:
			_main.set_tool(randi() % 4)
		3:
			tank.pinch(ShopManager.get_food("basic_flakes"), Vector2(randf() * 1100.0, 150.0 + randf() * 300.0))
		4, 5:
			_main.set_tool(TankController.Tool.SCRAPER if roll == 4 else TankController.Tool.VACUUM)
			for k in range(6):
				tank._tool_stroke(Vector2(randf() * 1100.0, 150.0 + randf() * 350.0))
			_main.set_tool(TankController.Tool.HAND)
		6:
			var species: Array = ShopManager.species_catalog.values()
			var pick: FishSpeciesData = species[randi() % species.size()]
			_main.buy_fish(pick.id, randi() % 2)
		7:
			var fish_list := tank.get_fish()
			if not fish_list.is_empty():
				_main.sell_specific_fish(fish_list[randi() % fish_list.size()])
		8:
			var fish_list2 := tank.get_fish()
			if not fish_list2.is_empty():
				_main.open_fish_detail(fish_list2[randi() % fish_list2.size()])
				await get_tree().process_frame
				_main.fish_detail.refresh()
				if randi() % 3 == 0:
					_main.fish_detail._on_auction_pressed()
				_main.close_panels()
		9:
			for tab in range(4):
				_main.open_business(tab)
				await get_tree().process_frame
				_main.business.refresh()
			_main.close_panels()
		10:
			_main.open_stats()
			for metric in StatsPanel.METRICS:
				_main.stats.show_metric(metric[0])
			_main.close_panels()
		11:
			_main.open_advisor()
			await get_tree().process_frame
			_main.close_panels()
		12:
			_main.open_shop(randi() % 4)
			await get_tree().process_frame
			_main.close_panels()
		13:
			_main.open_fish_panel()
			await get_tree().process_frame
			_main.close_panels()
		14:
			_main.open_tank_panel()
			await get_tree().process_frame
			_main.close_panels()
		15:
			_main.open_guide()
			_main.guide.select_tab(randi() % 3)
			await get_tree().process_frame
			_main.close_panels()
		16:
			TimeManager.cycle_speed()
		17:
			for order in Market.orders.duplicate():
				if Market.can_fulfill(order):
					Market.fulfill_order(int(order["id"]))
		18:
			if Market.contest_open():
				var entrants := Market.eligible_for_contest()
				if not entrants.is_empty():
					Market.enter_contest(entrants[0])
		19:
			var presets: Array = ShopManager.tank_preset_catalog.keys()
			_main.buy_tank(presets[randi() % presets.size()])
		20:
			_main.select_tank(randi() % 8)
		21:
			_main.treat_disease()
		22:
			_main.open_settings()
			await get_tree().process_frame
			_main.settings.refresh()
			_main.close_panels()
		23:
			Localization.set_language("en" if Localization.current_language == "he" else "he")
			await get_tree().process_frame
			await get_tree().process_frame
	## the language switch rebuilds the UI, so re-fetch nothing: _main keeps its panel references


func _save_and_reload() -> void:
	var cash := EconomyManager.cash
	var species_count: int = Progress.owned_species.size()
	var tank_count: int = TankRegistry.tanks.size()
	SaveManager.save_game()
	_check("The save file exists and verifies", SaveManager.has_save() and SaveManager._is_valid_save_file(SaveManager.SAVE_PATH))
	_check("Loading the save works", SaveManager.load_game())
	_check("Cash survives a reload (within offline income)", EconomyManager.cash >= cash - 5)
	_check("The collection and tank count survive a reload", Progress.owned_species.size() >= species_count and TankRegistry.tanks.size() == tank_count)


## A save written by 1.5 has none of the newer sections: it must still load.
func _legacy_load_check() -> void:
	SaveManager.save_game()
	var parsed = SaveManager._read_save_file(SaveManager.SAVE_PATH)
	for key in ["game_state", "progress", "market", "history"]:
		parsed.erase(key)
	parsed["economy"].erase("bonus_xp")
	for tank_data in parsed["tanks"].values():
		tank_data.erase("algae")
		tank_data.erase("mulm")
	var file := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(parsed))
	file.close()
	_check("An old-format save loads", SaveManager.load_game())
	_check("...as free play on normal", GameState.mode == GameState.Mode.FREE and GameState.difficulty == GameState.Difficulty.NORMAL)
	## A truncated main save falls back to the backup instead of loading nothing.
	SaveManager.save_game()
	SaveManager.save_game()
	var truncated := FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	truncated.store_string("{\"economy\": {\"cash\": 5")
	truncated.close()
	_check("A truncated save falls back to the backup", SaveManager.load_game())
	_check("...and the damaged file is kept aside", FileAccess.file_exists(SaveManager.CORRUPT_PATH))
