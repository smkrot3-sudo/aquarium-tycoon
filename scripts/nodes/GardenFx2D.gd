extends Node2D
class_name GardenFx2D
## The moving part of the garden's sky: clouds drifting past, rain, a storm's lightning, snow.
## RoomView draws the still scenery; this node sits above the tanks, in the same world
## coordinates, and only draws while the camera is looking at the garden.

var room: RoomView


func _process(_delta: float) -> void:
	var show: bool = room != null and room.garden_visible()
	if show != visible:
		visible = show
	if show:
		queue_redraw()


func _draw() -> void:
	if room == null:
		return
	var x0: float = room.garden_left()
	var x1: float = room.garden_right()
	var span: float = maxf(x1 - x0, 1200.0)
	var t: float = Time.get_ticks_msec() * 0.001
	var kind: int = Weather.kind
	var day: float = room.daylight()

	## Clouds: a few small white ones when it is sunny, many dark ones when it rains.
	var cloud_count := 4
	var cloud_tint := Color(1.0, 1.0, 1.0, 0.92)
	match kind:
		Weather.Kind.SUNNY:
			cloud_count = 3
		Weather.Kind.HEAT:
			cloud_count = 1
		Weather.Kind.CLOUDY:
			cloud_count = 9
			cloud_tint = Color(0.86, 0.88, 0.9, 0.95)
		Weather.Kind.RAIN, Weather.Kind.SNOW:
			cloud_count = 11
			cloud_tint = Color(0.66, 0.69, 0.74, 0.97)
		Weather.Kind.STORM:
			cloud_count = 13
			cloud_tint = Color(0.38, 0.4, 0.47, 0.98)
	cloud_tint = cloud_tint.lerp(Color(0.2, 0.22, 0.32, cloud_tint.a), 1.0 - day)
	for i in range(cloud_count):
		var travel: float = fmod(float(i) * 1531.0 + t * (14.0 + float(i % 3) * 7.0), span + 2400.0)
		var cx: float = x0 - 1200.0 + travel
		var cy: float = -3100.0 + float((i * 277) % 1000)
		var size: float = 1.0 + float(i % 4) * 0.25
		for puff in [Vector3(0.0, 0.0, 150.0), Vector3(150.0, -50.0, 190.0), Vector3(330.0, 0.0, 160.0), Vector3(-130.0, 30.0, 110.0), Vector3(450.0, 40.0, 100.0)]:
			draw_circle(Vector2(cx + puff.x * size, cy + puff.y * size), puff.z * size, cloud_tint)

	var wet: bool = kind == Weather.Kind.RAIN or kind == Weather.Kind.STORM
	if wet:
		var drops: int = 170 if kind == Weather.Kind.STORM else 100
		var color := Color(0.72, 0.82, 0.96, 0.55)
		for i in range(drops):
			var x: float = x0 + fmod(float(i) * 197.3, span)
			var y: float = fmod(float(i) * 311.7 + t * 1500.0, 2700.0) - 2700.0
			draw_line(Vector2(x, y), Vector2(x - 26.0, y + 90.0), color, 4.0)
		## Rings where the drops land on the ground and the pond.
		for i in range(26):
			var phase: float = fmod(t * 1.3 + float(i) * 0.37, 1.0)
			var rx: float = x0 + fmod(float(i) * 433.7 + floorf(t * 1.3 + float(i) * 0.37) * 211.0, span)
			var rw: float = 14.0 + phase * 50.0
			draw_arc(Vector2(rx, 4.0), rw, 0.0, TAU, 16, Color(1, 1, 1, 0.5 * (1.0 - phase)), 3.0)
		if kind == Weather.Kind.STORM and fmod(t, 8.0) < 0.14:
			draw_rect(Rect2(x0, -3800.0, span, 3800.0), Color(1.0, 1.0, 0.95, 0.3))
	elif kind == Weather.Kind.SNOW:
		for i in range(110):
			var sway: float = sin(t * 0.9 + float(i)) * 50.0
			var x: float = x0 + fmod(float(i) * 173.9, span) + sway
			var y: float = fmod(float(i) * 251.3 + t * 170.0, 2700.0) - 2700.0
			draw_circle(Vector2(x, y), 6.0 + float(i % 3) * 2.0, Color(1, 1, 1, 0.9))
	elif kind == Weather.Kind.HEAT:
		## A shimmering warm haze low over the garden.
		draw_rect(Rect2(x0, -520.0, span, 520.0), Color(1.0, 0.85, 0.5, 0.07 + 0.03 * sin(t * 1.5)))
