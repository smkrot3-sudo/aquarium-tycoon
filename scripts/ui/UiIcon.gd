extends Control
class_name UiIcon
## Small code-drawn vector icons for the HUD and panels (the illustrated art covers fish and
## equipment; these cover the abstract actions — water, shop, close, settings...). Drawn to fit
## whatever size the control is given, so they stay crisp at any phone resolution.

var kind: String = "close":
	set(value):
		kind = value
		queue_redraw()
var color: Color = Color.WHITE:
	set(value):
		color = value
		queue_redraw()


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	var s: float = minf(size.x, size.y)
	var c: Vector2 = size * 0.5
	var w: float = maxf(2.0, s * 0.11)
	match kind:
		"close":
			var d := s * 0.28
			draw_line(c + Vector2(-d, -d), c + Vector2(d, d), color, w * 1.2, true)
			draw_line(c + Vector2(d, -d), c + Vector2(-d, d), color, w * 1.2, true)
		"plus":
			draw_line(c + Vector2(-s * 0.3, 0), c + Vector2(s * 0.3, 0), color, w * 1.3, true)
			draw_line(c + Vector2(0, -s * 0.3), c + Vector2(0, s * 0.3), color, w * 1.3, true)
		"minus":
			draw_line(c + Vector2(-s * 0.3, 0), c + Vector2(s * 0.3, 0), color, w * 1.3, true)
		"play":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.22, -s * 0.32), c + Vector2(s * 0.34, 0), c + Vector2(-s * 0.22, s * 0.32)]), color)
		"next":
			draw_polyline(PackedVector2Array([c + Vector2(-s * 0.12, -s * 0.26), c + Vector2(s * 0.14, 0), c + Vector2(-s * 0.12, s * 0.26)]), color, w * 1.2, true)
		"check":
			draw_polyline(PackedVector2Array([c + Vector2(-s * 0.3, 0), c + Vector2(-s * 0.08, s * 0.22), c + Vector2(s * 0.32, -s * 0.24)]), color, w * 1.3, true)
		"coin":
			draw_circle(c, s * 0.44, Color(0.8, 0.52, 0.08))
			draw_circle(c, s * 0.37, Color(1.0, 0.8, 0.25))
			draw_arc(c, s * 0.25, 0.0, TAU, 28, Color(0.86, 0.6, 0.12), w * 0.7, true)
		"drop":
			var base := c + Vector2(0, s * 0.12)
			var r := s * 0.28
			var points := PackedVector2Array([c + Vector2(0, -s * 0.44)])
			for i in range(17):
				var a: float = lerpf(-0.35, PI + 0.35, float(i) / 16.0)
				points.append(base + Vector2(cos(a), sin(a)) * r)
			draw_colored_polygon(points, color)
			draw_arc(base, r * 0.55, 0.3, 1.4, 8, Color(1, 1, 1, 0.7), w * 0.6, true)
		"gear":
			for i in range(8):
				var a: float = float(i) / 8.0 * TAU
				var dir := Vector2(cos(a), sin(a))
				draw_line(c + dir * s * 0.26, c + dir * s * 0.44, color, s * 0.15, true)
			draw_arc(c, s * 0.25, 0.0, TAU, 32, color, s * 0.15, true)
		"home":
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 0.42), c + Vector2(s * 0.44, -s * 0.02), c + Vector2(-s * 0.44, -s * 0.02)]), color)
			draw_rect(Rect2(c + Vector2(-s * 0.3, -s * 0.04), Vector2(s * 0.6, s * 0.42)), color)
			draw_rect(Rect2(c + Vector2(-s * 0.08, s * 0.12), Vector2(s * 0.16, s * 0.26)), Color(0, 0, 0, 0.45))
		"book":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.03, -s * 0.28), c + Vector2(-s * 0.42, -s * 0.36), c + Vector2(-s * 0.42, s * 0.26), c + Vector2(-s * 0.03, s * 0.36)]), color)
			draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.03, -s * 0.28), c + Vector2(s * 0.42, -s * 0.36), c + Vector2(s * 0.42, s * 0.26), c + Vector2(s * 0.03, s * 0.36)]), color)
			for i in range(3):
				var y := -s * 0.14 + i * s * 0.13
				draw_line(c + Vector2(-s * 0.34, y - s * 0.04), c + Vector2(-s * 0.1, y), Color(0, 0, 0, 0.35), w * 0.45, true)
				draw_line(c + Vector2(s * 0.34, y - s * 0.04), c + Vector2(s * 0.1, y), Color(0, 0, 0, 0.35), w * 0.45, true)
		"bag":
			draw_arc(c + Vector2(0, -s * 0.16), s * 0.17, PI, TAU, 14, color, w, true)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.32, -s * 0.16), c + Vector2(s * 0.32, -s * 0.16), c + Vector2(s * 0.4, s * 0.4), c + Vector2(-s * 0.4, s * 0.4)]), color)
			draw_circle(c + Vector2(0, s * 0.12), s * 0.11, Color(0, 0, 0, 0.35))
		"lock":
			draw_arc(c + Vector2(0, -s * 0.1), s * 0.18, PI, TAU, 14, color, w, true)
			draw_rect(Rect2(c + Vector2(-s * 0.28, -s * 0.1), Vector2(s * 0.56, s * 0.46)), color)
			draw_circle(c + Vector2(0, s * 0.12), s * 0.07, Color(0, 0, 0, 0.5))
		"gauge":
			draw_arc(c + Vector2(0, s * 0.12), s * 0.38, PI, TAU, 24, color, w * 1.2, true)
			draw_line(c + Vector2(0, s * 0.12), c + Vector2(s * 0.2, -s * 0.16), color, w, true)
			draw_circle(c + Vector2(0, s * 0.12), s * 0.08, color)
		"cross":
			draw_rect(Rect2(c + Vector2(-s * 0.12, -s * 0.36), Vector2(s * 0.24, s * 0.72)), color)
			draw_rect(Rect2(c + Vector2(-s * 0.36, -s * 0.12), Vector2(s * 0.72, s * 0.24)), color)
		"dot":
			draw_circle(c, s * 0.34, color)
		"tank":
			draw_rect(Rect2(c + Vector2(-s * 0.42, -s * 0.28), Vector2(s * 0.84, s * 0.6)), color, false, w)
			draw_line(c + Vector2(-s * 0.34, -s * 0.1), c + Vector2(s * 0.34, -s * 0.1), color, w * 0.6, true)
			draw_circle(c + Vector2(-s * 0.08, s * 0.12), s * 0.08, color)
		_:
			draw_circle(c, s * 0.3, color)
