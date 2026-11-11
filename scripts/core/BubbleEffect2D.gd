extends Node2D
class_name BubbleEffect2D
## Lightweight ambient rising-bubble effect for the 2D tank view. Purely cosmetic (not part of
## the simulation) — a handful of small code-drawn circles instead of a particle system +
## texture, consistent with the rest of the project's code-drawn visuals.

const AMBIENT_COUNT := 9
const COLUMN_COUNT := 16

var _bounds: Rect2
var _bubbles: Array = []  ## [{node, speed, wobble_phase, wobble_amp, column}]
var _column_x: float = -1.0


## Rebuilds the bubble pool for a new `bounds` (called whenever TankController recomputes its
## view, e.g. on resize or an equipment change). `column_x` >= 0 adds a dense stream of bubbles
## rising from that x — the visible output of an air stone / powerhead.
func setup(bounds: Rect2, column_x: float = -1.0) -> void:
	_bounds = bounds
	_column_x = column_x
	for child in get_children():
		child.queue_free()
	_bubbles.clear()
	for i in range(AMBIENT_COUNT):
		_add_bubble(false)
	if column_x >= 0.0:
		for i in range(COLUMN_COUNT):
			_add_bubble(true)


func _add_bubble(in_column: bool) -> void:
	var bubble := _make_bubble(randf_range(2.5, 6.0) if in_column else randf_range(3.0, 8.0))
	add_child(bubble)
	var entry := {
		"node": bubble,
		"speed": randf_range(60.0, 110.0) if in_column else randf_range(18.0, 40.0),
		"wobble_phase": randf() * TAU,
		"wobble_amp": randf_range(4.0, 12.0),
		"column": in_column,
	}
	_respawn(entry, true)
	_bubbles.append(entry)


func _make_bubble(radius: float) -> Node2D:
	var root := Node2D.new()
	var points := PackedVector2Array()
	var segments := 12
	for i in range(segments):
		var t: float = float(i) / float(segments) * TAU
		points.append(Vector2(cos(t), sin(t)) * radius)
	var body := Polygon2D.new()
	body.polygon = points
	body.color = Color(0.85, 0.96, 1.0, 0.22)
	root.add_child(body)
	var rim := Line2D.new()
	points.append(points[0])
	rim.points = points
	rim.width = 1.2
	rim.default_color = Color(1.0, 1.0, 1.0, 0.5)
	root.add_child(rim)
	return root


## A one-off bubble released from `point` (e.g. a labyrinth fish taking a breath at the
## surface) that rises, wobbles and frees itself — not part of the ambient pool above.
func spawn_single(point: Vector2) -> void:
	var bubble := _make_bubble(randf_range(3.0, 5.0))
	bubble.position = point
	add_child(bubble)
	var tween := create_tween()
	tween.tween_property(bubble, "position:y", point.y - randf_range(60.0, 110.0), 1.0)
	tween.parallel().tween_property(bubble, "modulate:a", 0.0, 1.0).set_delay(0.5)
	tween.tween_callback(bubble.queue_free)


func _respawn(entry: Dictionary, initial: bool = false) -> void:
	var x: float = _bounds.position.x + randf() * _bounds.size.x
	if entry["column"]:
		x = _column_x + randf_range(-10.0, 10.0)
	var y: float = _bounds.end.y - 4.0
	if initial:
		y = _bounds.position.y + randf() * _bounds.size.y
	entry["node"].position = Vector2(x, y)


func _process(delta: float) -> void:
	for entry in _bubbles:
		var bubble: Node2D = entry["node"]
		entry["wobble_phase"] += delta * 2.0
		bubble.position.y -= entry["speed"] * delta
		bubble.position.x += sin(entry["wobble_phase"]) * entry["wobble_amp"] * delta
		if bubble.position.y < _bounds.position.y:
			_respawn(entry)
