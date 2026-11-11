extends Node2D
class_name TankController
## Drives one tank's water-chemistry simulation and owns its fish as children. Registered
## with TankRegistry so TimeManager-driven ticks reach it. See plan "Core simulation model".
##
## View: the tank fills the whole screen above the HUD's docked bottom bar. An illustrated
## background (assets/backgrounds/<type>.jpg — sand, plants/corals at the edges, open water in
## the middle) is cover-scaled into that area; on top of it sit a light shimmer overlay, the
## installed equipment (so a purchase is visible in the water, not just a number), bubbles and
## the fish. Everything is laid out in viewport pixels and rebuilt when the viewport resizes.

const FISH_SCENE := preload("res://scenes/fish/Fish.tscn")
const WATER_SHADER := preload("res://shaders/water_shimmer.gdshader")

enum TankType { FRESHWATER, SALTWATER }
## What a finger does on the water: the hand opens fish cards and startles, the others act.
enum Tool { HAND, FOOD, SCRAPER, VACUUM }

## Marine tanks drift toward a higher baseline pH (real reef water runs ~8.1-8.4, alkaline-
## buffered) and a salty specific-gravity target instead of freshwater's near-neutral pH.
const PH_BASELINE := { TankType.FRESHWATER: 7.0, TankType.SALTWATER: 8.2 }
const SG_TARGET := { TankType.FRESHWATER: 1.000, TankType.SALTWATER: 1.025 }
const BACKGROUND := {
	TankType.FRESHWATER: "res://assets/backgrounds/freshwater.jpg",
	TankType.SALTWATER: "res://assets/backgrounds/marine.jpg",
}
## Which illustrated icon stands in for each equipment id inside the tank (tier variants share
## their base tier's art).
const EQUIPMENT_SPRITE := {
	"basic_heater": "heater", "pro_heater": "heater",
	"basic_filter": "filter", "canister_filter": "filter", "protein_skimmer": "protein_skimmer",
	"air_stone": "air_stone", "powerhead": "powerhead",
}

## Screen space the HUD keeps for itself (see scripts/ui/Hud.gd): a floating top bar and a
## docked, opaque bottom action bar. Fish stay out of both.
const HUD_TOP_PX := 84.0
const HUD_BOTTOM_PX := 100.0
## Fraction of the background art's height taken by the sand floor at the bottom.
const SAND_FRACTION := 0.17
## Chemistry is integrated in 1-hour steps even when a bigger chunk of time arrives at once
## (debug fast-forward, offline catch-up) — one giant step would overshoot badly.
const MAX_CHEMISTRY_SUBSTEPS := 240

@export var tank_liters: float = 40.0
@export var ambient_temp_base_c: float = 22.0
@export var tank_type: TankType = TankType.FRESHWATER
## Tanks beyond the player's first are purchased in-game (see GameController.buy_tank);
## a locked tank exists in the scene but isn't registered with TankRegistry, so it costs no
## simulation time and can't be saved as "owned" until bought.
@export var locked: bool = false
@export var heater: EquipmentData
@export var filter: EquipmentData
@export var light_equipment: EquipmentData
@export var air_stone: EquipmentData
@export var has_test_kit: bool = false

## Set by GameController._ready(); lets a direct tap on a fish (_unhandled_input below) open its
## identity card. Never set in a dev tool that doesn't build the full UI — null-checked before use.
var game: GameController

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

## True only inside apply_offline_catch_up(); see there.
var is_catching_up: bool = false

## event_id -> {event: RandomEventData, remaining_days: float}
var active_events: Dictionary = {}

var _background: Sprite2D
var _shimmer: Polygon2D
var _dim: Polygon2D
var _equipment_layer: Node2D
var _bubbles: BubbleEffect2D
var _food_layer: Node2D
var _food_bits: Array = []  ## [{node: Polygon2D, speed: float, phase: float, life: float}]

## Algae on the glass and mulm on the sand (see DirtOverlay2D); the player cleans them with tools.
var _algae: DirtOverlay2D
var _mulm: DirtOverlay2D
var tool: int = Tool.HAND:
	set(value):
		tool = value
		_end_tool_drag()
var _tool_dragging: bool = false
var _last_pinch_msec: int = 0

## Recomputed by _rebuild_view(): the on-screen area the tank art fills.
var _view_rect: Rect2 = Rect2(0.0, 0.0, 1152.0, 548.0)
var _sand_top_y: float = 450.0

## species_id -> {pos: Vector2, time_left: float}; schooling fish steer around a shared point.
var _school_targets: Dictionary = {}
## species_id -> Vector2; "waddler" fish (clownfish) each keep near this spot, like an anemone.
var _home_points: Dictionary = {}

## Egg-layer breeding: {species_id: String, count: int, remaining_days: float}
var pending_egg_batches: Array = []

## Emits a Localization key, not a user-facing string — TankController is the simulation layer
## and shouldn't own display text; GameController._on_water_quality_alert() does the lookup.
signal water_quality_alert(message_key: String)
signal fish_born(species: FishSpeciesData, count: int)
## reason: "old_age" or "neglect" (FishController.death_reason) — lets the toast tell them apart.
signal fish_died(species: FishSpeciesData, fish_name: String, reason: String)
## A cleaning stroke removed some algae (tool == SCRAPER) or mulm (tool == VACUUM).
signal tool_cleaned(tool_kind: int, blobs: int)


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


## Rebuilds everything whose layout depends on the viewport size. Fish aren't repositioned —
## they simply pick their next swim target inside the new bounds.
func _rebuild_view() -> void:
	var vp := get_viewport_rect().size
	_view_rect = Rect2(0.0, 0.0, vp.x, maxf(200.0, vp.y - HUD_BOTTOM_PX))
	_rebuild_background()
	_rebuild_shimmer()
	refresh_equipment_visuals()
	_rebuild_dim()
	if _food_layer == null:
		_food_layer = Node2D.new()
		_food_layer.name = "Food"
		_food_layer.z_index = 5
		add_child(_food_layer)
	_ensure_overlays()


func _ensure_overlays() -> void:
	if _algae == null:
		_algae = DirtOverlay2D.new()
		_algae.name = "Algae"
		_algae.z_index = 5
		add_child(_algae)
		_algae.setup(DirtOverlay2D.Kind.ALGAE, hash(String(name)) + 1)
		_algae.cursor_radius = 64.0
		_mulm = DirtOverlay2D.new()
		_mulm.name = "Mulm"
		add_child(_mulm)
		_mulm.setup(DirtOverlay2D.Kind.MULM, hash(String(name)) + 2)
		_mulm.cursor_radius = 56.0
	_algae.set_rect(Rect2(_view_rect.position.x, HUD_TOP_PX + 20.0, _view_rect.size.x, maxf(60.0, _sand_top_y - HUD_TOP_PX - 10.0)))
	_mulm.set_rect(Rect2(_view_rect.position.x + _view_rect.size.x * 0.08, _sand_top_y + 8.0, _view_rect.size.x * 0.84, maxf(30.0, _view_rect.end.y - _sand_top_y - 18.0)))


func algae_level() -> float:
	return _algae.level() if _algae != null else 0.0


func mulm_level() -> float:
	return _mulm.level() if _mulm != null else 0.0


## Open water where mid-water fish swim: clear of the top HUD, the side decor and the sand.
func get_swim_rect() -> Rect2:
	var r := _view_rect
	var top := HUD_TOP_PX + 36.0
	return Rect2(r.position.x + r.size.x * 0.08, top, r.size.x * 0.84, maxf(60.0, _sand_top_y - 40.0 - top))


## Thin band just over the sand for bottom dwellers and shrimp.
func get_floor_rect() -> Rect2:
	var r := _view_rect
	return Rect2(r.position.x + r.size.x * 0.12, _sand_top_y - 6.0, r.size.x * 0.76, maxf(20.0, (r.end.y - _sand_top_y) * 0.45))


func get_zone_for(species: FishSpeciesData) -> Rect2:
	if species.archetype_id == "bottom_dweller" or species.archetype_id == "invertebrate":
		return get_floor_rect()
	return get_swim_rect()


## Shared wandering point for a schooling species, so the group moves as a loose shoal.
func get_school_target(species: FishSpeciesData) -> Vector2:
	if not _school_targets.has(species.id):
		_school_targets[species.id] = {"pos": _random_point(get_zone_for(species).grow(-40.0)), "time_left": randf_range(4.0, 8.0)}
	return _school_targets[species.id]["pos"]


## A fixed spot each "waddler" species (clownfish) treats as home — picked once and kept, like
## the anemone a real clownfish never strays far from.
func get_home_point(species: FishSpeciesData) -> Vector2:
	if not _home_points.has(species.id):
		_home_points[species.id] = _random_point(get_zone_for(species).grow(-60.0))
	return _home_points[species.id]


## Roughly where the water surface is, for air-breathing fish (bettas, gouramis) to rise to.
func get_surface_y() -> float:
	return HUD_TOP_PX + 30.0


## A single bubble released at the surface when an air-breather exhales.
func spawn_breath_bubble(point: Vector2) -> void:
	if _bubbles != null:
		_bubbles.spawn_single(point)


static func _random_point(rect: Rect2) -> Vector2:
	var r := rect.abs()
	return Vector2(randf_range(r.position.x, r.end.x), randf_range(r.position.y, r.end.y))


## Tapping the water itself (not a HUD button — those are Controls and consume the event
## first) startles nearby fish, the way real fish scatter when you tap the glass. Purely
## cosmetic flavor; harmless if it never fires.
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var point: Vector2 = Vector2.ZERO
	var phase := ""  ## "down", "up" or "move"
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		point = event.position
		phase = "down" if event.pressed else "up"
	elif event is InputEventScreenTouch:
		point = event.position
		phase = "down" if event.pressed else "up"
	elif event is InputEventMouseMotion and _tool_dragging:
		point = event.position
		phase = "move" if (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0 else "up"
	elif event is InputEventScreenDrag and _tool_dragging:
		point = event.position
		phase = "move"
	if phase == "":
		return
	if phase == "up":
		_end_tool_drag()
		return
	if phase == "down" and not _view_rect.has_point(point):
		return

	match tool:
		Tool.FOOD:
			if phase == "down":
				_pinch_at(point)
			return
		Tool.SCRAPER, Tool.VACUUM:
			if phase == "down":
				_tool_dragging = true
			_tool_stroke(point)
			return
	if phase != "down":
		return

	## A tap that lands ON a fish (within its own drawn size) opens its identity card instead of
	## startling the tank — the closest one wins if a few overlap.
	if game != null:
		var closest: FishController = null
		var closest_dist := INF
		for fish in get_fish():
			var dist := fish.position.distance_to(point)
			if dist < fish.tap_radius() and dist < closest_dist:
				closest = fish
				closest_dist = dist
		if closest != null:
			game.open_fish_detail(closest)
			return

	for fish in get_fish():
		if fish.position.distance_to(point) < 220.0:
			fish.startle(point)


func _pinch_at(point: Vector2) -> void:
	## On a phone a touch arrives as both a touch and an emulated mouse event: one pinch, not two.
	var now := Time.get_ticks_msec()
	if now - _last_pinch_msec < 140:
		return
	_last_pinch_msec = now
	if game != null:
		game.pinch_feed(self, point)
	else:
		pinch(ShopManager.get_food("basic_flakes"), point)


func _tool_stroke(point: Vector2) -> void:
	var scraper: bool = tool == Tool.SCRAPER
	var overlay: DirtOverlay2D = _algae if scraper else _mulm
	if overlay == null:
		return
	overlay.cursor = point
	var cleaned := overlay.clean_at(point, overlay.cursor_radius)
	if cleaned > 0:
		tool_cleaned.emit(tool, cleaned)
		if not scraper and _bubbles != null:
			_bubbles.spawn_single(point)


func _end_tool_drag() -> void:
	_tool_dragging = false
	if _algae != null:
		_algae.cursor = Vector2.INF
	if _mulm != null:
		_mulm.cursor = Vector2.INF


## One pinch of flakes dropped at `point`: the fish within reach of it eat some, the rest of
## the shoal drifts over to look. Returns how many fish ate.
func pinch(food: FoodItemData, point: Vector2) -> int:
	_spawn_food_burst(point, 9, false)
	var fed := 0
	for fish in get_fish():
		var dist: float = fish.position.distance_to(point)
		if dist < 300.0:
			fish.hunger = minf(100.0, fish.hunger + food.hunger_restored * 0.7)
			fish.attract_to(point + Vector2(randf_range(-50.0, 50.0), randf_range(-30.0, 40.0)))
			fed += 1
	ammonia += food.waste_factor * 0.02
	if _mulm != null:
		_mulm.grow(0.5)
	if fed > 0:
		days_since_feeding = 0.0
	return fed


func _process(delta: float) -> void:
	for species_id in _school_targets.keys():
		var entry: Dictionary = _school_targets[species_id]
		entry["time_left"] -= delta
		if entry["time_left"] <= 0.0:
			var species := ShopManager.get_species(species_id)
			if species == null:
				_school_targets.erase(species_id)
				continue
			entry["pos"] = _random_point(get_zone_for(species).grow(-40.0))
			entry["time_left"] = randf_range(4.0, 8.0)

	for bit in _food_bits.duplicate():
		var node: Polygon2D = bit["node"]
		bit["life"] -= delta
		bit["phase"] += delta * 3.0
		node.position += Vector2(sin(bit["phase"]) * 14.0, bit["speed"]) * delta
		node.rotation += delta * 2.0
		node.modulate.a = clampf(bit["life"], 0.0, 1.0)
		if bit["life"] <= 0.0:
			node.queue_free()
			_food_bits.erase(bit)


func _rebuild_background() -> void:
	if _background != null:
		_background.queue_free()
		_background = null
	var path: String = BACKGROUND[tank_type]
	if not ResourceLoader.exists(path):
		_sand_top_y = _view_rect.end.y - _view_rect.size.y * 0.15
		return
	var sprite := Sprite2D.new()
	sprite.name = "Background"
	sprite.texture = load(path)
	sprite.centered = false
	var tex_size: Vector2 = sprite.texture.get_size()
	## Cover-scale, anchored to the bottom: on a wide phone the excess is cropped off the top
	## (plain water surface) so the sand floor always lands right above the bottom bar.
	var s: float = maxf(_view_rect.size.x / tex_size.x, _view_rect.size.y / tex_size.y)
	sprite.scale = Vector2.ONE * s
	sprite.position = Vector2(_view_rect.position.x + (_view_rect.size.x - tex_size.x * s) * 0.5, _view_rect.end.y - tex_size.y * s)
	add_child(sprite)
	move_child(sprite, 0)
	_background = sprite
	_sand_top_y = _view_rect.end.y - tex_size.y * s * SAND_FRACTION


func _full_view_polygon() -> PackedVector2Array:
	var r := _view_rect
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])


## Additive moving light pattern over the (static) background art, so the water feels alive.
func _rebuild_shimmer() -> void:
	if _shimmer != null:
		_shimmer.queue_free()
	var shimmer := Polygon2D.new()
	shimmer.name = "Shimmer"
	shimmer.polygon = _full_view_polygon()
	shimmer.uv = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	var shader_mat := ShaderMaterial.new()
	shader_mat.shader = WATER_SHADER
	shimmer.material = shader_mat
	add_child(shimmer)
	move_child(shimmer, 1 if _background != null else 0)
	_shimmer = shimmer


## A tank without a light is visibly gloomy — buying one "switches the lights on".
func _rebuild_dim() -> void:
	if _dim != null:
		_dim.queue_free()
	var dim := Polygon2D.new()
	dim.name = "Dim"
	dim.polygon = _full_view_polygon()
	dim.color = Color(0.0, 0.03, 0.1, 0.42)
	dim.z_index = 6
	dim.visible = light_equipment == null
	add_child(dim)
	_dim = dim


## Call after changing heater/filter/light/air_stone (GameController does on purchase/load).
func refresh_equipment_visuals() -> void:
	if _equipment_layer != null:
		_equipment_layer.queue_free()
	_equipment_layer = Node2D.new()
	_equipment_layer.name = "Equipment"
	add_child(_equipment_layer)
	move_child(_equipment_layer, mini(2, get_child_count() - 1))

	var r := _view_rect
	var top := HUD_TOP_PX + 8.0
	if filter != null:
		_add_equipment_sprite(filter.id, Vector2(r.end.x - r.size.x * 0.035, top), 150.0, Vector2(1.0, 0.0))
	if heater != null:
		var heater_sprite := _add_equipment_sprite(heater.id, Vector2(r.position.x + r.size.x * 0.035, top + 10.0), 120.0, Vector2(0.0, 0.0))
		if heater_sprite != null and heater_failed:
			heater_sprite.modulate = Color(0.45, 0.45, 0.5)
	var bubble_x := -1.0
	if air_stone != null:
		bubble_x = r.position.x + r.size.x * 0.7
		var stone_height := 70.0 if air_stone.id == "air_stone" else 62.0
		_add_equipment_sprite(air_stone.id, Vector2(bubble_x, _sand_top_y + 26.0), stone_height, Vector2(0.5, 1.0))

	if _bubbles != null:
		_bubbles.queue_free()
	_bubbles = BubbleEffect2D.new()
	_bubbles.name = "Bubbles"
	add_child(_bubbles)
	_bubbles.setup(Rect2(r.position.x, HUD_TOP_PX * 0.5, r.size.x, _sand_top_y - HUD_TOP_PX * 0.5), bubble_x)
	if _dim != null:
		_dim.visible = light_equipment == null


## `anchor` is the point of the sprite (0..1 in each axis) placed at `pos`.
func _add_equipment_sprite(equipment_id: String, pos: Vector2, target_height: float, anchor: Vector2) -> Sprite2D:
	var path := "res://assets/equipment/%s.png" % EQUIPMENT_SPRITE.get(equipment_id, equipment_id)
	if not ResourceLoader.exists(path):
		return null
	var sprite := Sprite2D.new()
	sprite.texture = load(path)
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var tex_size: Vector2 = sprite.texture.get_size()
	var s: float = target_height / maxf(tex_size.y, 1.0)
	sprite.scale = Vector2.ONE * s
	sprite.position = pos - Vector2(tex_size.x * s * anchor.x, tex_size.y * s * anchor.y)
	_equipment_layer.add_child(sprite)
	return sprite


## Cosmetic: a pinch of flakes drifting down; fish rush up to it. With no `at` it falls from the
## surface and the whole tank comes to eat (the bottom-bar Feed button).
func _spawn_food_burst(at: Vector2 = Vector2.INF, count: int = 18, attract_all: bool = true) -> void:
	if _food_layer == null:
		return
	var swim := get_swim_rect()
	var origin := Vector2(randf_range(swim.position.x + swim.size.x * 0.3, swim.position.x + swim.size.x * 0.7), HUD_TOP_PX + 64.0)
	if at != Vector2.INF:
		origin = at
	var colors := [Color(0.95, 0.55, 0.2), Color(0.85, 0.3, 0.2), Color(0.95, 0.8, 0.35), Color(0.55, 0.75, 0.3)]
	for i in range(count):
		var bit := Polygon2D.new()
		var half := randf_range(2.5, 5.0)
		bit.polygon = PackedVector2Array([Vector2(-half, -half * 0.6), Vector2(half, -half * 0.6), Vector2(half, half * 0.6), Vector2(-half, half * 0.6)])
		bit.color = colors[randi() % colors.size()]
		bit.position = origin + Vector2(randf_range(-110.0, 110.0), randf_range(-8.0, 20.0))
		_food_layer.add_child(bit)
		_food_bits.append({"node": bit, "speed": randf_range(22.0, 46.0), "phase": randf() * TAU, "life": randf_range(3.0, 5.5)})
	if not attract_all:
		return
	for fish in get_fish():
		fish.attract_to(origin + Vector2(randf_range(-150.0, 150.0), randf_range(40.0, 150.0)))


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


## Back to a factory-fresh slot (new game). `as_locked` re-locks a purchasable slot.
func reset_to_new(as_locked: bool, liters: float, type: TankType, ambient_base_c: float) -> void:
	for fish in get_fish():
		fish.free()
	heater = null
	filter = null
	light_equipment = null
	air_stone = null
	has_test_kit = false
	tank_liters = liters
	tank_type = type
	ambient_temp_base_c = ambient_base_c
	temperature = 24.0
	ph = PH_BASELINE[tank_type]
	gh = 10.0
	specific_gravity = SG_TARGET[tank_type]
	ammonia = 0.0
	nitrite = 0.0
	nitrate = 0.0
	oxygen = 8.0
	filter_maturity = 0.0
	days_since_water_change = 0.0
	days_since_feeding = 0.0
	heater_failed = false
	medication_remaining_days = 0.0
	active_events.clear()
	pending_egg_batches.clear()
	_school_targets.clear()
	_home_points.clear()
	if _algae != null:
		_algae.set_level(0.0)
		_mulm.set_level(0.0)
	tool = Tool.HAND
	if as_locked and not locked:
		TankRegistry.unregister_tank(self)
	elif not as_locked and locked:
		TankRegistry.register_tank(self)
	locked = as_locked
	_rebuild_view()


func _exit_tree() -> void:
	TankRegistry.unregister_tank(self)


func get_fish() -> Array[FishController]:
	var result: Array[FishController] = []
	for child in get_children():
		if child is FishController and not child.is_queued_for_deletion():
			result.append(child)
	return result


func total_bioload() -> float:
	var total: float = 0.0
	for fish in get_fish():
		total += fish.species.bioload_factor * (fish.size_cm / maxf(fish.species.max_size_cm, 0.01))
	return total


## 0..1+ : how full the tank is relative to its safe stocking level.
func stocking_fraction() -> float:
	return total_bioload() / maxf(Economy.max_safe_bioload(tank_liters), 0.01)


func ambient_temp() -> float:
	var season_shift := {
		TimeManager.Season.SPRING: 0.0,
		TimeManager.Season.SUMMER: 3.0,
		TimeManager.Season.AUTUMN: -1.0,
		TimeManager.Season.WINTER: -5.0,
	}
	return ambient_temp_base_c + season_shift.get(TimeManager.current_season, 0.0)


## Called by TankRegistry once per sim-hour (and, with a larger `hours`, by debug fast-forward
## and offline catch-up).
func simulate_hours(hours: float) -> void:
	var steps: int = clampi(int(ceil(hours)), 1, MAX_CHEMISTRY_SUBSTEPS)
	var step_hours: float = hours / float(steps)
	for i in range(steps):
		_step_chemistry(step_hours)

	_apply_active_event_effects(hours)

	for fish in get_fish():
		fish.simulate_hours(hours, self)

	if ammonia > WaterChemistry.AMMONIA_DANGER:
		water_quality_alert.emit("alert_ammonia_danger")
	if algae_level() >= 90.0 and not is_catching_up:
		for fish in get_fish():
			fish.health -= 0.4 * hours / 24.0
		water_quality_alert.emit("alert_algae_heavy")


func _step_chemistry(hours: float) -> void:
	var bioload: float = total_bioload()
	var heater_active: bool = heater != null and not heater_failed
	var heater_target: float = heater.heater_target_temp_c if heater != null else 24.0
	var heater_power: float = heater.heater_power if heater != null else 0.0
	var filter_flow: float = filter.filter_flow_liters_per_hour if filter != null else 20.0
	var filter_bio_cap: float = filter.filter_bio_capacity if filter != null else 0.3
	var oxygen_boost: float = air_stone.oxygen_boost if air_stone != null else 0.0

	temperature = WaterChemistry.step_temperature(temperature, ambient_temp(), heater_target, heater_power, heater_active, hours)
	filter_maturity = WaterChemistry.step_filter_maturity(filter_maturity, bioload, filter_bio_cap, hours)
	oxygen = WaterChemistry.step_oxygen(oxygen, temperature, bioload, oxygen_boost, hours)

	var ammonia_result: Dictionary = WaterChemistry.step_ammonia(ammonia, 0.0, bioload, filter_flow, filter_maturity, hours)
	ammonia = ammonia_result["ammonia"]
	nitrite = WaterChemistry.step_nitrite(nitrite, ammonia_result["processed"], filter_maturity, hours)
	## Nitrate is the end product of the cycle: nothing in the tank removes it, so it simply
	## builds up with the stocking level until the next water change.
	nitrate += bioload * 0.04 * hours
	_grow_dirt(bioload, hours)

	## Soft/neglected freshwater tanks drift toward a lower effective pH ("old tank syndrome");
	## marine mixes are carbonate-buffered and don't realistically crash the same way.
	var ph_baseline: float = PH_BASELINE[tank_type]
	if tank_type == TankType.FRESHWATER:
		ph_baseline = WaterChemistry.freshwater_ph_baseline(ph_baseline, gh, ammonia, nitrite)
	ph = WaterChemistry.step_drift_toward(ph, ph_baseline, 0.01, hours)
	gh = WaterChemistry.step_drift_toward(gh, 10.0, 0.01, hours)
	specific_gravity = WaterChemistry.step_specific_gravity(specific_gravity, SG_TARGET[tank_type], days_since_water_change, hours)


## Algae grows with light and nutrients; mulm piles up in proportion to the fish. Gunk left on
## the sand slowly feeds the water (the reason to run the gravel vacuum), and an algae-smothered
## glass slowly wears the fish down.
func _grow_dirt(bioload: float, hours: float) -> void:
	if _algae == null or _mulm == null:
		return
	var light_rate: float = 0.14 if light_equipment != null else 0.03
	_algae.grow(light_rate * (1.0 + clampf(nitrate / 40.0, 0.0, 2.0)) * hours)
	_mulm.grow(bioload * 0.045 * hours)
	var mulm_now := _mulm.level()
	if mulm_now > 40.0:
		ammonia += (mulm_now - 40.0) * 0.00015 * hours
	nitrate += mulm_now * 0.0008 * hours


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
			refresh_equipment_visuals()
		active_events.erase(event_id)

	_advance_egg_batches(1.0)


func apply_offline_catch_up(sim_days_elapsed: float) -> void:
	## Coming back to a graveyard after closing the app is just punishing: while catching up,
	## fish can get hungry, stressed and sick, but they hang on until the player is back.
	is_catching_up = true
	simulate_hours(sim_days_elapsed * 24.0)
	is_catching_up = false
	days_since_water_change += sim_days_elapsed
	days_since_feeding += sim_days_elapsed
	medication_remaining_days = max(0.0, medication_remaining_days - sim_days_elapsed)
	_advance_egg_batches(sim_days_elapsed)


func _advance_egg_batches(days: float) -> void:
	var hatched := []
	for batch in pending_egg_batches:
		batch.remaining_days -= days
		if batch.remaining_days <= 0.0:
			hatched.append(batch)
	for batch in hatched:
		var species := ShopManager.get_species(batch.species_id)
		if species != null:
			for i in range(batch.count):
				add_fish(species, true)
			fish_born.emit(species, batch.count)
		pending_egg_batches.erase(batch)


func get_neglect_score() -> float:
	return WaterChemistry.compute_neglect_score(ammonia, nitrite, days_since_water_change, days_since_feeding)


func sick_fish_count() -> int:
	var count := 0
	for fish in get_fish():
		if fish.is_sick:
			count += 1
	return count


func hungry_fish_count() -> int:
	var count := 0
	for fish in get_fish():
		if fish.hunger < 35.0:
			count += 1
	return count


func fry_count() -> int:
	var count := 0
	for fish in get_fish():
		if fish.is_fry:
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
		refresh_equipment_visuals()
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
		if effects.has("algae_boost") and _algae != null:
			_algae.grow(float(effects["algae_boost"]) * (hours / 24.0))
		if effects.has("health_penalty_per_day"):
			for fish in get_fish():
				fish.health -= float(effects["health_penalty_per_day"]) * (hours / 24.0)
		if effects.has("temp_swing_c"):
			temperature += float(effects["temp_swing_c"]) * (hours / 24.0)


## The single "Feed" action is a mixed feeding (flakes for the mid-water fish, sinking pellets
## for bottom dwellers and shrimp, a bit of protein for carnivores) — every fish eats. Feeding
## only one food type used to leave shrimp, corys and bettas permanently starving.
func feed(food: FoodItemData) -> void:
	for fish in get_fish():
		fish.hunger = min(100.0, fish.hunger + food.hunger_restored)
	ammonia += food.waste_factor * 0.05
	days_since_feeding = 0.0
	_spawn_food_burst()


func perform_water_change(fraction: float = 0.25) -> void:
	ammonia *= (1.0 - fraction)
	nitrite *= (1.0 - fraction)
	nitrate *= (1.0 - fraction)
	ph = lerp(ph, PH_BASELINE[tank_type], fraction)
	gh = lerp(gh, 10.0, fraction)
	specific_gravity = lerp(specific_gravity, SG_TARGET[tank_type], fraction)
	days_since_water_change = 0.0


## `forced_sex` lets the shop buy a specific sex (-1 = random, used for bred fry and dev tools).
func add_fish(species: FishSpeciesData, is_fry: bool = false, forced_sex: int = -1) -> FishController:
	var fish: FishController = FISH_SCENE.instantiate()
	add_child(fish)
	fish.setup(species, is_fry, forced_sex)
	fish.died.connect(_on_fish_died)
	Progress.note_fish_added(species, is_fry, fish.hue_shift_value())
	return fish


func _on_fish_died(fish: FishController) -> void:
	fish_died.emit(fish.species, fish.fish_name, fish.death_reason)


func sell_fish(fish: FishController) -> int:
	var value := Economy.fry_sale_value(fish.species, fish.is_fry)
	EconomyManager.earn(value, "Sold %s" % fish.species.display_name)
	Progress.bump("fish_sold")
	fish.queue_free()
	return value


func _on_season_changed(_season: TimeManager.Season) -> void:
	pass  # ambient_temp() reads current_season live; nothing else to react to yet.


static func _equipment_id(equipment: EquipmentData) -> String:
	return equipment.id if equipment != null else ""


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
		"pending_egg_batches": pending_egg_batches, "algae": algae_level(), "mulm": mulm_level(),
		"tank_liters": tank_liters, "tank_type": tank_type, "locked": locked,
		"ambient_temp_base_c": ambient_temp_base_c,
		"equipment": {
			"heater": _equipment_id(heater), "filter": _equipment_id(filter),
			"light": _equipment_id(light_equipment), "air_stone": _equipment_id(air_stone),
			"test_kit": has_test_kit,
		},
		"fish": fish_saves,
	}


func from_save_dict(d: Dictionary) -> void:
	tank_liters = d.get("tank_liters", tank_liters)
	tank_type = int(d.get("tank_type", tank_type)) as TankType
	ambient_temp_base_c = d.get("ambient_temp_base_c", ambient_temp_base_c)
	var was_locked: bool = locked
	locked = d.get("locked", locked)
	if was_locked and not locked:
		TankRegistry.register_tank(self)
	## Saves from before equipment was persisted simply have no "equipment" entry — keep
	## whatever the tank has rather than wiping it.
	if d.has("equipment"):
		var eq: Dictionary = d["equipment"]
		heater = ShopManager.get_equipment(eq.get("heater", ""))
		filter = ShopManager.get_equipment(eq.get("filter", ""))
		light_equipment = ShopManager.get_equipment(eq.get("light", ""))
		air_stone = ShopManager.get_equipment(eq.get("air_stone", ""))
		has_test_kit = eq.get("test_kit", false)
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
	_rebuild_view()
	if _algae != null:
		_algae.set_level(float(d.get("algae", 0.0)))
		_mulm.set_level(float(d.get("mulm", 0.0)))
	for fish in get_fish():
		fish.free()
	for fish_data in d.get("fish", []):
		var species := ShopManager.get_species(fish_data.get("species_id", ""))
		if species != null:
			var fish := add_fish(species)
			fish.from_save_dict(fish_data)
