extends ModalPanel
class_name StatsPanel
## Graphs of how the current tank has done over the last weeks (water, temperature, fish, algae,
## mulm) and of the player's cash, from the History autoload.

## [key, History field ("" = cash series), Localization key, danger line, format, from zero]
const METRICS := [
	["ammonia", "ammonia", "stat_ammonia", WaterChemistry.AMMONIA_DANGER, "%.2f", true],
	["nitrite", "nitrite", "stat_nitrite", WaterChemistry.NITRITE_DANGER, "%.2f", true],
	["nitrate", "nitrate", "stat_nitrate", WaterChemistry.NITRATE_DANGER, "%.0f", true],
	["temp", "temp", "stat_temp", -1.0, "%.1f", false],
	["fish", "fish", "stat_fish", -1.0, "%.0f", true],
	["algae", "algae", "stat_algae", -1.0, "%.0f", true],
	["mulm", "mulm", "stat_mulm", -1.0, "%.0f", true],
	["cash", "", "stat_cash", -1.0, "%.0f", true],
]

var _metric: String = "nitrate"
var _chips: Array[Button] = []
var _graph: LineGraph
var _caption: Label


func _build() -> void:
	var row := UiKit.hbox(6)
	body.add_child(row)
	for i in range(METRICS.size()):
		var b := UiKit.button(Localization.t(METRICS[i][2]), "tab", 56.0, UiKit.FONT_SMALL)
		b.toggle_mode = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		b.pressed.connect(show_metric.bind(METRICS[i][0]))
		row.add_child(b)
		_chips.append(b)

	var card := UiKit.panel(UiKit.COL_CARD, 18, 12.0, 12.0)
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(card)
	var column := UiKit.vbox(8)
	card.add_child(column)
	_caption = UiKit.label("", UiKit.FONT_BODY, UiKit.COL_TEXT, true)
	column.add_child(_caption)
	_graph = LineGraph.new()
	column.add_child(_graph)

	game.state_changed.connect(func():
		if visible:
			refresh()
	)


func show_metric(key: String) -> void:
	_metric = key
	refresh()


func refresh() -> void:
	var tank := game.current_tank()
	set_title(Localization.t("stats_title", [game.tank_display_name(game.current_tank_index())]))
	var def: Array = METRICS[0]
	for i in range(METRICS.size()):
		_chips[i].set_pressed_no_signal(METRICS[i][0] == _metric)
		if METRICS[i][0] == _metric:
			def = METRICS[i]
	var values: Array = History.cash_values() if def[1] == "" else History.values(String(tank.name), def[1])
	var color: Color = UiKit.COL_GOLD if def[1] == "" else UiKit.COL_ACCENT
	_graph.set_data(values, float(def[3]), color, def[4], bool(def[5]))
	if values.is_empty():
		_caption.text = Localization.t(def[2])
	else:
		_caption.text = "%s: %s" % [Localization.t(def[2]), String(def[4]) % float(values[values.size() - 1])]
