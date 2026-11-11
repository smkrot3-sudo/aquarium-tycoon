extends ModalPanel
class_name GuidePanel
## In-game guide: a short "how to play" page first, then the full encyclopedia — every fish
## species, equipment item and food with its real stats and a localized description, pulled
## live from ShopManager's catalogs (so "add species #40" stays a pure data-authoring task).

enum Tab { HOW_TO_PLAY, FISH, EQUIPMENT, FOOD }

const FOOD_ICON := {"basic_flakes": "food_flakes", "shrimp_pellets": "food_flakes"}
const HOW_TO_STEPS := 7

var _tab: int = Tab.HOW_TO_PLAY
var _tab_buttons: Array[Button] = []
var _scroll: ScrollContainer
var _list: VBoxContainer


func _build() -> void:
	set_title(Localization.t("guide_title"))
	var tabs := UiKit.hbox(8)
	body.add_child(tabs)
	var names := [Localization.t("guide_tab_how"), Localization.t("guide_tab_fish"), Localization.t("guide_tab_equipment"), Localization.t("guide_tab_food")]
	for i in range(names.size()):
		var tab_button := UiKit.button(names[i], "tab", 60.0)
		tab_button.toggle_mode = true
		tab_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab_button.pressed.connect(select_tab.bind(i))
		tabs.add_child(tab_button)
		_tab_buttons.append(tab_button)

	_scroll = UiKit.scroll()
	body.add_child(_scroll)
	_list = UiKit.vbox(10)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)


func select_tab(tab: int) -> void:
	_tab = tab
	refresh()
	_scroll.set_deferred("scroll_vertical", 0)


func refresh() -> void:
	for i in range(_tab_buttons.size()):
		_tab_buttons[i].set_pressed_no_signal(i == _tab)
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	match _tab:
		Tab.HOW_TO_PLAY:
			for i in range(HOW_TO_STEPS):
				_add_how_to(i + 1, Localization.t("howto_%d_title" % (i + 1)), Localization.t("howto_%d_body" % (i + 1)))
		Tab.FISH:
			var species_list: Array = ShopManager.species_catalog.values()
			species_list.sort_custom(func(a, b): return a.unlock_tier < b.unlock_tier if a.unlock_tier != b.unlock_tier else a.id < b.id)
			for species in species_list:
				_add_fish_card(species)
		Tab.EQUIPMENT:
			var equipment_list: Array = ShopManager.equipment_catalog.values()
			equipment_list.sort_custom(func(a, b): return a.unlock_tier < b.unlock_tier if a.unlock_tier != b.unlock_tier else a.id < b.id)
			for equipment in equipment_list:
				_add_equipment_card(equipment)
		Tab.FOOD:
			for food in ShopManager.food_catalog.values():
				_add_food_card(food)
	UiKit.pass_mouse(_list)


func _add_how_to(number: int, title: String, text: String) -> void:
	var card := UiKit.panel(UiKit.COL_CARD, 18, 14.0, 12.0)
	_list.add_child(card)
	var row := UiKit.hbox(14)
	card.add_child(row)
	var badge := UiKit.panel(UiKit.COL_PRIMARY, 26, 0.0, 0.0)
	badge.custom_minimum_size = Vector2(52.0, 52.0)
	badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var number_label := UiKit.label(str(number), UiKit.FONT_HEADING, UiKit.COL_TEXT, true)
	number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(number_label)
	row.add_child(badge)
	var column := UiKit.vbox(4)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)
	column.add_child(UiKit.label(title, UiKit.FONT_HEADING, UiKit.COL_TEXT, true))
	column.add_child(UiKit.paragraph(text, UiKit.FONT_BODY, UiKit.COL_MUTED))


## Returns the text column of a new encyclopedia card.
func _card(icon_path: String, title: String, description: String) -> VBoxContainer:
	var card := UiKit.panel(UiKit.COL_CARD, 18, 14.0, 12.0)
	_list.add_child(card)
	var row := UiKit.hbox(14)
	card.add_child(row)
	var art := UiKit.texture_icon(icon_path, Vector2(150.0, 100.0))
	art.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(art)
	var column := UiKit.vbox(4)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)
	column.add_child(UiKit.label(title, UiKit.FONT_HEADING, UiKit.COL_TEXT, true))
	column.add_child(UiKit.paragraph(description, UiKit.FONT_BODY, UiKit.COL_TEXT))
	return column


static func _add_stats(column: VBoxContainer, lines: Array) -> void:
	column.add_child(UiKit.paragraph("  ·  ".join(lines), UiKit.FONT_SMALL, UiKit.COL_MUTED))


func _add_fish_card(species: FishSpeciesData) -> void:
	var column := _card("res://assets/fish/%s.png" % species.id, Localization.t("sp_%s" % species.id), Localization.t("desc_sp_%s" % species.id))
	var lines: Array = []
	if species.is_marine:
		lines.append(Localization.t("guide_stat_marine"))
		lines.append(Localization.t("guide_stat_sg", [species.sg_min, species.sg_max]))
	else:
		lines.append(Localization.t("guide_stat_freshwater"))
		lines.append(Localization.t("guide_stat_gh", [species.gh_min, species.gh_max]))
	lines.append(Localization.t("guide_stat_temp", [species.temp_min_c, species.temp_max_c]))
	lines.append(Localization.t("guide_stat_ph", [species.ph_min, species.ph_max]))
	lines.append(Localization.t("guide_stat_diet", [Localization.t("diet_%d" % species.diet_type)]))
	lines.append(Localization.t("guide_stat_temperament", [Localization.t("temperament_%d" % species.temperament)]))
	if species.schooling_min_group > 1:
		lines.append(Localization.t("guide_stat_schooling", [species.schooling_min_group]))
	lines.append(Localization.t("guide_stat_tank_size", [int(species.min_tank_liters)]))
	lines.append(Localization.t("guide_stat_max_size", [species.max_size_cm]))
	_add_stats(column, lines)

	var money: Array = [Localization.t("guide_stat_price", [species.base_price]), Localization.t("guide_stat_sell", [species.sell_price_adult, species.sell_price_fry])]
	if species.fry_per_batch_max > 0:
		money.append(Localization.t("guide_stat_breeds", [Economy.breeding_cooldown_days(species), Economy.maturity_days(species)]))
	else:
		money.append(Localization.t("fish_no_breeding"))
	if species.unlock_tier > 0:
		money.append(Localization.t("guide_stat_tier", [species.unlock_tier]))
	column.add_child(UiKit.paragraph("  ·  ".join(money), UiKit.FONT_SMALL, UiKit.COL_GOLD))


func _add_equipment_card(equipment: EquipmentData) -> void:
	var icon_id: String = ShopPanel.EQUIPMENT_ICON.get(equipment.id, equipment.id)
	var column := _card("res://assets/equipment/%s.png" % icon_id, Localization.t("eq_%s" % equipment.id), Localization.t("desc_eq_%s" % equipment.id))
	var lines: Array = []
	match equipment.slot:
		EquipmentData.Slot.HEATER:
			lines.append(Localization.t("guide_eq_stat_heater", [equipment.heater_target_temp_c, equipment.heater_power]))
		EquipmentData.Slot.FILTER:
			lines.append(Localization.t("guide_eq_stat_filter", [equipment.filter_flow_liters_per_hour, equipment.filter_bio_capacity]))
		EquipmentData.Slot.LIGHT:
			lines.append(Localization.t("guide_eq_stat_light", [equipment.light_intensity]))
		EquipmentData.Slot.AIR_STONE:
			lines.append(Localization.t("guide_eq_stat_air", [equipment.oxygen_boost]))
		EquipmentData.Slot.TEST_KIT:
			lines.append(Localization.t("guide_eq_stat_testkit"))
	lines.append(Localization.t("guide_stat_price", [equipment.price]))
	if equipment.unlock_tier > 0:
		lines.append(Localization.t("guide_stat_tier", [equipment.unlock_tier]))
	_add_stats(column, lines)


func _add_food_card(food: FoodItemData) -> void:
	var icon_id: String = FOOD_ICON.get(food.id, food.id)
	var column := _card("res://assets/food/%s.png" % icon_id, Localization.t("food_%s" % food.id), Localization.t("desc_food_%s" % food.id))
	var diets: Array = []
	for diet in food.compatible_diets:
		diets.append(Localization.t("diet_%d" % diet))
	_add_stats(column, [
		Localization.t("guide_stat_diet", [", ".join(diets)]),
		Localization.t("guide_stat_price", [food.price_per_feeding]),
	])
