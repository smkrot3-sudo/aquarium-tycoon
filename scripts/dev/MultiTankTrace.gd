extends Node
## Dev-only: verifies the four-tank-slot system (buying fills the first free slot, in order,
## and the fourth purchase is correctly rejected once all slots are full). Not shipped.
func _ready() -> void:
	var main: GameController = load("res://scenes/main/Main.tscn").instantiate()
	add_child(main)
	EconomyManager.earn(2000, "test funds")
	print("owned tanks at start: %d" % main.owned_tank_count())
	print("buy #2 (huge_freshwater_tank): %s -> owned=%d index=%d" % [main.buy_tank("huge_freshwater_tank"), main.owned_tank_count(), main.current_tank_index()])
	print("buy #3 (marine_reef_tank): %s -> owned=%d index=%d" % [main.buy_tank("marine_reef_tank"), main.owned_tank_count(), main.current_tank_index()])
	print("buy #4 (large_marine_tank): %s -> owned=%d index=%d" % [main.buy_tank("large_marine_tank"), main.owned_tank_count(), main.current_tank_index()])
	print("buy #5 (large_freshwater_tank), should fail, no slots left: %s -> owned=%d" % [main.buy_tank("large_freshwater_tank"), main.owned_tank_count()])
	print("find_tank_of_type(saltwater=true) -> %d (expect 2, first salt tank bought)" % main.find_tank_of_type(true))
	print("find_tank_of_type(saltwater=false) -> %d (expect 0, current tank)" % main.find_tank_of_type(false))
	main.cycle_tank()
	print("cycle_tank once -> index=%d" % main.current_tank_index())
	get_tree().quit()
