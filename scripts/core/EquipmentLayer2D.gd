extends Node2D
class_name EquipmentLayer2D
## The equipment inside a tank, drawn where and how big it really goes, in the tank's local
## pixels (TankController.PX_PER_CM per cm):
##  - heater: a glass tube held to the left glass by suction cups, its cap just above the water,
##    the coil glowing while it heats, the cable running up and over the rim
##  - sponge filter: a sponge on the sand in the back corner with its uplift tube and airline
##  - canister filter: intake pipe with a strainer and a spray bar along the back, both running
##    over the rim to the canister hidden in the cabinet
##  - protein skimmer: hangs on the back corner, its collection cup above the rim
##  - air stone: on the sand, its airline running up the back glass and out over the rim
##  - powerhead: stuck to the right glass, pushing a current across the tank
## Two instances per tank: `above = false` draws everything in the water (behind the fish),
## `above = true` draws only the cables and pipes where they cross the rim (in front of it).

var tank: TankController
var above: bool = false

const AIRLINE := Color(0.62, 0.78, 0.74, 0.75)
const CABLE := Color(0.08, 0.08, 0.09)
const PIPE := Color(0.32, 0.45, 0.36)

var _skimmer_tex: Texture2D = preload("res://assets/equipment/protein_skimmer.png")
var _powerhead_tex: Texture2D = preload("res://assets/equipment/powerhead.png")


func cm(value: float) -> float:
	return value * TankController.PX_PER_CM


## Gear is real size, but a little forgiving at the extremes so it stays readable.
func _gear_scale() -> float:
	return clampf(tank._view_rect.size.y / cm(30.0), 0.75, 1.35)


func _water_top() -> float:
	return tank.water_top_y()


# ----------------------------------------------------------------------------------------
# Geometry shared with TankController (bubbles)
# ----------------------------------------------------------------------------------------

func air_stone_x() -> float:
	return tank._view_rect.size.x * 0.62


func sponge_center_x() -> float:
	return tank._view_rect.size.x - cm(1.2) - cm(3.4) * _gear_scale()


func sponge_top_y() -> float:
	return tank._sand_top_y + cm(0.6) - cm(8.0) * _gear_scale()


## Where streams of bubbles start: [{x, y}] (air stone on the sand, sponge filter uplift).
func bubble_sources() -> Array:
	var out: Array = []
	if tank.air_stone != null and tank.air_stone.id == "air_stone":
		out.append({"x": air_stone_x(), "y": tank._sand_top_y})
	if tank.filter != null and tank.filter.id == "basic_filter":
		out.append({"x": sponge_center_x(), "y": sponge_top_y()})
	return out


func _draw() -> void:
	if tank == null:
		return
	## Back to front: the air line runs behind the filter, the heater is on the near glass.
	if tank.air_stone != null:
		if tank.air_stone.id == "powerhead":
			_draw_powerhead()
		else:
			_draw_air_stone()
	if tank.filter != null:
		match tank.filter.id:
			"canister_filter":
				_draw_canister()
			"protein_skimmer":
				_draw_skimmer()
			_:
				_draw_sponge_filter()
	if tank.heater != null:
		_draw_heater()


## A line that leaves the water at `x` and goes over the rim towards the back (above layer).
func _over_rim(x: float, color: Color, width: float, lean: float) -> void:
	var rim := TankController.RIM_PX
	draw_polyline(PackedVector2Array([Vector2(x, 0.0), Vector2(x, -rim - 6.0), Vector2(x + lean * 0.5, -rim - 16.0), Vector2(x + lean, -rim - 12.0)]), color, width, true)


# ----------------------------------------------------------------------------------------
# Heater
# ----------------------------------------------------------------------------------------

func _draw_heater() -> void:
	var g := _gear_scale()
	var height_cm := tank._view_rect.size.y / TankController.PX_PER_CM
	var tube_w: float = cm(2.4) * g
	var cap_h: float = cm(3.0) * g
	var length: float = cm(clampf(height_cm * 0.62, 12.0, 34.0))
	var x: float = cm(0.9) + 10.0
	var top: float = _water_top() - cap_h * 0.55
	var bottom: float = minf(top + length, tank._sand_top_y - 10.0)
	var cx: float = x + tube_w * 0.5
	if above:
		_over_rim(cx, CABLE, 5.0, -40.0)
		return
	var failed: bool = tank.heater_failed
	var heating: bool = not failed and tank.temperature < tank.heater.heater_target_temp_c - 0.15
	# suction cups against the glass, with their clips
	for f in [0.32, 0.78]:
		var cy: float = lerpf(top + cap_h, bottom, f)
		draw_circle(Vector2(x - 6.0, cy), 9.0 * g, Color(0.85, 0.95, 1.0, 0.45))
		draw_rect(Rect2(x - 6.0, cy - 4.0, tube_w * 0.5 + 6.0, 8.0), Color(0.9, 0.95, 1.0, 0.55))
	# glass tube
	var tube := Rect2(x, top + cap_h - 4.0, tube_w, bottom - top - cap_h + 4.0)
	draw_rect(tube, Color(0.85, 0.95, 1.0, 0.28))
	draw_circle(Vector2(cx, tube.end.y), tube_w * 0.5, Color(0.85, 0.95, 1.0, 0.28))
	draw_rect(tube, Color(1, 1, 1, 0.55), false, 2.0)
	draw_line(Vector2(x + 4.0, tube.position.y + 6.0), Vector2(x + 4.0, tube.end.y - 4.0), Color(1, 1, 1, 0.5), 2.0)
	# heating coil
	var coil := Color(0.55, 0.55, 0.58) if failed else (Color(1.0, 0.36, 0.14) if heating else Color(0.72, 0.32, 0.22))
	var pts := PackedVector2Array()
	var coil_top: float = tube.position.y + tube.size.y * 0.12
	var coil_bottom: float = tube.end.y - tube.size.y * 0.1
	var turns := int(clampf((coil_bottom - coil_top) / 9.0, 6.0, 60.0))
	for i in range(turns + 1):
		var t := float(i) / float(turns)
		pts.append(Vector2(cx + (tube_w * 0.28 if i % 2 == 0 else -tube_w * 0.28), lerpf(coil_top, coil_bottom, t)))
	if heating:
		draw_polyline(pts, Color(1.0, 0.55, 0.2, 0.35), 7.0, true)
	draw_polyline(pts, coil, 2.5, true)
	# control cap above the water line, with its dial and indicator light
	draw_rect(Rect2(x - 2.0, top, tube_w + 4.0, cap_h), Color(0.18, 0.19, 0.22))
	draw_rect(Rect2(x - 2.0, top, tube_w + 4.0, cap_h * 0.3), Color(0.3, 0.31, 0.35))
	draw_circle(Vector2(cx, top + cap_h * 0.62), tube_w * 0.22, Color(0.55, 0.57, 0.6))
	var led := Color(0.4, 0.4, 0.4) if failed else (Color(1.0, 0.25, 0.2) if heating else Color(0.3, 0.95, 0.4))
	draw_circle(Vector2(x + tube_w - 3.0, top + cap_h * 0.25), 3.5, led)
	draw_line(Vector2(cx, top), Vector2(cx, 0.0), CABLE, 5.0, true)


# ----------------------------------------------------------------------------------------
# Filters
# ----------------------------------------------------------------------------------------

func _draw_sponge_filter() -> void:
	var g := _gear_scale()
	var w: float = cm(6.8) * g
	var h: float = cm(8.0) * g
	var cx := sponge_center_x()
	var bottom: float = tank._sand_top_y + cm(0.6)
	var top: float = bottom - h
	var uplift_top: float = _water_top() + cm(1.6)
	if above:
		_over_rim(cx + cm(0.5), AIRLINE, 4.0, 46.0)
		return
	# uplift tube with its elbow outlet
	var tube_w: float = cm(1.5) * g
	draw_rect(Rect2(cx - tube_w * 0.5, uplift_top, tube_w, top - uplift_top + 4.0), Color(0.85, 0.95, 1.0, 0.3))
	draw_rect(Rect2(cx - tube_w * 0.5, uplift_top, tube_w, top - uplift_top + 4.0), Color(1, 1, 1, 0.5), false, 2.0)
	draw_rect(Rect2(cx - tube_w * 1.6, uplift_top - tube_w * 0.2, tube_w * 1.6, tube_w * 0.9), Color(0.85, 0.95, 1.0, 0.35))
	# airline from the top of the uplift to the surface
	draw_line(Vector2(cx + cm(0.5), uplift_top), Vector2(cx + cm(0.5), 0.0), AIRLINE, 4.0, true)
	# sponge with pores, on a weighted base
	draw_rect(Rect2(cx - w * 0.55, bottom - cm(1.0) * g, w * 1.1, cm(1.0) * g), Color(0.25, 0.27, 0.3))
	var sponge := Rect2(cx - w * 0.5, top, w, h - cm(1.0) * g)
	draw_rect(sponge, Color(0.2, 0.25, 0.22))
	draw_rect(Rect2(sponge.position, Vector2(sponge.size.x * 0.25, sponge.size.y)), Color(0.27, 0.32, 0.28))
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in range(int(sponge.size.x * sponge.size.y / 60.0)):
		draw_circle(sponge.position + Vector2(rng.randf() * sponge.size.x, rng.randf() * sponge.size.y), rng.randf_range(1.0, 2.4), Color(0.1, 0.13, 0.11))
	draw_rect(Rect2(cx - w * 0.55, top - 6.0, w * 1.1, 8.0), Color(0.3, 0.32, 0.36))


func _draw_canister() -> void:
	var g := _gear_scale()
	var w: float = tank._view_rect.size.x
	var pipe_w: float = cm(1.6) * g
	var intake_x: float = w - cm(3.0)
	var outflow_x: float = cm(5.0) + 40.0
	if above:
		_over_rim(intake_x, PIPE, pipe_w, 30.0)
		_over_rim(outflow_x, PIPE, pipe_w, -30.0)
		return
	# intake: down the back glass to a slotted strainer near the bottom
	var strainer_top: float = tank._sand_top_y - cm(9.0) * g
	draw_line(Vector2(intake_x, 0.0), Vector2(intake_x, strainer_top), PIPE, pipe_w)
	draw_line(Vector2(intake_x - pipe_w * 0.3, 0.0), Vector2(intake_x - pipe_w * 0.3, strainer_top), Color(1, 1, 1, 0.18), 2.0)
	var strainer := Rect2(intake_x - pipe_w * 0.8, strainer_top, pipe_w * 1.6, cm(6.0) * g)
	draw_rect(strainer, Color(0.28, 0.38, 0.32))
	for i in range(6):
		var y: float = strainer.position.y + 6.0 + float(i) * (strainer.size.y - 12.0) / 5.0
		draw_line(Vector2(strainer.position.x + 4.0, y), Vector2(strainer.end.x - 4.0, y), Color(0.1, 0.14, 0.12), 2.0)
	# outflow: down a little, then a spray bar along the back just under the surface
	var bar_y: float = _water_top() + cm(2.5)
	draw_line(Vector2(outflow_x, 0.0), Vector2(outflow_x, bar_y), PIPE, pipe_w)
	var bar_end: float = outflow_x + w * 0.32
	draw_line(Vector2(outflow_x, bar_y), Vector2(bar_end, bar_y), PIPE, pipe_w * 0.8)
	var hole_x := outflow_x + cm(2.0)
	while hole_x < bar_end - 4.0:
		draw_circle(Vector2(hole_x, bar_y + pipe_w * 0.25), 2.0, Color(0.08, 0.1, 0.09))
		draw_line(Vector2(hole_x, bar_y + pipe_w * 0.5), Vector2(hole_x + 10.0, bar_y + pipe_w * 0.5 + 22.0), Color(1, 1, 1, 0.12), 2.0)
		hole_x += cm(2.4)


func _draw_skimmer() -> void:
	if above or _skimmer_tex == null:
		return
	var h: float = tank._view_rect.size.y * 0.55 + TankController.RIM_PX + 30.0
	var tex_size := _skimmer_tex.get_size()
	var w: float = h * tex_size.x / tex_size.y
	var rect := Rect2(tank._view_rect.size.x - w - cm(0.5), -TankController.RIM_PX - 30.0, w, h)
	draw_texture_rect(_skimmer_tex, rect, false, Color(1, 1, 1, 0.92))


# ----------------------------------------------------------------------------------------
# Air
# ----------------------------------------------------------------------------------------

func _draw_air_stone() -> void:
	var g := _gear_scale()
	var x := air_stone_x()
	var w: float = cm(3.6) * g
	var h: float = cm(2.2) * g
	var bottom: float = tank._sand_top_y + cm(0.7)
	var corner_x: float = tank._view_rect.size.x - cm(0.6)
	if above:
		_over_rim(corner_x, AIRLINE, 4.0, 30.0)
		return
	# airline: up from the stone, along the back glass to the corner, then up to the rim
	var rise: float = bottom - h - cm(2.5)
	draw_polyline(PackedVector2Array([Vector2(x, bottom - h), Vector2(x, rise), Vector2(x + cm(2.0), rise - cm(1.2)), Vector2(corner_x, rise - cm(1.2)), Vector2(corner_x, 0.0)]), AIRLINE, 4.0, true)
	var stone := Rect2(x - w * 0.5, bottom - h, w, h)
	draw_rect(stone, Color(0.5, 0.52, 0.55))
	draw_circle(Vector2(stone.position.x, stone.get_center().y), h * 0.5, Color(0.5, 0.52, 0.55))
	draw_circle(Vector2(stone.end.x, stone.get_center().y), h * 0.5, Color(0.5, 0.52, 0.55))
	draw_rect(Rect2(stone.position.x, stone.position.y, w, h * 0.35), Color(0.62, 0.64, 0.67))
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	for i in range(14):
		draw_circle(stone.position + Vector2(rng.randf() * w, rng.randf() * h), 1.5, Color(0.36, 0.38, 0.41))


func _draw_powerhead() -> void:
	if _powerhead_tex == null:
		return
	var g := _gear_scale()
	var length: float = cm(10.0) * g
	var tex_size := _powerhead_tex.get_size()
	var height: float = length * tex_size.y / tex_size.x
	## Stuck to the back glass on the left half (heater on the left side glass, skimmer in the
	## right corner), its outlet pushing a current along the tank.
	var left: float = tank._view_rect.size.x * 0.2
	var top: float = _water_top() + tank._view_rect.size.y * 0.16
	var cable_x: float = left + length * 0.3
	if above:
		_over_rim(cable_x, CABLE, 5.0, -30.0)
		return
	draw_line(Vector2(cable_x, top + height * 0.2), Vector2(cable_x, 0.0), CABLE, 5.0, true)
	draw_texture_rect(_powerhead_tex, Rect2(left, top, length, height), false)
	for i in range(4):
		var y: float = top + height * (0.35 + 0.1 * float(i))
		draw_line(Vector2(left + length + 10.0, y), Vector2(left + length + 90.0 + float(i) * 30.0, y + 6.0), Color(1, 1, 1, 0.1), 2.0)
