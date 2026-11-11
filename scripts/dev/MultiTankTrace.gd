extends Node
## Dev-only: verifies the eight-tank-slot system (buying fills the first free slot, in order, and a
## ninth purchase is rejected once all slots are full). Not shipped.

var _failures: int = 0


func _check(what: String, ok: bool) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", what])


func _ready() -> void:
	var main: GameController = load("res://scenes/main/Main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	main.begin_new_game(GameState.Mode.SANDBOX, GameState.Difficulty.NORMAL)
	_check("One tank to start", main.owned_tank_count() == 1)
	var presets := ["huge_freshwater_tank", "marine_reef_tank", "large_marine_tank", "large_freshwater_tank", "marine_reef_tank", "large_freshwater_tank", "huge_freshwater_tank"]
	for i in range(presets.size()):
		_check("Buying tank #%d (%s) works" % [i + 2, presets[i]], main.buy_tank(presets[i]) and main.owned_tank_count() == i + 2 and main.current_tank_index() == i + 1)
	_check("All eight slots are in use", main.owned_tank_count() == 8)
	_check("A ninth tank is refused", not main.buy_tank("large_freshwater_tank") and main.owned_tank_count() == 8)
	_check("The first saltwater tank is slot 2", main.find_tank_of_type(true) == 2 or main.current_tank().tank_type == TankController.TankType.SALTWATER)
	var start_index: int = main.current_tank_index()
	main.cycle_tank()
	_check("Cycling moves to the next tank", main.current_tank_index() == (start_index + 1) % 8)
	_check("Every owned tank is registered for simulation", TankRegistry.tanks.size() == 8)
	print("=== Multi-tank trace finished: %s ===" % ("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit()
