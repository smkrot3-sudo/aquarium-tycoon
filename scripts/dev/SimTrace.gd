extends Node
## Dev-only balance trace: plays the first in-game days the way a real session runs (hourly
## ticks, feeding when hungry, a water change when the water turns bad) and prints one line per
## day, so pacing and water chemistry can be sanity-checked without a phone. Not shipped logic.

const DAYS := 30


func _ready() -> void:
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	add_child(main)
	var tank: TankController = main.current_tank()

	main.buy_equipment("basic_filter")
	main.buy_fish("guppy", FishController.Sex.MALE)
	main.buy_fish("guppy", FishController.Sex.FEMALE)
	print("start cash=%d" % EconomyManager.cash)

	var feeds := 0
	var water_changes := 0
	for day in range(DAYS):
		for hour in range(24):
			TimeManager.sim_minutes_total += 60.0
			TimeManager.sim_tick.emit(1.0)
			if tank.hungry_fish_count() > 0 and main.feed(false):
				feeds += 1
			if tank.ammonia > WaterChemistry.AMMONIA_DANGER or tank.nitrate > WaterChemistry.NITRATE_DANGER:
				main.water_change()
				water_changes += 1
		TimeManager.sim_day_elapsed.emit(TimeManager.current_day())
		## Sell grown fish down to a breeding pair, like a player cashing in.
		var adults: int = main.count_fish("guppy", false)
		while adults > 4:
			main.sell_one_of("guppy", false)
			adults -= 1
		var stress := 0.0
		var health := 0.0
		for fish in tank.get_fish():
			stress = maxf(stress, fish.stress)
			health += fish.health
		var n: int = tank.get_fish().size()
		print("day %2d | fish=%2d fry=%2d | cash=%3d earned=%3d tier=%d | temp=%.1f nh3=%.2f no2=%.2f no3=%.0f ph=%.2f mat=%3.0f%% stock=%3.0f%% | maxstress=%.0f avghealth=%.0f | feeds=%d wc=%d" % [
			day + 1, n, tank.fry_count(), EconomyManager.cash, EconomyManager.lifetime_earnings, EconomyManager.unlock_tier,
			tank.temperature, tank.ammonia, tank.nitrite, tank.nitrate, tank.ph, tank.filter_maturity, tank.stocking_fraction() * 100.0,
			stress, health / maxf(1.0, float(n)), feeds, water_changes,
		])
	get_tree().quit()
