extends Node
## Wires the HUD buttons to the Tank/Shop/Economy systems and keeps the status labels
## refreshed. This is the MVP "glue" script — see plan Phase 1 deliverables.
##
## Multi-tank (Phase 3): exactly two tank slots exist as scene nodes from the start (see
## Main.tscn). Tank 1 is always owned; Tank 2 starts `locked` and is configured from a
## TankPresetData when the player buys it (see _on_buy_tank). Only the selected tank's meshes
## are shown — all tanks share one Camera3D/WorldEnvironment positioned at the common origin
## (see Main.tscn), so switching tabs is just a visibility swap, not a camera move.
##
## Localization: every player-facing string is built here via Localization.t(), since almost
## all of them mix a translated name with live data (price, tier, readings) — see
## autoload/Localization.gd for why this doesn't use Godot's built-in auto-translate.

@onready var _tanks: Array[TankController] = [%TankInstance, %Tank2Instance]
var _current_tank_index: int = 0

@onready var _title_label: Label = %TitleLabel
@onready var _cash_label: Label = %CashLabel
@onready var _day_label: Label = %DayLabel
@onready var _fish_count_label: Label = %FishCountLabel
@onready var _temp_label: Label = %TempLabel
@onready var _ammonia_label: Label = %AmmoniaLabel
@onready var _nitrite_label: Label = %NitriteLabel
@onready var _nitrate_label: Label = %NitrateLabel
@onready var _filter_label: Label = %FilterLabel
@onready var _oxygen_label: Label = %OxygenLabel
@onready var _salinity_label: Label = %SalinityLabel
@onready var _sick_label: Label = %SickLabel
@onready var _alert_label: Label = %AlertLabel

@onready var _equipment_label: Label = %EquipmentLabel
@onready var _fish_label: Label = %FishLabel
@onready var _actions_label: Label = %ActionsLabel
@onready var _debug_label: Label = %DebugLabel
@onready var _tanks_label: Label = %TanksLabel

@onready var _tank_tab1_button: Button = %TankTab1Button
@onready var _tank_tab2_button: Button = %TankTab2Button
@onready var _guide_button: Button = %GuideButton
@onready var _guide_panel: GuideController = %GuidePanel
@onready var _lang_toggle_button: Button = %LangToggleButton
@onready var _volume_label: Label = %VolumeLabel
@onready var _volume_slider: HSlider = %VolumeSlider

@onready var _buy_heater_button: Button = %BuyHeaterButton
@onready var _buy_filter_button: Button = %BuyFilterButton
@onready var _buy_light_button: Button = %BuyLightButton
@onready var _buy_air_stone_button: Button = %BuyAirStoneButton
@onready var _buy_test_kit_button: Button = %BuyTestKitButton
@onready var _buy_pro_heater_button: Button = %BuyProHeaterButton
@onready var _buy_canister_filter_button: Button = %BuyCanisterFilterButton
@onready var _buy_led_light_button: Button = %BuyLedLightButton
@onready var _buy_protein_skimmer_button: Button = %BuyProteinSkimmerButton
@onready var _buy_powerhead_button: Button = %BuyPowerheadButton
@onready var _buy_guppy_button: Button = %BuyGuppyButton
@onready var _buy_shrimp_button: Button = %BuyShrimpButton
@onready var _buy_tetra_button: Button = %BuyTetraButton
@onready var _buy_danio_button: Button = %BuyDanioButton
@onready var _buy_platy_button: Button = %BuyPlatyButton
@onready var _buy_betta_button: Button = %BuyBettaButton
@onready var _buy_molly_button: Button = %BuyMollyButton
@onready var _buy_cory_button: Button = %BuyCoryButton
@onready var _buy_rasbora_button: Button = %BuyRasboraButton
@onready var _buy_gourami_button: Button = %BuyGouramiButton
@onready var _buy_clownfish_button: Button = %BuyClownfishButton
@onready var _buy_chromis_button: Button = %BuyChromisButton
@onready var _buy_cleaner_shrimp_button: Button = %BuyCleanerShrimpButton
@onready var _feed_button: Button = %FeedButton
@onready var _water_change_button: Button = %WaterChangeButton
@onready var _treat_disease_button: Button = %TreatDiseaseButton
@onready var _sell_one_button: Button = %SellOneButton
@onready var _fast_forward_button: Button = %FastForwardButton

@onready var _buy_large_freshwater_tank_button: Button = %BuyLargeFreshwaterTankButton
@onready var _buy_marine_reef_tank_button: Button = %BuyMarineReefTankButton

@onready var _content_vbox: VBoxContainer = %ContentVBox
@onready var _sidebar_panel: PanelContainer = %SidebarPanel

var _alert_timer: float = 0.0
var _ui_refresh_accum: float = 0.0
const UI_REFRESH_INTERVAL := 0.25
const FEED_COST := 1


func current_tank() -> TankController:
	return _tanks[_current_tank_index]


func _ready() -> void:
	if SaveManager.has_save():
		SaveManager.load_game()

	_buy_heater_button.pressed.connect(_on_buy_equipment.bind("basic_heater"))
	_buy_filter_button.pressed.connect(_on_buy_equipment.bind("basic_filter"))
	_buy_light_button.pressed.connect(_on_buy_equipment.bind("basic_light"))
	_buy_air_stone_button.pressed.connect(_on_buy_equipment.bind("air_stone"))
	_buy_test_kit_button.pressed.connect(_on_buy_equipment.bind("digital_test_kit"))
	_buy_pro_heater_button.pressed.connect(_on_buy_equipment.bind("pro_heater"))
	_buy_canister_filter_button.pressed.connect(_on_buy_equipment.bind("canister_filter"))
	_buy_led_light_button.pressed.connect(_on_buy_equipment.bind("led_light"))
	_buy_protein_skimmer_button.pressed.connect(_on_buy_equipment.bind("protein_skimmer"))
	_buy_powerhead_button.pressed.connect(_on_buy_equipment.bind("powerhead"))
	_buy_guppy_button.pressed.connect(_on_buy_fish.bind("guppy"))
	_buy_shrimp_button.pressed.connect(_on_buy_fish.bind("cherry_shrimp"))
	_buy_tetra_button.pressed.connect(_on_buy_fish.bind("neon_tetra"))
	_buy_danio_button.pressed.connect(_on_buy_fish.bind("zebra_danio"))
	_buy_platy_button.pressed.connect(_on_buy_fish.bind("platy"))
	_buy_betta_button.pressed.connect(_on_buy_fish.bind("betta"))
	_buy_molly_button.pressed.connect(_on_buy_fish.bind("molly"))
	_buy_cory_button.pressed.connect(_on_buy_fish.bind("cory_catfish"))
	_buy_rasbora_button.pressed.connect(_on_buy_fish.bind("harlequin_rasbora"))
	_buy_gourami_button.pressed.connect(_on_buy_fish.bind("honey_gourami"))
	_buy_clownfish_button.pressed.connect(_on_buy_fish.bind("clownfish"))
	_buy_chromis_button.pressed.connect(_on_buy_fish.bind("blue_green_chromis"))
	_buy_cleaner_shrimp_button.pressed.connect(_on_buy_fish.bind("cleaner_shrimp"))
	_feed_button.pressed.connect(_on_feed)
	_water_change_button.pressed.connect(_on_water_change)
	_treat_disease_button.pressed.connect(_on_treat_disease)
	_sell_one_button.pressed.connect(_on_sell_one)
	_fast_forward_button.pressed.connect(_on_fast_forward)

	_tank_tab1_button.pressed.connect(_on_select_tank.bind(0))
	_tank_tab2_button.pressed.connect(_on_select_tank.bind(1))
	_guide_button.pressed.connect(_guide_panel.open)
	_lang_toggle_button.pressed.connect(_on_toggle_language)
	_volume_slider.value = AudioManager.master_volume
	_volume_slider.value_changed.connect(func(v): AudioManager.master_volume = v)
	_buy_large_freshwater_tank_button.pressed.connect(_on_buy_tank.bind("large_freshwater_tank"))
	_buy_marine_reef_tank_button.pressed.connect(_on_buy_tank.bind("marine_reef_tank"))

	for t in _tanks:
		t.water_quality_alert.connect(_on_water_quality_alert)
	EconomyManager.cash_changed.connect(func(_c): _refresh_ui())
	TimeManager.sim_day_elapsed.connect(func(_d): _refresh_ui())

	_sidebar_panel.theme = _build_theme()
	_normalize_sidebar_buttons()
	_apply_static_labels()
	_refresh_tank_tabs()
	_select_tank(0 if not _tanks[0].locked else 1)
	_connect_click_sounds(_sidebar_panel)


## Generic UI feedback on every button in the sidebar — simplest way to get "a sound somewhere
## for every interaction" without hand-wiring each one. Economy actions (buy/sell/feed/water
## change) layer a more specific sound (coin/cash/feed/splash) on top of this from their own
## handlers below.
func _connect_click_sounds(node: Node) -> void:
	if node is Button:
		node.pressed.connect(func(): AudioManager.play("click"))
	for child in node.get_children():
		_connect_click_sounds(child)


## Long translated button labels (especially Hebrew, which tends to run longer than the
## English source) would otherwise force the sidebar wider than its anchored column and spill
## past the screen edge — Buttons normally ask for enough width to show their full text
## un-truncated. clip_text lets a Button's minimum size shrink below its text's natural width
## (truncating with an ellipsis instead), and expand/fill makes it hug the column's real width
## rather than its own intrinsic content width.
## Built in code rather than a hand-authored .tres Theme resource — a handful of StyleBoxFlat
## overrides is easier to iterate on and screenshot-verify than Theme file syntax, and this is
## still an early visual pass (see memory: "looks like a debug tool" was the explicit complaint
## this addresses). Gives buttons a teal, rounded, water-themed look instead of default gray.
func _build_theme() -> Theme:
	var theme := Theme.new()

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.11, 0.3, 0.42, 0.92)
	normal.set_corner_radius_all(6)
	normal.set_content_margin_all(8)
	normal.content_margin_left = 10
	normal.content_margin_right = 10

	var hover := normal.duplicate()
	hover.bg_color = Color(0.16, 0.4, 0.55, 0.95)

	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.3, 0.62, 0.45, 1.0)

	var disabled := normal.duplicate()
	disabled.bg_color = Color(0.16, 0.18, 0.22, 0.55)

	theme.set_stylebox("normal", "Button", normal)
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("pressed", "Button", pressed)
	theme.set_stylebox("hover_pressed", "Button", pressed)
	theme.set_stylebox("disabled", "Button", disabled)
	theme.set_color("font_color", "Button", Color(0.92, 0.96, 0.98))
	theme.set_color("font_hover_color", "Button", Color(1.0, 1.0, 1.0))
	theme.set_color("font_pressed_color", "Button", Color(1.0, 1.0, 1.0))
	theme.set_color("font_disabled_color", "Button", Color(0.55, 0.58, 0.62))

	theme.set_color("font_color", "Label", Color(0.88, 0.92, 0.95))

	## Equipment/food buttons carry an icon texture (see Main.tscn); the source art is sized for
	## clarity (up to ~96px), so this caps it down to a small inline icon instead of ballooning
	## every button's height. Buttons without an icon are unaffected.
	theme.set_constant("icon_max_width", "Button", 22)
	return theme


func _normalize_sidebar_buttons() -> void:
	for child in _content_vbox.get_children():
		if child is Button:
			child.clip_text = true
			child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tank_tab1_button.clip_text = true
	_tank_tab2_button.clip_text = true
	_guide_button.clip_text = true
	_guide_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _process(delta: float) -> void:
	if _alert_timer > 0.0:
		_alert_timer -= delta
		if _alert_timer <= 0.0:
			_alert_label.text = ""
	_ui_refresh_accum += delta
	if _ui_refresh_accum >= UI_REFRESH_INTERVAL:
		_ui_refresh_accum = 0.0
		_refresh_ui()


## Labels/buttons whose text never changes per-frame (section headers, static buy buttons).
## Rebuilt once at start and again whenever the language toggles.
func _apply_static_labels() -> void:
	_title_label.text = Localization.t("ui_title")
	_guide_button.text = Localization.t("nav_guide")
	_volume_label.text = Localization.t("settings_volume")
	_lang_toggle_button.text = Localization.t("lang_toggle_to_en" if Localization.current_language == "he" else "lang_toggle_to_he")

	_equipment_label.text = Localization.t("section_equipment")
	_fish_label.text = Localization.t("section_fish")
	_actions_label.text = Localization.t("section_actions")
	_debug_label.text = Localization.t("section_debug")
	_tanks_label.text = Localization.t("section_buy_tank")

	_set_item_button_text(_buy_heater_button, "basic_heater")
	_set_item_button_text(_buy_filter_button, "basic_filter")
	_set_item_button_text(_buy_light_button, "basic_light")
	_set_item_button_text(_buy_air_stone_button, "air_stone")
	_set_item_button_text(_buy_test_kit_button, "digital_test_kit")
	_set_item_button_text(_buy_pro_heater_button, "pro_heater")
	_set_item_button_text(_buy_canister_filter_button, "canister_filter")
	_set_item_button_text(_buy_led_light_button, "led_light")
	_set_item_button_text(_buy_protein_skimmer_button, "protein_skimmer")
	_set_item_button_text(_buy_powerhead_button, "powerhead")

	_set_item_button_text(_buy_guppy_button, "guppy")
	_set_item_button_text(_buy_shrimp_button, "cherry_shrimp")
	_set_item_button_text(_buy_tetra_button, "neon_tetra")
	_set_item_button_text(_buy_danio_button, "zebra_danio")
	_set_item_button_text(_buy_platy_button, "platy")
	_set_item_button_text(_buy_betta_button, "betta")
	_set_item_button_text(_buy_molly_button, "molly")
	_set_item_button_text(_buy_cory_button, "cory_catfish")
	_set_item_button_text(_buy_rasbora_button, "harlequin_rasbora")
	_set_item_button_text(_buy_gourami_button, "honey_gourami")
	_set_item_button_text(_buy_clownfish_button, "clownfish")
	_set_item_button_text(_buy_chromis_button, "blue_green_chromis")
	_set_item_button_text(_buy_cleaner_shrimp_button, "cleaner_shrimp")

	_feed_button.text = Localization.t("action_feed")
	_water_change_button.text = Localization.t("action_water_change")
	var medication := ShopManager.get_medication("general_illness_treatment")
	_treat_disease_button.text = Localization.t("action_treat_disease", [medication.price if medication != null else 0])
	_sell_one_button.text = Localization.t("action_sell_one")
	_fast_forward_button.text = Localization.t("action_fast_forward")

	_set_tank_preset_button_text(_buy_large_freshwater_tank_button, "large_freshwater_tank")
	_set_tank_preset_button_text(_buy_marine_reef_tank_button, "marine_reef_tank")


## Equipment ids share their species-id-style lookup: "eq_<id>" / "sp_<id>" name keys.
func _set_item_button_text(button: Button, item_id: String) -> void:
	var species := ShopManager.get_species(item_id)
	if species != null:
		var name_key := "sp_%s" % item_id
		var price := species.base_price
		if species.unlock_tier <= 0:
			button.text = Localization.t("btn_buy_item", [Localization.t(name_key), price])
		elif species.is_marine:
			button.text = Localization.t("btn_buy_item_marine", [Localization.t(name_key), price, species.unlock_tier])
		else:
			button.text = Localization.t("btn_buy_item_tier", [Localization.t(name_key), price, species.unlock_tier])
		return
	var equipment := ShopManager.get_equipment(item_id)
	if equipment != null:
		var name_key := "eq_%s" % item_id
		if equipment.unlock_tier <= 0:
			button.text = Localization.t("btn_buy_item", [Localization.t(name_key), equipment.price])
		elif equipment.unlock_tier >= 2:
			button.text = Localization.t("btn_buy_item_marine", [Localization.t(name_key), equipment.price, equipment.unlock_tier])
		else:
			button.text = Localization.t("btn_buy_item_tier", [Localization.t(name_key), equipment.price, equipment.unlock_tier])


func _set_tank_preset_button_text(button: Button, preset_id: String) -> void:
	var preset := ShopManager.get_tank_preset(preset_id)
	if preset == null:
		return
	var name_key := "tank_%s" % preset_id
	button.text = Localization.t("btn_tank_option", [Localization.t(name_key), preset.price, preset.unlock_tier])


func _on_toggle_language() -> void:
	Localization.set_language(Localization.other_language())
	_apply_static_labels()
	_refresh_tank_tabs()
	_refresh_ui()


func _on_select_tank(index: int) -> void:
	if _tanks[index].locked:
		return
	_select_tank(index)


func _select_tank(index: int) -> void:
	_current_tank_index = index
	for i in range(_tanks.size()):
		_tanks[i].visible = (i == index)
	_tank_tab1_button.button_pressed = (index == 0)
	_tank_tab2_button.button_pressed = (index == 1)
	_refresh_ui()


func _refresh_tank_tabs() -> void:
	var tank2 := _tanks[1]
	_tank_tab1_button.text = Localization.t("tab_tank1")
	_tank_tab2_button.disabled = tank2.locked
	if tank2.locked:
		_tank_tab2_button.text = Localization.t("tab_tank2_locked")
	else:
		_tank_tab2_button.text = Localization.t("tab_tank2_salt" if tank2.tank_type == TankController.TankType.SALTWATER else "tab_tank2_fresh")
	_buy_large_freshwater_tank_button.visible = tank2.locked
	_buy_marine_reef_tank_button.visible = tank2.locked
	_tank_tab1_button.button_pressed = (_current_tank_index == 0)
	_tank_tab2_button.button_pressed = (_current_tank_index == 1)


func _on_buy_tank(preset_id: String) -> void:
	var tank2 := _tanks[1]
	if not tank2.locked:
		_show_alert(Localization.t("alert_tank2_already_setup"))
		return
	var preset := ShopManager.get_tank_preset(preset_id)
	if preset == null:
		return
	if preset.unlock_tier > EconomyManager.unlock_tier:
		_show_alert(Localization.t("alert_item_locked_tier", [Localization.t("tank_%s" % preset_id)]))
		return
	if not EconomyManager.spend(preset.price, "Bought %s" % preset.display_name):
		_show_alert(Localization.t("alert_not_enough_cash"))
		return
	tank2.unlock(preset.tank_liters, preset.tank_type, preset.ambient_temp_base_c)
	AudioManager.play("coin")
	_refresh_tank_tabs()
	_select_tank(1)


func _on_buy_equipment(equipment_id: String) -> void:
	var equipment := ShopManager.get_equipment(equipment_id)
	if equipment == null:
		return
	if not EconomyManager.spend(equipment.price, "Bought %s" % equipment.display_name):
		_show_alert(Localization.t("alert_not_enough_cash"))
		return
	var tank := current_tank()
	match equipment.slot:
		EquipmentData.Slot.HEATER:
			tank.heater = equipment
		EquipmentData.Slot.FILTER:
			tank.filter = equipment
		EquipmentData.Slot.LIGHT:
			tank.light_equipment = equipment
		EquipmentData.Slot.AIR_STONE:
			tank.air_stone = equipment
		EquipmentData.Slot.TEST_KIT:
			tank.has_test_kit = equipment.reveals_exact_readings
	AudioManager.play("coin")


func _on_buy_fish(species_id: String) -> void:
	var species := ShopManager.get_species(species_id)
	if species == null:
		return
	if species.unlock_tier > EconomyManager.unlock_tier:
		_show_alert(Localization.t("alert_item_locked_tier", [Localization.t("sp_%s" % species_id)]))
		return
	var tank := current_tank()
	var is_saltwater: bool = tank.tank_type == TankController.TankType.SALTWATER
	var reason := _localized_compatibility_reason(species, tank, is_saltwater)
	if reason != "":
		_show_alert(reason)
		return
	if not EconomyManager.spend(species.base_price, "Bought %s" % species.display_name):
		_show_alert(Localization.t("alert_not_enough_cash"))
		return
	tank.add_fish(species, false)
	AudioManager.play("coin")


## Translates Economy.compatibility_reason_code()'s result — single source of truth for the
## actual compatibility RULES lives in Economy; this only maps a code to localized text.
func _localized_compatibility_reason(species: FishSpeciesData, tank: TankController, is_saltwater: bool) -> String:
	var code := Economy.compatibility_reason_code(species, tank.tank_liters, is_saltwater, tank.heater != null, tank.total_bioload())
	var name := Localization.t("sp_%s" % species.id)
	match code:
		"marine_needs_saltwater":
			return Localization.t("alert_marine_needs_saltwater", [name])
		"freshwater_in_saltwater":
			return Localization.t("alert_freshwater_in_saltwater", [name])
		"tank_too_small":
			return Localization.t("alert_tank_too_small", [int(species.min_tank_liters), int(tank.tank_liters)])
		"needs_heater":
			return Localization.t("alert_needs_heater", [species.temp_min_c, species.temp_max_c])
		"tank_at_capacity":
			return Localization.t("alert_tank_at_capacity")
		_:
			return ""


func _on_feed() -> void:
	var tank := current_tank()
	if tank.get_fish().is_empty():
		_show_alert(Localization.t("alert_no_fish_to_feed"))
		return
	if not EconomyManager.spend(FEED_COST, "Bought food"):
		_show_alert(Localization.t("alert_not_enough_cash_for_food"))
		return
	tank.feed(ShopManager.get_food("basic_flakes"))
	AudioManager.play("feed")


func _on_water_change() -> void:
	current_tank().perform_water_change(0.25)
	AudioManager.play("splash")


func _on_treat_disease() -> void:
	var tank := current_tank()
	if tank.sick_fish_count() == 0 and tank.medication_remaining_days <= 0.0:
		_show_alert(Localization.t("alert_no_sick_fish"))
		return
	var medication := ShopManager.get_medication("general_illness_treatment")
	if medication == null:
		return
	if not EconomyManager.spend(medication.price, "Bought %s" % medication.display_name):
		_show_alert(Localization.t("alert_not_enough_cash_for_medication"))
		return
	tank.administer_medication(medication)
	AudioManager.play("coin")


func _on_sell_one() -> void:
	var fish_list := current_tank().get_fish()
	if fish_list.is_empty():
		_show_alert(Localization.t("alert_no_fish_to_sell"))
		return
	current_tank().sell_fish(fish_list[0])
	AudioManager.play("cash")


func _on_fast_forward() -> void:
	TimeManager.debug_fast_forward_days(1.0)


func _on_water_quality_alert(message_key: String) -> void:
	_show_alert(Localization.t(message_key))


func _show_alert(message: String) -> void:
	_alert_label.text = message
	_alert_timer = 5.0
	AudioManager.play("alert")


func _refresh_ui() -> void:
	var tank := current_tank()
	_cash_label.text = Localization.t("status_cash", [EconomyManager.cash])
	_day_label.text = Localization.t("status_day", [TimeManager.current_day(), Localization.t("season_%d" % TimeManager.current_season)])
	_fish_count_label.text = Localization.t("status_fish", [tank.get_fish().size()])
	_temp_label.text = Localization.t("status_temp", [tank.temperature])
	if tank.has_test_kit:
		_ammonia_label.text = Localization.t("status_ammonia_known", [tank.ammonia])
		_nitrite_label.text = Localization.t("status_nitrite_known", [tank.nitrite])
		_nitrate_label.text = Localization.t("status_nitrate_known", [tank.nitrate])
		_oxygen_label.text = Localization.t("status_oxygen_known", [tank.oxygen])
	else:
		var neglect := tank.get_neglect_score()
		var water_rough_key := "water_good" if neglect < 0.3 else ("water_fair" if neglect < 0.6 else "water_poor")
		_ammonia_label.text = Localization.t("status_ammonia_unknown")
		_nitrite_label.text = Localization.t("status_nitrite_unknown")
		_nitrate_label.text = Localization.t("status_nitrate_unknown")
		_oxygen_label.text = Localization.t("status_water_quality_rough", [Localization.t(water_rough_key)])
	_salinity_label.text = Localization.t("status_salinity", [tank.specific_gravity]) if tank.tank_type == TankController.TankType.SALTWATER else ""
	_filter_label.text = Localization.t("status_filter", [int(tank.filter_maturity)])
	_sick_label.text = Localization.t("status_sick", [tank.sick_fish_count()])
