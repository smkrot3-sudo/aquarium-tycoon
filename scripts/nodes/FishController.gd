extends Node2D
class_name FishController
## One fish instance's state machine: hunger/stress/health/growth/breeding. See plan
## "Core simulation model" and "Fish species data schema".

const MAX_FRY_PER_BATCH_SPAWNED := 8  ## safety cap so a big offline catch-up can't flood the tank
const DISEASE_BASE_RISK_PER_DAY := 0.015
const DISEASE_HEALTH_PENALTY_PER_DAY := 4.0
const DISEASE_UNTREATED_RECOVERY_PER_DAY := 0.04
const HUNGER_LOSS_PER_HOUR := 1.0

## How big sprites are drawn relative to FishShapeBuilder2D.ARCHETYPE_SIZE — the tank now fills
## the whole phone screen, so fish need to be large enough to actually enjoy looking at.
const VISUAL_SCALE := 2.8
## Fry are drawn at this fraction of full size, growing linearly to 1.0 at max_size_cm.
const MIN_SIZE_SCALE := 0.28

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
var _base_scale: float = 1.0
var _swim_phase: float = randf() * TAU

## Cosmetic wandering (not part of the simulation): swim to a point, pause, pick another.
var _target: Vector2 = Vector2.ZERO
var _velocity: Vector2 = Vector2.ZERO
var _speed: float = 50.0
var _pause_left: float = 0.0
var _facing: float = 1.0       ## smoothed -1..1; the art faces right at +1
var _facing_goal: float = 1.0


func setup(fish_species: FishSpeciesData, as_fry: bool = false) -> void:
	species = fish_species
	is_fry = as_fry
	size_cm = species.max_size_cm * (0.15 if as_fry else 0.6)
	age_sim_days = 0.0 if as_fry else Economy.maturity_days(species)
	hunger = 80.0
	stress = 0.0
	health = 100.0
	is_sick = false
	breeding_cooldown_remaining = Economy.breeding_cooldown_days(species) * 0.5

	## Built once per fish instance: an illustrated sprite when one exists for the species,
	## else a procedural fallback shape (see FishVisualBuilder2D).
	if _visual_root != null:
		_visual_root.queue_free()
	_visual_root = FishVisualBuilder2D.build(species)
	add_child(_visual_root)
	_apply_scale()

	var tank := get_parent() as TankController
	var zone: Rect2 = tank.get_zone_for(species) if tank != null else Rect2(100, 120, 900, 300)
	position = TankController._random_point(zone)
	_facing_goal = 1.0 if randf() < 0.5 else -1.0
	_facing = _facing_goal
	_pick_target()


func _apply_scale() -> void:
	if _visual_root == null:
		return
	var ratio: float = clampf(size_cm / maxf(species.max_size_cm, 0.01), 0.0, 1.0)
	_base_scale = VISUAL_SCALE * lerpf(MIN_SIZE_SCALE, 1.0, ratio)


func _pick_target() -> void:
	var tank := get_parent() as TankController
	if tank == null or species == null:
		return
	var zone: Rect2 = tank.get_zone_for(species)
	if species.schooling_min_group > 1:
		var center: Vector2 = tank.get_school_target(species)
		_target = center + Vector2(randf_range(-110.0, 110.0), randf_range(-55.0, 55.0))
	else:
		## Mostly-horizontal laps with a gentle change of depth read as "swimming"; a fully
		## random point makes fish look like they're bouncing around a box.
		_target = Vector2(
			randf_range(zone.position.x, zone.end.x),
			position.y + randf_range(-90.0, 90.0)
		)
	_target.x = clampf(_target.x, zone.position.x, zone.end.x)
	_target.y = clampf(_target.y, zone.position.y, zone.end.y)
	var pace: float = 1.35 if species.archetype_id == "schooler" else (0.55 if species.archetype_id == "invertebrate" else 1.0)
	_speed = randf_range(38.0, 72.0) * pace * (0.8 if is_fry else 1.0)


## Feeding time: hurry toward `point` (TankController._spawn_food_burst).
func attract_to(point: Vector2) -> void:
	_target = point
	_speed = randf_range(110.0, 160.0)
	_pause_left = 0.0


func _process(delta: float) -> void:
	if _visual_root == null:
		return
	_swim_phase += delta * 3.0

	if _pause_left > 0.0:
		_pause_left -= delta
		_velocity = _velocity.lerp(Vector2.ZERO, clampf(delta * 2.5, 0.0, 1.0))
		if _pause_left <= 0.0:
			_pick_target()
	else:
		var to_target := _target - position
		var dist := to_target.length()
		if dist < 10.0:
			_pause_left = randf_range(0.2, 1.8)
		else:
			var desired := to_target / dist * _speed
			_velocity = _velocity.lerp(desired, clampf(delta * 1.6, 0.0, 1.0))
	position += _velocity * delta

	if absf(_velocity.x) > 6.0:
		_facing_goal = signf(_velocity.x)
	_facing = move_toward(_facing, _facing_goal, delta * 5.0)
	## Turning passes through a thin sliver rather than zero width, which reads as the fish
	## pivoting around instead of blinking out.
	var face: float = _facing if absf(_facing) > 0.12 else 0.12 * (1.0 if _facing_goal >= 0.0 else -1.0)
	_visual_root.scale = Vector2(_base_scale * face, _base_scale)
	_visual_root.position.y = sin(_swim_phase * 0.5) * 3.0
	_visual_root.rotation = clampf(_velocity.y / 220.0, -0.3, 0.3) * signf(face)
	## A light tail-beat shear, stronger the faster the fish is moving.
	_visual_root.skew = sin(_swim_phase * 2.2) * (0.02 + clampf(_velocity.length() / 160.0, 0.0, 1.0) * 0.06)
	_visual_root.modulate = Color(0.72, 0.82, 0.66) if is_sick else Color.WHITE


func simulate_hours(hours: float, tank: TankController) -> void:
	var days := hours / 24.0
	age_sim_days += days

	hunger = max(0.0, hunger - HUNGER_LOSS_PER_HOUR * hours)

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
	if tank.ammonia > WaterChemistry.AMMONIA_DANGER:
		target_stress += 30.0
	if tank.nitrite > WaterChemistry.NITRITE_DANGER:
		target_stress += 20.0
	if tank.nitrate > WaterChemistry.NITRATE_DANGER:
		target_stress += 15.0
	if tank.stocking_fraction() > 1.3:
		target_stress += 20.0
	target_stress = clampf(target_stress, 0.0, 100.0)
	var stress_fraction: float = clampf(0.15 * hours, 0.0, 1.0)
	stress += (target_stress - stress) * stress_fraction

	## Badly stressed fish decline all the way to death if nothing is fixed; a merely hungry or
	## mildly stressed fish just sits at reduced health (and stops breeding below 50).
	var target_health := 100.0
	if stress > 60.0:
		target_health -= (stress - 60.0) * 2.5
	if hunger < 10.0:
		target_health -= 30.0
	if is_sick:
		target_health -= DISEASE_HEALTH_PENALTY_PER_DAY * 2.0
	target_health = clampf(target_health, 0.0, 100.0)
	var health_fraction: float = clampf(0.05 * hours, 0.0, 1.0)
	health = clampf(health + (target_health - health) * health_fraction, 0.0, 100.0)

	if health < 1.0 and tank.is_catching_up:
		health = 5.0
	if health < 1.0:
		died.emit(self)
		queue_free()
		return

	_update_growth(days)
	_update_disease(days, tank)
	_update_breeding(days, in_tolerance, tank)


## Fry grow from 15% to adult starting size (60%) over their (pace-scaled) maturity age, at
## which point they stop being fry — worth the adult price and able to breed. Adults keep
## filling out slowly toward the species' maximum size.
func _update_growth(days: float) -> void:
	if health <= 30.0:
		return
	if is_fry:
		var progress: float = clampf(age_sim_days / Economy.maturity_days(species), 0.0, 1.0)
		size_cm = maxf(size_cm, species.max_size_cm * lerpf(0.15, 0.6, progress))
		if progress >= 1.0:
			is_fry = false
			breeding_cooldown_remaining = Economy.breeding_cooldown_days(species) * 0.5
	elif size_cm < species.max_size_cm:
		size_cm = minf(species.max_size_cm, size_cm + species.growth_rate_cm_per_sim_day / Economy.MATURITY_PACE * 0.25 * days)
	_apply_scale()


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
	if health < 50.0 or not in_tolerance:
		return
	if tank.stocking_fraction() >= Economy.BREEDING_STOCKING_LIMIT:
		return
	var partner: FishController = null
	if species.pair_required:
		partner = _find_partner(tank)
		if partner == null:
			return
	if species.is_livebearer:
		_breed_livebearer(tank)
	else:
		_breed_egg_layer(tank)
	## One batch per pair: the partner's clock restarts too, otherwise two guppies would each
	## drop a full batch every cycle and the tank would flood.
	if partner != null:
		partner.breeding_cooldown_remaining = Economy.breeding_cooldown_days(species)


func _find_partner(tank: TankController) -> FishController:
	for fish in tank.get_fish():
		if fish != self and fish.species == species and not fish.is_fry and not fish.is_sick:
			return fish
	return null


func _breed_livebearer(tank: TankController) -> void:
	var fry_count: int = randi_range(species.fry_per_batch_min, species.fry_per_batch_max)
	fry_count = min(fry_count, MAX_FRY_PER_BATCH_SPAWNED)
	for i in range(fry_count):
		var fry := tank.add_fish(species, true)
		fry.position = position + Vector2(randf_range(-30.0, 30.0), randf_range(-20.0, 20.0))
	breeding_cooldown_remaining = Economy.breeding_cooldown_days(species)
	tank.fish_born.emit(species, fry_count)


## Egg-layers (plan's "broadens breeding mechanics" roster item): a batch of eggs sits in
## the tank for egg_incubation_sim_days before hatching, rather than spawning free-swimming
## fry immediately like a livebearer does.
func _breed_egg_layer(tank: TankController) -> void:
	var egg_count: int = randi_range(species.fry_per_batch_min, species.fry_per_batch_max)
	egg_count = min(egg_count, MAX_FRY_PER_BATCH_SPAWNED)
	tank.schedule_egg_batch(species, egg_count, species.egg_incubation_sim_days)
	breeding_cooldown_remaining = Economy.breeding_cooldown_days(species)


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
	## Clamp so saves written under the old (much longer) breeding clock don't leave fish
	## waiting weeks of sim time for their first batch.
	breeding_cooldown_remaining = minf(d.get("breeding_cooldown_remaining", 0.0), Economy.breeding_cooldown_days(species))
	is_sick = d.get("is_sick", false)
	_apply_scale()
