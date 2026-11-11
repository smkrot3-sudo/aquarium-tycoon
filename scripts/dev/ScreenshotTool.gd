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
	await _shot("02_new_game")
	_main.begin_new_game(GameState.Mode.CAREER, GameState.Difficulty.NORMAL)
	await _settle(10)
	await _shot("02b_welcome")
	_main.close_panels()
	await _settle(10)
	await _shot("03_hud_new_game")

	_main.open_shop(ShopPanel.Tab.EQUIPMENT)
	await _settle(10)
	await _shot("04_shop_equipment")
	_main.buy_equipment("basic_filter")
	_main.buy_equipment("basic_light")
	_main.open_shop(ShopPanel.Tab.FRESH)
	await _settle(10)
	await _shot("05_shop_fish_fresh")
	_main.open_shop(ShopPanel.Tab.SALT)
	await _settle(10)
	await _shot("06_shop_fish_salt_locked_tank")
	_main.buy_fish("guppy", FishController.Sex.MALE)
	_main.buy_fish("guppy", FishController.Sex.FEMALE)
	_main.buy_fish("cherry_shrimp")
	_main.open_shop(ShopPanel.Tab.FRESH)
	await _settle(10)
	await _shot("07_shop_fish_after_buying")
	_main.open_shop(ShopPanel.Tab.TANKS)
	await _settle(10)
	await _shot("08_shop_tanks")
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
	await _shot("09_hud_with_fish")

	var tank := _main.current_tank()
	if not tank.get_fish().is_empty():
		_main.open_fish_detail(tank.get_fish()[0])
		await _settle(10)
		await _shot("09b_fish_identity_card")
		_main.close_panels()

	_main.open_business(BusinessPanel.Tab.GOALS)
	await _settle(10)
	await _shot("09c_business_goals")
	Market.orders.append({"id": 990, "kind": "customer", "species_id": "guppy", "count": 1, "sex": -1, "adult_only": true, "min_health": 50, "reward": 14, "days_left": 6.0, "customer": 6})
	Market.orders.append({"id": 991, "kind": "wholesale", "species_id": "guppy", "count": 8, "sex": -1, "adult_only": false, "min_health": 40, "reward": 40, "days_left": 11.0, "customer": 3})
	_main.open_business(BusinessPanel.Tab.ORDERS)
	await _settle(10)
	await _shot("09d_business_orders")
	_main.open_business(BusinessPanel.Tab.COLLECTION)
	await _settle(10)
	await _shot("09e_business_collection")
	Market.orders.clear()
	_main.close_panels()

	_main.current_tank()._algae.grow(55.0)
	_main.current_tank()._mulm.grow(60.0)
	_main.set_tool(TankController.Tool.SCRAPER)
	await _settle(10)
	await _shot("09f_scraper_tool")
	_main.set_tool(TankController.Tool.HAND)

	for day in range(6):
		TimeManager.debug_fast_forward_days(1.0)
	_main.open_stats()
	await _settle(10)
	await _shot("09g_stats_graph")
	_main.open_advisor()
	await _settle(10)
	await _shot("09h_advisor")
	_main.close_panels()

	_main.open_fish_panel()
	await _settle(10)
	await _shot("10_my_fish")
	_main.open_tank_panel()
	await _settle(10)
	await _shot("11_tank_status")
	_main.open_guide()
	await _settle(10)
	await _shot("12_guide_how_to")
	_main.guide.select_tab(GuidePanel.Tab.FRESH)
	await _settle(10)
	await _shot("13_guide_fish_album")
	_main.guide.show_species(ShopManager.get_species("guppy"))
	await _settle(10)
	await _shot("14_guide_species_page")
	_main.guide.select_tab(GuidePanel.Tab.EQUIPMENT)
	await _settle(10)
	await _shot("15_guide_equipment")
	_main.open_settings()
	await _settle(10)
	await _shot("16_settings")
	_main.close_panels()

	_main.feed(true)
	await _settle(40)
	await _shot("17_feeding")

	EconomyManager.earn(900, "screenshot funds")
	_main.buy_equipment("basic_heater")
	_main.buy_equipment("air_stone")
	_main.buy_fish("neon_tetra")
	for i in range(5):
		_main.buy_fish("neon_tetra")
	_main.buy_fish("betta")
	_main.buy_fish("angelfish")
	await _settle(200)
	await _shot("18_hud_full_tank")

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
	_main.buy_fish("flame_angelfish")
	_main.buy_fish("yellow_tang")
	_main.buy_fish("seahorse")
	await _settle(200)
	await _shot("19_marine_tank")
	_main.guide.show_species(ShopManager.get_species("lionfish"))
	await _settle(10)
	await _shot("20_guide_marine_species_page")
	_main.close_panels()

	_main.buy_tank("huge_freshwater_tank")
	await _settle(10)
	await _shot("21_third_tank")

	GameState.mode = GameState.Mode.SANDBOX
	EconomyManager.apply_mode()
	for id in ["tank_25", "tank_60", "huge_freshwater_tank", "tank_450", "marine_120"]:
		_main.buy_tank(id)
		_main.buy_equipment("basic_light")
		_main.buy_equipment("basic_heater")
		if id == "marine_120":
			_main.buy_equipment("protein_skimmer")
			_main.buy_equipment("powerhead")
		elif id == "huge_freshwater_tank" or id == "tank_450":
			_main.buy_equipment("canister_filter")
			_main.buy_equipment("air_stone")
		else:
			_main.buy_equipment("basic_filter")
			_main.buy_equipment("air_stone")
		if id != "marine_120":
			for species_id in ["guppy", "platy", "neon_tetra", "angelfish", "goldfish", "oscar"]:
				_main.buy_fish(species_id, FishController.Sex.MALE)
				_main.buy_fish(species_id, FishController.Sex.FEMALE)
	_main.room.set_zoom(RoomView.Zoom.OVERVIEW)
	await _settle(90)
	await _shot("24_room_overview")
	_main.select_tank(3)
	_main.room.set_zoom(RoomView.Zoom.FOCUS)
	await _settle(90)
	await _shot("25_big_tank_focus")
	_main.room.set_zoom(RoomView.Zoom.CLOSE)
	await _settle(90)
	await _shot("26_big_tank_close")
	_main.select_tank(1)
	_main.room.set_zoom(RoomView.Zoom.FOCUS)
	await _settle(90)
	await _shot("27_small_tank_focus")
	_main.select_tank(5)
	await _settle(90)
	await _shot("28_marine_equipment")
	_main.select_tank(2)
	_main.room.set_zoom(RoomView.Zoom.CLOSE)
	await _settle(90)
	await _shot("29_close_equipment")
	_main.room.set_zoom(RoomView.Zoom.FOCUS)
	Localization.set_language("en")
	await _settle(20)
	await _shot("22_english_hud")
	_main.open_shop(ShopPanel.Tab.FRESH)
	await _settle(10)
	await _shot("23_english_shop")
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
