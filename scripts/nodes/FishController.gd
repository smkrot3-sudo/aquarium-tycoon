extends Node2D
class_name FishController
## One fish instance's state machine: hunger/stress/health/growth/breeding. See plan
## "Core simulation model" and "Fish species data schema".

const MAX_FRY_PER_BATCH_SPAWNED := 8  ## safety cap so a big offline catch-up can't flood the tank
const DISEASE_BASE_RISK_PER_DAY := 0.015
const DISEASE_HEALTH_PENALTY_PER_DAY := 4.0
const DISEASE_UNTREATED_RECOVERY_PER_DAY := 0.04

## Idle-swim wobble amplitude, in screen pixels — purely cosmetic, independent of tank size.
const SWIM_AMPLITUDE := Vector2(16.0, 6.0)

var species: FishSpeciesData
var is_fry: bool = false
var hunger: float = 80.0       ## 0..100, 100 = fully fed
var stress: float = 0.0        ## 0..100, 0 = calm
var health: float = 100.0      ## 0..100
var size_cm: float = 1.0
var age_sim_days: float = 0.0
var breeding_cooldown_remaining: float = 0.0
var is_sick: bool = false      ## generic illness; see FishController.simulate_hours disease roll

signal died(fish: FishController)

var _visual_root: Node2D
var _swim_phase: float = randf() * TAU
## Each fish wobbles around its own point within the tank's current swim rect (see
## TankController.get_swim_rect()) instead of the tank's shared origin — without a per-fish
## center every fish used to sit glued to one spot (see memory on the original Y=0 bug).
var _swim_center: Vector2 = Vector2.ZERO


func setup(fish_species: FishSpeciesData, as_fry: bool = false) -> void:
	species = fish_species
	is_fry = as_fry
	size_cm = species.max_size_cm * (0.15 if as_fry else 0.6)
	age_sim_days = 0.0 if as_fry else species.maturity_age_sim_days
	hunger = 80.0
	stress = 0.0
	health = 100.0
	is_sick = false
	breeding_cooldown_remaining = species.breeding_cooldown_sim_days * 0.5

	## Built once per fish instance: an illustrated sprite when one exists for the species,
	## else a procedural fallback shape (see FishVisualBuilder2D).
	if _visual_root != null:
		_visual_root.queue_free()
	_visual_root = FishVisualBuilder2D.build(species)
	add_child(_visual_root)
	_apply_scale()

	var tank := get_parent() as TankController
	var bounds: Rect2 = tank.get_swim_rect() if tank != null else Rect2(16, 16, 600, 400)
	_swim_center = Vector2(
		randf_range(bounds.position.x, bounds.position.x + bounds.size.x),
		randf_range(bounds.position.y, bounds.position.y + bounds.size.y)
	)
	position = _swim_center


func _apply_scale() -> void:
	if _visual_root == null:
		return
	var scale_factor: float = clampf(size_cm / maxf(species.max_size_cm, 0.01), 0.15, 1.0)
	_visual_root.scale = Vector2.ONE * scale_factor


func _process(delta: float) -> void:
	## Purely cosmetic idle "swim" motion — not part of the simulation, safe to run every frame.
	_swim_phase += delta * 0.6
	position = _swim_center + Vector2(sin(_swim_phase) * SWIM_AMPLITUDE.x, sin(_swim_phase * 0.4) * SWIM_AMPLITUDE.y)
	if _visual_root != null:
		## Only the procedural-fallback shapes have a separate tail piece to flick; illustrated
		## sprites are one flat image and just ride the idle wobble above.
		var tail: Node2D = _visual_root.get_node_or_null("TailFin")
		if tail != null:
			tail.rotation = sin(_swim_phase * 5.0) * 0.35


func simulate_hours(hours: float, tank: TankController) -> void:
	var days := hours / 24.0
	age_sim_days += days

	hunger = max(0.0, hunger - 1.5 * hours)

	var in_tolerance := species.is_within_tolerance(tank.temperature, tank.ph, tank.gh, tank.specific_gravity)
	var schooling_ok := true
	if species.schooling_min_group > 1:
		schooling_ok = _same_species_count(tank) >= species.schooling_min_group

	var target_stress := 0.0
	if not in_tolerance:
		target_stress += 50.0
	if not schooling_ok:
		target_stress += 30.0
	if hunger < 20.0:
		target_stress += 20.0
	if tank.oxygen < WaterChemistry.OXYGEN_DANGER:
		target_stress += 25.0
	target_stress = clampf(target_stress, 0.0, 100.0)
	var stress_fraction: float = clampf(0.15 * hours, 0.0, 1.0)
	stress += (target_stress - stress) * stress_fraction

	var target_health := 100.0
	if stress > 60.0:
		target_health -= (stress - 60.0)
	if hunger < 10.0:
		target_health -= 30.0
	if is_sick:
		target_health -= DISEASE_HEALTH_PENALTY_PER_DAY * 2.0
	target_health = clampf(target_health, 0.0, 100.0)
	var health_fraction: float = clampf(0.05 * hours, 0.0, 1.0)
	health = clampf(health + (target_health - health) * health_fraction, 0.0, 100.0)

	if health <= 0.0:
		died.emit(self)
		queue_free()
		return

	if size_cm < species.max_size_cm and health > 30.0:
		size_cm = minf(species.max_size_cm, size_cm + species.growth_rate_cm_per_sim_day * days)
		_apply_scale()

	_update_disease(days, tank)
	_update_breeding(days, in_tolerance, tank)


## Generic illness: stress, poor water, and low species disease_resistance raise daily risk.
## Once sick, recovery happens slowly on its own or much faster while the tank is medicated
## (mirrors real-world "quarantine and treat" aquarium practice).
func _update_disease(days: float, tank: TankController) -> void:
	if not is_sick:
		var risk_per_day: float = DISEASE_BASE_RISK_PER_DAY * (1.0 - species.disease_resistance)
		if stress > 50.0:
			risk_per_day *= 3.0
		if tank.ammonia > WaterChemistry.AMMONIA_DANGER or tank.nitrite > WaterChemistry.NITRITE_DANGER:
			risk_per_day *= 2.0
		if randf() < risk_per_day * days:
			is_sick = true
		return

	var recovery_per_day: float = DISEASE_UNTREATED_RECOVERY_PER_DAY
	if tank.medication_remaining_days > 0.0:
		var medication: MedicationData = ShopManager.get_medication("general_illness_treatment")
		recovery_per_day = medication.recovery_chance_per_day if medication != null else 0.35
	if randf() < recovery_per_day * days:
		is_sick = false


func _update_breeding(days: float, in_tolerance: bool, tank: TankController) -> void:
	if is_fry or is_sick or species.fry_per_batch_max <= 0:
		return
	breeding_cooldown_remaining = max(0.0, breeding_cooldown_remaining - days)
	if breeding_cooldown_remaining > 0.0:
		return
	if age_sim_days < species.maturity_age_sim_days or health < 50.0 or not in_tolerance:
		return
	if species.pair_required and _same_species_count(tank) < 2:
		return
	if species.is_livebearer:
		_breed_livebearer(tank)
	else:
		_breed_egg_layer(tank)


func _breed_livebearer(tank: TankController) -> void:
	var fry_count: int = randi_range(species.fry_per_batch_min, species.fry_per_batch_max)
	fry_count = min(fry_count, MAX_FRY_PER_BATCH_SPAWNED)
	for i in range(fry_count):
		tank.add_fish(species, true)
	breeding_cooldown_remaining = species.breeding_cooldown_sim_days


## Egg-layers (plan's "broadens breeding mechanics" roster item): a batch of eggs sits in
## the tank for egg_incubation_sim_days before hatching, rather than spawning free-swimming
## fry immediately like a livebearer does.
func _breed_egg_layer(tank: TankController) -> void:
	var egg_count: int = randi_range(species.fry_per_batch_min, species.fry_per_batch_max)
	egg_count = min(egg_count, MAX_FRY_PER_BATCH_SPAWNED)
	tank.schedule_egg_batch(species, egg_count, species.egg_incubation_sim_days)
	breeding_cooldown_remaining = species.breeding_cooldown_sim_days


func _same_species_count(tank: TankController) -> int:
	var count := 0
	for fish in tank.get_fish():
		if fish.species == species:
			count += 1
	return count


func to_save_dict() -> Dictionary:
	return {
		"species_id": species.id, "is_fry": is_fry,
		"hunger": hunger, "stress": stress, "health": health,
		"size_cm": size_cm, "age_sim_days": age_sim_days,
		"breeding_cooldown_remaining": breeding_cooldown_remaining,
		"is_sick": is_sick,
	}


func from_save_dict(d: Dictionary) -> void:
	is_fry = d.get("is_fry", false)
	hunger = d.get("hunger", 80.0)
	stress = d.get("stress", 0.0)
	health = d.get("health", 100.0)
	size_cm = d.get("size_cm", size_cm)
	age_sim_days = d.get("age_sim_days", 0.0)
	breeding_cooldown_remaining = d.get("breeding_cooldown_remaining", 0.0)
	is_sick = d.get("is_sick", false)
	_apply_scale()
