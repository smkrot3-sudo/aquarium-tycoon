extends Node2D
class_name TankController
## Drives one tank's water-chemistry simulation and owns its fish as children. Registered
## with TankRegistry so TimeManager-driven ticks reach it. See plan "Core simulation model".
##
## 2D view: water/substrate/glass/decor are all built procedurally in absolute viewport-pixel
## coordinates (not Node2D transform scale — FishVisualBuilder2D's sprites are already sized in
## pixel units, so scaling this node would scale them right off the screen). `_view_rect` is
## recomputed from the viewport size, reserving space for Main.tscn's docked sidebar; fish read
## `get_swim_rect()` for where they're allowed to wander.

const FISH_SCENE := preload("res://scenes/fish/Fish.tscn")
const WATER_SHADER := preload("res://shaders/water_shimmer.gdshader")

enum TankType { FRESHWATER, SALTWATER }

## Marine tanks drift toward a higher baseline pH (real reef water runs ~8.1-8.4, alkaline-
## buffered) and a salty specific-gravity target instead of freshwater's near-neutral pH.
const PH_BASELINE := { TankType.FRESHWATER: 7.0, TankType.SALTWATER: 8.2 }
const SG_TARGET := { TankType.FRESHWATER: 1.000, TankType.SALTWATER: 1.025 }

@export var tank_liters: float = 40.0
@export var ambient_temp_base_c: float = 22.0
@export var tank_type: TankType = TankType.FRESHWATER
## Tanks beyond the player's first are purchased in-game (see GameController "Buy 2nd Tank");
## a locked tank exists in the scene but isn't registered with TankRegistry, so it costs no
## simulation time and can't be saved as "owned" until bought.
@export var locked: bool = false
@export var heater: EquipmentData
@export var filter: EquipmentData
@export var light_equipment: EquipmentData
@export var air_stone: EquipmentData
@export var has_test_kit: bool = false

var temperature: float = 24.0
var ph: float = 7.0
var gh: float = 10.0
var specific_gravity: float = 1.000
var ammonia: float = 0.0
var nitrite: float = 0.0
var nitrate: float = 0.0
var oxygen: float = 8.0
var filter_maturity: float = 0.0

var days_since_water_change: float = 0.0
var days_since_feeding: float = 0.0
var heater_failed: bool = false
var medication_remaining_days: float = 0.0

## event_id -> {event: RandomEventData, remaining_days: float}
var active_events: Dictionary = {}

var _decor: Node2D
var _water: Node2D
var _substrate: Node2D
var _glass: Node2D
var _bubbles: BubbleEffect2D

## Recomputed by _rebuild_view(); see class doc above.
var _view_rect: Rect2 = Rect2(16.0, 16.0, 600.0, 400.0)
const SIDEBAR_RESERVE_PX := 520.0
const VIEW_MARGIN_PX := 16.0

## Egg-layer breeding: {species_id: String, count: int, remaining_days: float}
var pending_egg_batches: Array = []

## Emits a Localization key, not a user-facing string — TankController is the simulation layer
## and shouldn't own display text; GameController._on_water_quality_alert() does the lookup.
signal water_quality_alert(message_key: String)


func _ready() -> void:
	## Locked tanks are still a real scene node (so they can be saved/loaded — see
	## SaveManager, which saves/restores every "tank_nodes" member, not just active ones)
	## but aren't registered with TankRegistry until unlocked, so they cost no sim time.
	add_to_group("tank_nodes")
	if not locked:
		TankRegistry.register_tank(self)
	TimeManager.season_changed.connect(_on_season_changed)
	_rebuild_view()
	get_viewport().size_changed.connect(_rebuild_view)


## Rebuilds everything whose layout depends on the viewport size: the view rect, and every
## purely-visual child positioned within it. Fish already in the tank keep their existing swim
## centers rather than being repositioned — acceptable drift for an occasional resize/rotation,
## not worth the complexity of live-migrating every fish's swim bounds.
func _rebuild_view() -> void:
	var vp := get_viewport_rect().size
	_view_rect = Rect2(
		VIEW_MARGIN_PX, VIEW_MARGIN_PX,
		maxf(200.0, vp.x - VIEW_MARGIN_PX * 2.0 - SIDEBAR_RESERVE_PX),
		maxf(200.0, vp.y - VIEW_MARGIN_PX * 2.0)
	)
	_rebuild_water()
	_rebuild_substrate()
	_rebuild_glass()
	_rebuild_decor()
	_rebuild_bubbles()


func get_swim_rect() -> Rect2:
	## Inset from the view rect so fish stay clear of the glass edge and the substrate.
	var r := _view_rect
	return Rect2(
		r.position.x + r.size.x * 0.06, r.position.y + r.size.y * 0.1,
		r.size.x * 0.88, r.size.y * 0.72
	)


func _rebuild_water() -> void:
	if _water != null:
		_water.queue_free()
	var water := Polygon2D.new()
	var r := _view_rect
	water.polygon = PackedVector2Array([
		r.position, Vector2(r.position.x + r.size.x, r.position.y),
		r.position + r.size, Vector2(r.position.x, r.position.y + r.size.y),
	])
	## Polygon2D auto-derives UV from the polygon's own bounding box when none is set, which
	## would normally be fine here (the box IS the bounding box) — set explicitly anyway so the
	## water shader's UV space stays the predictable unit square regardless of future changes
	## to this shape (e.g. a wavy water-line edge).
	water.uv = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	var is_marine := tank_type == TankType.SALTWATER
	var top_c := Color(0.3, 0.6, 0.78) if not is_marine else Color(0.18, 0.5, 0.68)
	var bottom_c := Color(0.08, 0.26, 0.42) if not is_marine else Color(0.05, 0.2, 0.4)
	water.vertex_colors = PackedColorArray([top_c, top_c, bottom_c, bottom_c])
	water.name = "Water"
	var shader_mat := ShaderMaterial.new()
	shader_mat.shader = WATER_SHADER
	water.material = shader_mat
	add_child(water)
	move_child(water, 0)
	_water = water


func _rebuild_bubbles() -> void:
	if _bubbles != null:
		_bubbles.queue_free()
	_bubbles = BubbleEffect2D.new()
	_bubbles.name = "Bubbles"
	add_child(_bubbles)
	_bubbles.setup(_view_rect)


func _rebuild_substrate() -> void:
	if _substrate != null:
		_substrate.queue_free()
	var r := _view_rect
	var top_y := r.position.y + r.size.y * 0.9
	var points := PackedVector2Array([
		Vector2(r.position.x, top_y + r.size.y * 0.02),
		Vector2(r.position.x + r.size.x * 0.25, top_y - r.size.y * 0.01),
		Vector2(r.position.x + r.size.x * 0.55, top_y + r.size.y * 0.015),
		Vector2(r.position.x + r.size.x * 0.8, top_y - r.size.y * 0.015),
		Vector2(r.position.x + r.size.x, top_y),
		Vector2(r.position.x + r.size.x, r.position.y + r.size.y),
		Vector2(r.position.x, r.position.y + r.size.y),
	])
	var substrate := Polygon2D.new()
	substrate.polygon = points
	substrate.color = Color(0.45, 0.35, 0.25)
	substrate.name = "Substrate"
	add_child(substrate)
	move_child(substrate, 1)
	_substrate = substrate


func _rebuild_glass() -> void:
	if _glass != null:
		_glass.queue_free()
	var r := _view_rect
	var frame := Line2D.new()
	frame.points = PackedVector2Array([
		r.position, Vector2(r.position.x + r.size.x, r.position.y),
		r.position + r.size, Vector2(r.position.x, r.position.y + r.size.y),
		r.position,
	])
	frame.width = 6.0
	frame.default_color = Color(0.85, 0.92, 0.95, 0.35)
	frame.joint_mode = Line2D.LINE_JOINT_ROUND
	frame.name = "Glass"
	add_child(frame)
	_glass = frame


func _rebuild_decor() -> void:
	if _decor != null:
		_decor.queue_free()
	_decor = TankDecorBuilder2D.build(tank_type == TankType.SALTWATER, _view_rect)
	_decor.name = "Decor"
	add_child(_decor)


## Called by GameController when the player buys this tank slot. `type` is a plain int
## (TankPresetData stores it that way to avoid a cross-resource enum type dependency) matching
## the TankType enum values above.
func unlock(liters: float, type: int, ambient_base_c: float) -> void:
	tank_liters = liters
	tank_type = type as TankType
	ambient_temp_base_c = ambient_base_c
	ph = PH_BASELINE[tank_type]
	specific_gravity = SG_TARGET[tank_type]
	locked = false
	TankRegistry.register_tank(self)
	_rebuild_view()


func _exit_tree() -> void:
	TankRegistry.unregister_tank(self)


func get_fish() -> Array[FishController]:
	var result: Array[FishController] = []
	for child in get_children():
		if child is FishController:
			result.append(child)
	return result


func total_bioload() -> float:
	var total: float = 0.0
	for fish in get_fish():
		total += fish.species.bioload_factor * (fish.size_cm / maxf(fish.species.max_size_cm, 0.01))
	return total


func ambient_temp() -> float:
	var season_shift := {
		TimeManager.Season.SPRING: 0.0,
		TimeManager.Season.SUMMER: 3.0,
		TimeManager.Season.AUTUMN: -1.0,
		TimeManager.Season.WINTER: -5.0,
	}
	return ambient_temp_base_c + season_shift.get(TimeManager.current_season, 0.0)


## Called by TankRegistry once per sim-hour (and, with a larger `hours`, by offline catch-up —
## our WaterChemistry formulas are fraction-based so a single large step still converges safely).
func simulate_hours(hours: float) -> void:
	var bioload: float = total_bioload()
	var waste_input: float = 0.0  # accumulated by feed(); consumed here into ammonia production
	var heater_active: bool = heater != null and not heater_failed
	var heater_target: float = heater.heater_target_temp_c if heater != null else 24.0
	var heater_power: float = heater.heater_power if heater != null else 0.0
	var filter_flow: float = filter.filter_flow_liters_per_hour if filter != null else 20.0
	var filter_bio_cap: float = filter.filter_bio_capacity if filter != null else 0.3
	var oxygen_boost: float = air_stone.oxygen_boost if air_stone != null else 0.0

	temperature = WaterChemistry.step_temperature(temperature, ambient_temp(), heater_target, heater_power, heater_active, hours)
	filter_maturity = WaterChemistry.step_filter_maturity(filter_maturity, bioload, filter_bio_cap, hours)
	oxygen = WaterChemistry.step_oxygen(oxygen, temperature, bioload, oxygen_boost, hours)

	var ammonia_result: Dictionary = WaterChemistry.step_ammonia(ammonia, waste_input, bioload, filter_flow, filter_maturity, hours)
	ammonia = ammonia_result["ammonia"]
	nitrite = WaterChemistry.step_nitrite(nitrite, ammonia_result["processed"], filter_maturity, hours)
	nitrate = WaterChemistry.step_nitrate(nitrate, nitrite * 0.1 * hours, 0.0)

	## Soft/neglected freshwater tanks drift toward a lower effective pH ("old tank syndrome");
	## marine mixes are carbonate-buffered and don't realistically crash the same way.
	var ph_baseline: float = PH_BASELINE[tank_type]
	if tank_type == TankType.FRESHWATER:
		ph_baseline = WaterChemistry.freshwater_ph_baseline(ph_baseline, gh, ammonia, nitrite)
	ph = WaterChemistry.step_drift_toward(ph, ph_baseline, 0.01, hours)
	gh = WaterChemistry.step_drift_toward(gh, 10.0, 0.01, hours)
	specific_gravity = WaterChemistry.step_specific_gravity(specific_gravity, SG_TARGET[tank_type], days_since_water_change, hours)

	_apply_active_event_effects(hours)

	for fish in get_fish():
		fish.simulate_hours(hours, self)

	if ammonia > WaterChemistry.AMMONIA_DANGER:
		water_quality_alert.emit("alert_ammonia_danger")


func on_day_elapsed() -> void:
	days_since_water_change += 1.0
	days_since_feeding += 1.0
	medication_remaining_days = max(0.0, medication_remaining_days - 1.0)

	var expired := []
	for event_id in active_events.keys():
		active_events[event_id].remaining_days -= 1.0
		if active_events[event_id].remaining_days <= 0.0:
			expired.append(event_id)
	for event_id in expired:
		if active_events[event_id].event.effects.get("heater_failed", false):
			heater_failed = false
		active_events.erase(event_id)

	var hatched := []
	for batch in pending_egg_batches:
		batch.remaining_days -= 1.0
		if batch.remaining_days <= 0.0:
			hatched.append(batch)
	for batch in hatched:
		var species := ShopManager.get_species(batch.species_id)
		if species != null:
			for i in range(batch.count):
				add_fish(species, true)
		pending_egg_batches.erase(batch)


func apply_offline_catch_up(sim_days_elapsed: float) -> void:
	simulate_hours(sim_days_elapsed * 24.0)
	days_since_water_change += sim_days_elapsed
	days_since_feeding += sim_days_elapsed
	medication_remaining_days = max(0.0, medication_remaining_days - sim_days_elapsed)
	for batch in pending_egg_batches.duplicate():
		batch.remaining_days -= sim_days_elapsed
	var hatched := pending_egg_batches.filter(func(b): return b.remaining_days <= 0.0)
	for batch in hatched:
		var species := ShopManager.get_species(batch.species_id)
		if species != null:
			for i in range(batch.count):
				add_fish(species, true)
		pending_egg_batches.erase(batch)


func get_neglect_score() -> float:
	return WaterChemistry.compute_neglect_score(ammonia, nitrite, days_since_water_change, days_since_feeding)


func sick_fish_count() -> int:
	var count := 0
	for fish in get_fish():
		if fish.is_sick:
			count += 1
	return count


func schedule_egg_batch(species: FishSpeciesData, count: int, incubation_days: float) -> void:
	pending_egg_batches.append({"species_id": species.id, "count": count, "remaining_days": incubation_days})


func administer_medication(medication: MedicationData) -> void:
	medication_remaining_days = medication.treatment_duration_sim_days


func apply_event(event: RandomEventData) -> void:
	active_events[event.id] = {"event": event, "remaining_days": event.duration_sim_days}
	if event.effects.get("heater_failed", false):
		heater_failed = true
	if event.effects.has("force_sick_fraction"):
		var fraction: float = float(event.effects["force_sick_fraction"])
		for fish in get_fish():
			if not fish.is_sick and randf() < fraction:
				fish.is_sick = true
	water_quality_alert.emit("event_%s" % event.id)


func _apply_active_event_effects(hours: float) -> void:
	for entry in active_events.values():
		var effects: Dictionary = entry.event.effects
		if effects.has("ammonia_spike"):
			ammonia += float(effects["ammonia_spike"]) * (hours / 24.0)
		if effects.has("nitrate_spike"):
			nitrate += float(effects["nitrate_spike"]) * (hours / 24.0)
		if effects.has("health_penalty_per_day"):
			for fish in get_fish():
				fish.health -= float(effects["health_penalty_per_day"]) * (hours / 24.0)
		if effects.has("temp_swing_c"):
			temperature += float(effects["temp_swing_c"]) * (hours / 24.0)


func feed(food: FoodItemData) -> void:
	for fish in get_fish():
		if fish.species.diet_type in food.compatible_diets:
			fish.hunger = min(100.0, fish.hunger + food.hunger_restored)
	ammonia += food.waste_factor * 0.05
	days_since_feeding = 0.0


func perform_water_change(fraction: float = 0.25) -> void:
	ammonia *= (1.0 - fraction)
	nitrite *= (1.0 - fraction)
	nitrate *= (1.0 - fraction)
	ph = lerp(ph, PH_BASELINE[tank_type], fraction)
	gh = lerp(gh, 10.0, fraction)
	specific_gravity = lerp(specific_gravity, SG_TARGET[tank_type], fraction)
	days_since_water_change = 0.0


func add_fish(species: FishSpeciesData, is_fry: bool = false) -> FishController:
	var fish: FishController = FISH_SCENE.instantiate()
	add_child(fish)
	fish.setup(species, is_fry)
	return fish


func sell_fish(fish: FishController) -> void:
	var value := Economy.fry_sale_value(fish.species, fish.is_fry)
	EconomyManager.earn(value, "Sold %s" % fish.species.display_name)
	fish.queue_free()


func _on_season_changed(_season: TimeManager.Season) -> void:
	pass  # ambient_temp() reads current_season live; nothing else to react to yet.


func to_save_dict() -> Dictionary:
	var fish_saves := []
	for fish in get_fish():
		fish_saves.append(fish.to_save_dict())
	return {
		"temperature": temperature, "ph": ph, "gh": gh, "specific_gravity": specific_gravity,
		"ammonia": ammonia, "nitrite": nitrite, "nitrate": nitrate, "oxygen": oxygen,
		"filter_maturity": filter_maturity,
		"days_since_water_change": days_since_water_change,
		"days_since_feeding": days_since_feeding,
		"heater_failed": heater_failed,
		"medication_remaining_days": medication_remaining_days,
		"pending_egg_batches": pending_egg_batches,
		"tank_liters": tank_liters, "tank_type": tank_type, "locked": locked,
		"fish": fish_saves,
	}


func from_save_dict(d: Dictionary) -> void:
	tank_liters = d.get("tank_liters", tank_liters)
	tank_type = d.get("tank_type", tank_type) as TankType
	var was_locked: bool = locked
	locked = d.get("locked", locked)
	if was_locked and not locked:
		TankRegistry.register_tank(self)
	_rebuild_view()
	temperature = d.get("temperature", temperature)
	ph = d.get("ph", ph)
	gh = d.get("gh", gh)
	specific_gravity = d.get("specific_gravity", 1.0)
	ammonia = d.get("ammonia", 0.0)
	nitrite = d.get("nitrite", 0.0)
	nitrate = d.get("nitrate", 0.0)
	oxygen = d.get("oxygen", 8.0)
	filter_maturity = d.get("filter_maturity", 0.0)
	days_since_water_change = d.get("days_since_water_change", 0.0)
	days_since_feeding = d.get("days_since_feeding", 0.0)
	heater_failed = d.get("heater_failed", false)
	medication_remaining_days = d.get("medication_remaining_days", 0.0)
	pending_egg_batches = d.get("pending_egg_batches", [])
	for fish in get_fish():
		fish.queue_free()
	for fish_data in d.get("fish", []):
		var species := ShopManager.get_species(fish_data.get("species_id", ""))
		if species != null:
			var fish := add_fish(species)
			fish.from_save_dict(fish_data)
