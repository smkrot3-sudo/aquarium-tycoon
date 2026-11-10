extends PanelContainer
class_name GuideController
## Full-screen in-game encyclopedia: every fish species, equipment item, and food, with its
## real stats and a localized flavor description — pulled live from ShopManager's catalogs, so
## "add species #40" stays a pure data-authoring task here too (no card is hand-authored).

enum Tab { FISH, EQUIPMENT, FOOD }
const CARD_SPACING := 10

## Tier variants reuse their base tier's icon (see Main.tscn's own icon wiring) — no distinct
## art exists for "pro"/"canister"/"led" versions, same category of equipment either way.
const EQUIPMENT_ICON_OVERRIDE := {
	"pro_heater": "heater", "canister_filter": "filter", "led_light": "light",
}
const FOOD_ICON_OVERRIDE := {
	"shrimp_pellets": "food_flakes",
}

@onready var _title_label: Label = %GuideTitleLabel
@onready var _tab_fish_button: Button = %GuideTabFishButton
@onready var _tab_equipment_button: Button = %GuideTabEquipmentButton
@onready var _tab_food_button: Button = %GuideTabFoodButton
@onready var _close_button: Button = %GuideCloseButton
@onready var _content_vbox: VBoxContainer = %GuideContentVBox

var _current_tab: Tab = Tab.FISH


func _ready() -> void:
	visible = false
	_tab_fish_button.pressed.connect(_select_tab.bind(Tab.FISH))
	_tab_equipment_button.pressed.connect(_select_tab.bind(Tab.EQUIPMENT))
	_tab_food_button.pressed.connect(_select_tab.bind(Tab.FOOD))
	_close_button.pressed.connect(func(): visible = false)
	Localization.language_changed.connect(func(_l): _apply_static_labels(); _rebuild_content())
	for b in [_tab_fish_button, _tab_equipment_button, _tab_food_button, _close_button]:
		b.pressed.connect(func(): AudioManager.play("click"))


func open() -> void:
	visible = true
	_apply_static_labels()
	_rebuild_content()


func _apply_static_labels() -> void:
	_title_label.text = Localization.t("guide_title")
	_tab_fish_button.text = Localization.t("guide_tab_fish")
	_tab_equipment_button.text = Localization.t("guide_tab_equipment")
	_tab_food_button.text = Localization.t("guide_tab_food")
	_close_button.text = Localization.t("guide_close")


func _select_tab(tab: Tab) -> void:
	_current_tab = tab
	_tab_fish_button.button_pressed = (tab == Tab.FISH)
	_tab_equipment_button.button_pressed = (tab == Tab.EQUIPMENT)
	_tab_food_button.button_pressed = (tab == Tab.FOOD)
	_rebuild_content()


func _rebuild_content() -> void:
	for child in _content_vbox.get_children():
		child.queue_free()
	match _current_tab:
		Tab.FISH:
			var species_list: Array = ShopManager.species_catalog.values()
			species_list.sort_custom(func(a, b): return a.unlock_tier < b.unlock_tier if a.unlock_tier != b.unlock_tier else a.id < b.id)
			for species in species_list:
				_content_vbox.add_child(_build_fish_card(species))
		Tab.EQUIPMENT:
			var equipment_list: Array = ShopManager.equipment_catalog.values()
			equipment_list.sort_custom(func(a, b): return a.unlock_tier < b.unlock_tier if a.unlock_tier != b.unlock_tier else a.id < b.id)
			for equipment in equipment_list:
				_content_vbox.add_child(_build_equipment_card(equipment))
		Tab.FOOD:
			for food in ShopManager.food_catalog.values():
				_content_vbox.add_child(_build_food_card(food))


static var _card_style: StyleBoxFlat


func _make_card_shell(icon_path: String) -> Dictionary:
	if _card_style == null:
		_card_style = StyleBoxFlat.new()
		_card_style.bg_color = Color(0.11, 0.14, 0.19, 0.9)
		_card_style.set_corner_radius_all(8)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _card_style)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", CARD_SPACING)
	margin.add_child(hbox)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(72, 72)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path)
	hbox.add_child(icon)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)

	return {"panel": panel, "vbox": vbox}


func _add_name_label(vbox: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(label)


func _add_desc_label(vbox: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(label)


func _add_stats_label(vbox: VBoxContainer, lines: Array) -> void:
	var label := Label.new()
	label.text = "\n".join(lines)
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.75, 0.8, 0.85))
	vbox.add_child(label)


func _build_fish_card(species: FishSpeciesData) -> PanelContainer:
	var shell := _make_card_shell("res://assets/fish/%s.png" % species.id)
	_add_name_label(shell["vbox"], Localization.t("sp_%s" % species.id))
	_add_desc_label(shell["vbox"], Localization.t("desc_sp_%s" % species.id))

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
	lines.append(Localization.t("guide_stat_lifespan", [int(species.lifespan_sim_days)]))
	lines.append(Localization.t("guide_stat_price", [species.base_price]))
	if species.unlock_tier > 0:
		lines.append(Localization.t("guide_stat_tier", [species.unlock_tier]))
	_add_stats_label(shell["vbox"], lines)

	return shell["panel"]


func _build_equipment_card(equipment: EquipmentData) -> PanelContainer:
	var icon_id: String = EQUIPMENT_ICON_OVERRIDE.get(equipment.id, equipment.id)
	var shell := _make_card_shell("res://assets/equipment/%s.png" % icon_id)
	_add_name_label(shell["vbox"], Localization.t("eq_%s" % equipment.id))
	_add_desc_label(shell["vbox"], Localization.t("desc_eq_%s" % equipment.id))

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
	_add_stats_label(shell["vbox"], lines)

	return shell["panel"]


func _build_food_card(food: FoodItemData) -> PanelContainer:
	var icon_id: String = FOOD_ICON_OVERRIDE.get(food.id, food.id)
	var shell := _make_card_shell("res://assets/food/%s.png" % icon_id)
	_add_name_label(shell["vbox"], Localization.t("food_%s" % food.id))
	_add_desc_label(shell["vbox"], Localization.t("desc_food_%s" % food.id))

	var diets: Array = []
	for diet in food.compatible_diets:
		diets.append(Localization.t("diet_%d" % diet))
	var lines: Array = [
		Localization.t("guide_stat_diet", [", ".join(diets)]),
		Localization.t("guide_stat_price", [food.price_per_feeding]),
	]
	_add_stats_label(shell["vbox"], lines)

	return shell["panel"]
