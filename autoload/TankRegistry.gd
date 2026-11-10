extends Node
## Tracks every owned Tank and drives their per-tick simulation centrally (rather than each
## Tank listening to TimeManager independently), so ordering and offline catch-up are predictable.

var tanks: Array[TankController] = []


func _ready() -> void:
	TimeManager.sim_tick.connect(_on_sim_tick)
	TimeManager.sim_day_elapsed.connect(_on_sim_day)


func register_tank(tank: TankController) -> void:
	if tank not in tanks:
		tanks.append(tank)


func unregister_tank(tank: TankController) -> void:
	tanks.erase(tank)


func _on_sim_tick(hours_elapsed: float) -> void:
	for tank in tanks:
		if is_instance_valid(tank):
			tank.simulate_hours(hours_elapsed)


func _on_sim_day(_day: int) -> void:
	for tank in tanks:
		if is_instance_valid(tank):
			tank.on_day_elapsed()


## Called once by SaveManager after an offline-progress jump: lets tanks apply a batched
## approximation instead of thousands of hourly ticks (see plan "Offline progress").
func apply_offline_catch_up(sim_days_elapsed: float) -> void:
	for tank in tanks:
		if is_instance_valid(tank):
			tank.apply_offline_catch_up(sim_days_elapsed)
