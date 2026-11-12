extends Node2D
class_name TankFrame2D
## The outside of one tank, drawn around its water in the tank's local pixels: the black glass
## rim, a lid or lighting hood on top, reflections on the front glass, and the stand it rests on
## (a little table for the nano tanks, a wooden cabinet with doors for the bigger ones), plus a
## shadow on the floor. TankController owns it and sizes everything from the tank's liters.

var tank: TankController

const WOOD_DARK := Color(0.33, 0.21, 0.12)
const WOOD_MID := Color(0.45, 0.29, 0.16)
const WOOD_LIGHT := Color(0.58, 0.39, 0.22)
const RIM_COLOR := Color(0.06, 0.07, 0.09)


func _draw() -> void:
	if tank == null:
		return
	var w: float = tank._view_rect.size.x
	var h: float = tank._view_rect.size.y
	var t: float = TankController.RIM_PX
	var plate: float = TankController.PLATE_PX
	var over: float = TankController.STAND_OVERHANG_PX
	var floor_y: float = tank.floor_local_y()
	var plate_top: float = h + t
	var stand_top: float = plate_top + plate
	if tank.is_pond():
		_draw_pond(w, h, t)
		return

	_draw_stand(w, plate_top, stand_top, floor_y, over, t)
	_draw_glass_and_rim(w, h, t)
	_draw_lid(w, t)


## A garden pond seen in cross-section: dark liner around the water, stone coping and lily pads
## on top, ice in winter, and a net strung over it when the player bought one.
func _draw_pond(w: float, h: float, t: float) -> void:
	var water_top: float = tank.water_top_y()
	var liner := Color(0.12, 0.16, 0.13)
	draw_rect(Rect2(-t, -2.0, t, h + t + 2.0), liner)
	draw_rect(Rect2(w, -2.0, t, h + t + 2.0), liner)
	draw_rect(Rect2(-t, h, w + 2.0 * t, t), liner)
	draw_rect(Rect2(0.0, 0.0, w, water_top), Color(0.86, 0.93, 0.97, 0.3))
	draw_line(Vector2(0.0, water_top), Vector2(w, water_top), Color(1.0, 1.0, 1.0, 0.5), 3.0)
	draw_rect(Rect2(0.0, water_top, w, 10.0), Color(1.0, 1.0, 1.0, 0.1))
	## A little light slanting through the water.
	draw_colored_polygon(PackedVector2Array([Vector2(w * 0.12, water_top), Vector2(w * 0.2, water_top), Vector2(w * 0.1, h), Vector2(w * 0.0, h)]), Color(1, 1, 0.9, 0.05))
	## Lily pads on the surface.
	var pad_count: int = maxi(2, int(w / 480.0))
	for i in range(pad_count):
		var px: float = w * (float(i) + 0.4 + 0.25 * sin(float(i) * 2.3)) / float(pad_count)
		var radius: float = 46.0 + float((i * 17) % 20)
		draw_colored_polygon(_ellipse(Vector2(px, water_top + 2.0), radius, radius * 0.22), Color(0.2, 0.52, 0.25, 0.95))
		draw_colored_polygon(_ellipse(Vector2(px + radius * 0.35, water_top - 4.0), 15.0, 8.0), Color(0.98, 0.78, 0.85, 0.95))
	## Stone coping around the top edge.
	var sx: float = -t - TankController.STAND_OVERHANG_PX
	var si: int = 0
	var edge: float = w + t + TankController.STAND_OVERHANG_PX
	while sx < edge:
		var sw: float = 70.0 + float((si * 29) % 50)
		var shade: float = 0.5 + float((si * 37) % 30) / 100.0
		draw_rect(Rect2(sx, -26.0, sw - 6.0, 34.0), Color(shade, shade * 0.97, shade * 0.9))
		draw_rect(Rect2(sx, -26.0, sw - 6.0, 6.0), Color(1, 1, 1, 0.22))
		sx += sw
		si += 1
	## Winter: ice over the water.
	if tank.is_frozen():
		draw_rect(Rect2(0.0, water_top - 4.0, w, 90.0), Color(0.85, 0.94, 1.0, 0.78))
		draw_rect(Rect2(0.0, water_top + 86.0, w, 70.0), Color(0.8, 0.92, 1.0, 0.2))
		for i in range(int(w / 140.0)):
			var cx: float = 70.0 + float(i) * 140.0
			draw_line(Vector2(cx, water_top), Vector2(cx + 40.0 * sin(float(i)), water_top + 70.0), Color(1, 1, 1, 0.7), 2.0)
		draw_rect(Rect2(0.0, 0.0, w, h), Color(0.8, 0.92, 1.0, 0.08))
	## A net strung over the water on two stakes.
	if tank.has_net:
		var net_col := Color(0.12, 0.35, 0.15, 0.8)
		draw_rect(Rect2(-t - 10.0, -190.0, 14.0, 190.0), Color(0.45, 0.3, 0.16))
		draw_rect(Rect2(w + t - 4.0, -190.0, 14.0, 190.0), Color(0.45, 0.3, 0.16))
		var nx: float = -t
		while nx <= w + t:
			draw_line(Vector2(nx, -170.0), Vector2(nx, -60.0), net_col, 2.0)
			nx += 46.0
		var ny: float = -170.0
		while ny <= -60.0:
			draw_line(Vector2(-t, ny), Vector2(w + t, ny), net_col, 2.0)
			ny += 44.0


static func _ellipse(center: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(21):
		var a: float = float(i) / 20.0 * TAU
		points.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	return points


func _draw_stand(w: float, plate_top: float, stand_top: float, floor_y: float, over: float, t: float) -> void:
	## Shadow on the floor.
	var shadow := PackedVector2Array()
	for i in range(21):
		var a: float = float(i) / 20.0 * TAU
		shadow.append(Vector2(w * 0.5 + cos(a) * (w * 0.5 + over + 60.0), floor_y + 10.0 + sin(a) * 26.0))
	draw_colored_polygon(shadow, Color(0.0, 0.0, 0.0, 0.22))

	var left: float = -over - t
	var width: float = w + 2.0 * (over + t)
	var small: bool = tank.tank_liters <= 25.0
	if small:
		## A little side table: apron under the plate and four legs.
		draw_rect(Rect2(left + 14.0, stand_top, width - 28.0, 44.0), WOOD_MID)
		draw_rect(Rect2(left + 14.0, stand_top + 40.0, width - 28.0, 6.0), WOOD_DARK)
		for lx in [left + 18.0, left + width - 18.0 - 26.0]:
			draw_rect(Rect2(lx, stand_top, 26.0, floor_y - stand_top), WOOD_MID)
			draw_rect(Rect2(lx + 18.0, stand_top, 8.0, floor_y - stand_top), WOOD_DARK)
	else:
		## A cabinet: carcass, doors with handles, plinth.
		draw_rect(Rect2(left + 8.0, stand_top, width - 16.0, floor_y - stand_top), WOOD_DARK)
		var plinth: float = 34.0
		var body_h: float = floor_y - stand_top - plinth
		var doors: int = clampi(int(round(w / 330.0)), 1, 7)
		var door_w: float = (width - 40.0) / float(doors)
		for i in range(doors):
			var dx: float = left + 20.0 + float(i) * door_w
			draw_rect(Rect2(dx + 4.0, stand_top + 12.0, door_w - 8.0, body_h - 20.0), WOOD_MID)
			draw_rect(Rect2(dx + 14.0, stand_top + 24.0, door_w - 28.0, body_h - 44.0), WOOD_LIGHT, false, 3.0)
			var handle_x: float = dx + (door_w - 16.0 if i % 2 == 0 else 16.0)
			draw_rect(Rect2(handle_x - 4.0, stand_top + body_h * 0.42, 8.0, 56.0), Color(0.85, 0.75, 0.5))
		draw_rect(Rect2(left + 8.0, floor_y - plinth, width - 16.0, plinth), Color(0.18, 0.12, 0.08))
	## Top plate with a lit front edge.
	draw_rect(Rect2(left, plate_top, width, TankController.PLATE_PX), WOOD_LIGHT)
	draw_rect(Rect2(left, plate_top, width, 5.0), Color(1.0, 0.9, 0.7, 0.35))
	draw_rect(Rect2(left, plate_top + TankController.PLATE_PX - 6.0, width, 6.0), WOOD_DARK)


func _draw_glass_and_rim(w: float, h: float, t: float) -> void:
	var water_top: float = tank.water_top_y()
	## Air above the water line, then the line itself.
	draw_rect(Rect2(0.0, 0.0, w, water_top), Color(0.86, 0.93, 0.97, 0.5))
	draw_line(Vector2(0.0, water_top), Vector2(w, water_top), Color(1.0, 1.0, 1.0, 0.55), 3.0)
	draw_rect(Rect2(0.0, water_top, w, 10.0), Color(1.0, 1.0, 1.0, 0.1))
	## Reflections on the front glass.
	draw_colored_polygon(PackedVector2Array([Vector2(w * 0.08, 0.0), Vector2(w * 0.17, 0.0), Vector2(w * 0.06, h), Vector2(-w * 0.03, h)]).duplicate(), Color(1, 1, 1, 0.07))
	draw_colored_polygon(PackedVector2Array([Vector2(w * 0.2, 0.0), Vector2(w * 0.23, 0.0), Vector2(w * 0.12, h), Vector2(w * 0.09, h)]), Color(1, 1, 1, 0.05))
	draw_rect(Rect2(0.0, 0.0, w * 0.012, h), Color(1, 1, 1, 0.16))
	## The black glass rim, with a thin bright inner edge.
	draw_rect(Rect2(-t, -t, w + 2.0 * t, t), RIM_COLOR)
	draw_rect(Rect2(-t, h, w + 2.0 * t, t), RIM_COLOR)
	draw_rect(Rect2(-t, 0.0, t, h), RIM_COLOR)
	draw_rect(Rect2(w, 0.0, t, h), RIM_COLOR)
	draw_rect(Rect2(0.0, 0.0, w, h), Color(1, 1, 1, 0.22), false, 2.0)
	draw_line(Vector2(w * 0.5, -t), Vector2(w * 0.5, 0.0), Color(0.2, 0.22, 0.26), 6.0)


## A lighting hood when a light is installed (with its glow), otherwise just a cross brace.
func _draw_lid(w: float, t: float) -> void:
	var lit: bool = tank.light_equipment != null
	if lit:
		draw_rect(Rect2(-t, -t - 44.0, w + 2.0 * t, 44.0), Color(0.16, 0.17, 0.2))
		draw_rect(Rect2(-t, -t - 44.0, w + 2.0 * t, 8.0), Color(0.3, 0.32, 0.36))
		draw_rect(Rect2(8.0, -t - 8.0, w - 16.0, 8.0), Color(1.0, 0.97, 0.82, 0.9))
		draw_rect(Rect2(8.0, -t, w - 16.0, 30.0), Color(1.0, 0.97, 0.82, 0.12))
	else:
		draw_rect(Rect2(-t, -t - 14.0, w + 2.0 * t, 14.0), Color(0.12, 0.13, 0.16))
