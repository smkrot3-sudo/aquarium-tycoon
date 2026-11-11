extends Node2D
class_name DirtOverlay2D
## Algae filming the glass, or mulm settling on the sand: a scatter of blobs, each with its own
## coverage (0..1) that grows over time. The player wipes them away with the scraper / the
## gravel vacuum (TankController tools). The tank's algae / mulm "level" (0..100) is simply the
## average coverage, so what you see is exactly what the simulation uses.

enum Kind { ALGAE, MULM }

const BLOB_COUNT := 56

var kind: int = Kind.ALGAE
## The area the blobs are spread over (viewport pixels).
var rect: Rect2 = Rect2(0.0, 0.0, 1152.0, 400.0)
## Where the player's tool is right now, or Vector2.INF.
var cursor: Vector2 = Vector2.INF:
	set(value):
		cursor = value
		queue_redraw()
var cursor_radius: float = 60.0
## Blobs shrink with small tanks so a 15 L tank isn't smothered by a few big ones.
var blob_scale: float = 1.0

var _blobs: Array = []  ## {pos: Vector2 (0..1 in rect), size: float, weight: float, cover: float}


func setup(kind_value: int, seed_value: int) -> void:
	kind = kind_value
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	_blobs.clear()
	for i in range(BLOB_COUNT):
		_blobs.append({
			"pos": Vector2(rng.randf(), rng.randf()), "size": rng.randf_range(0.55, 1.0),
			"weight": rng.randf_range(0.4, 1.6), "cover": 0.0,
		})


func set_rect(new_rect: Rect2) -> void:
	rect = new_rect
	queue_redraw()


func level() -> float:
	if _blobs.is_empty():
		return 0.0
	var total := 0.0
	for b in _blobs:
		total += float(b["cover"])
	return total / float(_blobs.size()) * 100.0


func set_level(value: float) -> void:
	for b in _blobs:
		b["cover"] = clampf(value / 100.0 * float(b["weight"]), 0.0, 1.0)
	queue_redraw()


func grow(delta_level: float) -> void:
	if delta_level <= 0.0:
		return
	for b in _blobs:
		b["cover"] = minf(1.0, float(b["cover"]) + delta_level / 100.0 * float(b["weight"]))
	queue_redraw()


## Wipes every visible blob within `radius` of `point`; returns how many were cleaned.
func clean_at(point: Vector2, radius: float) -> int:
	var cleaned := 0
	for b in _blobs:
		if float(b["cover"]) < 0.12:
			continue
		var blob_pos: Vector2 = rect.position + Vector2(b["pos"].x * rect.size.x, b["pos"].y * rect.size.y)
		if blob_pos.distance_to(point) <= radius + _blob_radius(b) * 0.7:
			b["cover"] = 0.0
			cleaned += 1
	if cleaned > 0:
		queue_redraw()
	return cleaned


func _blob_radius(b: Dictionary) -> float:
	var base := (58.0 if kind == Kind.ALGAE else 34.0) * blob_scale
	return base * float(b["size"]) * (0.45 + 0.55 * float(b["cover"]))


func _draw() -> void:
	for b in _blobs:
		var cover: float = b["cover"]
		if cover < 0.05:
			continue
		var p: Vector2 = rect.position + Vector2(b["pos"].x * rect.size.x, b["pos"].y * rect.size.y)
		var r := _blob_radius(b)
		if kind == Kind.ALGAE:
			var a := minf(1.0, cover * 1.2)
			draw_circle(p, r, Color(0.22, 0.6, 0.18, 0.16 * a))
			draw_circle(p + Vector2(r * 0.12, -r * 0.1), r * 0.7, Color(0.2, 0.55, 0.14, 0.26 * a))
			draw_circle(p, r * 0.38, Color(0.32, 0.72, 0.2, 0.34 * a))
		else:
			draw_set_transform(p, 0.0, Vector2(1.0, 0.5))
			draw_circle(Vector2.ZERO, r, Color(0.3, 0.2, 0.1, 0.5 * minf(1.0, cover * 1.3)))
			draw_circle(Vector2(r * 0.1, -r * 0.15), r * 0.6, Color(0.42, 0.29, 0.14, 0.55 * minf(1.0, cover * 1.3)))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if cursor != Vector2.INF:
		draw_arc(cursor, cursor_radius, 0.0, TAU, 36, Color(1.0, 1.0, 1.0, 0.75), 3.0, true)
		draw_arc(cursor, cursor_radius * 0.55, 0.0, TAU, 28, Color(1.0, 1.0, 1.0, 0.35), 2.0, true)
