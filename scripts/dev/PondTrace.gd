extends Node
## Dev-only: the 1.8 pond and weather, and the new species. Run windowed (screenshots go to the
## SHOT_DIR environment variable). Not shipped.

var _failures: int = 0
var _dir: String = ""
var _main: GameController


func _check(what: String, ok: bool) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", what])


func _settle(frames: int) -> void:
	for i in range(frames):
		await get_tree().process_frame


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png("%s/%s.png" % [_dir, shot_name])


func _day(feed: bool = false) -> void:
	for hour in range(24):
		TimeManager.sim_minutes_total += 60.0
		TimeManager.sim_tick.emit(1.0)
	TimeManager.sim_day_elapsed.emit(TimeManager.current_day())
	if feed:
		_main.feed(true)


func _ready() -> void:
	_dir = OS.get_environment("SHOT_DIR")
	if _dir == "":
		_dir = OS.get_user_data_dir()

	# --- data
	var new_ids := ["peacock_cichlid", "red_zebra_cichlid", "frontosa", "silver_arowana", "ocellate_stingray", "pea_puffer", "golden_wonder_killifish", "blue_gularis_killifish", "red_tailed_shark", "rainbow_shark", "clown_loach", "blue_crayfish", "porcupine_puffer", "dogface_puffer", "maxima_clam", "sally_lightfoot_crab", "koi", "comet_goldfish", "shubunkin", "golden_orfe"]
	var all_there := true
	var all_art := true
	var all_text := true
	for id in new_ids:
		var species: FishSpeciesData = ShopManager.get_species(id)
		if species == null:
			all_there = false
			print("missing species ", id)
			continue
		if not ResourceLoader.exists("res://assets/fish/%s.png" % id):
			all_art = false
			print("missing art ", id)
		if Localization.t("sp_%s" % id) == "sp_%s" % id or Localization.t("lore_sp_%s" % id) == "lore_sp_%s" % id:
			all_text = false
			print("missing text ", id)
	_check("All 20 new species load", all_there)
	_check("...each with its picture", all_art)
	_check("...and its encyclopedia text", all_text)
	_check("Koi is a pond-only fish", ShopManager.get_species("koi").habitat == 1)
	_check("Goldfish can live in either", ShopManager.get_species("goldfish").habitat == 2)
	var pond_presets := 0
	for preset in ShopManager.tank_preset_catalog.values():
		if preset.tank_type == TankController.TankType.POND:
			pond_presets += 1
	_check("There are pond sizes to buy", pond_presets == 4)
	_check("The heron net exists", ShopManager.get_equipment("pond_net") != null)

	_main = load("res://scenes/main/Main.tscn").instantiate()
	add_child(_main)
	await _settle(5)
	_main.begin_new_game(GameState.Mode.FREE, GameState.Difficulty.NORMAL)
	_main.close_panels()
	GameState.mode = GameState.Mode.SANDBOX
	EconomyManager.apply_mode()
	EconomyManager.add_xp(Levels.xp_for_level(45))
	EconomyManager.cash = 100000
	Progress.loading = true

	# --- buying and rules
	_check("A pond can be bought", _main.buy_tank("pond_4000"))
	var pond: TankController = _main.current_tank()
	_check("The pond is a pond", pond.is_pond() and pond.tank_liters == 4000.0)
	_check("The pond's width follows its volume", pond._view_rect.size.x > TankController.interior_size_for(1000.0).x)
	_check("Heaters can't be bought for a pond", _main.equipment_block_reason(ShopManager.get_equipment("basic_heater")) != "")
	_check("A net can be bought for a pond", _main.equipment_block_reason(ShopManager.get_equipment("pond_net")) == "")
	_check("Tropical fish don't go in a pond", _main.fish_block_reason(ShopManager.get_species("guppy")) != "")
	_check("Koi can go in the pond", _main.fish_block_reason(ShopManager.get_species("koi")) == "")
	_main.select_tank(0)
	_check("Koi can't go in an aquarium", _main.fish_block_reason(ShopManager.get_species("koi")) != "")
	_check("A heron net is for ponds only", _main.equipment_block_reason(ShopManager.get_equipment("pond_net")) != "")
	_main.select_tank(1)
	pond = _main.current_tank()
	_check("The room puts the pond in the garden", _main.room._has_garden and pond.position.x > _main.tanks()[0].position.x)

	_main.buy_equipment("canister_filter")
	_main.buy_equipment("air_stone")
	for i in range(4):
		_main.buy_fish("koi", FishController.Sex.MALE if i % 2 == 0 else FishController.Sex.FEMALE)
	for i in range(3):
		_main.buy_fish("comet_goldfish")
	_main.buy_fish("shubunkin")
	_check("The pond holds fish", pond.get_fish().size() == 8)

	# --- weather and seasons
	Weather.set_kind(Weather.Kind.SUNNY)
	TimeManager.current_season = TimeManager.Season.SPRING
	pond.temperature = 14.0
	await _settle(60)
	_main.room.set_zoom(RoomView.Zoom.FOCUS)
	await _settle(90)
	await _shot("pond_spring_focus")
	Weather.set_kind(Weather.Kind.RAIN)
	await _settle(60)
	await _shot("pond_rain")
	Weather.set_kind(Weather.Kind.STORM)
	await _settle(60)
	await _shot("pond_storm")
	_main.buy_equipment("pond_net")
	_check("The net is installed", pond.has_net)
	Weather.set_kind(Weather.Kind.SUNNY)
	await _settle(60)
	await _shot("pond_net")

	# --- winter: ice, no feeding, the fish survive
	TimeManager.current_season = TimeManager.Season.WINTER
	Weather.set_kind(Weather.Kind.SNOW)
	for day in range(8):
		_day()
	_check("The winter pond cools down", pond.temperature < 8.0)
	await _settle(60)
	_check("...and the hardy fish live through it", pond.get_fish().size() >= 7)
	pond.perform_water_change(1.0)
	pond.temperature = 2.5
	pond.simulate_hours(0.01)
	_check("A pond at 2.5 degrees is iced over", pond.is_frozen())
	_check("...and can't be fed", not _main.feed(true))
	_check("...but a tip says so", _main.current_tip()["text"] == Localization.t("tip_pond_frozen"))
	await _settle(60)
	await _shot("pond_winter_ice")

	# --- summer heat is survivable with aeration
	TimeManager.current_season = TimeManager.Season.SUMMER
	Weather.set_kind(Weather.Kind.HEAT)
	for day in range(6):
		_day(true)
	_check("Summer water warms up", pond.temperature > 15.0)
	await _settle(60)
	await _shot("pond_summer_heat")
	_check("The pond fish are still alive after summer care", pond.get_fish().size() >= 6)

	# --- a heron takes fish from an open pond, never from a netted one
	pond.has_net = false
	var before := pond.get_fish().size()
	for day in range(300):
		pond._heron_visit()
	await _settle(2)
	_check("An open pond loses fish to the heron", pond.get_fish().size() < before)
	pond.has_net = true
	var netted := pond.get_fish().size()
	for day in range(300):
		pond._heron_visit()
	await _settle(2)
	_check("A netted pond doesn't", pond.get_fish().size() == netted)

	# --- the garden in the overview
	_main.room.set_zoom(RoomView.Zoom.OVERVIEW)
	TimeManager.current_season = TimeManager.Season.SPRING
	Weather.set_kind(Weather.Kind.CLOUDY)
	await _settle(90)
	await _shot("room_overview_with_garden")

	# --- aquarium-only species in an aquarium (a few of the new ones)
	_main.select_tank(0)
	_main.room.set_zoom(RoomView.Zoom.FOCUS)
	await _settle(60)
	_check("A pea puffer can't live in the starter tank (size)", _main.fish_block_reason(ShopManager.get_species("pea_puffer")) != "")

	# --- the save keeps ponds, nets and weather
	Weather.set_kind(Weather.Kind.STORM)
	SaveManager.save_game()
	pond.has_net = false
	pond.tank_liters = 99.0
	Weather.set_kind(Weather.Kind.SUNNY)
	_check("The save loads", SaveManager.load_game())
	await _settle(5)
	var reloaded: TankController = _main.tanks()[1]
	_check("The pond survives a reload", reloaded.is_pond() and reloaded.tank_liters == 4000.0)
	_check("...with its net", reloaded.has_net)
	_check("...and the weather is remembered", Weather.kind == Weather.Kind.STORM)

	SaveManager.delete_save()
	print("=== Pond trace finished: %s ===" % ("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit()
