extends Node
## Dev-only headless integration smoke test. Temporarily set as the project's main scene
## to exercise the MVP loop (buy/feed/breed/sell/save) through normal autoload startup,
## then reverted. Not part of the shipped game.

func _ready() -> void:
	var main_scene: PackedScene = load("res://scenes/main/Main.tscn")
	var main: Node = main_scene.instantiate()
	add_child(main)

	print("=== Initial state ===")
	print("Cash: ", EconomyManager.cash)

	main._on_buy_equipment("basic_heater")
	main._on_buy_equipment("basic_filter")
	main._on_buy_equipment("basic_light")
	print("=== After buying heater+filter+light ===")
	print("Cash: ", EconomyManager.cash)

	## Explicit male+female so breeding is deterministic to watch in this log (buy_fish's
	## default is a random sex, which would make "should have produced fry" a coin flip).
	main.buy_fish("guppy", FishController.Sex.MALE)
	main.buy_fish("guppy", FishController.Sex.FEMALE)
	main._on_buy_fish("cherry_shrimp")
	print("=== After buying 2 guppies + 1 shrimp ===")
	print("Cash: ", EconomyManager.cash, " | Fish count: ", main.current_tank().get_fish().size())

	for fish in main.current_tank().get_fish():
		print("  - %s (fry=%s) hunger=%.1f health=%.1f size=%.2f" % [fish.species.display_name, fish.is_fry, fish.hunger, fish.health, fish.size_cm])

	print("=== Fast-forwarding 20 sim-days (daily feeding, water change every 4 days) ===")
	for day in range(20):
		TimeManager.debug_fast_forward_days(1.0)
		main._on_feed()
		if day % 4 == 3:
			main._on_water_change()
	var fry_count: int = main.current_tank().fry_count()
	print("Adults: %d | Fry: %d (fry must grow into adults over time)" % [main.current_tank().get_fish().size() - fry_count, fry_count])

	print("Tank state -> temp=%.2f ammonia=%.3f nitrite=%.3f nitrate=%.2f filter_maturity=%.1f" % [main.current_tank().temperature, main.current_tank().ammonia, main.current_tank().nitrite, main.current_tank().nitrate, main.current_tank().filter_maturity])
	print("Fish count after 20 days (breeding should have produced fry): ", main.current_tank().get_fish().size())
	print("Cash: ", EconomyManager.cash)

	print("=== Water change ===")
	main._on_water_change()
	print("Ammonia after water change: %.3f" % main.current_tank().ammonia)

	print("=== Selling one fish ===")
	var before_cash: int = EconomyManager.cash
	main._on_sell_one()
	print("Cash before/after sell: %d -> %d | Fish count now: %d" % [before_cash, EconomyManager.cash, main.current_tank().get_fish().size()])

	print("=== Phase 2 feature checks ===")
	print("Lifetime earnings: %d | Unlock tier: %d" % [EconomyManager.lifetime_earnings, EconomyManager.unlock_tier])
	while EconomyManager.unlock_tier < 2 and not main.current_tank().get_fish().is_empty():
		main._on_sell_one()
	print("Unlock tier after selling down to afford Tier 2: %d | Cash: %d" % [EconomyManager.unlock_tier, EconomyManager.cash])

	main._on_buy_equipment("air_stone")
	main._on_buy_equipment("digital_test_kit")
	print("Has test kit: %s | Air stone equipped: %s" % [main.current_tank().has_test_kit, main.current_tank().air_stone != null])

	main._on_buy_fish("cory_catfish")
	main._on_buy_fish("harlequin_rasbora")
	main._on_buy_fish("honey_gourami")
	print("Fish count after buying Phase 2 species: %d" % main.current_tank().get_fish().size())

	print("=== Fast-forwarding another 30 sim-days (egg-layer breeding + disease) ===")
	for day in range(30):
		TimeManager.debug_fast_forward_days(1.0)
		main._on_feed()
		if day % 4 == 3:
			main._on_water_change()
	print("Fish count after 30 more days: %d | Pending egg batches: %d" % [main.current_tank().get_fish().size(), main.current_tank().pending_egg_batches.size()])
	print("Oxygen: %.2f ppm | Sick fish: %d" % [main.current_tank().oxygen, main.current_tank().sick_fish_count()])

	print("=== Deterministic disease/medication check ===")
	EconomyManager.earn(50, "test funds for medication check")
	var fish_list: Array = main.current_tank().get_fish()
	if not fish_list.is_empty():
		var patient: FishController = fish_list[0]
		patient.is_sick = true
		print("Forced %s sick. sick_fish_count=%d" % [patient.species.display_name, main.current_tank().sick_fish_count()])
		main._on_treat_disease()
		print("Medication remaining days after treating: %.1f | Cash: %d" % [main.current_tank().medication_remaining_days, EconomyManager.cash])
		for day in range(10):
			TimeManager.debug_fast_forward_days(1.0)
		print("Patient sick after 10 treated days: %s (health=%.1f)" % [patient.is_sick, patient.health] if is_instance_valid(patient) else "Patient died")

	print("=== Phase 3: multi-tank + marine check ===")
	EconomyManager.earn(300, "test funds for marine tank")
	print("Lifetime earnings: %d | Unlock tier: %d" % [EconomyManager.lifetime_earnings, EconomyManager.unlock_tier])
	main._on_buy_tank("marine_reef_tank")
	print("Tank 2 locked=%s type=%d liters=%.1f | selected index after buy=%d" % [main._tanks[1].locked, main._tanks[1].tank_type, main._tanks[1].tank_liters, main._current_tank_index])

	main.buy_fish("guppy", FishController.Sex.FEMALE)
	if main.current_tank().get_fish().size() > 0:
		print("BUG: freshwater guppy was allowed into the saltwater tank")
	else:
		print("Correctly rejected freshwater guppy in the saltwater tank")

	main._on_buy_equipment("protein_skimmer")
	main._on_buy_equipment("powerhead")
	main._on_buy_fish("clownfish")
	main._on_buy_fish("blue_green_chromis")
	main._on_buy_fish("blue_green_chromis")
	main._on_buy_fish("cleaner_shrimp")
	print("Marine tank fish count: %d | Specific gravity: %.4f" % [main.current_tank().get_fish().size(), main.current_tank().specific_gravity])

	print("=== Fast-forwarding marine tank 20 sim-days ===")
	for day in range(20):
		TimeManager.debug_fast_forward_days(1.0)
		main._on_feed()
		if day % 4 == 3:
			main._on_water_change()
	print("Marine tank after 20 days -> temp=%.2f sg=%.4f ph=%.2f fish=%d sick=%d" % [main.current_tank().temperature, main.current_tank().specific_gravity, main.current_tank().ph, main.current_tank().get_fish().size(), main.current_tank().sick_fish_count()])

	print("=== Switching back to Tank 1 (freshwater) to confirm it kept simulating independently ===")
	main._on_select_tank(0)
	print("Tank 1 after same elapsed time -> temp=%.2f ph=%.2f fish=%d" % [main.current_tank().temperature, main.current_tank().ph, main.current_tank().get_fish().size()])

	print("=== Save/load round trip (now with 2 tanks) ===")
	var tank1: TankController = main._tanks[0]
	var before := "fish=%d filter=%s heater=%s kit=%s cash=%d" % [tank1.get_fish().size(), tank1.filter != null, tank1.heater != null, tank1.has_test_kit, EconomyManager.cash]
	SaveManager.save_game()
	print("Saved. has_save() = ", SaveManager.has_save())
	tank1.filter = null
	tank1.heater = null
	tank1.has_test_kit = false
	SaveManager.load_game()
	var after := "fish=%d filter=%s heater=%s kit=%s cash=%d" % [tank1.get_fish().size(), tank1.filter != null, tank1.heater != null, tank1.has_test_kit, EconomyManager.cash]
	print("Before save: ", before)
	print("After load:  ", after, "  ->  ", "ROUND TRIP OK" if before == after else "ROUND TRIP MISMATCH")

	print("=== New game reset ===")
	main.reset_game()
	print("After reset: cash=%d tank1 fish=%d filter=%s | tank2 locked=%s | has_save=%s" % [EconomyManager.cash, tank1.get_fish().size(), tank1.filter != null, main._tanks[1].locked, SaveManager.has_save()])

	print("=== Smoke test complete, no crashes ===")
	get_tree().quit()
