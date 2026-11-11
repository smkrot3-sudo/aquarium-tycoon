extends ModalPanel
class_name MoveFishPanel
## "Move fish": pick which tank a group of fish should go to. Used from a fish's card (one fish)
## and from the My Fish list (a whole species: everything, only the adults or only the fry — the
## fry option is how a spare tank becomes a nursery). Tanks that can't take them say why.

enum Filter { ALL, ADULTS, FRY }

var _fish_list: Array = []
var _filter: int = Filter.ALL
var _chips: HBoxContainer
var _list: VBoxContainer


func _build() -> void:
	set_title(Localization.t("move_title"))
	_chips = UiKit.hbox(8)
	body.add_child(_chips)
	body.add_child(UiKit.label(Localization.t("move_pick"), UiKit.FONT_SMALL, UiKit.COL_MUTED))
	var scroll := UiKit.scroll()
	body.add_child(scroll)
	_list = UiKit.vbox(10)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)


func setup(fish_list: Array) -> void:
	_fish_list = fish_list
	_filter = Filter.ALL


func _selected() -> Array:
	var out: Array = []
	for fish in _fish_list:
		if not is_instance_valid(fish):
			continue
		if _filter == Filter.ADULTS and fish.is_fry:
			continue
		if _filter == Filter.FRY and not fish.is_fry:
			continue
		out.append(fish)
	return out


func refresh() -> void:
	for child in _chips.get_children():
		_chips.remove_child(child)
		child.queue_free()
	var adults := 0
	var fry := 0
	for fish in _fish_list:
		if is_instance_valid(fish):
			if fish.is_fry:
				fry += 1
			else:
				adults += 1
	if adults > 0 and fry > 0:
		var entries := [[Filter.ALL, Localization.t("move_all", [adults + fry])], [Filter.ADULTS, Localization.t("move_adults", [adults])], [Filter.FRY, Localization.t("move_fry", [fry])]]
		for entry in entries:
			var chip := UiKit.button(entry[1], "tab", 56.0, UiKit.FONT_BODY)
			chip.toggle_mode = true
			chip.button_pressed = _filter == entry[0]
			chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			chip.pressed.connect(_set_filter.bind(entry[0]))
			_chips.add_child(chip)
	_chips.visible = _chips.get_child_count() > 0

	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var selected := _selected()
	var any_target := false
	for i in range(game.tanks().size()):
		var tank: TankController = game.tanks()[i]
		if tank.locked or tank == _current_source():
			continue
		any_target = true
		_add_tank_row(i, tank, selected)
	if not any_target:
		_list.add_child(UiKit.paragraph(Localization.t("move_none"), UiKit.FONT_BODY, UiKit.COL_MUTED))
	UiKit.pass_mouse(_list)


func _current_source() -> TankController:
	for fish in _fish_list:
		if is_instance_valid(fish):
			return fish.get_parent() as TankController
	return null


func _set_filter(value: int) -> void:
	_filter = value
	refresh()


func _add_tank_row(index: int, tank: TankController, selected: Array) -> void:
	var fits := 0
	var first_reason := ""
	for fish in selected:
		var reason: String = game.move_block_reason(fish, tank)
		if reason == "":
			fits += 1
		elif first_reason == "":
			first_reason = reason
	var card := UiKit.panel(UiKit.COL_CARD if fits > 0 else UiKit.COL_CARD_DIM, 18, 14.0, 10.0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_child(card)
	var row := UiKit.hbox(12)
	card.add_child(row)
	var text := UiKit.vbox(2)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	text.add_child(UiKit.label(game.tank_display_name(index), UiKit.FONT_HEADING, UiKit.COL_TEXT, true))
	var fits_text := Localization.t("move_fits", [fits, selected.size()])
	text.add_child(UiKit.label(fits_text, UiKit.FONT_SMALL, UiKit.COL_GOOD if fits == selected.size() else UiKit.COL_WARN))
	if first_reason != "" and fits < selected.size():
		text.add_child(UiKit.paragraph(first_reason, UiKit.FONT_SMALL, UiKit.COL_WARN, 2))
	var go := UiKit.button(Localization.t("move_here"), "primary" if fits > 0 else "tab", 64.0, UiKit.FONT_BODY)
	go.disabled = fits == 0
	go.custom_minimum_size.x = 160.0
	go.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	go.pressed.connect(func():
		game.move_fish(selected, index)
		close()
	)
	row.add_child(go)
