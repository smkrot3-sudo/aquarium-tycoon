extends Node
## Dev-only: the 50-level progression, real tank sizes, the room layout and camera, moving fish
## between tanks, fry being eaten by adults, and selling a tank. Not shipped.

var _failures: int = 0


func _check(what: String, ok: bool) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", what])


func _ready() -> void:
	# --- the level curve
	_check("Level 1 needs no experience", Levels.xp_for_level(1) == 0 and Levels.level_for_xp(0) == 1)
	_check("Level 2 comes quickly", Levels.level_for_xp(Levels.xp_for_level(2)) == 2 and Levels.level_for_xp(Levels.xp_for_level(2) - 1) == 1)
	var monotonic := true
	for level in range(2, Levels.MAX_LEVEL + 1):
		if Levels.xp_for_level(level) <= Levels.xp_for_level(level - 1):
			monotonic = false
	_check("Every level costs more than the one before", monotonic)
	_check("There are 50 levels", Levels.MAX_LEVEL == 50 and Levels.level_for_xp(Levels.xp_for_level(50) + 1000) == 50)
	_check("Old saves map to a sensible level", Levels.level_for_legacy_tier(0) == 1 and Levels.level_for_legacy_tier(5) > 25)

	# --- what unlocks when
	var saltwater_min := 99
	var freshwater_max := 0
	for species in ShopManager.species_catalog.values():
		if species.is_marine:
			saltwater_min = mini(saltwater_min, species.unlock_tier)
		else:
			freshwater_max = maxi(freshwater_max, species.unlock_tier)
	_check("Saltwater fish only unlock late (level 25+)", saltwater_min >= 25)
	_check("Freshwater fish are spread over many levels", freshwater_max >= 25)
	var marine_tank_min := 99
	for preset in ShopManager.tank_preset_catalog.values():
		if preset.tank_type == TankController.TankType.SALTWATER:
			marine_tank_min = mini(marine_tank_min, preset.unlock_tier)
	_check("The first saltwater tank is a late unlock", marine_tank_min >= 25)
	_check("There is a long ladder of tanks", ShopManager.tank_preset_catalog.size() >= 15)

	var main: GameController = load("res://scenes/main/Main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	main.begin_new_game(GameState.Mode.FREE, GameState.Difficulty.NORMAL)
	var tank := main.current_tank()
	_check("A new game starts at level 1", EconomyManager.unlock_tier == 1)
	_check("...with a small starter tank (10-20 L)", tank.tank_liters >= 10.0 and tank.tank_liters <= 20.0)
	main.buy_equipment("basic_filter")
	_check("A starter fish can live in the starter tank", main.fish_block_reason(ShopManager.get_species("guppy")) == "")
	_check("A higher-level fish is locked", main.fish_block_reason(ShopManager.get_species("betta")) != "")

	# --- level ups
	EconomyManager.add_xp(Levels.xp_for_level(6))
	_check("Experience raises the level", EconomyManager.unlock_tier >= 6)
	_check("...which unlocks the next fish", main.fish_block_reason(ShopManager.get_species("betta")) == "")

	# --- real sizes
	var nano := TankController.interior_size_for(15.0)
	var big := TankController.interior_size_for(300.0)
	_check("A big tank is really bigger than a nano tank", big.x > nano.x * 2.0 and big.y > nano.y * 1.5)
	_check("The tank's interior follows its liters", absf(tank._view_rect.size.x - TankController.interior_size_for(tank.tank_liters).x) < 1.0)

	# --- buying more tanks and the room layout
	EconomyManager.earn(5000, "test")
	EconomyManager.add_xp(Levels.xp_for_level(30))
	_check("A second tank can be bought", main.buy_tank("tank_25"))
	_check("...and a third", main.buy_tank("tank_60"))
	var tank_b: TankController = main.tanks()[1]
	var tank_c: TankController = main.tanks()[2]
	_check("Tanks stand side by side along the wall", tank_b.position.x > tank.position.x + tank._view_rect.size.x and tank_c.position.x > tank_b.position.x)
	var on_floor := true
	for t in [tank, tank_b, tank_c]:
		if absf(t.position.y + t.floor_local_y()) > 0.5:
			on_floor = false
	_check("Every tank stands on the same floor", on_floor)
	_check("A bigger tank sits higher above the floor", -tank_c.position.y > -tank.position.y)
	_check("Unowned slots are hidden", not main.tanks()[5].visible and main.tanks()[2].visible)
	_check("The tank price is remembered", tank_b.purchase_price == 30)

	# --- the camera
	main.room.set_zoom(RoomView.Zoom.FOCUS)
	main.room._update_target()
	var focus_scale: float = main.room._target_scale
	main.room.set_zoom(RoomView.Zoom.OVERVIEW)
	main.room._update_target()
	var overview_scale: float = main.room._target_scale
	main.room.set_zoom(RoomView.Zoom.CLOSE)
	main.room._update_target()
	var close_scale: float = main.room._target_scale
	_check("Overview is zoomed out, close-up zoomed in", overview_scale < focus_scale and close_scale > focus_scale)
	main.room.set_zoom(RoomView.Zoom.FOCUS)
	main.select_tank(1)
	_check("Selecting a tank makes it the current one", main.current_tank() == tank_b)
	main.select_tank(0)

	# --- moving fish
	main.buy_fish("guppy", FishController.Sex.MALE)
	main.buy_fish("guppy", FishController.Sex.FEMALE)
	var mover: FishController = tank.get_fish()[0]
	var name_before := mover.fish_name
	_check("A fish can be moved to another tank", main.move_fish([mover], 1) == 1)
	_check("...it now lives there", mover.get_parent() == tank_b and tank_b.get_fish().has(mover) and not tank.get_fish().has(mover))
	_check("...with its identity intact", mover.fish_name == name_before)
	_check("...and its death is reported by the new tank", mover.died.is_connected(tank_b._on_fish_died) and not mover.died.is_connected(tank._on_fish_died))
	_check("...inside the new tank's water", tank_b.get_swim_rect().grow(5.0).has_point(mover.position) or tank_b.get_floor_rect().grow(5.0).has_point(mover.position))
	var clown := tank.add_fish(ShopManager.get_species("clownfish"))
	_check("A saltwater fish cannot go into a freshwater tank", main.move_block_reason(clown, tank_b) != "")
	_check("...so moving it does nothing", main.move_fish([clown], 1) == 0 and clown.get_parent() == tank)
	clown.queue_free()
	await get_tree().process_frame

	# --- fry are eaten by adults, and safe in a tank of their own
	for fish in tank_b.get_fish():
		fish.queue_free()
	await get_tree().process_frame
	var adult_tank := tank
	var nursery := tank_b
	for i in range(2):
		adult_tank.add_fish(ShopManager.get_species("guppy"), false, i)
	var fry_here: Array = []
	var fry_there: Array = []
	for i in range(30):
		fry_here.append(adult_tank.add_fish(ShopManager.get_species("guppy"), true))
		fry_there.append(nursery.add_fish(ShopManager.get_species("guppy"), true))
	var eaten_signals := [0]
	adult_tank.fry_eaten.connect(func(count): eaten_signals[0] += count)
	for day in range(12):
		adult_tank._fry_predation()
		nursery._fry_predation()
		await get_tree().process_frame
	_check("Adults eat some of the fry they live with", eaten_signals[0] > 0 and adult_tank.fry_count() < 30)
	_check("Fry in a tank of their own are left alone", nursery.fry_count() == 30)
	_check("Moving the fry out works", main.move_fish(adult_tank.get_fish().filter(func(f): return f.is_fry), 1) >= 0)

	# --- selling a tank
	var cash_before := EconomyManager.cash
	_check("A tank with fish in it can't be sold", not main.sell_tank(1))
	for fish in tank_b.get_fish():
		fish.queue_free()
	await get_tree().process_frame
	var expected := main.tank_sale_value(tank_b)
	_check("A sold tank pays back part of its price", expected > 0 and expected < tank_b.purchase_price + 20)
	_check("An empty tank can be sold", main.sell_tank(1))
	_check("...for that money", EconomyManager.cash >= cash_before + expected)
	_check("...and its slot is free again", main.tanks()[1].locked and not main.tanks()[1].visible and main.owned_tank_count() == 2)
	_check("The room lays out the remaining tanks", absf(main.tanks()[2].position.x - (main.tanks()[0].position.x + main.tanks()[0]._view_rect.size.x)) < 3000.0)
	for fish in tank.get_fish():
		fish.queue_free()
	await get_tree().process_frame
	_check("The only tank can't be sold", main.owned_tank_count() == 2 and main.sell_tank(2) and not main.sell_tank(0))

	# --- males and females are drawn differently
	var test_tank: TankController = main.tanks()[0]
	var f_guppy := test_tank.add_fish(ShopManager.get_species("guppy"), false, FishController.Sex.FEMALE)
	var m_guppy := test_tank.add_fish(ShopManager.get_species("guppy"), false, FishController.Sex.MALE)
	var f_path: String = f_guppy._visual_root.get_node("Sprite").texture.resource_path
	var m_path: String = m_guppy._visual_root.get_node("Sprite").texture.resource_path
	_check("A female guppy has her own plain picture", f_path.ends_with("guppy_f.png") and m_path.ends_with("guppy.png"))
	var f_sword := test_tank.add_fish(ShopManager.get_species("swordtail"), false, FishController.Sex.FEMALE)
	_check("A female swordtail is drawn without the sword", f_sword._visual_root.get_node("Sprite").texture.resource_path.ends_with("swordtail_f.png"))
	var f_betta := test_tank.add_fish(ShopManager.get_species("betta"), false, FishController.Sex.FEMALE)
	_check("A female betta isn't drawn like the male", f_betta._visual_root.get_node("Sprite").texture.resource_path.ends_with("betta_f.png"))
	var f_goldfish := test_tank.add_fish(ShopManager.get_species("goldfish"), false, FishController.Sex.FEMALE)
	_check("Species without a female picture keep the shared one", f_goldfish._visual_root.get_node("Sprite").texture.resource_path.ends_with("goldfish.png"))
	var saved_female_count := 0
	for fish in test_tank.get_fish():
		if fish.species.id == "guppy" and fish.sex == FishController.Sex.FEMALE:
			saved_female_count += 1
	SaveManager.save_game()

	# --- a saved game keeps all of it
	SaveManager.save_game()
	var liters_before: float = main.tanks()[0].tank_liters
	main.tanks()[0].tank_liters = 999.0
	_check("A save loads", SaveManager.load_game())
	var reloaded_ok := true
	for fish in main.tanks()[0].get_fish():
		var path: String = fish._visual_root.get_node("Sprite").texture.resource_path
		if fish.species.id == "guppy" and (fish.sex == FishController.Sex.FEMALE) != path.ends_with("guppy_f.png"):
			reloaded_ok = false
	_check("Every reloaded fish is drawn as its own sex", reloaded_ok)
	_check("Tank sizes survive a reload", absf(main.tanks()[0].tank_liters - liters_before) < 0.1)
	_check("The level survives a reload", EconomyManager.unlock_tier >= 30)

	SaveManager.delete_save()
	print("=== Room trace finished: %s ===" % ("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit()
