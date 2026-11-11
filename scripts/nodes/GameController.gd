extends Node
class_name GameController
## The game's glue: owns the two tank slots, performs every player action (buy / sell / feed /
## water change / treat), and builds the phone UI in code (scripts/ui/*) on top of them. The UI
## never touches the simulation directly — it calls the methods here and re-reads state when
## `state_changed` fires.
##
## Multi-tank: exactly two tank slots exist as scene nodes from the start (see Main.tscn).
## Tank 1 is always owned; Tank 2 starts `locked` and is configured from a TankPresetData when
## the player buys it. Only the selected tank is shown.
##
## Localization: every player-facing string is built via Localization.t(). Switching language
## simply rebuilds the whole UI tree (_rebuild_ui), so no screen needs its own re-label code.

signal state_changed
signal update_status_changed

const FEED_COST := 1
const ALERT_REPEAT_SECONDS := 40.0
const BAILOUT_CASH := 20

@onready var _tanks: Array[TankController] = [%TankInstance, %Tank2Instance]
@onready var _ui_layer: CanvasLayer = $UI
var _current_tank_index: int = 0

var ui_root: Control
var hud: Hud
var home: HomeScreen
var shop: ShopPanel
var fish_panel: FishPanel
var tank_panel: TankInfoPanel
var guide: GuidePanel
var settings: SettingsPanel
var welcome: WelcomePanel
var toast_view: ToastView

## Where the in-app update flow currently is — see UpdateChecker (autoload) for the actual
## check/download/install logic. Lives here (not in SettingsPanel) so it survives a UI rebuild.
enum UpdateState { IDLE, CHECKING, AVAILABLE, DOWNLOADING, READY_TO_INSTALL }
var update_state: UpdateState = UpdateState.IDLE
var update_status_text: String = ""

var _show_welcome_on_start: bool = false
var _alert_last_shown: Dictionary = {}  ## message key -> Time.get_ticks_msec() of last toast


func current_tank() -> TankController:
	return _tanks[_current_tank_index]


func tanks() -> Array[TankController]:
	return _tanks


func current_tank_index() -> int:
	return _current_tank_index


func _ready() -> void:
	var had_save := SaveManager.has_save()
	if had_save:
		SaveManager.load_game()
	_show_welcome_on_start = not had_save

	for tank in _tanks:
		tank.water_quality_alert.connect(_on_water_quality_alert)
		tank.fish_born.connect(_on_fish_born)
		tank.fish_died.connect(_on_fish_died)
		tank.refresh_equipment_visuals()
	EconomyManager.cash_changed.connect(func(_c): state_changed.emit())
	state_changed.connect(func(): _check_bailout.call_deferred())
	EconomyManager.unlock_tier_changed.connect(_on_unlock_tier_changed)
	Localization.language_changed.connect(func(_l): _rebuild_ui.call_deferred())

	UpdateChecker.check_completed.connect(_on_update_check_completed)
	UpdateChecker.download_progress.connect(_on_update_download_progress)
	UpdateChecker.download_completed.connect(_on_update_download_completed)
	UpdateChecker.download_failed.connect(_on_update_download_failed)

	_build_ui()
	_check_bailout()
	_select_tank(0 if not _tanks[0].locked else 1)
	show_home()
	## Quiet check at launch so the home screen can offer the update without being asked.
	check_for_update()


# ----------------------------------------------------------------------------------------
# UI construction / navigation
# ----------------------------------------------------------------------------------------

func _build_ui() -> void:
	ui_root = Control.new()
	ui_root.name = "Root"
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.theme = UiKit.build_theme()
	## Explicit, from the in-game language — not the device locale — so Hebrew is always
	## right-to-left and English always left-to-right, whatever the phone is set to.
	ui_root.layout_direction = Control.LAYOUT_DIRECTION_RTL if Localization.current_language == "he" else Control.LAYOUT_DIRECTION_LTR
	_ui_layer.add_child(ui_root)

	hud = Hud.new()
	hud.game = self
	ui_root.add_child(hud)

	home = HomeScreen.new()
	home.game = self
	ui_root.add_child(home)

	shop = ShopPanel.new()
	fish_panel = FishPanel.new()
	tank_panel = TankInfoPanel.new()
	guide = GuidePanel.new()
	settings = SettingsPanel.new()
	welcome = WelcomePanel.new()
	for panel in [shop, fish_panel, tank_panel, guide, settings, welcome]:
		panel.game = self
		ui_root.add_child(panel)

	## Last child = drawn over everything, panels included.
	toast_view = ToastView.new()
	ui_root.add_child(toast_view)


func _rebuild_ui() -> void:
	var home_was_visible: bool = home != null and home.visible
	var settings_was_open: bool = settings != null and settings.visible
	if ui_root != null:
		ui_root.queue_free()
	_build_ui()
	home.visible = home_was_visible
	if settings_was_open:
		settings.open()
	state_changed.emit()


func show_home() -> void:
	close_panels()
	home.refresh()
	home.visible = true
	TimeManager.paused = true


func go_home() -> void:
	SaveManager.save_game()
	show_home()


func start_game() -> void:
	home.visible = false
	TimeManager.paused = false
	AudioManager.play("splash")
	if _show_welcome_on_start:
		_show_welcome_on_start = false
		welcome.open()
	state_changed.emit()


func close_panels() -> void:
	for panel in [shop, fish_panel, tank_panel, guide, settings, welcome]:
		if panel != null and panel.visible:
			panel.close()


func open_shop(tab: int = ShopPanel.Tab.FISH) -> void:
	close_panels()
	shop.open_tab(tab)


func open_fish_panel() -> void:
	close_panels()
	fish_panel.open()


func open_tank_panel() -> void:
	close_panels()
	tank_panel.open()


func open_guide() -> void:
	close_panels()
	guide.open()


func open_settings() -> void:
	close_panels()
	settings.open()


func toast(message: String, kind: String = "info") -> void:
	if toast_view != null:
		toast_view.show_toast(message, kind)
	if kind == "bad":
		AudioManager.play("alert")


# ----------------------------------------------------------------------------------------
# Tanks
# ----------------------------------------------------------------------------------------

func _on_select_tank(index: int) -> void:
	select_tank(index)


func select_tank(index: int) -> void:
	if index < 0 or index >= _tanks.size() or _tanks[index].locked:
		return
	_select_tank(index)


func _select_tank(index: int) -> void:
	_current_tank_index = index
	for i in range(_tanks.size()):
		_tanks[i].visible = (i == index)
	state_changed.emit()


## HUD tank button: flip to the other tank, or straight to the tank shop if there isn't one yet.
func cycle_tank() -> void:
	var other := (_current_tank_index + 1) % _tanks.size()
	if _tanks[other].locked:
		open_shop(ShopPanel.Tab.TANKS)
	else:
		_select_tank(other)


func tank_display_name(index: int) -> String:
	var tank := _tanks[index]
	var type_key := "tank_type_salt" if tank.tank_type == TankController.TankType.SALTWATER else "tank_type_fresh"
	return Localization.t("tank_name", [index + 1, Localization.t(type_key), int(tank.tank_liters)])


func tank_block_reason(preset: TankPresetData) -> String:
	if not _tanks[1].locked:
		return Localization.t("alert_tank2_already_setup")
	if preset.unlock_tier > EconomyManager.unlock_tier:
		return _tier_lock_text(preset.unlock_tier)
	return ""


func _on_buy_tank(preset_id: String) -> void:
	buy_tank(preset_id)


func buy_tank(preset_id: String) -> bool:
	var preset := ShopManager.get_tank_preset(preset_id)
	if preset == null:
		return false
	var reason := tank_block_reason(preset)
	if reason != "":
		toast(reason, "bad")
		return false
	if not EconomyManager.spend(preset.price, "Bought %s" % preset.display_name):
		toast(Localization.t("alert_not_enough_cash"), "bad")
		return false
	_tanks[1].unlock(preset.tank_liters, preset.tank_type, preset.ambient_temp_base_c)
	AudioManager.play("coin")
	_select_tank(1)
	toast(Localization.t("toast_bought", [Localization.t("tank_%s" % preset_id)]), "good")
	return true


# ----------------------------------------------------------------------------------------
# Shop: equipment
# ----------------------------------------------------------------------------------------

func _tier_lock_text(tier: int) -> String:
	var needed: int = maxi(0, Economy.TIER_THRESHOLDS[mini(tier, Economy.TIER_THRESHOLDS.size() - 1)] - EconomyManager.lifetime_earnings)
	return Localization.t("shop_locked_tier", [tier, needed])


func is_equipment_installed(equipment: EquipmentData) -> bool:
	var tank := current_tank()
	match equipment.slot:
		EquipmentData.Slot.HEATER:
			return tank.heater == equipment and not tank.heater_failed
		EquipmentData.Slot.FILTER:
			return tank.filter == equipment
		EquipmentData.Slot.LIGHT:
			return tank.light_equipment == equipment
		EquipmentData.Slot.AIR_STONE:
			return tank.air_stone == equipment
		EquipmentData.Slot.TEST_KIT:
			return tank.has_test_kit
	return false


## "" when the item can be bought for the current tank (money aside).
func equipment_block_reason(equipment: EquipmentData) -> String:
	if equipment.unlock_tier > EconomyManager.unlock_tier:
		return _tier_lock_text(equipment.unlock_tier)
	if is_equipment_installed(equipment):
		return Localization.t("shop_installed")
	return ""


func _on_buy_equipment(equipment_id: String) -> void:
	buy_equipment(equipment_id)


func buy_equipment(equipment_id: String) -> bool:
	var equipment := ShopManager.get_equipment(equipment_id)
	if equipment == null:
		return false
	var reason := equipment_block_reason(equipment)
	if reason != "":
		toast(reason, "bad")
		return false
	if not EconomyManager.spend(equipment.price, "Bought %s" % equipment.display_name):
		toast(Localization.t("alert_not_enough_cash"), "bad")
		return false
	var tank := current_tank()
	match equipment.slot:
		EquipmentData.Slot.HEATER:
			tank.heater = equipment
			tank.heater_failed = false
		EquipmentData.Slot.FILTER:
			tank.filter = equipment
		EquipmentData.Slot.LIGHT:
			tank.light_equipment = equipment
		EquipmentData.Slot.AIR_STONE:
			tank.air_stone = equipment
		EquipmentData.Slot.TEST_KIT:
			tank.has_test_kit = equipment.reveals_exact_readings
	tank.refresh_equipment_visuals()
	AudioManager.play("coin")
	toast(Localization.t("toast_installed", [Localization.t("eq_%s" % equipment_id)]), "good")
	state_changed.emit()
	return true


# ----------------------------------------------------------------------------------------
# Shop: fish
# ----------------------------------------------------------------------------------------

## "" when the species can be added to the current tank (money aside).
func fish_block_reason(species: FishSpeciesData) -> String:
	if species.unlock_tier > EconomyManager.unlock_tier:
		return _tier_lock_text(species.unlock_tier)
	var tank := current_tank()
	return _localized_compatibility_reason(species, tank, tank.tank_type == TankController.TankType.SALTWATER)


## Translates Economy.compatibility_reason_code()'s result — single source of truth for the
## actual compatibility RULES lives in Economy; this only maps a code to localized text.
func _localized_compatibility_reason(species: FishSpeciesData, tank: TankController, is_saltwater: bool) -> String:
	var code := Economy.compatibility_reason_code(species, tank.tank_liters, is_saltwater, tank.heater != null, tank.total_bioload())
	var species_name := Localization.t("sp_%s" % species.id)
	match code:
		"marine_needs_saltwater":
			return Localization.t("alert_marine_needs_saltwater", [species_name])
		"freshwater_in_saltwater":
			return Localization.t("alert_freshwater_in_saltwater", [species_name])
		"tank_too_small":
			return Localization.t("alert_tank_too_small", [int(species.min_tank_liters), int(tank.tank_liters)])
		"needs_heater":
			return Localization.t("alert_needs_heater", [species.temp_min_c, species.temp_max_c])
		"tank_at_capacity":
			return Localization.t("alert_tank_at_capacity")
		_:
			return ""


func count_fish(species_id: String, fry: bool) -> int:
	var count := 0
	for fish in current_tank().get_fish():
		if fish.species.id == species_id and fish.is_fry == fry:
			count += 1
	return count


func _on_buy_fish(species_id: String) -> void:
	buy_fish(species_id)


func buy_fish(species_id: String) -> bool:
	var species := ShopManager.get_species(species_id)
	if species == null:
		return false
	var reason := fish_block_reason(species)
	if reason != "":
		toast(reason, "bad")
		return false
	if not EconomyManager.spend(species.base_price, "Bought %s" % species.display_name):
		toast(Localization.t("alert_not_enough_cash"), "bad")
		return false
	current_tank().add_fish(species, false)
	AudioManager.play("coin")
	toast(Localization.t("toast_bought", [Localization.t("sp_%s" % species_id)]), "good")
	state_changed.emit()
	return true


# ----------------------------------------------------------------------------------------
# Selling
# ----------------------------------------------------------------------------------------

func sell_one_of(species_id: String, fry: bool) -> bool:
	## Sell the least healthy one first — the player keeps their best breeders.
	var pick: FishController = null
	for fish in current_tank().get_fish():
		if fish.species.id == species_id and fish.is_fry == fry:
			if pick == null or fish.health < pick.health:
				pick = fish
	if pick == null:
		return false
	var value := current_tank().sell_fish(pick)
	AudioManager.play("cash")
	toast(Localization.t("toast_sold", [Localization.t("sp_%s" % species_id), value]), "good")
	state_changed.emit()
	return true


func sell_all_fry(species_id: String) -> int:
	var total := 0
	for fish in current_tank().get_fish():
		if fish.species.id == species_id and fish.is_fry:
			total += current_tank().sell_fish(fish)
	if total > 0:
		AudioManager.play("cash")
		toast(Localization.t("toast_sold_many", [total]), "good")
		state_changed.emit()
	return total


## Legacy entry point used by the dev smoke test: sells whichever fish comes first.
func _on_sell_one() -> void:
	var fish_list := current_tank().get_fish()
	if fish_list.is_empty():
		toast(Localization.t("alert_no_fish_to_sell"), "bad")
		return
	current_tank().sell_fish(fish_list[0])
	AudioManager.play("cash")
	state_changed.emit()


# ----------------------------------------------------------------------------------------
# Care actions
# ----------------------------------------------------------------------------------------

func _on_feed() -> void:
	feed(true)


## `force` skips the "they're not hungry" guard (dev tools feed on a fixed schedule).
func feed(force: bool = false) -> bool:
	var tank := current_tank()
	var fish_list := tank.get_fish()
	if fish_list.is_empty():
		toast(Localization.t("alert_no_fish_to_feed"), "bad")
		return false
	if not force:
		var hungriest := 100.0
		for fish in fish_list:
			hungriest = minf(hungriest, fish.hunger)
		if hungriest > 75.0:
			toast(Localization.t("alert_fish_full"), "info")
			return false
	if not EconomyManager.spend(FEED_COST, "Bought food"):
		toast(Localization.t("alert_not_enough_cash_for_food"), "bad")
		return false
	tank.feed(ShopManager.get_food("basic_flakes"))
	AudioManager.play("feed")
	state_changed.emit()
	return true


func _on_water_change() -> void:
	water_change()


func water_change() -> void:
	current_tank().perform_water_change(0.25)
	AudioManager.play("splash")
	toast(Localization.t("toast_water_changed"), "good")
	state_changed.emit()


func medication_price() -> int:
	var medication := ShopManager.get_medication("general_illness_treatment")
	return medication.price if medication != null else 0


func _on_treat_disease() -> void:
	treat_disease()


func treat_disease() -> bool:
	var tank := current_tank()
	if tank.sick_fish_count() == 0:
		toast(Localization.t("alert_no_sick_fish"), "info")
		return false
	if tank.medication_remaining_days > 0.0:
		toast(Localization.t("alert_already_treating"), "info")
		return false
	var medication := ShopManager.get_medication("general_illness_treatment")
	if medication == null:
		return false
	if not EconomyManager.spend(medication.price, "Bought %s" % medication.display_name):
		toast(Localization.t("alert_not_enough_cash_for_medication"), "bad")
		return false
	tank.administer_medication(medication)
	AudioManager.play("coin")
	toast(Localization.t("toast_treating"), "good")
	state_changed.emit()
	return true


func _on_fast_forward() -> void:
	TimeManager.debug_fast_forward_days(1.0)
	state_changed.emit()


## Wipes all progress back to a brand-new game (Settings -> New game).
func reset_game() -> void:
	SaveManager.delete_save()
	EconomyManager.from_save_dict({})
	EconomyManager.cash_changed.emit(EconomyManager.cash)
	TimeManager.sim_minutes_total = 0.0
	TimeManager.current_season = TimeManager.Season.SPRING
	_tanks[0].reset_to_new(false, 40.0, TankController.TankType.FRESHWATER, 22.0)
	_tanks[1].reset_to_new(true, 40.0, TankController.TankType.FRESHWATER, 22.0)
	_alert_last_shown.clear()
	_show_welcome_on_start = true
	_select_tank(0)
	show_home()


# ----------------------------------------------------------------------------------------
# "What should I do now?" — the one-line coach under the top bar
# ----------------------------------------------------------------------------------------

## Returns {"text": String, "action": Callable, "kind": "info"|"warn"|"bad"}. Ordered from most
## urgent to least, so a brand-new player is walked through the whole loop one step at a time.
func current_tip() -> Dictionary:
	var tank := current_tank()
	var fish_list := tank.get_fish()
	var to_shop_equipment := open_shop.bind(ShopPanel.Tab.EQUIPMENT)
	var to_shop_fish := open_shop.bind(ShopPanel.Tab.FISH)

	if tank.filter == null:
		return {"text": Localization.t("tip_buy_filter"), "action": to_shop_equipment, "kind": "warn"}
	if fish_list.is_empty():
		return {"text": Localization.t("tip_buy_fish"), "action": to_shop_fish, "kind": "warn"}
	if tank.ammonia > WaterChemistry.AMMONIA_DANGER or tank.nitrite > WaterChemistry.NITRITE_DANGER or tank.nitrate > WaterChemistry.NITRATE_DANGER:
		return {"text": Localization.t("tip_water_change"), "action": water_change, "kind": "bad"}
	if tank.hungry_fish_count() > 0:
		return {"text": Localization.t("tip_feed"), "action": feed.bind(false), "kind": "warn"}
	if tank.sick_fish_count() > 0 and tank.medication_remaining_days <= 0.0:
		return {"text": Localization.t("tip_treat", [medication_price()]), "action": treat_disease, "kind": "bad"}
	if tank.heater == null or tank.heater_failed:
		for fish in fish_list:
			if tank.temperature < fish.species.temp_min_c:
				var key := "tip_heater_failed" if tank.heater_failed else "tip_buy_heater"
				return {"text": Localization.t(key), "action": to_shop_equipment, "kind": "bad"}
	if tank.stocking_fraction() > 0.9:
		return {"text": Localization.t("tip_crowded"), "action": open_fish_panel, "kind": "warn"}

	var adults_by_species: Dictionary = {}
	for fish in fish_list:
		if not fish.is_fry:
			adults_by_species[fish.species] = adults_by_species.get(fish.species, 0) + 1
	for species in adults_by_species.keys():
		if species.fry_per_batch_max > 0 and species.pair_required and adults_by_species[species] == 1:
			return {"text": Localization.t("tip_need_pair", [Localization.t("sp_%s" % species.id)]), "action": to_shop_fish, "kind": "info"}
	for species in adults_by_species.keys():
		if species.schooling_min_group > 1 and _count_species(fish_list, species) < species.schooling_min_group:
			return {"text": Localization.t("tip_need_school", [Localization.t("sp_%s" % species.id), species.schooling_min_group]), "action": to_shop_fish, "kind": "info"}

	var fry := tank.fry_count()
	if fry > 0:
		return {"text": Localization.t("tip_fry", [fry]), "action": open_fish_panel, "kind": "info"}
	if tank.light_equipment == null:
		return {"text": Localization.t("tip_buy_light"), "action": to_shop_equipment, "kind": "info"}
	var to_next := Economy.earnings_to_next_tier(EconomyManager.lifetime_earnings)
	if to_next > 0:
		return {"text": Localization.t("tip_next_tier", [to_next, EconomyManager.unlock_tier + 1]), "action": open_fish_panel, "kind": "info"}
	return {"text": Localization.t("tip_all_good"), "action": open_tank_panel, "kind": "info"}


static func _count_species(fish_list: Array, species: FishSpeciesData) -> int:
	var count := 0
	for fish in fish_list:
		if fish.species == species:
			count += 1
	return count


# ----------------------------------------------------------------------------------------
# Simulation events -> toasts
# ----------------------------------------------------------------------------------------

func _on_water_quality_alert(message_key: String) -> void:
	## The ammonia warning fires every sim-hour while it's high; don't nag every few seconds.
	var now := Time.get_ticks_msec()
	if _alert_last_shown.has(message_key) and now - int(_alert_last_shown[message_key]) < ALERT_REPEAT_SECONDS * 1000.0:
		return
	_alert_last_shown[message_key] = now
	toast(Localization.t(message_key), "bad")


func _on_fish_born(species: FishSpeciesData, count: int) -> void:
	toast(Localization.t("toast_born", [count, Localization.t("sp_%s" % species.id)]), "good")
	AudioManager.play("coin")
	state_changed.emit()


func _on_fish_died(species: FishSpeciesData) -> void:
	toast(Localization.t("toast_died", [Localization.t("sp_%s" % species.id)]), "bad")
	state_changed.emit()
	_check_bailout.call_deferred()


## Safety net against a dead end: no fish anywhere and not enough money to buy a pair. The
## pet shop "lends a hand" so the player can always start again instead of being stuck.
func _check_bailout() -> void:
	if EconomyManager.cash >= BAILOUT_CASH:
		return
	for tank in _tanks:
		if not tank.locked and not tank.get_fish().is_empty():
			return
	EconomyManager.cash = BAILOUT_CASH
	EconomyManager.cash_changed.emit(EconomyManager.cash)
	toast(Localization.t("toast_bailout", [BAILOUT_CASH]), "good")


func _on_unlock_tier_changed(new_tier: int) -> void:
	toast(Localization.t("toast_tier_up", [new_tier]), "good")
	AudioManager.play("coin")
	state_changed.emit()


# ----------------------------------------------------------------------------------------
# In-app update
# ----------------------------------------------------------------------------------------

func check_for_update() -> void:
	if update_state != UpdateState.IDLE:
		return
	update_state = UpdateState.CHECKING
	update_status_text = Localization.t("update_checking")
	update_status_changed.emit()
	UpdateChecker.check_for_update()


## The single update button: check -> download -> install, depending on where we are.
func advance_update() -> void:
	match update_state:
		UpdateState.IDLE:
			check_for_update()
		UpdateState.AVAILABLE:
			update_state = UpdateState.DOWNLOADING
			update_status_text = Localization.t("update_downloading", [0])
			update_status_changed.emit()
			UpdateChecker.start_download()
		UpdateState.READY_TO_INSTALL:
			UpdateChecker.install_downloaded_update()


func update_button_text() -> String:
	match update_state:
		UpdateState.AVAILABLE:
			return Localization.t("update_btn_download")
		UpdateState.DOWNLOADING:
			return Localization.t("update_btn_downloading")
		UpdateState.READY_TO_INSTALL:
			return Localization.t("update_btn_install")
		_:
			return Localization.t("update_check")


func _on_update_check_completed(update_available: bool, latest_tag: String, error_code: String) -> void:
	if error_code != "":
		update_state = UpdateState.IDLE
		update_status_text = Localization.t("update_check_failed")
	elif not update_available:
		update_state = UpdateState.IDLE
		update_status_text = Localization.t("update_up_to_date")
	else:
		update_state = UpdateState.AVAILABLE
		update_status_text = Localization.t("update_available", [latest_tag])
	update_status_changed.emit()


func _on_update_download_progress(fraction: float) -> void:
	update_status_text = Localization.t("update_downloading", [int(fraction * 100)])
	update_status_changed.emit()


func _on_update_download_completed(_local_path: String) -> void:
	update_state = UpdateState.READY_TO_INSTALL
	update_status_text = Localization.t("update_ready_install")
	update_status_changed.emit()


func _on_update_download_failed(_error_code: String) -> void:
	update_state = UpdateState.IDLE
	update_status_text = Localization.t("update_download_failed")
	update_status_changed.emit()
