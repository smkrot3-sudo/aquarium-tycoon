extends Node2D
class_name BubbleEffect2D
## Lightweight ambient rising-bubble effect for the 2D tank view. Purely cosmetic (not part of
## the simulation) — a handful of small code-drawn circles instead of a particle system +
## texture, consistent with the rest of the project's code-drawn visuals.

const BUBBLE_COUNT := 8

var _bounds: Rect2
var _bubbles: Array = []  ## [{node: Polygon2D, speed: float, wobble_phase: float, wobble_amp: float}]


## Rebuilds the bubble pool for a new `bounds` (called whenever TankController recomputes its
## view rect, e.g. on resize).
func setup(bounds: Rect2) -> void:
	_bounds = bounds
	for child in get_children():
		child.queue_free()
	_bubbles.clear()
	for i in range(BUBBLE_COUNT):
		var bubble := _make_bubble()
		add_child(bubble)
		var entry := {
			"node": bubble,
			"speed": randf_range(14.0, 28.0),
			"wobble_phase": randf() * TAU,
			"wobble_amp": randf_range(3.0, 9.0),
		}
		_respawn(entry, true)
		_bubbles.append(entry)


func _make_bubble() -> Polygon2D:
	var radius := randf_range(2.0, 5.0)
	var points := PackedVector2Array()
	var segments := 8
	for i in range(segments):
		var t: float = float(i) / float(segments) * TAU
		points.append(Vector2(cos(t), sin(t)) * radius)
	var bubble := Polygon2D.new()
	bubble.polygon = points
	bubble.color = Color(1.0, 1.0, 1.0, 0.35)
	return bubble


func _respawn(entry: Dictionary, initial: bool = false) -> void:
	var x: float = _bounds.position.x + randf() * _bounds.size.x
	var y: float = _bounds.position.y + _bounds.size.y - 4.0
	if initial:
		y = _bounds.position.y + randf() * _bounds.size.y
	entry["node"].position = Vector2(x, y)


func _process(delta: float) -> void:
	for entry in _bubbles:
		var bubble: Polygon2D = entry["node"]
		entry["wobble_phase"] += delta * 2.0
		bubble.position.y -= entry["speed"] * delta
		bubble.position.x += sin(entry["wobble_phase"]) * entry["wobble_amp"] * delta
		if bubble.position.y < _bounds.position.y:
			_respawn(entry)
