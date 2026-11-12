extends Node
## Dev-only: pregnancy and birth for livebearers and mouthbrooders, and visible eggs for
## egg-layers (laying, guarding, being eaten, fungus, hatching, moving, saving). Not shipped.

var _failures: int = 0
var _dir: String = ""
var _main: GameController
var _toasts: Array = []


func _check(what: String, ok: bool) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", what])


func _settle(frames: int) -> void:
	for i in range(frames):
		await get_tree().process_frame


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_dir, shot_name])


func _hours(count: int) -> void:
	for i in range(count):
		TimeManager.sim_minutes_total += 60.0
		TimeManager.sim_tick.emit(1.0)


func _pair(tank: TankController, species_id: String) -> Array:
	var species := ShopManager.get_species(species_id)
	var male := tank.add_fish(species, false, FishController.Sex.MALE)
	var female := tank.add_fish(species, false, FishController.Sex.FEMALE)
	for fish in [male, female]:
		fish.age_sim_days = Economy.maturity_days(species) * 2.0
		fish.size_cm = species.max_size_cm
		fish.is_fry = false
		fish.hunger = 100.0
	female.breeding_cooldown_remaining = 0.0
	male.breeding_cooldown_remaining = 0.0
	return [male, female]


func _keep_healthy(tank: TankController) -> void:
	tank.ammonia = 0.0
	tank.nitrite = 0.0
	tank.nitrate = 0.0
	for fish in tank.get_fish():
		fish.hunger = 100.0
		fish.health = 100.0


func _ready() -> void:
	_dir = OS.get_environment("SHOT_DIR")
	if _dir == "":
		_dir = OS.get_user_data_dir()
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
	_main.toast_view.visible = true
	var tank: TankController = _main.current_tank()
	_main.buy_tank("tank_150")
	_main.buy_tank("tank_150")
	var nursery_index := 2
	_main.select_tank(1)
	var big: TankController = _main.current_tank()
	_main.buy_equipment("canister_filter")
	_main.buy_equipment("basic_heater")
	var births: Array = []
	var pregnancies: Array = []
	var laid: Array = []
	var hatched: Array = []
	var lost: Array = []
	big.fish_gave_birth.connect(func(f, n, m): births.append([f, n, m]))
	big.fish_became_pregnant.connect(func(f): pregnancies.append(f))
	big.eggs_laid.connect(func(s, n): laid.append(n))
	big.eggs_hatched.connect(func(s, n): hatched.append(n))
	big.eggs_lost.connect(func(s, r): lost.append(r))

	# --- livebearer pregnancy and birth
	var guppies := _pair(big, "guppy")
	var mother: FishController = guppies[1]
	var guppy_count: int = big.get_fish().size()
	var bulge_seen := 0.0
	var got_pregnant := false
	for hour in range(24 * 6):
		_hours(1)
		_keep_healthy(big)
		if mother.is_pregnant() and not got_pregnant:
			got_pregnant = true
			_check("A mated guppy becomes pregnant", true)
			_check("...and the game says so", pregnancies.has(mother))
			_check("...with a due date", mother.pregnancy_left > 0.5 and mother.pregnancy_total > 1.0)
		if mother.is_pregnant():
			bulge_seen = maxf(bulge_seen, mother.pregnancy_bulge())
		if not births.is_empty():
			break
	_check("She actually got pregnant", got_pregnant)
	_check("Her belly grew while she was pregnant", bulge_seen > 0.6)
	_check("She gave birth", not births.is_empty())
	_check("...to live fry", births.size() > 0 and births[0][1] > 0 and big.fry_count() >= births[0][1])
	_check("...and is no longer pregnant", not mother.is_pregnant())
	_check("...with a rest period before the next batch", mother.breeding_cooldown_remaining > 0.5)

	# --- pregnancy is saved
	var again := false
	for hour in range(24 * 8):
		_hours(1)
		_keep_healthy(big)
		if mother.is_pregnant() and mother.pregnancy_progress() > 0.3:
			again = true
			break
	_check("She can get pregnant again", again)
	_main.open_fish_detail(mother)
	await _settle(5)
	_check("The fish card shows the pregnancy", _main.fish_detail.visible)
	await _shot("fish_card_pregnant")
	_main.close_panels()
	await _shot("pregnant_guppy")
	SaveManager.save_game()
	var left_before := mother.pregnancy_left
	var name_before := mother.fish_name
	mother.pregnancy_total = 0.0
	mother.pregnancy_left = 0.0
	_check("The save loads", SaveManager.load_game())
	await _settle(5)
	big = _main.tanks()[1]
	var reloaded: FishController = null
	for fish in big.get_fish():
		if fish.fish_name == name_before:
			reloaded = fish
	_check("A pregnancy survives a reload", reloaded != null and reloaded.is_pregnant() and absf(reloaded.pregnancy_left - left_before) < 0.01)
	for f in big.get_fish():
		f.queue_free()
	await _settle(3)

	# --- mouthbrooder
	big.fish_gave_birth.connect(func(f, n, m): births.append([f, n, m]))
	births.clear()
	var cichlids := _pair(big, "yellow_lab_cichlid")
	var cmother: FishController = cichlids[1]
	var mouth := false
	for hour in range(24 * 10):
		_hours(1)
		_keep_healthy(big)
		if cmother.is_mouthbrooding():
			mouth = true
			cmother.hunger = 50.0
			big.feed(ShopManager.get_food("basic_flakes"))
			_check("A mouthbrooder carrying eggs doesn't eat", cmother.hunger == 50.0)
			break
	_check("A cichlid female carries the eggs in her mouth", mouth)
	for hour in range(24 * 10):
		_hours(1)
		_keep_healthy(big)
		if not births.is_empty():
			break
	print("births: ", births.map(func(b): return [b[0].fish_name, b[1], b[2]]), " strain: ", cmother.pregnancy_strain)
	_check("...and releases live fry", not births.is_empty() and births[0][2] == true and births[0][1] > 0)
	for f in big.get_fish():
		f.queue_free()
	await _settle(3)

	# --- egg-layers: a betta's bubble nest, guarded by the pair
	laid.clear()
	var bettas := _pair(big, "betta")
	var nest := false
	for hour in range(24 * 8):
		_hours(1)
		_keep_healthy(big)
		if not big.pending_egg_batches.is_empty():
			nest = true
			break
	_check("Betta lay eggs", nest and not laid.is_empty())
	await _settle(5)
	if nest:
		var batch: Dictionary = big.pending_egg_batches[0]
		_check("The eggs are on screen", big._egg_nodes.has(int(batch["id"])))
		_check("...at the surface (a bubble nest)", float(batch["y"]) < big.get_swim_rect().position.y + 80.0)
		_check("...and the parents guard them", bool(batch["guard"]) and bool(big.pending_egg_batches[0]["guarded_now"]) or big.get_fish().size() >= 2)
		var point := Vector2(float(batch["x"]), float(batch["y"]))
		_check("A tap on the eggs finds them", not big.egg_batch_at(point, 10.0).is_empty())
		_main.open_egg_info(big, int(batch["id"]))
		await _settle(5)
		_check("The egg card opens", _main.egg_panel.visible)
		await _shot("egg_card")
		_main.close_panels()
		await _shot("betta_nest")
		_check("Hatching: the fry swim out", await _hatch_check(big, int(batch["id"]), hatched))
	for f in big.get_fish():
		f.queue_free()
	await _settle(3)

	# --- eggs get eaten when nobody guards them
	lost.clear()
	hatched.clear()
	var barb_species := ShopManager.get_species("tiger_barb")
	big.schedule_egg_batch(barb_species, 30, 3.0)
	for i in range(5):
		var eater := big.add_fish(ShopManager.get_species("goldfish"), false)
		eater.age_sim_days = 500.0
	await _settle(5)
	await _shot("scatter_eggs")
	for hour in range(24 * 4):
		_hours(1)
		_keep_healthy(big)
		if big.pending_egg_batches.is_empty():
			break
	_check("Unguarded eggs get eaten by tankmates", lost.has("eaten") or (hatched.size() > 0 and hatched[0] < 15))
	for f in big.get_fish():
		f.queue_free()
	await _settle(3)

	# --- dirty water makes eggs rot, white eggs can be picked out
	lost.clear()
	hatched.clear()
	big.schedule_egg_batch(barb_species, 30, 3.0)
	var duds_before: float = float(big.pending_egg_batches[0]["duds"])
	for hour in range(24):
		big.ammonia = 1.5
		_hours(1)
	var dirty: Dictionary = big.pending_egg_batches[0] if not big.pending_egg_batches.is_empty() else {}
	_check("Eggs in dirty water go white", dirty.is_empty() or float(dirty["duds"]) > duds_before + 3.0 or not lost.is_empty())
	if not dirty.is_empty():
		big.remove_dud_eggs(int(dirty["id"]))
		_check("White eggs can be removed", float(big.find_egg_batch(int(dirty["id"]))["duds"]) == 0.0)
	for batch in big.pending_egg_batches.duplicate():
		big.remove_egg_batch(int(batch["id"]))
	_check("A clutch can be thrown away", big.pending_egg_batches.is_empty())

	# --- moving eggs to a nursery tank, and keeping them safe there
	big.ammonia = 0.0
	big.schedule_egg_batch(barb_species, 20, 2.0)
	var nursery: TankController = _main.tanks()[nursery_index]
	var move_id := int(big.pending_egg_batches[0]["id"])
	_check("Eggs can be moved to another tank", _main.move_eggs(big, move_id, nursery_index))
	_check("...they leave the old tank and appear in the new one", big.pending_egg_batches.is_empty() and nursery.pending_egg_batches.size() == 1)
	_check("A freshwater clutch can't go in the saltwater slot rules", _main.egg_move_block_reason(barb_species, nursery) == "")
	hatched.clear()
	nursery.eggs_hatched.connect(func(s, n): hatched.append(n))
	nursery.ammonia = 0.0
	for hour in range(24 * 3):
		_hours(1)
		nursery.ammonia = 0.0
		nursery.nitrite = 0.0
		nursery.nitrate = 0.0
		if nursery.pending_egg_batches.is_empty():
			break
	_check("Eggs in the empty nursery hatch", not hatched.is_empty() and hatched[0] > 0 and nursery.fry_count() > 0)

	# --- eggs survive saving
	big.schedule_egg_batch(barb_species, 18, 4.0)
	var saved_id := int(big.pending_egg_batches[0]["id"])
	var saved_remaining := float(big.pending_egg_batches[0]["remaining_days"])
	SaveManager.save_game()
	big.remove_egg_batch(saved_id)
	_check("The save loads again", SaveManager.load_game())
	await _settle(5)
	big = _main.tanks()[1]
	_check("Eggs survive a reload", big.pending_egg_batches.size() == 1 and absf(float(big.pending_egg_batches[0]["remaining_days"]) - saved_remaining) < 0.01)
	_check("...and are drawn again", big._egg_nodes.has(int(big.pending_egg_batches[0]["id"])))

	# --- an old save's egg format still loads
	big.from_save_dict(big.to_save_dict().merged({"pending_egg_batches": [{"species_id": "tiger_barb", "count": 6, "remaining_days": 1.0}]}, true))
	_check("An old-format egg batch is upgraded", big.pending_egg_batches.size() == 1 and float(big.pending_egg_batches[0]["viable"]) == 6.0)

	SaveManager.delete_save()
	print("=== Breeding trace finished: %s ===" % ("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit()


func _hatch_check(tank: TankController, batch_id: int, hatched: Array) -> bool:
	var fry_before: int = tank.fry_count()
	for hour in range(24 * 6):
		_hours(1)
		_keep_healthy(tank)
		if tank.find_egg_batch(batch_id).is_empty():
			break
	await _settle(2)
	return tank.fry_count() > fry_before and not hatched.is_empty()
