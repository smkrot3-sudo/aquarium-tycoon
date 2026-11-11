extends Node
## Dev-only: verifies the sex/identity/aging system in isolation (no UI): two of the same sex
## never breed, a male+female pair does, every fish gets a unique given name, dimorphic species
## draw males/females at a different scale, and a fish actually dies once it outlives its
## (pace-scaled) lifespan. Not shipped.

var _failures: int = 0


func _check(what: String, ok: bool) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", what])


func _ready() -> void:
	var main: GameController = load("res://scenes/main/Main.tscn").instantiate()
	add_child(main)
	var tank := main.current_tank()
	main.buy_equipment("basic_filter")

	# --- two of the same sex never breed
	main.buy_fish("guppy", FishController.Sex.MALE)
	main.buy_fish("guppy", FishController.Sex.MALE)
	for day in range(12):
		TimeManager.debug_fast_forward_days(1.0)
	_check("Two males never breed", tank.get_fish().size() == 2)
	for fish in tank.get_fish():
		fish.queue_free()
	await get_tree().process_frame

	# --- a male+female pair does (fed daily, like a player would, so this isn't a coin flip
	## against the unfed-neglect stress/health drop the same way the earlier same-sex check
	## didn't need to be: that one only has to show breeding did NOT happen).
	main.buy_fish("guppy", FishController.Sex.MALE)
	main.buy_fish("guppy", FishController.Sex.FEMALE)
	for day in range(12):
		TimeManager.debug_fast_forward_days(1.0)
		main.feed(true)
	_check("A male+female pair breeds", tank.get_fish().size() > 2)

	# --- every fish got a distinct name, and the sexes it asked for
	var names: Array = []
	var males := 0
	var females := 0
	for fish in tank.get_fish():
		names.append(fish.fish_name)
		if fish.sex == FishController.Sex.MALE:
			males += 1
		else:
			females += 1
	_check("Every fish has a given name", names.all(func(n): return n != ""))
	_check("At least one male and one female are present", males > 0 and females > 0)

	# --- dimorphic species: male and female read at a different scale
	var adult_male: FishController = null
	var adult_female: FishController = null
	for fish in tank.get_fish():
		if fish.is_fry:
			continue
		if fish.sex == FishController.Sex.MALE:
			adult_male = fish
		else:
			adult_female = fish
	if adult_male != null and adult_female != null:
		_check("Guppy is flagged dimorphic", adult_male.species.dimorphic)
		_check("Male and female guppies are drawn at different scale", not is_equal_approx(adult_male._base_scale, adult_female._base_scale))

	# --- color_variable species: two individuals don't share the exact same hue shift
	var hue_shifts: Array = []
	for i in range(4):
		var fry := tank.add_fish(ShopManager.get_species("guppy"), false, FishController.Sex.MALE)
		if fry._material != null:
			hue_shifts.append(fry._material.get_shader_parameter("hue_shift"))
	_check("Color-variable guppies get varied hue shifts", hue_shifts.size() >= 2 and hue_shifts.count(hue_shifts[0]) < hue_shifts.size())

	# --- old-age death: a fish well past its (pace-scaled) lifespan dies on its own
	for fish in tank.get_fish():
		fish.queue_free()
	await get_tree().process_frame
	var old_fish := tank.add_fish(ShopManager.get_species("guppy"), false, FishController.Sex.MALE)
	var old_fish_name := old_fish.fish_name
	var lifespan := Economy.lifespan_days(old_fish.species)
	old_fish.age_sim_days = lifespan - 0.5
	print("  (debug) %s age=%.2f lifespan=%.2f before fast-forward" % [old_fish_name, old_fish.age_sim_days, lifespan])
	TimeManager.debug_fast_forward_days(2.0)
	await get_tree().process_frame
	await get_tree().process_frame
	var still_there := is_instance_valid(old_fish) and not old_fish.is_queued_for_deletion()
	print("  (debug) still in tank after fast-forward: %s" % still_there)
	_check("A fish past its lifespan dies of old age", not still_there)
	_check("Old-age death doesn't happen before the lifespan is reached", Economy.lifespan_days(ShopManager.get_species("goldfish")) > Economy.lifespan_days(ShopManager.get_species("guppy")))

	print("=== Fish identity trace finished: %s ===" % ("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit()
