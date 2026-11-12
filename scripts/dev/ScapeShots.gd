extends Node
## Dev-only: screenshots of several tanks (each with its own scenery) with fish in them.
var _main: GameController
var _dir := ""

func _settle(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_dir, name])

func _ready() -> void:
	_dir = OS.get_environment("SHOT_DIR")
	_main = load("res://scenes/main/Main.tscn").instantiate()
	add_child(_main)
	await _settle(5)
	_main.begin_new_game(GameState.Mode.FREE, GameState.Difficulty.NORMAL)
	_main.close_panels()
	GameState.mode = GameState.Mode.SANDBOX
	EconomyManager.apply_mode()
	EconomyManager.add_xp(Levels.xp_for_level(50))
	EconomyManager.cash = 1000000
	Progress.loading = true
	var plans := [["tank_60", ["guppy", "platy", "neon_tetra", "molly", "betta", "cory_catfish"]], ["tank_150", ["yellow_lab_cichlid", "peacock_cichlid", "red_zebra_cichlid", "clown_loach"]], ["huge_freshwater_tank", ["angelfish", "discus", "goldfish", "oscar", "swordtail"]], ["marine_120", ["clownfish", "blue_tang", "yellow_tang", "royal_gramma", "blue_green_chromis"]]]
	var index := 0
	for plan in plans:
		_main.buy_tank(plan[0])
		_main.buy_equipment("basic_filter")
		_main.buy_equipment("basic_light")
		for species_id in plan[1]:
			_main.buy_fish(species_id, FishController.Sex.MALE)
			_main.buy_fish(species_id, FishController.Sex.FEMALE)
		index += 1
		_main.room.set_zoom(RoomView.Zoom.FOCUS)
		await _settle(90)
		await _shot("scape_%d_%s" % [index, plan[0]])
	_main.select_tank(0)
	await _settle(60)
	await _shot("scape_0_starter")
	_main.room.set_zoom(RoomView.Zoom.OVERVIEW)
	await _settle(90)
	await _shot("scape_overview")
	get_tree().quit()
