extends Control
class_name LineGraph
## A simple line chart for the Stats and Advisor panels: one series, light grid, an optional
## dashed "danger" line, and the latest value marked with a dot.

var values: Array = []
var danger: float = -1.0
var line_color: Color = UiKit.COL_ACCENT
var value_format: String = "%.1f"
## True: the vertical axis starts at 0 (concentrations, counts). False: fits the data (temperature).
var zero_based: bool = true


func _init() -> void:
	custom_minimum_size = Vector2(0.0, 220.0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_data(new_values: Array, danger_value: float, color: Color, format: String, from_zero: bool) -> void:
	values = new_values
	danger = danger_value
	line_color = color
	value_format = format
	zero_based = from_zero
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.25))
	var font: Font = ThemeDB.fallback_font
	if values.size() < 2:
		draw_string(font, Vector2(16.0, size.y * 0.5), Localization.t("graph_no_data"), HORIZONTAL_ALIGNMENT_LEFT, size.x - 32.0, 20, UiKit.COL_MUTED)
		return

	var pad_left := 70.0
	var plot := Rect2(pad_left, 16.0, maxf(40.0, size.x - pad_left - 18.0), maxf(40.0, size.y - 16.0 - 30.0))
	var lo: float = values[0]
	var hi: float = values[0]
	for v in values:
		lo = minf(lo, float(v))
		hi = maxf(hi, float(v))
	if danger > 0.0:
		hi = maxf(hi, danger * 1.15)
	if zero_based:
		lo = 0.0
	if hi - lo < 0.001:
		hi = lo + 1.0
	var span := hi - lo
	lo -= 0.0 if zero_based else span * 0.1
	hi += span * 0.1
	span = hi - lo

	for i in range(5):
		var f: float = float(i) / 4.0
		var y: float = plot.end.y - f * plot.size.y
		draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), Color(1, 1, 1, 0.1), 1.0)
		draw_string(font, Vector2(4.0, y + 6.0), value_format % (lo + f * span), HORIZONTAL_ALIGNMENT_RIGHT, pad_left - 10.0, 16, UiKit.COL_MUTED)

	if danger > 0.0:
		var dy: float = plot.end.y - (danger - lo) / span * plot.size.y
		var x := plot.position.x
		while x < plot.end.x:
			draw_line(Vector2(x, dy), Vector2(minf(x + 10.0, plot.end.x), dy), UiKit.COL_BAD, 2.0)
			x += 18.0

	var points := PackedVector2Array()
	for i in range(values.size()):
		var px: float = plot.position.x + float(i) / float(values.size() - 1) * plot.size.x
		var py: float = plot.end.y - (float(values[i]) - lo) / span * plot.size.y
		points.append(Vector2(px, py))
	draw_polyline(points, line_color, 3.0, true)
	draw_circle(points[points.size() - 1], 6.0, line_color)
	draw_circle(points[points.size() - 1], 3.0, Color.WHITE)
	draw_string(font, Vector2(plot.position.x, size.y - 6.0), Localization.t("graph_days_back", [values.size()]), HORIZONTAL_ALIGNMENT_LEFT, plot.size.x, 16, UiKit.COL_MUTED)
