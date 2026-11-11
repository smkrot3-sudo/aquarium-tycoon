extends Node2D
class_name FishController
## One fish instance: its simulation state (hunger / stress / health / growth / breeding / sex /
## identity / aging — see plan "Core simulation model") and its on-screen life. The second half
## of this file is purely cosmetic and never feeds back into the simulation.
##
## Animation, in short: the sprite is drawn through shaders/fish_swim.gdshader, which bends the
## picture with a travelling wave so the tail really beats; this script drives that wave from
## how the fish is moving (burst-and-glide swimming, harder tail beats when accelerating, a body
## curve while turning), and gives each kind of animal its own way of getting about — see STYLES.
##
## Identity: every fish is born male or female (FishController.Sex), gets a given name from
## FishNames, and breeding genuinely needs one of each (see _find_partner) — buying "2 guppies"
## no longer breeds on its own unless one of each sex was bought. Species flagged `dimorphic`
## draw males and females at a different size/vividness (real for livebearers and betta);
## species flagged `color_variable` give each individual its own small random hue, so a tankful
## of guppies doesn't look like identical copies.

const MAX_FRY_PER_BATCH_SPAWNED := 8  ## safety cap so a big offline catch-up can't flood the tank
const DISEASE_BASE_RISK_PER_DAY := 0.015
const DISEASE_HEALTH_PENALTY_PER_DAY := 4.0
const DISEASE_UNTREATED_RECOVERY_PER_DAY := 0.04
const HUNGER_LOSS_PER_HOUR := 1.0

enum Sex { MALE, FEMALE }

## How big sprites are drawn relative to FishVisualBuilder2D.display_length().
const VISUAL_SCALE := 2.8
## Fry are drawn at this fraction of full size, growing linearly to 1.0 at max_size_cm.
const MIN_SIZE_SCALE := 0.28
## Dimorphic species only: males read as the smaller, showier sex; females as the larger, plainer
## one — true to life for the livebearers/betta this is actually set on.
const MALE_SCALE := 0.84
const FEMALE_SCALE := 1.14
const MALE_TINT := Color(1.08, 1.0, 0.94)
const FEMALE_TINT := Color(0.86, 0.9, 0.96)
## Color-variable species: how far an individual's hue can wander from the species' reference
## color — enough to look like a different strain, not so much it reads as a different fish.
const HUE_VARIETY := 0.16

## How each kind of animal moves. speed = cruising px/s range; pause = seconds it lingers
## between swims; burst = speed multiplier while actively kicking (it then glides at ~half);
## beat = tail beats per second at cruising speed; amp/wave/stiff feed the swim shader;
## drift = how far up/down a new target may be from where the fish is; steer = how sharply it
## changes direction.
const STYLES := {
	"cruiser": {"speed": Vector2(40, 74), "pause": Vector2(0.2, 1.6), "burst": 1.5, "beat": 2.6, "amp": 0.036, "wave": 0.9, "stiff": 0.3, "drift": 90.0, "steer": 1.6},
	"darter": {"speed": Vector2(60, 104), "pause": Vector2(0.1, 0.8), "burst": 2.0, "beat": 4.2, "amp": 0.03, "wave": 1.1, "stiff": 0.35, "drift": 55.0, "steer": 3.0},
	"hoverer": {"speed": Vector2(18, 40), "pause": Vector2(1.0, 3.6), "burst": 1.25, "beat": 1.5, "amp": 0.03, "wave": 0.7, "stiff": 0.4, "drift": 70.0, "steer": 1.1},
	"waddler": {"speed": Vector2(30, 56), "pause": Vector2(0.3, 1.4), "burst": 1.6, "beat": 4.6, "amp": 0.034, "wave": 0.8, "stiff": 0.3, "drift": 60.0, "steer": 2.4},
	"bottom": {"speed": Vector2(26, 56), "pause": Vector2(1.0, 4.0), "burst": 1.9, "beat": 3.2, "amp": 0.03, "wave": 1.0, "stiff": 0.35, "drift": 10.0, "steer": 2.2},
	"eel": {"speed": Vector2(30, 60), "pause": Vector2(0.8, 3.0), "burst": 1.5, "beat": 3.6, "amp": 0.075, "wave": 1.9, "stiff": 0.02, "drift": 12.0, "steer": 2.0},
	"crawler": {"speed": Vector2(10, 24), "pause": Vector2(0.5, 2.6), "burst": 1.0, "beat": 0.0, "amp": 0.0, "wave": 1.0, "stiff": 0.5, "drift": 6.0, "steer": 3.0},
	"snail": {"speed": Vector2(3, 7), "pause": Vector2(2.0, 6.0), "burst": 1.0, "beat": 0.0, "amp": 0.0, "wave": 1.0, "stiff": 0.5, "drift": 0.0, "steer": 3.0},
	"seahorse": {"speed": Vector2(8, 18), "pause": Vector2(1.5, 4.5), "burst": 1.0, "beat": 2.2, "amp": 0.03, "wave": 1.0, "stiff": 0.5, "drift": 80.0, "steer": 0.9},
}
const FLOOR_STYLES := ["bottom", "eel", "crawler", "snail"]

var species: FishSpeciesData
var is_fry: bool = false
var hunger: float = 80.0       ## 0..100, 100 = fully fed
var stress: float = 0.0        ## 0..100, 0 = calm
var health: float = 100.0      ## 0..100
var size_cm: float = 1.0
var age_sim_days: float = 0.0
## Separate from age: resets to 0 every time this exact fish is added to a tank (a bought adult
## is already grown, but it hasn't been YOUR fish for very long) — what "Tap a fish" shows.
var days_in_tank: float = 0.0
var breeding_cooldown_remaining: float = 0.0
var is_sick: bool = false      ## generic illness; see FishController.simulate_hours disease roll

var sex: Sex = Sex.MALE
var fish_name: String = ""
## "" (alive), "old_age" or "neglect" — set just before `died` fires, so listeners can tell
## a natural end from a preventable one without guessing from the stats.
var death_reason: String = ""

signal died(fish: FishController)

# --- cosmetic state --------------------------------------------------------------------
var _visual_root: Node2D
var _material: ShaderMaterial
var _shadow: Polygon2D
var _style_id: String = "cruiser"
var _style: Dictionary = STYLES["cruiser"]
var _base_scale: float = 1.0
var _depth: float = 1.0          ## 0 = far back (smaller, bluer), 1 = right at the glass
var _phase: float = randf() * TAU
var _amplitude: float = 0.0
var _bend: float = 0.0
var _dimorph_scale: float = 1.0
var _dimorph_tint: Color = Color.WHITE
var _built_sex: int = -1

var _target: Vector2 = Vector2.ZERO
var _velocity: Vector2 = Vector2.ZERO
var _cruise_speed: float = 50.0
var _pause_left: float = 0.0
var _kicking: bool = true        ## burst-and-glide: true while the tail is driving
var _kick_left: float = 0.5
var _facing: float = 1.0         ## smoothed -1..1; the art faces right at +1
var _facing_goal: float = 1.0
var _feeding_left: float = 0.0   ## > 0 while milling around a food drop
var _food_point: Vector2 = Vector2.ZERO
var _startle_left: float = 0.0
var _gulp_in: float = randf_range(8.0, 26.0)  ## labyrinth fish: seconds until the next breath
var _gulp_state: int = 0         ## 0 = no, 1 = rising to the surface, 2 = heading back down


## `forced_sex` lets the shop buy a specific sex (-1 = random, used for bred fry).
func setup(fish_species: FishSpeciesData, as_fry: bool = false, forced_sex: int = -1) -> void:
	species = fish_species
	is_fry = as_fry
	size_cm = species.max_size_cm * (0.15 if as_fry else 0.6)
	age_sim_days = 0.0 if as_fry else Economy.maturity_days(species)
	days_in_tank = 0.0
	hunger = 80.0
	stress = 0.0
	health = 100.0
	is_sick = false
	death_reason = ""
	breeding_cooldown_remaining = Economy.breeding_cooldown_days(species) * 0.5

	sex = (forced_sex as Sex) if forced_sex >= 0 else (Sex.MALE if randf() < 0.5 else Sex.FEMALE)
	fish_name = FishNames.pick(sex, Localization.current_language)
	if species.dimorphic:
		_dimorph_scale = MALE_SCALE if sex == Sex.MALE else FEMALE_SCALE
		_dimorph_tint = MALE_TINT if sex == Sex.MALE else FEMALE_TINT
		if FishVisualBuilder2D.has_female_sprite(species):
			_dimorph_tint = Color.WHITE
	else:
		_dimorph_scale = 1.0
		_dimorph_tint = Color.WHITE

	_style_id = _resolve_style(species)
	_style = STYLES[_style_id]
	_depth = randf()

	_build_visual()
	## Fish further back are drawn behind nearer ones.
	z_index = int(_depth * 3.0)
	_apply_scale()

	var tank := get_parent() as TankController
	var zone: Rect2 = tank.get_zone_for(species) if tank != null else Rect2(100, 120, 900, 300)
	position = TankController._random_point(zone)
	_facing_goal = 1.0 if randf() < 0.5 else -1.0
	_facing = _facing_goal
	_pick_target()


## Builds (or rebuilds, if a loaded save turns out to be the other sex) the fish's picture: an
## illustrated sprite when one exists for the species and sex, else a procedural fallback shape.
func _build_visual() -> void:
	if _visual_root != null:
		_visual_root.queue_free()
	if _shadow != null:
		_shadow.queue_free()
		_shadow = null
	_visual_root = FishVisualBuilder2D.build(species, int(sex))
	_material = _visual_root.get_meta("material", null) if _visual_root.has_meta("material") else null
	if _material != null:
		_material.set_shader_parameter("wave_length", _style["wave"])
		_material.set_shader_parameter("stiff_head", _style["stiff"])
		_material.set_shader_parameter("upright", 1.0 if _style_id == "seahorse" else 0.0)
		_material.set_shader_parameter("breathe", 0.0 if _style_id in ["crawler", "snail"] else 1.0)
		if species.color_variable:
			_material.set_shader_parameter("hue_shift", randf_range(-HUE_VARIETY, HUE_VARIETY))
	if _style_id in FLOOR_STYLES:
		_shadow = _make_shadow()
		add_child(_shadow)
	add_child(_visual_root)
	_built_sex = sex


static func _resolve_style(fish_species: FishSpeciesData) -> String:
	if STYLES.has(fish_species.swim_style):
		return fish_species.swim_style
	match fish_species.archetype_id:
		"schooler":
			return "darter"
		"labyrinth", "tall":
			return "hoverer"
		"bottom_dweller":
			return "bottom"
		"invertebrate":
			return "crawler"
	return "cruiser"


func _make_shadow() -> Polygon2D:
	var points := PackedVector2Array()
	for i in range(14):
		var a: float = float(i) / 14.0 * TAU
		points.append(Vector2(cos(a) * 26.0, sin(a) * 5.0))
	var shadow := Polygon2D.new()
	shadow.polygon = points
	shadow.color = Color(0.0, 0.04, 0.08, 0.22)
	return shadow


func _apply_scale() -> void:
	if _visual_root == null:
		return
	var ratio: float = clampf(size_cm / maxf(species.max_size_cm, 0.01), 0.0, 1.0)
	_base_scale = VISUAL_SCALE * lerpf(MIN_SIZE_SCALE, 1.0, ratio) * lerpf(0.84, 1.0, _depth) * _dimorph_scale
	if _shadow != null:
		var half_height: float = float(_visual_root.get_meta("half_height", 12.0)) * _base_scale
		_shadow.position = Vector2(0.0, half_height * 0.78)
		_shadow.scale = Vector2.ONE * _base_scale * FishVisualBuilder2D.display_length(species) / 70.0


## The fish was just moved into another tank: pick a spot in its new water and settle in (a
## move is a small stress, like acclimatising to new water in real life).
func relocated() -> void:
	var tank := get_parent() as TankController
	if tank == null:
		return
	position = TankController._random_point(tank.get_zone_for(species))
	_feeding_left = 0.0
	_pause_left = 0.0
	_gulp_state = 0
	days_in_tank = 0.0
	stress = minf(100.0, stress + 12.0)
	_pick_target()


## This individual's colour shift (0 for a species that doesn't vary); Progress buckets it into
## a "morph" for the collection.
func hue_shift_value() -> float:
	if _material == null:
		return 0.0
	var value = _material.get_shader_parameter("hue_shift")
	return float(value) if value != null else 0.0


## On-screen hit radius for tap-to-inspect (TankController._unhandled_input), in px.
func tap_radius() -> float:
	return maxf(26.0, FishVisualBuilder2D.display_length(species) * _base_scale * 0.6)


# ----------------------------------------------------------------------------------------
# Getting about (cosmetic)
# ----------------------------------------------------------------------------------------

func _zone() -> Rect2:
	var tank := get_parent() as TankController
	return tank.get_zone_for(species) if tank != null else Rect2(100, 120, 900, 300)


func _pick_target() -> void:
	var tank := get_parent() as TankController
	if tank == null or species == null:
		return
	var zone: Rect2 = tank.get_zone_for(species)
	if _feeding_left > 0.0:
		_target = _food_point + Vector2(randf_range(-70.0, 70.0), randf_range(-30.0, 50.0))
	elif species.schooling_min_group > 1:
		## Each fish keeps its own slot around the shared point, so the shoal has a shape.
		_target = tank.get_school_target(species) + Vector2(randf_range(-120.0, 120.0), randf_range(-55.0, 55.0))
	elif _style_id == "waddler":
		## Clownfish never stray far from "their" spot, like the anemone they'd guard.
		_target = tank.get_home_point(species) + Vector2(randf_range(-150.0, 150.0), randf_range(-70.0, 70.0))
	else:
		## Mostly-horizontal laps with a gentle change of depth read as swimming; a fully
		## random point makes fish look like they're bouncing around a box.
		var drift: float = _style["drift"]
		_target = Vector2(randf_range(zone.position.x, zone.end.x), position.y + randf_range(-drift, drift))
		if _style_id == "hoverer" or _style_id == "seahorse":
			## Hoverers shift a short way at a time instead of crossing the whole tank.
			_target.x = position.x + randf_range(-260.0, 260.0)
	_target.x = clampf(_target.x, zone.position.x, zone.end.x)
	_target.y = clampf(_target.y, zone.position.y, zone.end.y)
	var speed_range: Vector2 = _style["speed"]
	_cruise_speed = randf_range(speed_range.x, speed_range.y) * (1.15 if is_fry else 1.0) * (0.55 if is_sick else 1.0)
	if _feeding_left > 0.0:
		_cruise_speed = maxf(_cruise_speed * 1.6, 70.0)


## Feeding time: hurry to the food and mill around it for a while (TankController.feed).
func attract_to(point: Vector2) -> void:
	if _style_id == "snail":
		return
	var zone := _zone()
	## Floor animals wait for what sinks; they shuffle under the food instead of rising to it.
	_food_point = Vector2(point.x, clampf(point.y, zone.position.y, zone.end.y))
	_feeding_left = randf_range(4.0, 6.5)
	_pause_left = 0.0
	_gulp_state = 0
	_pick_target()
	_kicking = true
	_kick_left = 0.8


## Something tapped the glass nearby: bolt away from it.
func startle(from_point: Vector2) -> void:
	if _style_id == "snail":
		return
	var away := position - from_point
	if away.length() < 1.0:
		away = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
	away = away.normalized()
	var zone := _zone()
	var reach: float = 150.0 if _style_id in FLOOR_STYLES else 300.0
	_target = position + away * reach
	_target.x = clampf(_target.x, zone.position.x, zone.end.x)
	_target.y = clampf(_target.y, zone.position.y, zone.end.y)
	_startle_left = 0.7
	_pause_left = 0.0
	_feeding_left = 0.0
	_gulp_state = 0
	_kicking = true
	_kick_left = 0.7
	_velocity = away * (140.0 if _style_id in FLOOR_STYLES else 300.0)


func _process(delta: float) -> void:
	if _visual_root == null or species == null:
		return
	if _feeding_left > 0.0:
		_feeding_left -= delta
	if _startle_left > 0.0:
		_startle_left -= delta
	_update_air_gulp(delta)

	# --- burst-and-glide: a few strong tail beats, then coast
	_kick_left -= delta
	if _kick_left <= 0.0:
		_kicking = not _kicking
		_kick_left = randf_range(0.35, 0.9) if _kicking else randf_range(0.5, 1.7)

	var moving: bool = _pause_left <= 0.0
	if not moving:
		_pause_left -= delta
		_velocity = _velocity.lerp(Vector2.ZERO, clampf(delta * 2.5, 0.0, 1.0))
		if _pause_left <= 0.0:
			_pick_target()
	else:
		var to_target := _target - position
		var dist := to_target.length()
		if dist < 12.0:
			var pause_range: Vector2 = _style["pause"]
			_pause_left = randf_range(pause_range.x, pause_range.y)
			if _feeding_left > 0.0 or _startle_left > 0.0:
				_pause_left = randf_range(0.05, 0.3)
			if _gulp_state == 1:
				_finish_air_gulp()
		else:
			var speed: float = _cruise_speed
			if _startle_left > 0.0:
				speed *= 4.0
			elif _style["burst"] > 1.0:
				speed *= float(_style["burst"]) if _kicking else 0.55
			var desired := to_target / dist * speed
			_velocity = _velocity.lerp(desired, clampf(delta * float(_style["steer"]), 0.0, 1.0))
	position += _velocity * delta

	var speed_now: float = _velocity.length()
	if absf(_velocity.x) > 6.0:
		_facing_goal = signf(_velocity.x)
	var turning: bool = signf(_facing) != _facing_goal or absf(_facing) < 0.98
	_facing = move_toward(_facing, _facing_goal, delta * (6.0 if _style_id == "darter" else 4.0))

	# --- drive the tail from the motion
	var effort: float = 0.0
	if moving:
		effort = 1.0 if (_kicking or _startle_left > 0.0 or _feeding_left > 0.0) else 0.3
	var beat: float = float(_style["beat"]) * (1.5 if is_fry else 1.0)
	_phase += delta * TAU * beat * (0.35 + 0.65 * effort + clampf(speed_now / 200.0, 0.0, 1.2))
	var amp_goal: float = float(_style["amp"]) * (0.45 + 0.75 * effort)
	if is_sick:
		amp_goal *= 0.5
	_amplitude = lerpf(_amplitude, amp_goal, clampf(delta * 5.0, 0.0, 1.0))
	_bend = lerpf(_bend, (_facing_goal if turning else 0.0), clampf(delta * 6.0, 0.0, 1.0))
	if _material != null:
		_material.set_shader_parameter("phase", _phase)
		_material.set_shader_parameter("amplitude", _amplitude)
		_material.set_shader_parameter("bend", _bend * (1.0 - absf(_facing)))

	# --- pose
	## Turning passes through a thin sliver rather than zero width, which reads as the fish
	## pivoting around instead of blinking out.
	var face: float = _facing if absf(_facing) > 0.14 else 0.14 * (1.0 if _facing_goal >= 0.0 else -1.0)
	var stretch := Vector2.ONE
	var lift: float = 0.0
	var tilt: float = clampf(_velocity.y / 200.0, -0.35, 0.35)
	match _style_id:
		"crawler":
			## Little steps: a quick hop on each stride while walking.
			lift = -absf(sin(Time.get_ticks_msec() * 0.012 + _depth * 6.0)) * 2.6 * clampf(speed_now / 10.0, 0.0, 1.0)
			tilt = 0.0
		"snail":
			## The foot stretches and bunches as the snail creeps.
			var creep: float = sin(Time.get_ticks_msec() * 0.003 + _depth * 6.0) * clampf(speed_now / 4.0, 0.0, 1.0)
			stretch = Vector2(1.0 + creep * 0.04, 1.0 - creep * 0.03)
			tilt = 0.0
		"waddler":
			## The clownfish waddle: the whole body rocks from side to side as it paddles.
			tilt += sin(_phase * 0.55) * 0.13
			lift = sin(_phase * 0.27) * 4.0
		"seahorse":
			tilt = sin(Time.get_ticks_msec() * 0.0012 + _depth * 6.0) * 0.07
			lift = sin(Time.get_ticks_msec() * 0.002 + _depth * 6.0) * 5.0
		"bottom", "eel":
			tilt *= 0.4
		_:
			## Hanging in the water is never perfectly still.
			lift = sin(Time.get_ticks_msec() * 0.0021 + _depth * 6.0) * (3.0 if moving else 4.5)
			## A hint of yaw: the body narrows very slightly with each tail beat.
			stretch.x = 1.0 - absf(sin(_phase)) * 0.025 * effort
	if is_sick:
		tilt += 0.28
	_visual_root.scale = Vector2(_base_scale * face * stretch.x, _base_scale * stretch.y)
	_visual_root.position.y = lift
	_visual_root.rotation = tilt * signf(face)

	var tint := Color.WHITE.lerp(Color(0.6, 0.8, 0.94), (1.0 - _depth) * 0.42) * _dimorph_tint
	if is_sick:
		tint = tint * Color(0.74, 0.84, 0.66)
	_visual_root.modulate = tint


## Bettas and gouramis breathe air: every so often they rise, take a gulp and sink back.
func _update_air_gulp(delta: float) -> void:
	if species.archetype_id != "labyrinth" or _feeding_left > 0.0 or _startle_left > 0.0:
		return
	if _gulp_state != 0:
		return
	_gulp_in -= delta
	if _gulp_in > 0.0:
		return
	var tank := get_parent() as TankController
	if tank == null:
		return
	_gulp_state = 1
	_target = Vector2(position.x + randf_range(-60.0, 60.0), tank.get_surface_y())
	_cruise_speed = 60.0
	_pause_left = 0.0


func _finish_air_gulp() -> void:
	_gulp_state = 0
	_gulp_in = randf_range(14.0, 34.0)
	_pause_left = 0.5
	var tank := get_parent() as TankController
	if tank != null:
		tank.spawn_breath_bubble(position + Vector2(18.0 * _facing_goal, -8.0))


# ----------------------------------------------------------------------------------------
# Simulation
# ----------------------------------------------------------------------------------------

func simulate_hours(hours: float, tank: TankController) -> void:
	var days := hours / 24.0
	age_sim_days += days
	days_in_tank += days

	## Old age: a fry that just hatched doesn't count its ancestors' years, so this only ever
	## ends a fish that lived out its (pace-scaled) natural span in THIS tank.
	if age_sim_days >= Economy.lifespan_days(species):
		death_reason = "old_age"
		died.emit(self)
		queue_free()
		return

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
		death_reason = "neglect"
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
	## Only a female carries fry/eggs — a male reaching his own cooldown-zero does nothing
	## until _find_partner (called from the female's turn) resets him.
	if sex != Sex.FEMALE:
		return
	breeding_cooldown_remaining = max(0.0, breeding_cooldown_remaining - days)
	if breeding_cooldown_remaining > 0.0:
		return
	if health < 50.0 or not in_tolerance:
		return
	if tank.stocking_fraction() >= Economy.BREEDING_STOCKING_LIMIT:
		return
	var partner: FishController = _find_partner(tank)
	if partner == null:
		return
	if species.is_livebearer:
		_breed_livebearer(tank)
	else:
		_breed_egg_layer(tank)
	## One batch per pair: the male's clock restarts too, otherwise he could father a batch
	## with every female in the tank on the same day.
	partner.breeding_cooldown_remaining = Economy.breeding_cooldown_days(species)


## A ready, healthy adult MALE of the same species — real breeding, not just "another adult".
func _find_partner(tank: TankController) -> FishController:
	for fish in tank.get_fish():
		if fish != self and fish.species == species and fish.sex == Sex.MALE and not fish.is_fry and not fish.is_sick and fish.health >= 50.0:
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
		"size_cm": size_cm, "age_sim_days": age_sim_days, "days_in_tank": days_in_tank,
		"breeding_cooldown_remaining": breeding_cooldown_remaining,
		"is_sick": is_sick, "sex": sex, "fish_name": fish_name,
		"hue_shift": _material.get_shader_parameter("hue_shift") if _material != null else 0.0,
	}


func from_save_dict(d: Dictionary) -> void:
	is_fry = d.get("is_fry", false)
	hunger = d.get("hunger", 80.0)
	stress = d.get("stress", 0.0)
	health = d.get("health", 100.0)
	size_cm = d.get("size_cm", size_cm)
	age_sim_days = d.get("age_sim_days", 0.0)
	days_in_tank = d.get("days_in_tank", age_sim_days)
	## Clamp so saves written under the old (much longer) breeding clock don't leave fish
	## waiting weeks of sim time for their first batch.
	breeding_cooldown_remaining = minf(d.get("breeding_cooldown_remaining", 0.0), Economy.breeding_cooldown_days(species))
	is_sick = d.get("is_sick", false)
	sex = int(d.get("sex", sex)) as Sex
	fish_name = d.get("fish_name", fish_name if fish_name != "" else FishNames.pick(sex, Localization.current_language))
	if species.dimorphic:
		_dimorph_scale = MALE_SCALE if sex == Sex.MALE else FEMALE_SCALE
		_dimorph_tint = Color.WHITE if FishVisualBuilder2D.has_female_sprite(species) else (MALE_TINT if sex == Sex.MALE else FEMALE_TINT)
	if _built_sex != int(sex):
		_build_visual()
	if _material != null:
		_material.set_shader_parameter("hue_shift", d.get("hue_shift", 0.0))
	_apply_scale()
