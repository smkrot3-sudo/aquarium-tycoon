extends Node2D
class_name RoomView
## The room the aquariums stand in. Every owned tank is placed side by side along one wall, on
## the floor, at its real relative size; this node draws the wall, floor, windows and furniture
## behind them and is also the camera: it scales and moves itself (and so every tank) so the
## player can look at one tank (FOCUS), look closer (CLOSE) or step back and see the whole room
## (OVERVIEW). Dragging pans; tapping another tank's water goes to that tank.
##
## World units are tank-local pixels (12 px per cm); the floor is y = 0 and up is negative.

enum Zoom { FOCUS, CLOSE, OVERVIEW }

const GAP_PX := 520.0
const WINDOW_SPACING := 7000.0
const WALL_TOP := -3800.0

var zoom_mode: int = Zoom.FOCUS
var game: GameController

var _tanks: Array = []
var _focus_index: int = 0
var _cam_center: Vector2 = Vector2.ZERO
var _cam_scale: float = 0.5
var _target_center: Vector2 = Vector2.ZERO
var _target_scale: float = 0.5
var _snap: bool = true
var _left: float = -2000.0
var _right: float = 3000.0
var _tallest: float = 900.0
var _redraw_timer: float = 0.0
var _panning: bool = false
var _pan_moved: float = 0.0


func setup(game_ref: GameController, tank_nodes: Array) -> void:
	game = game_ref
	_tanks = tank_nodes
	for tank in _tanks:
		tank.layout_changed.connect(layout)
	layout()
	_snap = true


## Places every owned tank along the wall (slot order) and works out the room's extent.
func layout() -> void:
	var x := 0.0
	_tallest = 600.0
	var first := true
	for tank in _tanks:
		if tank.locked:
			continue
		var ext: Rect2 = tank.exterior_rect()
		tank.position = Vector2(x - ext.position.x, -tank.floor_local_y())
		if first:
			_left = x
			first = false
		x += ext.size.x + GAP_PX
		_right = x - GAP_PX
		_tallest = maxf(_tallest, ext.size.y)
	if first:
		_left = 0.0
		_right = 2000.0
	queue_redraw()


func focus_tank(index: int, instant: bool = false) -> void:
	_focus_index = index
	if instant:
		_snap = true


func set_zoom(mode: int) -> void:
	zoom_mode = mode


func cycle_zoom() -> int:
	zoom_mode = (zoom_mode + 1) % 3
	return zoom_mode


func zoom_label_key() -> String:
	return ["zoom_focus", "zoom_close", "zoom_room"][zoom_mode]


func _tank_world_rect(index: int) -> Rect2:
	var tank: TankController = _tanks[index]
	var ext: Rect2 = tank.exterior_rect()
	return Rect2(tank.position + ext.position, ext.size)


func _screen_info() -> Dictionary:
	var screen := get_viewport_rect().size
	var avail := Vector2(screen.x - 40.0, screen.y - TankController.HUD_TOP_PX - TankController.HUD_BOTTOM_PX - 24.0)
	var anchor := Vector2(screen.x * 0.5, TankController.HUD_TOP_PX + (screen.y - TankController.HUD_TOP_PX - TankController.HUD_BOTTOM_PX) * 0.5)
	return {"avail": avail, "anchor": anchor}


## Where the camera should end up for the current zoom mode and focused tank.
func _update_target() -> void:
	if _tanks.is_empty() or _focus_index >= _tanks.size() or _tanks[_focus_index].locked:
		return
	var info := _screen_info()
	var avail: Vector2 = info["avail"]
	var ext := _tank_world_rect(_focus_index)
	## Framing: the glass, hood and the top of the stand, so the tank is as big as it can be
	## while the room around it is still seen; the rest of the stand runs off the bottom.
	var focus_tank: TankController = _tanks[_focus_index]
	var framed := Rect2(ext.position.x, ext.position.y, ext.size.x, 52.0 + focus_tank._view_rect.size.y + TankController.RIM_PX + TankController.PLATE_PX + focus_tank.stand_height_px(focus_tank.tank_liters) * 0.34)
	var fit: float = minf(minf(avail.x / framed.size.x, avail.y / framed.size.y), 2.4)
	match zoom_mode:
		Zoom.FOCUS:
			_target_scale = fit
			_target_center = framed.get_center()
		Zoom.CLOSE:
			_target_scale = minf(fit * 1.9, 3.4)
			## Keep the water, not the stand, in the middle when zoomed in.
			var tank: TankController = _tanks[_focus_index]
			_target_center = tank.position + tank._view_rect.get_center()
		Zoom.OVERVIEW:
			var width := _right - _left + 700.0
			_target_scale = minf(minf(avail.x / width, avail.y / (_tallest * 1.25)), 0.4)
			var room_center := Vector2((_left + _right) * 0.5, -_tallest * 0.55)
			## A row too wide for the screen follows the focused tank instead.
			if width * _target_scale > avail.x * 1.02:
				room_center.x = ext.get_center().x
			_target_center = room_center


func _process(delta: float) -> void:
	if not _panning:
		_update_target()
	var blend: float = 1.0 if _snap else 1.0 - exp(-delta * 7.0)
	_snap = false
	_cam_center = _cam_center.lerp(_target_center, blend)
	_cam_scale = exp(lerpf(log(maxf(_cam_scale, 0.001)), log(maxf(_target_scale, 0.001)), blend))
	var info := _screen_info()
	scale = Vector2.ONE * _cam_scale
	position = (info["anchor"] as Vector2) - _cam_center * _cam_scale
	_redraw_timer += delta
	if _redraw_timer >= 1.0:
		_redraw_timer = 0.0
		queue_redraw()


# ----------------------------------------------------------------------------------------
# Dragging pans the camera (only reaches here when no tank used the touch)
# ----------------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if game != null and game.tool != TankController.Tool.HAND:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_panning = event.pressed
		_pan_moved = 0.0
	elif event is InputEventScreenTouch:
		_panning = event.pressed
		_pan_moved = 0.0
	elif _panning and event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_pan(event.relative)
	elif _panning and event is InputEventScreenDrag:
		_pan(event.relative)


func _pan(relative: Vector2) -> void:
	_pan_moved += relative.length()
	if _pan_moved < 10.0:
		return
	_target_center -= relative / maxf(_cam_scale, 0.001)
	_target_center.x = clampf(_target_center.x, _left - 600.0, _right + 600.0)
	_target_center.y = clampf(_target_center.y, -_tallest * 1.3, 200.0)


# ----------------------------------------------------------------------------------------
# The room itself
# ----------------------------------------------------------------------------------------

func _daylight() -> float:
	var hour: float = TimeManager.current_hour_of_day()
	return clampf(sin((hour - 6.0) / 12.0 * PI) * 1.4 + 0.2, 0.0, 1.0)


func _tint(color: Color, day: float) -> Color:
	var night := Color(color.r * 0.42, color.g * 0.46, color.b * 0.62)
	return night.lerp(color, day)


func _draw() -> void:
	var day := _daylight()
	var left := _left - 5200.0
	var right := _right + 5200.0
	var width := right - left

	# wall
	draw_rect(Rect2(left, WALL_TOP, width, -WALL_TOP), _tint(Color(0.9, 0.85, 0.76), day))
	var stripe := _tint(Color(0.86, 0.8, 0.7), day)
	var x := left
	while x < right:
		draw_rect(Rect2(x, WALL_TOP, 110.0, -WALL_TOP), stripe)
		x += 420.0
	# wainscot and baseboard
	var wain := _tint(Color(0.55, 0.62, 0.66), day)
	draw_rect(Rect2(left, -1050.0, width, 1050.0), wain)
	draw_rect(Rect2(left, -1062.0, width, 16.0), _tint(Color(0.93, 0.93, 0.9), day))
	x = left
	while x < right:
		draw_rect(Rect2(x + 40.0, -980.0, 440.0, 740.0), _tint(Color(0.48, 0.55, 0.6), day), false, 6.0)
		x += 560.0
	draw_rect(Rect2(left, -140.0, width, 140.0), _tint(Color(0.93, 0.92, 0.88), day))
	draw_rect(Rect2(left, -146.0, width, 8.0), _tint(Color(0.78, 0.76, 0.7), day))

	# floor
	var floor_a := _tint(Color(0.62, 0.43, 0.26), day)
	var floor_b := _tint(Color(0.55, 0.37, 0.22), day)
	draw_rect(Rect2(left, 0.0, width, 2400.0), floor_a)
	var row := 0
	var y := 0.0
	while y < 2400.0:
		var h := 150.0 + y * 0.12
		draw_rect(Rect2(left, y, width, h * 0.5), floor_b if row % 2 == 0 else floor_a)
		draw_line(Vector2(left, y), Vector2(right, y), _tint(Color(0.4, 0.27, 0.15), day), 3.0)
		var jx := left + float((row * 337) % 700)
		while jx < right:
			draw_line(Vector2(jx, y), Vector2(jx, y + h), _tint(Color(0.4, 0.27, 0.15), day), 2.0)
			jx += 760.0
		y += h
		row += 1
	draw_rect(Rect2(left, 0.0, width, 30.0), Color(0, 0, 0, 0.18))

	# windows, pictures, clock, plant, shelf: repeated along the wall
	var k := floori((left - 1500.0) / WINDOW_SPACING)
	while k * WINDOW_SPACING < right + 1500.0:
		var base := float(k) * WINDOW_SPACING
		_draw_window(base + 1400.0, day)
		_draw_picture(base + 3600.0, day)
		_draw_clock(base + 4700.0, day)
		_draw_plant(base + 5600.0, day)
		_draw_shelf(base + 6300.0, day)
		k += 1


func _draw_window(x: float, day: float) -> void:
	var w := 1500.0
	var top := -2650.0
	var h := 1900.0
	var sky_top := _tint(Color(0.45, 0.72, 0.95), day).lerp(Color(0.03, 0.05, 0.14), 1.0 - day)
	var sky_bottom := _tint(Color(0.75, 0.9, 1.0), day).lerp(Color(0.1, 0.13, 0.26), 1.0 - day)
	draw_polygon(PackedVector2Array([Vector2(x, top), Vector2(x + w, top), Vector2(x + w, top + h), Vector2(x, top + h)]), PackedColorArray([sky_top, sky_top, sky_bottom, sky_bottom]))
	if day < 0.45:
		for i in range(14):
			var sx := x + 80.0 + float((i * 397) % int(w - 160.0))
			var sy := top + 60.0 + float((i * 211) % 900)
			draw_circle(Vector2(sx, sy), 7.0, Color(1, 1, 0.9, 0.8 * (1.0 - day * 2.0)))
	else:
		draw_circle(Vector2(x + w * 0.72, top + 420.0), 130.0, Color(1.0, 0.95, 0.7, 0.9))
	var frame := _tint(Color(0.95, 0.94, 0.9), day)
	draw_rect(Rect2(x, top, w, h), frame, false, 34.0)
	draw_line(Vector2(x + w * 0.5, top), Vector2(x + w * 0.5, top + h), frame, 24.0)
	draw_line(Vector2(x, top + h * 0.5), Vector2(x + w, top + h * 0.5), frame, 24.0)
	draw_rect(Rect2(x - 40.0, top + h, w + 80.0, 50.0), frame)
	var curtain := _tint(Color(0.72, 0.28, 0.3), day)
	draw_polygon(PackedVector2Array([Vector2(x - 150.0, top - 60.0), Vector2(x + 220.0, top - 60.0), Vector2(x + 140.0, top + h + 40.0), Vector2(x - 150.0, top + h + 40.0)]), PackedColorArray([curtain]))
	draw_polygon(PackedVector2Array([Vector2(x + w + 150.0, top - 60.0), Vector2(x + w - 220.0, top - 60.0), Vector2(x + w - 140.0, top + h + 40.0), Vector2(x + w + 150.0, top + h + 40.0)]), PackedColorArray([curtain]))
	draw_line(Vector2(x - 260.0, top - 70.0), Vector2(x + w + 260.0, top - 70.0), _tint(Color(0.35, 0.25, 0.15), day), 16.0)
	if day > 0.4:
		## A warm patch of sunlight on the floor below the window.
		var light := PackedVector2Array([Vector2(x + 100.0, 40.0), Vector2(x + w - 100.0, 40.0), Vector2(x + w + 500.0, 700.0), Vector2(x - 400.0, 700.0)])
		draw_colored_polygon(light, Color(1.0, 0.95, 0.7, 0.14 * day))


func _draw_picture(x: float, day: float) -> void:
	var frame := _tint(Color(0.35, 0.22, 0.12), day)
	draw_rect(Rect2(x, -2400.0, 760.0, 560.0), frame)
	draw_rect(Rect2(x + 36.0, -2364.0, 688.0, 488.0), _tint(Color(0.78, 0.88, 0.92), day))
	draw_polygon(PackedVector2Array([Vector2(x + 36.0, -1876.0), Vector2(x + 260.0, -2160.0), Vector2(x + 430.0, -1950.0), Vector2(x + 560.0, -2080.0), Vector2(x + 724.0, -1876.0)]), PackedColorArray([_tint(Color(0.35, 0.55, 0.4), day)]))
	draw_circle(Vector2(x + 560.0, -2250.0), 46.0, _tint(Color(1.0, 0.9, 0.5), day))


func _draw_clock(x: float, day: float) -> void:
	var c := Vector2(x, -2150.0)
	draw_circle(c, 190.0, _tint(Color(0.3, 0.2, 0.12), day))
	draw_circle(c, 165.0, _tint(Color(0.97, 0.96, 0.92), day))
	for i in range(12):
		var a := float(i) / 12.0 * TAU
		draw_line(c + Vector2(sin(a), -cos(a)) * 135.0, c + Vector2(sin(a), -cos(a)) * 155.0, Color(0.2, 0.2, 0.2), 6.0)
	var minutes: float = TimeManager.sim_minutes_total
	var hour_angle := fmod(minutes / 60.0, 12.0) / 12.0 * TAU
	var minute_angle := fmod(minutes, 60.0) / 60.0 * TAU
	draw_line(c, c + Vector2(sin(hour_angle), -cos(hour_angle)) * 85.0, Color(0.15, 0.15, 0.15), 12.0)
	draw_line(c, c + Vector2(sin(minute_angle), -cos(minute_angle)) * 125.0, Color(0.15, 0.15, 0.15), 7.0)
	draw_circle(c, 12.0, Color(0.15, 0.15, 0.15))


func _draw_plant(x: float, day: float) -> void:
	var pot := _tint(Color(0.72, 0.4, 0.25), day)
	draw_polygon(PackedVector2Array([Vector2(x - 150.0, -330.0), Vector2(x + 150.0, -330.0), Vector2(x + 110.0, 0.0), Vector2(x - 110.0, 0.0)]), PackedColorArray([pot]))
	draw_rect(Rect2(x - 170.0, -360.0, 340.0, 50.0), _tint(Color(0.8, 0.46, 0.3), day))
	var leaf := _tint(Color(0.25, 0.55, 0.3), day)
	var leaf_dark := _tint(Color(0.18, 0.42, 0.24), day)
	for i in range(9):
		var a := -PI * 0.5 + (float(i) - 4.0) * 0.28
		var tip := Vector2(x, -330.0) + Vector2(cos(a), sin(a)) * (520.0 + float((i * 71) % 160))
		var mid := Vector2(x, -330.0) + Vector2(cos(a), sin(a)) * 260.0
		var side := Vector2(-sin(a), cos(a)) * 70.0
		draw_polygon(PackedVector2Array([Vector2(x, -330.0), mid + side, tip, mid - side]), PackedColorArray([leaf if i % 2 == 0 else leaf_dark]))


func _draw_shelf(x: float, day: float) -> void:
	var wood := _tint(Color(0.5, 0.33, 0.18), day)
	draw_rect(Rect2(x, -1700.0, 900.0, 40.0), wood)
	draw_rect(Rect2(x + 60.0, -1740.0, 40.0, 40.0), wood)
	var colors := [Color(0.7, 0.25, 0.25), Color(0.25, 0.45, 0.7), Color(0.9, 0.75, 0.3), Color(0.3, 0.6, 0.4), Color(0.6, 0.35, 0.6)]
	var bx := x + 80.0
	for i in range(7):
		var bh := 280.0 + float((i * 53) % 110)
		draw_rect(Rect2(bx, -1700.0 - bh, 70.0, bh), _tint(colors[i % colors.size()], day))
		bx += 76.0
	draw_circle(Vector2(x + 740.0, -1790.0), 70.0, _tint(Color(0.35, 0.6, 0.85), day))
	draw_rect(Rect2(x + 700.0, -1710.0, 80.0, 12.0), wood)
