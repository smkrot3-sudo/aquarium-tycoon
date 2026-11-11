extends ModalPanel
class_name GuidePanel
## The encyclopedia. A short "how to play" page, then an album of every fish — freshwater and
## saltwater on separate tabs — where tapping a fish opens its full page: a big picture, where
## in the world it comes from, its story, and how to keep it. Equipment and food get full-width
## articles. Everything is read live from ShopManager's catalogs and LoreStrings, so adding a
## species file plus its text adds its page.

enum Tab { HOW_TO_PLAY, FRESH, SALT, EQUIPMENT, FOOD }

const FOOD_ICON := {"basic_flakes": "food_flakes", "shrimp_pellets": "food_flakes"}
const HOW_TO_STEPS := 8
const ALBUM_COLUMNS := 4

var _tab: int = Tab.HOW_TO_PLAY
var _tab_buttons: Array[Button] = []
var _tabs_row: HBoxContainer
var _scroll: ScrollContainer
var _list: VBoxContainer
var _detail: VBoxContainer
var _detail_species: FishSpeciesData


func _build() -> void:
	set_title(Localization.t("guide_title"))
	_tabs_row = UiKit.hbox(8)
	body.add_child(_tabs_row)
	var names := [Localization.t("guide_tab_how"), Localization.t("shop_tab_fresh"), Localization.t("shop_tab_salt"), Localization.t("guide_tab_equipment"), Localization.t("guide_tab_food")]
	for i in range(names.size()):
		var tab_button := UiKit.button(names[i], "tab", 60.0, UiKit.FONT_BODY)
		tab_button.toggle_mode = true
		tab_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab_button.clip_text = true
		tab_button.pressed.connect(select_tab.bind(i))
		_tabs_row.add_child(tab_button)
		_tab_buttons.append(tab_button)

	_scroll = UiKit.scroll()
	body.add_child(_scroll)
	_list = UiKit.vbox(10)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)

	_detail = UiKit.vbox(10)
	_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail.visible = false
	body.add_child(_detail)


func select_tab(tab: int) -> void:
	_tab = tab
	_detail_species = null
	refresh()
	_scroll.set_deferred("scroll_vertical", 0)


func show_species(species: FishSpeciesData) -> void:
	_detail_species = species
	_tab = Tab.SALT if species.is_marine else Tab.FRESH
	visible = true
	refresh()


func _back_to_list() -> void:
	_detail_species = null
	refresh()


static func _clear(container: Control) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func refresh() -> void:
	for i in range(_tab_buttons.size()):
		_tab_buttons[i].set_pressed_no_signal(i == _tab)
	var in_detail: bool = _detail_species != null
	_tabs_row.visible = not in_detail
	_scroll.visible = not in_detail
	_detail.visible = in_detail
	_clear(_detail)
	if in_detail:
		_build_species_page(_detail_species)
		return

	_clear(_list)
	match _tab:
		Tab.HOW_TO_PLAY:
			for i in range(HOW_TO_STEPS):
				_add_how_to(i + 1, Localization.t("howto_%d_title" % (i + 1)), Localization.t("howto_%d_body" % (i + 1)))
		Tab.FRESH:
			_add_album(false)
		Tab.SALT:
			_add_album(true)
		Tab.EQUIPMENT:
			var equipment_list: Array = ShopManager.equipment_catalog.values()
			equipment_list.sort_custom(func(a, b):
				if a.slot != b.slot:
					return a.slot < b.slot
				return a.price < b.price
			)
			for equipment in equipment_list:
				_add_equipment_article(equipment)
		Tab.FOOD:
			for food in ShopManager.food_catalog.values():
				_add_food_article(food)
	UiKit.pass_mouse(_list)


# ----------------------------------------------------------------------------------------
# How to play
# ----------------------------------------------------------------------------------------

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


# ----------------------------------------------------------------------------------------
# Fish album + species page
# ----------------------------------------------------------------------------------------

func _species_list(saltwater: bool) -> Array:
	var list: Array = []
	for species in ShopManager.species_catalog.values():
		if species.is_marine == saltwater:
			list.append(species)
	list.sort_custom(func(a, b):
		if a.unlock_tier != b.unlock_tier:
			return a.unlock_tier < b.unlock_tier
		if a.base_price != b.base_price:
			return a.base_price < b.base_price
		return a.id < b.id
	)
	return list


func _add_album(saltwater: bool) -> void:
	var list := _species_list(saltwater)
	var hint := UiKit.label("%s  ·  %s" % [Localization.t("guide_count", [list.size()]), Localization.t("guide_tap_hint")], UiKit.FONT_SMALL, UiKit.COL_MUTED)
	_list.add_child(hint)
	var grid := GridContainer.new()
	grid.columns = ALBUM_COLUMNS
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	_list.add_child(grid)
	for species in list:
		grid.add_child(_album_tile(species))


## A whole-tile button: picture, name and where the fish is from.
func _album_tile(species: FishSpeciesData) -> Button:
	var tile := Button.new()
	tile.focus_mode = Control.FOCUS_NONE
	UiKit.style_button(tile, "tab")
	tile.custom_minimum_size = Vector2(0.0, 214.0)
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.clip_contents = true
	tile.pressed.connect(func(): AudioManager.play("click"))
	UiKit.on_tap(tile, _scroll, show_species.bind(species))

	var pad := UiKit.margin(10.0, 10.0, 10.0, 8.0)
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(pad)
	var column := UiKit.vbox(2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(column)
	var art := UiKit.texture_icon("res://assets/fish/%s.png" % species.id, Vector2(0.0, 104.0))
	art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(art)
	var name_label := UiKit.label(Localization.t("sp_%s" % species.id), UiKit.FONT_BODY, UiKit.COL_TEXT, true)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	column.add_child(name_label)
	var origin := UiKit.paragraph(Localization.t("origin_sp_%s" % species.id), 16, UiKit.COL_ACCENT, 2)
	origin.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(origin)
	return tile


func _heading(text: String) -> Label:
	return UiKit.label(text, UiKit.FONT_BODY, UiKit.COL_ACCENT, true)


func _build_species_page(species: FishSpeciesData) -> void:
	var top := UiKit.hbox(12)
	_detail.add_child(top)
	var back := UiKit.action_button(Localization.t("guide_back"), UiKit.icon("next", 26.0), "secondary", false, Vector2(0.0, 60.0), UiKit.FONT_BODY)
	back.pressed.connect(_back_to_list)
	top.add_child(back)
	var title := UiKit.label(Localization.t("sp_%s" % species.id), UiKit.FONT_TITLE, UiKit.COL_TEXT, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.clip_text = true
	top.add_child(title)
	if species.scientific_name != "":
		top.add_child(UiKit.label(species.scientific_name, UiKit.FONT_SMALL, UiKit.COL_MUTED))

	var columns := UiKit.hbox(12)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail.add_child(columns)

	# --- picture + origin + money
	var left := UiKit.vbox(10)
	left.custom_minimum_size = Vector2(380.0, 0.0)
	columns.add_child(left)
	var is_marine: bool = species.is_marine
	var frame := UiKit.panel(Color(0.05, 0.3, 0.5) if is_marine else Color(0.07, 0.36, 0.42), 20, 14.0, 14.0)
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(frame)
	var art := UiKit.texture_icon("res://assets/fish/%s.png" % species.id, Vector2(340.0, 180.0))
	frame.add_child(art)

	var origin_card := UiKit.panel(UiKit.COL_CARD, 16, 14.0, 10.0)
	left.add_child(origin_card)
	var origin_column := UiKit.vbox(2)
	origin_card.add_child(origin_column)
	origin_column.add_child(_heading(Localization.t("guide_origin")))
	origin_column.add_child(UiKit.paragraph(Localization.t("origin_sp_%s" % species.id), UiKit.FONT_SMALL, UiKit.COL_TEXT))

	var owned := 0
	for tank in game.tanks():
		if not tank.locked:
			for fish in tank.get_fish():
				if fish.species == species:
					owned += 1
	var money: Array = [Localization.t("guide_stat_price", [species.base_price]), Localization.t("guide_stat_sell", [species.sell_price_adult, species.sell_price_fry])]
	if species.unlock_tier > 0:
		money.append(Localization.t("guide_stat_tier", [species.unlock_tier]))
	if owned > 0:
		money.append(Localization.t("guide_owned", [owned]))
	var money_card := UiKit.panel(UiKit.COL_CARD, 16, 14.0, 10.0)
	left.add_child(money_card)
	money_card.add_child(UiKit.paragraph("  ·  ".join(money), UiKit.FONT_SMALL, UiKit.COL_GOLD))

	# --- story + care
	var right := UiKit.panel(UiKit.COL_CARD, 20, 18.0, 14.0)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right)
	var story_scroll := UiKit.scroll()
	right.add_child(story_scroll)
	var story := UiKit.vbox(8)
	story.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	story_scroll.add_child(story)

	story.add_child(_heading(Localization.t("guide_about")))
	var lore := UiKit.paragraph(Localization.t("lore_sp_%s" % species.id), UiKit.FONT_BODY, UiKit.COL_TEXT)
	lore.add_theme_constant_override("line_spacing", 6)
	story.add_child(lore)

	story.add_child(_heading(Localization.t("guide_care")))
	var care: Array = [
		Localization.t("guide_stat_marine") if is_marine else Localization.t("guide_stat_freshwater"),
		Localization.t("guide_stat_tank_size", [int(species.min_tank_liters)]),
		Localization.t("guide_stat_temp", [species.temp_min_c, species.temp_max_c]),
	]
	if species.schooling_min_group > 1:
		care.append(Localization.t("guide_stat_schooling", [species.schooling_min_group]))
	care.append(Localization.t("guide_stat_max_size", [species.max_size_cm]))
	care.append(Localization.t("guide_stat_temperament", [Localization.t("temperament_%d" % species.temperament)]))
	care.append(Localization.t("guide_stat_diet", [Localization.t("diet_%d" % species.diet_type)]))
	care.append(Localization.t("guide_stat_ph", [species.ph_min, species.ph_max]))
	if is_marine:
		care.append(Localization.t("guide_stat_sg", [species.sg_min, species.sg_max]))
	story.add_child(_chips(care))

	story.add_child(_heading(Localization.t("guide_money")))
	var breeding: String = Localization.t("fish_no_breeding")
	if species.fry_per_batch_max > 0:
		breeding = Localization.t("guide_stat_breeds", [Economy.breeding_cooldown_days(species), Economy.maturity_days(species)])
	story.add_child(UiKit.paragraph(breeding, UiKit.FONT_SMALL, UiKit.COL_MUTED))
	UiKit.pass_mouse(story)


## A wrapping row of small pills, one per care fact.
func _chips(lines: Array) -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	for line in lines:
		var pill := UiKit.panel(Color(0.04, 0.11, 0.2), 18, 14.0, 6.0)
		pill.add_child(UiKit.label(line, UiKit.FONT_SMALL, UiKit.COL_TEXT))
		flow.add_child(pill)
	return flow


# ----------------------------------------------------------------------------------------
# Equipment and food
# ----------------------------------------------------------------------------------------

## Returns the text column of a new full-width article card.
func _article(icon_path: String, title: String, subtitle: String, text: String) -> VBoxContainer:
	var card := UiKit.panel(UiKit.COL_CARD, 18, 16.0, 14.0)
	_list.add_child(card)
	var row := UiKit.hbox(16)
	card.add_child(row)
	var art := UiKit.texture_icon(icon_path, Vector2(130.0, 130.0))
	art.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(art)
	var column := UiKit.vbox(4)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)
	column.add_child(UiKit.label(title, UiKit.FONT_HEADING, UiKit.COL_TEXT, true))
	if subtitle != "":
		column.add_child(UiKit.label(subtitle, UiKit.FONT_SMALL, UiKit.COL_ACCENT, true))
	var paragraph := UiKit.paragraph(text, UiKit.FONT_BODY, UiKit.COL_TEXT)
	paragraph.add_theme_constant_override("line_spacing", 5)
	column.add_child(paragraph)
	return column


func _add_equipment_article(equipment: EquipmentData) -> void:
	var icon_id: String = ShopPanel.EQUIPMENT_ICON.get(equipment.id, equipment.id)
	var column := _article(
		"res://assets/equipment/%s.png" % icon_id, Localization.t("eq_%s" % equipment.id),
		Localization.t("slot_%d" % equipment.slot), Localization.t("lore_eq_%s" % equipment.id)
	)
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
	column.add_child(_chips(lines))


func _add_food_article(food: FoodItemData) -> void:
	var icon_id: String = FOOD_ICON.get(food.id, food.id)
	_article("res://assets/food/%s.png" % icon_id, Localization.t("food_%s" % food.id), "", Localization.t("desc_food_%s" % food.id))
