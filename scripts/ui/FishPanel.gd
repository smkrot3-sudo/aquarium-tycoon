extends ModalPanel
class_name FishPanel
## "My fish": everything living in the current tank, grouped by species, with how they're doing
## and the buttons that turn them into money — sell one adult, sell one fry, sell all the fry.

const POLL_INTERVAL := 1.0

var _scroll: ScrollContainer
var _list: VBoxContainer
var _summary: Label
var _signature: String = ""
var _poll_accum: float = 0.0


func _build() -> void:
	set_title(Localization.t("fish_title"))
	_summary = UiKit.label("", UiKit.FONT_SMALL, UiKit.COL_MUTED)
	header_extra.add_child(_summary)

	_scroll = UiKit.scroll()
	body.add_child(_scroll)
	_list = UiKit.vbox(10)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)

	game.state_changed.connect(func():
		if visible:
			refresh()
	)


## Fry are born and grow up on their own, so the list also re-checks itself once a second —
## but only rebuilds when the head-count actually changed (a rebuild mid-scroll is jarring).
func _process(delta: float) -> void:
	if not visible:
		return
	_poll_accum += delta
	if _poll_accum >= POLL_INTERVAL:
		_poll_accum = 0.0
		if _compute_signature() != _signature:
			refresh()


func _groups() -> Dictionary:
	var groups: Dictionary = {}  ## species -> {adults, males, females, fry, health_sum, hungry, sick}
	for fish in game.current_tank().get_fish():
		if not groups.has(fish.species):
			groups[fish.species] = {"adults": 0, "males": 0, "females": 0, "fry": 0, "health_sum": 0.0, "hungry": 0, "sick": 0}
		var g: Dictionary = groups[fish.species]
		if fish.is_fry:
			g["fry"] += 1
		else:
			g["adults"] += 1
			g[("males" if fish.sex == FishController.Sex.MALE else "females")] += 1
		g["health_sum"] += fish.health
		if fish.hunger < 35.0:
			g["hungry"] += 1
		if fish.is_sick:
			g["sick"] += 1
	return groups


func _compute_signature() -> String:
	var parts: Array = ["tank%d" % game.current_tank_index()]
	var groups := _groups()
	for species in groups.keys():
		var g: Dictionary = groups[species]
		parts.append("%s:%d:%d:%d:%d:%d" % [species.id, g["adults"], g["fry"], g["hungry"], g["sick"], int(g["health_sum"] / maxf(1.0, g["adults"] + g["fry"]) / 10.0)])
	parts.sort()
	return "|".join(parts)


func refresh() -> void:
	_signature = _compute_signature()
	var tank := game.current_tank()
	_summary.text = Localization.t("fish_summary", [tank.get_fish().size(), int(round(tank.stocking_fraction() * 100.0))])

	var keep_scroll := _scroll.scroll_vertical
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()

	var groups := _groups()
	if groups.is_empty():
		var empty := UiKit.vbox(16)
		empty.alignment = BoxContainer.ALIGNMENT_CENTER
		empty.size_flags_vertical = Control.SIZE_EXPAND_FILL
		empty.custom_minimum_size = Vector2(0.0, 320.0)
		var message := UiKit.label(Localization.t("fish_empty"), UiKit.FONT_HEADING, UiKit.COL_MUTED)
		message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_child(message)
		var to_shop := UiKit.button(Localization.t("fish_go_shop"), "primary", 72.0)
		to_shop.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		to_shop.pressed.connect(func(): game.open_shop(ShopPanel.Tab.FRESH))
		empty.add_child(to_shop)
		_list.add_child(empty)
		return

	var species_list: Array = groups.keys()
	species_list.sort_custom(func(a, b): return a.id < b.id)
	for species in species_list:
		_add_row(species, groups[species])
	UiKit.pass_mouse(_list)
	_scroll.set_deferred("scroll_vertical", keep_scroll)


func _add_row(species: FishSpeciesData, g: Dictionary) -> void:
	var card := UiKit.panel(UiKit.COL_CARD, 18, 12.0, 10.0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_child(card)
	var row := UiKit.hbox(12)
	card.add_child(row)

	row.add_child(UiKit.texture_icon("res://assets/fish/%s.png" % species.id, Vector2(130.0, 82.0)))

	var text := UiKit.vbox(2)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(text)
	text.add_child(UiKit.label(Localization.t("sp_%s" % species.id), UiKit.FONT_HEADING, UiKit.COL_TEXT, true))
	text.add_child(UiKit.label(Localization.t("fish_counts_sexed", [g["males"], g["females"], g["fry"]]), UiKit.FONT_BODY, UiKit.COL_ACCENT))

	var total: int = g["adults"] + g["fry"]
	var health: int = int(round(g["health_sum"] / maxf(1.0, float(total))))
	var notes: Array = [Localization.t("fish_health", [health])]
	var note_color: Color = UiKit.COL_GOOD if health >= 70 else UiKit.COL_WARN
	if g["hungry"] > 0:
		notes.append(Localization.t("fish_hungry", [g["hungry"]]))
		note_color = UiKit.COL_WARN
	if g["sick"] > 0:
		notes.append(Localization.t("fish_sick", [g["sick"]]))
		note_color = UiKit.COL_BAD
	if species.fry_per_batch_max <= 0:
		notes.append(Localization.t("fish_no_breeding"))
	elif g["males"] == 0 or g["females"] == 0:
		notes.append(Localization.t("fish_needs_pair"))
	text.add_child(UiKit.paragraph(" · ".join(notes), UiKit.FONT_SMALL, note_color, 2))

	var buttons := UiKit.hbox(8)
	buttons.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(buttons)
	if g["adults"] > 0:
		var sell_adult := UiKit.action_button("$%d" % species.sell_price_adult, UiKit.label(Localization.t("fish_sell_adult"), UiKit.FONT_SMALL, UiKit.COL_TEXT, true), "warn", true, Vector2(150.0, 84.0), 26)
		UiKit.on_tap(sell_adult, _scroll, game.sell_one_of.bind(species.id, false))
		buttons.add_child(sell_adult)
	if g["fry"] > 0:
		var sell_fry := UiKit.action_button("$%d" % species.sell_price_fry, UiKit.label(Localization.t("fish_sell_fry"), UiKit.FONT_SMALL, UiKit.COL_TEXT, true), "warn", true, Vector2(150.0, 84.0), 26)
		UiKit.on_tap(sell_fry, _scroll, game.sell_one_of.bind(species.id, true))
		buttons.add_child(sell_fry)
		if g["fry"] > 1:
			var sell_all := UiKit.action_button("$%d" % (species.sell_price_fry * g["fry"]), UiKit.label(Localization.t("fish_sell_all_fry"), UiKit.FONT_SMALL, UiKit.COL_TEXT, true), "warn", true, Vector2(170.0, 84.0), 26)
			UiKit.on_tap(sell_all, _scroll, game.sell_all_fry.bind(species.id))
			buttons.add_child(sell_all)
