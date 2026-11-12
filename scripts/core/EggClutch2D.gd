extends Node2D
class_name EggClutch2D
## One clutch of eggs sitting in a tank, drawn where the parents laid them: a bubble nest at the
## surface (bettas and gouramis), a heap on the sand (cichlids, loaches), sticky beads on the
## plants (most others). Living eggs show a dark embryo that grows with time and starts to wiggle
## just before hatching; dead eggs turn white and fuzzy. TankController keeps `batch` current.

const STYLE_SCATTER := "scatter"   ## small pale beads among plants
const STYLE_BIG := "big"           ## big orange eggs on the sand
const STYLE_FOAM := "foam"         ## a bubble nest at the surface
const STYLE_BERRIED := "berried"   ## carried under the tail (crayfish, shrimp)

var batch_id: int = 0
var style: String = STYLE_SCATTER
var viable: float = 0.0
var duds: float = 0.0
var progress: float = 0.0
var guarded: bool = false
var _seed: int = 1


func setup(id: int, egg_style: String) -> void:
	batch_id = id
	style = egg_style
	_seed = id * 7919 + 13
	z_index = 1


func update_from(batch: Dictionary) -> void:
	viable = float(batch.get("viable", 0.0))
	duds = float(batch.get("duds", 0.0))
	var total: float = maxf(0.001, float(batch.get("total_days", 1.0)))
	progress = clampf(1.0 - float(batch.get("remaining_days", 0.0)) / total, 0.0, 1.0)
	guarded = bool(batch.get("guard", false))
	queue_redraw()


func total_eggs() -> int:
	return int(ceil(viable + duds))


func cluster_radius() -> float:
	var n: float = maxf(1.0, viable + duds)
	var base: float = 16.0 if style != STYLE_FOAM else 26.0
	return base + 7.0 * sqrt(n) * (1.4 if style == STYLE_BIG else 1.0)


func _process(_delta: float) -> void:
	queue_redraw()  ## the glow pulses and, near hatching, the embryos wiggle


func _egg_radius() -> float:
	match style:
		STYLE_BIG:
			return 11.0
		STYLE_FOAM:
			return 9.0
		STYLE_BERRIED:
			return 5.0
	return 7.0


func _draw() -> void:
	var total: int = total_eggs()
	if total <= 0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed
	var radius: float = cluster_radius()
	var t: float = Time.get_ticks_msec() * 0.001
	## A soft glow so a clutch is easy to spot (and to tap) even when the tank is zoomed out.
	var pulse: float = 0.5 + 0.5 * sin(t * 2.2 + float(batch_id))
	draw_circle(Vector2.ZERO, radius + 10.0 + pulse * 4.0, Color(1.0, 1.0, 0.9, 0.10 + 0.06 * pulse))
	if style == STYLE_FOAM:
		draw_circle(Vector2.ZERO, radius, Color(0.9, 0.96, 1.0, 0.18))

	var egg_r: float = _egg_radius()
	var dud_count: int = int(round(duds))
	for i in range(total):
		## Eggs pack loosely inside the cluster; the same seed puts every egg in the same place.
		var angle: float = rng.randf() * TAU
		var dist: float = sqrt(rng.randf()) * radius
		var pos := Vector2(cos(angle) * dist, sin(angle) * dist * (0.55 if style != STYLE_FOAM else 0.8))
		var is_dud: bool = i >= total - dud_count
		var r: float = egg_r * (0.85 + 0.3 * rng.randf())
		if style == STYLE_FOAM:
			draw_circle(pos, r, Color(0.92, 0.97, 1.0, 0.55))
			draw_arc(pos, r, 0.0, TAU, 14, Color(1, 1, 1, 0.9), 1.5)
			draw_circle(pos + Vector2(-r * 0.3, -r * 0.3), r * 0.28, Color(1, 1, 1, 0.9))
			if not is_dud:
				draw_circle(pos + Vector2(0.0, r * 0.15), r * 0.38, Color(1.0, 0.85, 0.5, 0.95))
			continue
		var body: Color = Color(1.0, 0.62, 0.25, 0.95) if style == STYLE_BIG else Color(1.0, 0.92, 0.6, 0.92)
		if style == STYLE_BERRIED:
			body = Color(0.55, 0.3, 0.25, 0.95)
		if is_dud:
			## A dead egg goes white and gets a fuzz of fungus.
			draw_circle(pos, r + 1.6, Color(1, 1, 1, 0.35))
			draw_circle(pos, r, Color(0.96, 0.96, 0.94, 0.98))
			draw_line(pos + Vector2(-r, 0.0), pos + Vector2(r, -r * 0.8), Color(1, 1, 1, 0.55), 1.2)
			continue
		draw_circle(pos, r, body)
		draw_circle(pos + Vector2(-r * 0.3, -r * 0.35), r * 0.3, Color(1, 1, 1, 0.65))
		if progress > 0.45:
			## The embryo: a dark eye that grows, and a little wiggle just before hatching.
			var wiggle: float = 0.0
			if progress > 0.85:
				wiggle = sin(t * 9.0 + float(i) * 1.7) * r * 0.25
			draw_circle(pos + Vector2(wiggle, r * 0.1), r * (0.18 + 0.3 * progress), Color(0.12, 0.08, 0.06, 0.95))
	if guarded:
		draw_arc(Vector2.ZERO, radius + 18.0, 0.0, TAU, 28, Color(0.5, 1.0, 0.7, 0.55), 2.0)
