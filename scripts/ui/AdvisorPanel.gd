extends ModalPanel
class_name AdvisorPanel
## The "?" next to the coach line: says WHY the coach is saying what it is (stocking, filter,
## last water change...), graphs the number involved, lists the fish concerned (tap one to open
## its card) and offers to do the suggested thing.

const METRIC_INFO := {
	"ammonia": ["ammonia", WaterChemistry.AMMONIA_DANGER, "%.2f", true],
	"nitrite": ["nitrite", WaterChemistry.NITRITE_DANGER, "%.2f", true],
	"nitrate": ["nitrate", WaterChemistry.NITRATE_DANGER, "%.0f", true],
	"temp": ["temp", -1.0, "%.1f", false],
	"algae": ["algae", -1.0, "%.0f", true],
	"mulm": ["mulm", -1.0, "%.0f", true],
}

var _title: Label
var _lines: VBoxContainer
var _graph: LineGraph
var _fish_row: HFlowContainer
var _act_button: Button


func _build() -> void:
	set_title(Localization.t("advisor_title"))
	var scroll := UiKit.scroll()
	body.add_child(scroll)
	var column := UiKit.vbox(10)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)

	var head := UiKit.panel(UiKit.COL_CARD, 18, 14.0, 12.0)
	column.add_child(head)
	_title = UiKit.paragraph("", UiKit.FONT_HEADING, UiKit.COL_GOLD)
	head.add_child(_title)

	var why := UiKit.panel(UiKit.COL_CARD, 18, 14.0, 12.0)
	column.add_child(why)
	_lines = UiKit.vbox(6)
	why.add_child(_lines)

	_graph = LineGraph.new()
	_graph.custom_minimum_size = Vector2(0.0, 200.0)
	column.add_child(_graph)

	_fish_row = HFlowContainer.new()
	_fish_row.add_theme_constant_override("h_separation", 8)
	_fish_row.add_theme_constant_override("v_separation", 8)
	column.add_child(_fish_row)

	_act_button = UiKit.button(Localization.t("advisor_do_it"), "primary", 68.0, UiKit.FONT_BUTTON)
	_act_button.pressed.connect(_do_it)
	column.add_child(_act_button)

	game.state_changed.connect(func():
		if visible:
			refresh()
	)


func refresh() -> void:
	var advice: Dictionary = game.advice()
	_title.text = advice["title"]
	for child in _lines.get_children():
		_lines.remove_child(child)
		child.queue_free()
	for line in advice["lines"]:
		_lines.add_child(UiKit.paragraph("• " + String(line), UiKit.FONT_BODY, UiKit.COL_TEXT))

	var metric: String = advice["metric"]
	_graph.visible = metric != ""
	if metric != "":
		var info: Array = METRIC_INFO[metric]
		_graph.set_data(History.values(String(game.current_tank().name), info[0]), float(info[1]), UiKit.COL_ACCENT, info[2], bool(info[3]))

	for child in _fish_row.get_children():
		_fish_row.remove_child(child)
		child.queue_free()
	for fish in advice["fish"]:
		if not is_instance_valid(fish):
			continue
		var b := UiKit.button(fish.fish_name, "secondary", 56.0, UiKit.FONT_BODY)
		b.pressed.connect(game.open_fish_detail.bind(fish))
		_fish_row.add_child(b)


func _do_it() -> void:
	var tip: Dictionary = game.current_tip()
	close()
	if tip["action"].is_valid():
		tip["action"].call()
