extends Node
## Dev-only: headless check of the career / market / tool systems — modes and difficulty,
## missions, the collection, orders, auctions, fish shows, rare stock, cleaning tools, speed
## control and a save/load round trip of all the new state. Not shipped.

var _failures: int = 0


func _check(what: String, ok: bool) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", what])


func _ready() -> void:
	var main: GameController = load("res://scenes/main/Main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	var tank := main.current_tank()

	# --- new game flow: easy career starts with $100 and a closed setup screen
	main.begin_new_game(GameState.Mode.CAREER, GameState.Difficulty.EASY)
	_check("Easy career starts with $100", EconomyManager.cash == 100)
	_check("Starting a game closes the setup panel", not main.new_game.visible)

	# --- missions pay out
	main.buy_equipment("basic_filter")
	main.buy_fish("guppy", FishController.Sex.MALE)
	var cash_before := EconomyManager.cash
	Progress.check()
	_check("First-fish mission completes", Progress.completed.has("first_fish"))
	_check("...and pays its (easy-scaled) reward", EconomyManager.cash == cash_before + 10)
	_check("The collection records the species", Progress.owned_species.has("guppy"))

	# --- breeding a species for the first time is a collection event
	main.buy_fish("guppy", FishController.Sex.FEMALE)
	for day in range(14):
		TimeManager.debug_fast_forward_days(1.0)
		main.feed(true)
	Progress.check()
	_check("Fry were born", tank.fry_count() > 0 or main.count_fish("guppy", true) > 0 or tank.get_fish().size() > 2)
	_check("Breeding is recorded in the collection", Progress.bred_species.has("guppy"))
	_check("First-fry mission completes", Progress.completed.has("first_fry"))

	# --- orders
	TimeManager.sim_minutes_total = 5.0 * 24.0 * 60.0
	Progress.stage = 2
	var spawned := false
	for i in range(80):
		Market._maybe_spawn_order()
		if not Market.orders.is_empty():
			spawned = true
			break
	_check("Customers eventually place an order", spawned)
	if spawned:
		var o: Dictionary = Market.orders[0]
		_check("An order names a real species and a reward", ShopManager.get_species(o["species_id"]) != null and int(o["reward"]) > 0 and int(o["count"]) >= 1)
	Market.orders.clear()
	var guppy_order := {"id": 900, "kind": "customer", "species_id": "guppy", "count": 1, "sex": -1, "adult_only": true, "min_health": 10, "reward": 20, "days_left": 5.0, "customer": 0}
	Market.orders.append(guppy_order)
	var adults_before := 0
	for fish in tank.get_fish():
		if fish.species.id == "guppy" and not fish.is_fry:
			adults_before += 1
	_check("A matching adult can fill the order", Market.can_fulfill(guppy_order))
	cash_before = EconomyManager.cash
	var reward := Market.fulfill_order(900)
	_check("Filling an order pays the reward", reward == 20 and EconomyManager.cash == cash_before + 20)
	var adults_after := 0
	for fish in tank.get_fish():
		if fish.species.id == "guppy" and not fish.is_fry:
			adults_after += 1
	_check("...and takes the fish", adults_after == adults_before - 1)
	_check("...and counts towards the career", Progress.metric("orders_done") == 1)
	var impossible := {"id": 901, "kind": "customer", "species_id": "guppy", "count": 99, "sex": -1, "adult_only": true, "min_health": 10, "reward": 20, "days_left": 5.0, "customer": 0}
	Market.orders.append(impossible)
	_check("An order needing too many fish cannot be filled", not Market.can_fulfill(impossible) and Market.fulfill_order(901) < 0)
	Market.orders.clear()

	# --- orders expire
	Market.orders.append({"id": 902, "kind": "customer", "species_id": "guppy", "count": 1, "sex": -1, "adult_only": true, "min_health": 10, "reward": 20, "days_left": 1.0, "customer": 0})
	Market._age_orders()
	_check("An order past its deadline expires", Market.orders.is_empty())

	# --- fish show
	Market.contest = {}
	Market.next_contest_in = 0.0
	Market._tick_contest()
	_check("A fish show opens in stage 2", Market.contest_open())
	var entrants := Market.eligible_for_contest()
	_check("Healthy adults are eligible", not entrants.is_empty())
	if not entrants.is_empty():
		var result := Market.enter_contest(entrants[0])
		_check("Entering gives a placing and score", result.has("place") and int(result["place"]) >= 1 and float(result["score"]) > 0.0)
		_check("A show can only be entered once", Market.enter_contest(entrants[0]).is_empty())

	# --- auction
	var seller: FishController = null
	for fish in tank.get_fish():
		if Market.can_auction(fish):
			seller = fish
			break
	if seller != null:
		var seller_species := seller.species.id
		var count_before := tank.get_fish().size()
		_check("A healthy adult can go to auction", Market.list_for_auction(seller))
		_check("...and leaves the tank", tank.get_fish().size() == count_before - 1)
		cash_before = EconomyManager.cash
		for i in range(3):
			Market._tick_auctions()
		_check("The auction pays out within a few days", Market.auctions.is_empty() and EconomyManager.cash > cash_before)
		_check("...from a real species", ShopManager.get_species(seller_species) != null)

	# --- rare stock
	var lionfish := ShopManager.get_species("lionfish")
	_check("A rare fish is not in stock by default", Market.is_rare(lionfish) and not Market.in_stock(lionfish))
	Market.rare_stock["lionfish"] = 3.0
	_check("...until the shop gets some", Market.in_stock(lionfish))
	for i in range(3):
		Market._tick_rare_stock()
	_check("...and it runs out again", not Market.in_stock(lionfish))
	_check("Common fish are always in stock", Market.in_stock(ShopManager.get_species("guppy")))

	# --- cleaning tools
	tank._algae.set_level(0.0)
	tank._algae.grow(80.0)
	_check("Algae builds up", tank.algae_level() > 50.0)
	var cleaned: int = tank._algae.clean_at(Vector2(576.0, 300.0), 5000.0)
	_check("The scraper removes it", cleaned > 0 and tank.algae_level() < 1.0)
	tank._mulm.grow(70.0)
	_check("Mulm builds up", tank.mulm_level() > 40.0)
	tank._mulm.clean_at(Vector2(576.0, 480.0), 5000.0)
	_check("The vacuum removes it", tank.mulm_level() < 1.0)
	for fish in tank.get_fish():
		fish.hunger = 10.0
	var first_fish: FishController = tank.get_fish()[0]
	var fed := tank.pinch(ShopManager.get_food("basic_flakes"), first_fish.position)
	_check("A pinch of food feeds the fish next to it", fed >= 1 and first_fish.hunger > 10.0)
	tank._algae.set_level(0.0)
	tank._algae.grow(30.0)
	main.set_tool(TankController.Tool.SCRAPER)
	_check("Choosing a tool reaches the tanks", tank.tool == TankController.Tool.SCRAPER)
	main.set_tool(TankController.Tool.HAND)

	# --- speed control cycles 1x, 2x, 4x, pause, 1x
	TimeManager.reset_speed()
	TimeManager.cycle_speed()
	TimeManager.cycle_speed()
	_check("Speed goes 1x, 2x, 4x", TimeManager.speed_index == 2 and not TimeManager.player_paused)
	TimeManager.cycle_speed()
	_check("...then pauses", TimeManager.player_paused)
	TimeManager.cycle_speed()
	_check("...then back to 1x", not TimeManager.player_paused and TimeManager.speed_index == 0)

	# --- history is recorded every day
	_check("The history graphs have data", History.values(String(tank.name), "nitrate").size() >= 10)

	# --- save and load round trip of the new state
	Progress.bump("scraped", 7)
	Market.orders.append({"id": 950, "kind": "wholesale", "species_id": "guppy", "count": 6, "sex": -1, "adult_only": false, "min_health": 40, "reward": 30, "days_left": 9.0, "customer": 3})
	Market.rare_stock["angelfish"] = 4.0
	var species_owned_before: int = Progress.owned_species.size()
	var stage_before: int = Progress.stage
	var tank_algae: float = tank.algae_level()
	SaveManager.save_game()
	Progress.reset()
	Market.reset()
	History.reset()
	GameState.mode = GameState.Mode.FREE
	_check("The state really was cleared", Progress.owned_species.is_empty() and Market.orders.is_empty())
	_check("...loading restores it", SaveManager.load_game())
	_check("Mode survives a reload", GameState.mode == GameState.Mode.CAREER and GameState.difficulty == GameState.Difficulty.EASY)
	_check("Counters survive a reload", Progress.metric("scraped") == 7 and Progress.stage == stage_before)
	_check("The collection survives a reload", Progress.owned_species.size() >= species_owned_before)
	_check("Open orders survive a reload", Market.orders.size() == 1 and int(Market.orders[0]["count"]) == 6)
	_check("Rare stock survives a reload", Market.in_stock(ShopManager.get_species("angelfish")))
	_check("History survives a reload", History.values(String(tank.name), "nitrate").size() >= 10)
	_check("Algae survives a reload", absf(main.current_tank().algae_level() - tank_algae) < 3.0)

	# --- sandbox: money is unlimited, everything unlocked
	GameState.mode = GameState.Mode.SANDBOX
	EconomyManager.apply_mode()
	cash_before = EconomyManager.cash
	_check("Sandbox can afford anything", EconomyManager.can_afford(1000000))
	_check("...and spending costs nothing", EconomyManager.spend(5000, "test") and EconomyManager.cash == cash_before)
	_check("...with every tier open", EconomyManager.unlock_tier == Levels.MAX_LEVEL)
	_check("...and rare fish always in stock", Market.in_stock(lionfish))

	# --- an old save with no mode information keeps playing as free play
	GameState.from_save_dict({})
	_check("A save without a mode becomes free play on normal", GameState.mode == GameState.Mode.FREE and GameState.difficulty == GameState.Difficulty.NORMAL)

	SaveManager.delete_save()
	print("=== Progress trace finished: %s ===" % ("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit()
