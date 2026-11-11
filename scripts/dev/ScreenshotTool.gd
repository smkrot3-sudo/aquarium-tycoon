extends Node
## Dev-only: boots the real Main scene and walks through every screen of the phone UI, saving
## a PNG of each. Run windowed (not --headless) with a phone-shaped --resolution. Output folder
## comes from the SHOT_DIR environment variable. Not part of the shipped game.

var _dir: String = ""
var _main: GameController


func _ready() -> void:
	_dir = OS.get_environment("SHOT_DIR")
	if _dir == "":
		_dir = OS.get_user_data_dir()
	_main = load("res://scenes/main/Main.tscn").instantiate()
	add_child(_main)
	await _settle(20)
	await _shot("01_home")

	_main.start_game()
	await _settle(10)
	await _shot("02_welcome")
	_main.close_panels()
	await _settle(10)
	await _shot("03_hud_new_game")

	_main.open_shop(ShopPanel.Tab.EQUIPMENT)
	await _settle(10)
	await _shot("04_shop_equipment")
	_main.buy_equipment("basic_filter")
	_main.buy_equipment("basic_light")
	_main.open_shop(ShopPanel.Tab.FISH)
	await _settle(10)
	await _shot("05_shop_fish")
	_main.buy_fish("guppy")
	_main.buy_fish("guppy")
	_main.buy_fish("cherry_shrimp")
	await _settle(10)
	await _shot("06_shop_fish_after_buying")
	_main.open_shop(ShopPanel.Tab.TANKS)
	await _settle(10)
	await _shot("07_shop_tanks")
	_main.close_panels()

	## A few in-game days so there are fry, a maturing filter and hungry fish to look at.
	for day in range(5):
		for hour in range(24):
			TimeManager.sim_minutes_total += 60.0
			TimeManager.sim_tick.emit(1.0)
		TimeManager.sim_day_elapsed.emit(TimeManager.current_day())
		if day < 3:
			_main.feed(true)
	await _settle(150)
	await _shot("08_hud_with_fish")

	_main.open_fish_panel()
	await _settle(10)
	await _shot("09_my_fish")
	_main.open_tank_panel()
	await _settle(10)
	await _shot("10_tank_status")
	_main.open_guide()
	await _settle(10)
	await _shot("11_guide_how_to")
	_main.guide.select_tab(GuidePanel.Tab.FISH)
	await _settle(10)
	await _shot("12_guide_fish")
	_main.open_settings()
	await _settle(10)
	await _shot("13_settings")
	_main.close_panels()

	_main.feed(true)
	await _settle(40)
	await _shot("14_feeding")

	EconomyManager.earn(400, "screenshot funds")
	_main.buy_equipment("basic_heater")
	_main.buy_equipment("air_stone")
	_main.buy_fish("neon_tetra")
	for i in range(5):
		_main.buy_fish("neon_tetra")
	_main.buy_fish("betta")
	await _settle(200)
	await _shot("15_hud_full_tank")

	_main.buy_tank("marine_reef_tank")
	_main.buy_equipment("protein_skimmer")
	_main.buy_equipment("led_light")
	_main.buy_equipment("basic_heater")
	_main.buy_equipment("powerhead")
	_main.buy_fish("clownfish")
	_main.buy_fish("clownfish")
	for i in range(6):
		_main.buy_fish("blue_green_chromis")
	_main.buy_fish("cleaner_shrimp")
	await _settle(200)
	await _shot("16_marine_tank")

	Localization.set_language("en")
	await _settle(20)
	await _shot("17_english_hud")
	_main.open_shop(ShopPanel.Tab.FISH)
	await _settle(10)
	await _shot("18_english_shop")
	get_tree().quit()


func _settle(frames: int) -> void:
	for i in range(frames):
		await get_tree().process_frame


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [_dir, shot_name]
	var err := image.save_png(path)
	print("shot %s -> %s (%s) %s" % [shot_name, path, error_string(err), image.get_size()])
