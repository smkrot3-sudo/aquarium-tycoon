extends Control
class_name Hud
## The in-game overlay on top of the full-screen tank:
##  - a floating top bar of readouts (cash, day, water, fish) plus home / tank-switch / settings
##  - a one-line "what to do next" coach that is itself a button
##  - a docked bottom bar with the six things a player actually does
## Heights here must match TankController.HUD_TOP_PX / HUD_BOTTOM_PX.

const REFRESH_INTERVAL := 0.25

var game: GameController

var _cash_label: Label
var _day_label: Label
var _water_label: Label
var _water_dot: UiIcon
var _fish_label: Label
var _tank_button: Button
var _tip_button: Button
var _tip_action: Callable
var _tip_kind: String = ""
var _feed_button: Button
var _water_button: Button
var _fish_button: Button
var _speed_button: Button
var _business_button: Button
var _tool_buttons: Array[Button] = []
var _tool_hint_holder: Control
var _tool_hint_label: Label
var _refresh_accum: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var insets := UiKit.safe_insets(get_viewport())
	_build_top_bar(insets)
	_build_tip()
	_build_tools(insets)
	_build_bottom_bar(insets)
	game.state_changed.connect(refresh)
	TimeManager.speed_changed.connect(_refresh_speed)
	refresh()


func _build_top_bar(insets: Vector2) -> void:
	var bar := UiKit.margin(insets.x + 4.0, 10.0, insets.y + 4.0, 0.0)
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)
	var row := UiKit.hbox(8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(row)

	var home_button := UiKit.action_button("", UiKit.icon("home", 34.0), "glass", false, Vector2(64.0, 60.0))
	home_button.pressed.connect(game.go_home)
	row.add_child(home_button)

	var cash_chip := UiKit.chip(60.0)
	cash_chip.get_meta("row").add_child(UiKit.icon("coin", 34.0))
	_cash_label = UiKit.label("$0", 28, UiKit.COL_GOLD, true)
	cash_chip.get_meta("row").add_child(_cash_label)
	row.add_child(cash_chip)

	var day_chip := UiKit.chip(60.0)
	_day_label = UiKit.label("", UiKit.FONT_BODY)
	day_chip.get_meta("row").add_child(_day_label)
	row.add_child(day_chip)

	_speed_button = UiKit.action_button("x1", null, "glass", false, Vector2(74.0, 60.0), UiKit.FONT_BODY)
	_speed_button.pressed.connect(TimeManager.cycle_speed)
	row.add_child(_speed_button)

	var water_chip := UiKit.chip(60.0)
	_water_dot = UiKit.icon("dot", 22.0, UiKit.COL_GOOD)
	water_chip.get_meta("row").add_child(_water_dot)
	_water_label = UiKit.label("", UiKit.FONT_BODY)
	water_chip.get_meta("row").add_child(_water_label)
	row.add_child(water_chip)

	var fish_chip := UiKit.chip(60.0)
	fish_chip.get_meta("row").add_child(UiKit.texture_icon("res://assets/fish/guppy.png", Vector2(46.0, 30.0)))
	_fish_label = UiKit.label("0", UiKit.FONT_BODY, UiKit.COL_TEXT, true)
	fish_chip.get_meta("row").add_child(_fish_label)
	row.add_child(fish_chip)

	row.add_child(UiKit.spacer())

	_business_button = UiKit.action_button("0", UiKit.icon("clipboard", 30.0), "glass", false, Vector2(0.0, 60.0), UiKit.FONT_BODY)
	_business_button.pressed.connect(func(): game.open_business())
	row.add_child(_business_button)

	_tank_button = UiKit.action_button(Localization.t("hud_tank_n", [1]), UiKit.icon("tank", 30.0), "glass", false, Vector2(0.0, 60.0), UiKit.FONT_BODY)
	_tank_button.pressed.connect(game.cycle_tank)
	row.add_child(_tank_button)

	var settings_button := UiKit.action_button("", UiKit.icon("gear", 34.0), "glass", false, Vector2(64.0, 60.0))
	settings_button.pressed.connect(game.open_settings)
	row.add_child(settings_button)


func _build_tip() -> void:
	var tip_holder := CenterContainer.new()
	tip_holder.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	tip_holder.offset_top = TankController.HUD_TOP_PX - 4.0
	tip_holder.offset_bottom = TankController.HUD_TOP_PX + 52.0
	tip_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tip_holder)
	var tip_row := UiKit.hbox(8)
	tip_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip_holder.add_child(tip_row)
	_tip_button = UiKit.button("", "glass", 52.0, UiKit.FONT_BODY)
	_tip_button.pressed.connect(_on_tip_pressed)
	tip_row.add_child(_tip_button)
	var why_button := UiKit.action_button("", UiKit.icon("question", 28.0), "glass", false, Vector2(56.0, 52.0))
	why_button.pressed.connect(game.open_advisor)
	tip_row.add_child(why_button)


## Left edge: which tool the finger is (hand / food / scraper / vacuum), plus a one-line hint
## of what the current tool does.
func _build_tools(insets: Vector2) -> void:
	var holder := VBoxContainer.new()
	holder.layout_direction = Control.LAYOUT_DIRECTION_LTR
	holder.add_theme_constant_override("separation", 6)
	## Bottom-left corner, just above the bottom bar, out of the way of the water.
	holder.anchor_left = 0.0
	holder.anchor_right = 0.0
	holder.anchor_top = 1.0
	holder.anchor_bottom = 1.0
	holder.offset_left = insets.x + 6.0
	holder.offset_right = insets.x + 62.0
	holder.offset_bottom = -(TankController.HUD_BOTTOM_PX + 10.0)
	holder.offset_top = holder.offset_bottom - 4.0 * 48.0 - 3.0 * 6.0
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	var defs := [
		[TankController.Tool.HAND, UiKit.icon("hand", 26.0)],
		[TankController.Tool.FOOD, UiKit.texture_icon("res://assets/food/food_flakes.png", Vector2(34.0, 22.0))],
		[TankController.Tool.SCRAPER, UiKit.icon("scraper", 26.0)],
		[TankController.Tool.VACUUM, UiKit.icon("vacuum", 26.0)],
	]
	for def in defs:
		var b := UiKit.action_button("", def[1], "glass", false, Vector2(56.0, 48.0))
		b.pressed.connect(game.set_tool.bind(def[0]))
		holder.add_child(b)
		_tool_buttons.append(b)

	var hint_holder := CenterContainer.new()
	hint_holder.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint_holder.offset_top = -(TankController.HUD_BOTTOM_PX + 64.0)
	hint_holder.offset_bottom = -(TankController.HUD_BOTTOM_PX + 12.0)
	hint_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint_holder)
	var chip := UiKit.chip(48.0)
	_tool_hint_label = UiKit.label("", UiKit.FONT_SMALL, UiKit.COL_TEXT, true)
	chip.get_meta("row").add_child(_tool_hint_label)
	hint_holder.add_child(chip)
	_tool_hint_holder = hint_holder


func _build_bottom_bar(insets: Vector2) -> void:
	var style := UiKit.box(Color(0.03, 0.08, 0.15, 1.0), 0, 0.0, 0.0)
	style.border_width_top = 3
	style.border_color = Color(0.35, 0.85, 0.95, 0.45)
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", style)
	bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -TankController.HUD_BOTTOM_PX
	add_child(bar)
	var pad := UiKit.margin(insets.x + 2.0, 9.0, insets.y + 2.0, 8.0)
	bar.add_child(pad)
	var row := UiKit.hbox(8)
	pad.add_child(row)

	var bar_size := Vector2(0.0, 78.0)
	_feed_button = _bar_button(row, Localization.t("hud_feed", [GameController.FEED_COST]), UiKit.texture_icon("res://assets/food/food_flakes.png", Vector2(58.0, 34.0)), "secondary", bar_size)
	_feed_button.pressed.connect(func(): game.feed(false))
	_water_button = _bar_button(row, Localization.t("hud_water_change"), UiKit.icon("drop", 34.0, UiKit.COL_ACCENT), "secondary", bar_size)
	_water_button.pressed.connect(game.water_change)
	var shop_button := _bar_button(row, Localization.t("hud_shop"), UiKit.icon("bag", 34.0), "gold", bar_size)
	shop_button.pressed.connect(func(): game.open_shop())
	_fish_button = _bar_button(row, Localization.t("hud_my_fish"), UiKit.texture_icon("res://assets/fish/platy.png", Vector2(58.0, 34.0)), "secondary", bar_size)
	_fish_button.pressed.connect(game.open_fish_panel)
	var status_button := _bar_button(row, Localization.t("hud_tank_status"), UiKit.icon("gauge", 34.0), "secondary", bar_size)
	status_button.pressed.connect(game.open_tank_panel)
	var guide_button := _bar_button(row, Localization.t("nav_guide"), UiKit.icon("book", 34.0), "secondary", bar_size)
	guide_button.pressed.connect(game.open_guide)


func _bar_button(row: HBoxContainer, text: String, icon: Control, kind: String, min_size: Vector2) -> Button:
	var b := UiKit.action_button(text, icon, kind, true, min_size, 20)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	## All six share the bar equally whatever their caption length.
	b.custom_minimum_size.x = 0.0
	b.clip_contents = true
	row.add_child(b)
	return b


func _process(delta: float) -> void:
	_refresh_accum += delta
	if _refresh_accum >= REFRESH_INTERVAL:
		_refresh_accum = 0.0
		refresh()


func _on_tip_pressed() -> void:
	if _tip_action.is_valid():
		_tip_action.call()


func _refresh_speed() -> void:
	if _speed_button == null:
		return
	if TimeManager.player_paused:
		UiKit.set_action_text(_speed_button, "||")
		UiKit.set_button_kind(_speed_button, "warn")
	else:
		UiKit.set_action_text(_speed_button, "x%d" % int(TimeManager.SPEEDS[TimeManager.speed_index]))
		UiKit.set_button_kind(_speed_button, "glass" if TimeManager.speed_index == 0 else "primary")


func refresh() -> void:
	if game == null or _cash_label == null:
		return
	var tank := game.current_tank()
	_refresh_speed()
	var ready_orders: int = Market.orders_ready_count()
	UiKit.set_action_text(_business_button, str(Market.orders.size()))
	UiKit.set_button_kind(_business_button, "gold" if ready_orders > 0 else "glass")
	for i in range(_tool_buttons.size()):
		UiKit.set_button_kind(_tool_buttons[i], "primary" if game.tool == i else "glass")
	_tool_hint_holder.visible = game.tool != TankController.Tool.HAND
	if game.tool != TankController.Tool.HAND:
		_tool_hint_label.text = Localization.t(["", "tool_hint_food", "tool_hint_scraper", "tool_hint_vacuum"][game.tool])
	_cash_label.text = "$%d" % EconomyManager.cash
	_day_label.text = Localization.t("hud_day", [TimeManager.current_day() + 1, Localization.t("season_%d" % TimeManager.current_season)])
	_fish_label.text = str(tank.get_fish().size())

	var neglect := tank.get_neglect_score()
	var danger: bool = tank.ammonia > WaterChemistry.AMMONIA_DANGER or tank.nitrite > WaterChemistry.NITRITE_DANGER
	var water_key := "water_good"
	var water_color: Color = UiKit.COL_GOOD
	if danger or neglect >= 0.6:
		water_key = "water_poor"
		water_color = UiKit.COL_BAD
	elif neglect >= 0.3:
		water_key = "water_fair"
		water_color = UiKit.COL_WARN
	_water_label.text = Localization.t("hud_water", [Localization.t(water_key)])
	_water_dot.color = water_color

	var owned := game.owned_tank_count()
	UiKit.set_action_text(_tank_button, Localization.t("hud_tank_add") if owned <= 1 else Localization.t("hud_tank_n_of", [game.current_tank_index() + 1, owned]))

	UiKit.set_button_kind(_feed_button, "primary" if tank.hungry_fish_count() > 0 else "secondary")
	UiKit.set_button_kind(_water_button, "primary" if water_key == "water_poor" else "secondary")
	var fry := tank.fry_count()
	UiKit.set_action_text(_fish_button, Localization.t("hud_my_fish_fry", [fry]) if fry > 0 else Localization.t("hud_my_fish"))

	var tip := game.current_tip()
	_tip_action = tip["action"]
	if _tip_button.text != tip["text"] or _tip_kind != tip["kind"]:
		_tip_kind = tip["kind"]
		_tip_button.text = tip["text"]
		var color: Color = UiKit.COL_ACCENT
		if _tip_kind == "warn":
			color = UiKit.COL_WARN
		elif _tip_kind == "bad":
			color = UiKit.COL_BAD
		for state in ["normal", "hover", "pressed", "hover_pressed"]:
			var style: StyleBoxFlat = _tip_button.get_theme_stylebox(state).duplicate()
			style.border_color = color
			style.set_border_width_all(2)
			style.set_corner_radius_all(26)
			_tip_button.add_theme_stylebox_override(state, style)
