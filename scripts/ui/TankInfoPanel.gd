extends ModalPanel
class_name TankInfoPanel
## "Tank status": the water readings in plain language (with a colour and a hint for anything
## that needs attention) on one side, the installed equipment on the other, and the two care
## actions that fix most problems underneath.

const POLL_INTERVAL := 0.5

var _readings: VBoxContainer
var _equipment: VBoxContainer
var _treat_button: Button
var _sell_button: Button
var _sell_armed: bool = false
var _poll_accum: float = 0.0


func _build() -> void:
	var columns := UiKit.hbox(12)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(columns)

	var left := UiKit.panel(UiKit.COL_CARD, 18, 14.0, 12.0)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.25
	columns.add_child(left)
	var left_scroll := UiKit.scroll()
	left.add_child(left_scroll)
	_readings = UiKit.vbox(8)
	_readings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.add_child(_readings)

	var right := UiKit.panel(UiKit.COL_CARD, 18, 14.0, 12.0)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right)
	var right_scroll := UiKit.scroll()
	right.add_child(right_scroll)
	_equipment = UiKit.vbox(8)
	_equipment.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.add_child(_equipment)

	var actions := UiKit.hbox(10)
	body.add_child(actions)
	var water_button := UiKit.action_button(Localization.t("hud_water_change"), UiKit.icon("drop", 30.0, UiKit.COL_ACCENT), "primary", false, Vector2(0.0, 68.0), UiKit.FONT_BUTTON)
	water_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	water_button.pressed.connect(game.water_change)
	actions.add_child(water_button)
	_treat_button = UiKit.action_button(Localization.t("action_treat_disease", [game.medication_price()]), UiKit.icon("cross", 28.0, UiKit.COL_BAD), "secondary", false, Vector2(0.0, 68.0), UiKit.FONT_BUTTON)
	_treat_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_treat_button.pressed.connect(game.treat_disease)
	actions.add_child(_treat_button)
	var stats_button := UiKit.action_button(Localization.t("tank_graphs"), UiKit.icon("chart", 30.0), "secondary", false, Vector2(0.0, 68.0), UiKit.FONT_BUTTON)
	stats_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_button.pressed.connect(game.open_stats)
	actions.add_child(stats_button)
	_sell_button = UiKit.action_button(Localization.t("sell_tank_button", [0]), UiKit.icon("coin", 28.0), "danger", false, Vector2(0.0, 68.0), UiKit.FONT_BODY)
	_sell_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sell_button.pressed.connect(_on_sell_pressed)
	actions.add_child(_sell_button)
	var shop_button := UiKit.action_button(Localization.t("tank_buy_equipment"), UiKit.icon("bag", 30.0), "gold", false, Vector2(0.0, 68.0), UiKit.FONT_BUTTON)
	shop_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_button.pressed.connect(func(): game.open_shop(ShopPanel.Tab.EQUIPMENT))
	actions.add_child(shop_button)

	game.state_changed.connect(func():
		if visible:
			refresh()
	)


## Selling asks for a second tap, so a stray touch can't get rid of a tank.
func _on_sell_pressed() -> void:
	if not _sell_armed:
		_sell_armed = true
		_refresh_sell_text()
		get_tree().create_timer(3.5).timeout.connect(func():
			_sell_armed = false
			_refresh_sell_text()
		)
		return
	_sell_armed = false
	game.sell_tank(game.current_tank_index())


func _refresh_sell_text() -> void:
	if _sell_button == null:
		return
	var value := game.tank_sale_value(game.current_tank())
	UiKit.set_action_text(_sell_button, Localization.t("sell_tank_confirm" if _sell_armed else "sell_tank_button", [value]))


func _process(delta: float) -> void:
	if not visible:
		return
	_poll_accum += delta
	if _poll_accum >= POLL_INTERVAL:
		_poll_accum = 0.0
		refresh()


func refresh() -> void:
	var tank := game.current_tank()
	set_title(game.tank_display_name(game.current_tank_index()))
	_fill_readings(tank)
	_fill_equipment(tank)
	_refresh_sell_text()
	UiKit.set_button_kind(_treat_button, "danger" if tank.sick_fish_count() > 0 and tank.medication_remaining_days <= 0.0 else "secondary")


static func _clear(container: Control) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _fill_readings(tank: TankController) -> void:
	_clear(_readings)
	_readings.add_child(UiKit.label(Localization.t("tank_section_water"), UiKit.FONT_HEADING, UiKit.COL_TEXT, true))

	## Temperature is judged against the fish actually living here.
	var too_cold := false
	var too_hot := false
	for fish in tank.get_fish():
		if tank.temperature < fish.species.temp_min_c:
			too_cold = true
		elif tank.temperature > fish.species.temp_max_c:
			too_hot = true
	var temp_hint := ""
	if too_cold:
		temp_hint = Localization.t("tank_hint_cold")
	elif too_hot:
		temp_hint = Localization.t("tank_hint_hot")
	_add_reading(Localization.t("tank_temp"), "%.1f°" % tank.temperature, UiKit.COL_BAD if (too_cold or too_hot) else UiKit.COL_GOOD, temp_hint)

	if tank.has_test_kit:
		_add_reading(Localization.t("tank_ammonia"), "%.2f" % tank.ammonia, _level_color(tank.ammonia, WaterChemistry.AMMONIA_DANGER), Localization.t("tank_hint_ammonia") if tank.ammonia > WaterChemistry.AMMONIA_DANGER else "")
		_add_reading(Localization.t("tank_nitrite"), "%.2f" % tank.nitrite, _level_color(tank.nitrite, WaterChemistry.NITRITE_DANGER), Localization.t("tank_hint_ammonia") if tank.nitrite > WaterChemistry.NITRITE_DANGER else "")
		_add_reading(Localization.t("tank_nitrate"), "%.0f" % tank.nitrate, _level_color(tank.nitrate, WaterChemistry.NITRATE_DANGER), Localization.t("tank_hint_nitrate") if tank.nitrate > WaterChemistry.NITRATE_DANGER else "")
		_add_reading(Localization.t("tank_oxygen"), "%.1f" % tank.oxygen, UiKit.COL_BAD if tank.oxygen < WaterChemistry.OXYGEN_DANGER else UiKit.COL_GOOD, Localization.t("tank_hint_oxygen") if tank.oxygen < WaterChemistry.OXYGEN_DANGER else "")
		_add_reading("pH", "%.1f" % tank.ph, UiKit.COL_TEXT, "")
	else:
		var neglect := tank.get_neglect_score()
		var danger: bool = tank.ammonia > WaterChemistry.AMMONIA_DANGER or tank.nitrite > WaterChemistry.NITRITE_DANGER
		var key := "water_good"
		var color: Color = UiKit.COL_GOOD
		if danger or neglect >= 0.6:
			key = "water_poor"
			color = UiKit.COL_BAD
		elif neglect >= 0.3:
			key = "water_fair"
			color = UiKit.COL_WARN
		_add_reading(Localization.t("tank_water_quality"), Localization.t(key), color, Localization.t("tank_hint_no_kit"))

	if tank.is_pond():
		_add_reading(Localization.t("pond_weather"), "%s · %d°" % [Localization.t(Weather.name_key()), int(round(Weather.outdoor_c()))], UiKit.COL_TEXT, "")
		if tank.is_frozen():
			_add_reading(Localization.t("pond_ice"), Localization.t("pond_iced_over"), UiKit.COL_WARN, Localization.t("alert_pond_frozen"))
		_add_reading(Localization.t("pond_net"), Localization.t("pond_net_on") if tank.has_net else Localization.t("pond_net_off"), UiKit.COL_GOOD if tank.has_net else UiKit.COL_WARN, "" if tank.has_net else Localization.t("tip_pond_net"))
	if tank.tank_type == TankController.TankType.SALTWATER:
		_add_reading(Localization.t("tank_salinity"), "%.3f" % tank.specific_gravity, UiKit.COL_TEXT, "")

	_add_bar(Localization.t("tank_filter_maturity"), tank.filter_maturity / 100.0, UiKit.COL_PRIMARY, Localization.t("tank_hint_filter") if tank.filter_maturity < 60.0 else "")
	var stocking := tank.stocking_fraction()
	_add_bar(Localization.t("tank_stocking"), stocking, UiKit.COL_BAD if stocking > 0.95 else (UiKit.COL_WARN if stocking > 0.75 else UiKit.COL_PRIMARY), Localization.t("tank_hint_crowded") if stocking > 0.95 else "")
	_add_reading(Localization.t("tank_last_water_change"), Localization.t("tank_days_ago", [int(tank.days_since_water_change)]), UiKit.COL_WARN if tank.days_since_water_change >= 10.0 else UiKit.COL_TEXT, "")
	if tank.sick_fish_count() > 0:
		var treating: bool = tank.medication_remaining_days > 0.0
		_add_reading(Localization.t("tank_sick"), str(tank.sick_fish_count()), UiKit.COL_BAD, Localization.t("tank_hint_treating") if treating else Localization.t("tank_hint_sick"))


static func _level_color(value: float, danger: float) -> Color:
	if value > danger:
		return UiKit.COL_BAD
	if value > danger * 0.6:
		return UiKit.COL_WARN
	return UiKit.COL_GOOD


func _add_reading(title: String, value: String, color: Color, hint: String) -> void:
	var row := UiKit.hbox(10)
	_readings.add_child(row)
	var name_label := UiKit.label(title, UiKit.FONT_BODY, UiKit.COL_MUTED)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	row.add_child(UiKit.label(value, UiKit.FONT_BODY, color, true))
	if hint != "":
		_readings.add_child(UiKit.paragraph(hint, UiKit.FONT_SMALL, color))


func _add_bar(title: String, fraction: float, color: Color, hint: String) -> void:
	var row := UiKit.hbox(10)
	_readings.add_child(row)
	var name_label := UiKit.label(title, UiKit.FONT_BODY, UiKit.COL_MUTED)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	row.add_child(UiKit.progress(fraction, color, Vector2(180.0, 18.0)))
	var percent := UiKit.label("%d%%" % int(round(fraction * 100.0)), UiKit.FONT_BODY, color, true)
	percent.custom_minimum_size = Vector2(64.0, 0.0)
	percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(percent)
	if hint != "":
		_readings.add_child(UiKit.paragraph(hint, UiKit.FONT_SMALL, color))


func _fill_equipment(tank: TankController) -> void:
	_clear(_equipment)
	_equipment.add_child(UiKit.label(Localization.t("tank_section_equipment"), UiKit.FONT_HEADING, UiKit.COL_TEXT, true))
	_add_slot(EquipmentData.Slot.FILTER, tank.filter, "filter", false)
	_add_slot(EquipmentData.Slot.HEATER, tank.heater, "heater", tank.heater_failed)
	_add_slot(EquipmentData.Slot.LIGHT, tank.light_equipment, "light", false)
	_add_slot(EquipmentData.Slot.AIR_STONE, tank.air_stone, "air_stone", false)
	_add_slot(EquipmentData.Slot.TEST_KIT, ShopManager.get_equipment("digital_test_kit") if tank.has_test_kit else null, "test_kit", false)
	_equipment.add_child(UiKit.label(Localization.t("tank_volume", [int(tank.tank_liters)]), UiKit.FONT_SMALL, UiKit.COL_MUTED))


func _add_slot(slot: int, equipment: EquipmentData, fallback_icon: String, broken: bool) -> void:
	var row := UiKit.hbox(10)
	_equipment.add_child(row)
	var icon_id: String = fallback_icon
	if equipment != null:
		icon_id = ShopPanel.EQUIPMENT_ICON.get(equipment.id, equipment.id)
	var art := UiKit.texture_icon("res://assets/equipment/%s.png" % icon_id, Vector2(52.0, 52.0))
	if equipment == null:
		art.modulate = Color(1, 1, 1, 0.3)
	row.add_child(art)
	var text := UiKit.vbox(0)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	text.add_child(UiKit.label(Localization.t("slot_%d" % slot), UiKit.FONT_SMALL, UiKit.COL_MUTED))
	if equipment == null:
		text.add_child(UiKit.label(Localization.t("tank_slot_missing"), UiKit.FONT_BODY, UiKit.COL_WARN, true))
	elif broken:
		text.add_child(UiKit.label(Localization.t("tank_slot_broken"), UiKit.FONT_BODY, UiKit.COL_BAD, true))
	else:
		text.add_child(UiKit.label(Localization.t("eq_%s" % equipment.id), UiKit.FONT_BODY, UiKit.COL_GOOD, true))
