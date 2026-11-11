extends Node
class_name GameController
## The game's glue: owns the two tank slots, performs every player action (buy / sell / feed /
## water change / treat), and builds the phone UI in code (scripts/ui/*) on top of them. The UI
## never touches the simulation directly — it calls the methods here and re-reads state when
## `state_changed` fires.
##
## Multi-tank: four tank slots exist as scene nodes from the start (see Main.tscn). Tank 1 is
## always owned; the others start `locked` and each is configured from a TankPresetData when the
## player buys a tank (the purchase fills the first free slot). Only the selected tank is shown.
##
## Localization: every player-facing string is built via Localization.t(). Switching language
## simply rebuilds the whole UI tree (_rebuild_ui), so no screen needs its own re-label code.

signal state_changed
signal update_status_changed

const FEED_COST := 1
const ALERT_REPEAT_SECONDS := 40.0
const BAILOUT_CASH := 20

@onready var _tanks: Array[TankController] = [%TankInstance, %Tank2Instance, %Tank3Instance, %Tank4Instance, %Tank5Instance, %Tank6Instance, %Tank7Instance, %Tank8Instance]
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
var fish_detail: FishDetailPanel
var new_game: NewGamePanel
var business: BusinessPanel
var stats: StatsPanel
var advisor: AdvisorPanel
var toast_view: ToastView

## Where the in-app update flow currently is — see UpdateChecker (autoload) for the actual
## check/download/install logic. Lives here (not in SettingsPanel) so it survives a UI rebuild.
enum UpdateState { IDLE, CHECKING, AVAILABLE, DOWNLOADING, READY_TO_INSTALL }
var update_state: UpdateState = UpdateState.IDLE
var update_status_text: String = ""

var _show_welcome_on_start: bool = false
## True until the player has picked a mode and difficulty for this (new) game.
var _needs_setup: bool = false
var tool: int = TankController.Tool.HAND
var _pinch_count: int = 0
var _alert_last_shown: Dictionary = {}  ## message key -> Time.get_ticks_msec() of last toast


func current_tank() -> TankController:
	return _tanks[_current_tank_index]


func tanks() -> Array[TankController]:
	return _tanks


func current_tank_index() -> int:
	return _current_tank_index


func _ready() -> void:
	var had_save := SaveManager.has_save() and SaveManager.load_game()
	_show_welcome_on_start = not had_save
	_needs_setup = not had_save
	EconomyManager.apply_mode()

	for tank in _tanks:
		tank.game = self
		tank.water_quality_alert.connect(_on_water_quality_alert)
		tank.fish_born.connect(_on_fish_born)
		tank.fish_died.connect(_on_fish_died)
		tank.tool_cleaned.connect(_on_tool_cleaned)
		tank.refresh_equipment_visuals()
	EconomyManager.cash_changed.connect(func(_c): state_changed.emit())
	state_changed.connect(func(): _check_bailout.call_deferred())
	EconomyManager.unlock_tier_changed.connect(_on_unlock_tier_changed)
	state_changed.connect(func(): Progress.check.call_deferred())
	Progress.mission_completed.connect(_on_mission_completed)
	Progress.stage_changed.connect(_on_stage_changed)
	Progress.collection_reward.connect(_on_collection_reward)
	Progress.visitors_paid.connect(func(visitors, income): toast(Localization.t("toast_visitors", [visitors, income]), "good"))
	Market.order_completed.connect(_on_order_completed)
	Market.order_expired.connect(_on_order_expired)
	Market.rare_arrived.connect(_on_rare_arrived)
	Market.rare_left.connect(func(_id): state_changed.emit())
	Market.auction_resolved.connect(_on_auction_resolved)
	Market.contest_started.connect(_on_contest_started)
	Market.orders_changed.connect(func(): state_changed.emit())
	Localization.language_changed.connect(func(_l): _rebuild_ui.call_deferred())

	UpdateChecker.check_completed.connect(_on_update_check_completed)
	UpdateChecker.download_progress.connect(_on_update_download_progress)
	UpdateChecker.download_completed.connect(_on_update_download_completed)
	UpdateChecker.download_failed.connect(_on_update_download_failed)

	## From here on the game state is real (loaded, or deliberately new), so saving is safe.
	SaveManager.saving_enabled = true
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
	fish_detail = FishDetailPanel.new()
	new_game = NewGamePanel.new()
	business = BusinessPanel.new()
	stats = StatsPanel.new()
	advisor = AdvisorPanel.new()
	for panel in _all_panels():
		panel.game = self
		ui_root.add_child(panel)

	## Last child = drawn over everything, panels included.
	toast_view = ToastView.new()
	ui_root.add_child(toast_view)


func _all_panels() -> Array:
	return [shop, fish_panel, tank_panel, guide, settings, welcome, fish_detail, new_game, business, stats, advisor]


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
	ErrorLog.crumb("go_home")
	SaveManager.save_game()
	show_home()


func start_game() -> void:
	ErrorLog.crumb("start_game")
	if _needs_setup:
		new_game.open()
		return
	home.visible = false
	TimeManager.paused = false
	AudioManager.play("splash")
	if _show_welcome_on_start:
		_show_welcome_on_start = false
		welcome.open()
	state_changed.emit()


func close_panels() -> void:
	for panel in _all_panels():
		if panel != null and panel.visible:
			panel.close()


## Tapping a fish directly in the tank (TankController._unhandled_input) opens this card —
## does NOT pause or leave the tank, so the player can keep tapping around while it's up.
func open_fish_detail(fish: FishController) -> void:
	ErrorLog.crumb("open_fish_detail")
	for panel in _all_panels():
		if panel != fish_detail and panel != null and panel.visible:
			panel.close()
	fish_detail.inspect(fish)
	fish_detail.open()


## Sells exactly this fish (the detail card's sell button) rather than "the least healthy one
## of this species" (sell_one_of) — the player can now tell them apart, so let them choose.
func sell_specific_fish(fish: FishController) -> int:
	ErrorLog.crumb("sell_specific_fish")
	var value := current_tank().sell_fish(fish)
	AudioManager.play("cash")
	toast(Localization.t("toast_sold", [fish.fish_name, value]), "good")
	state_changed.emit()
	return value


## The new-game screen's Start button: fixes the mode and difficulty, sets the starting cash and
## carries on into the game.
func begin_new_game(mode: int, difficulty: int) -> void:
	ErrorLog.crumb("begin_new_game")
	GameState.mode = mode
	GameState.difficulty = difficulty
	EconomyManager.cash = GameState.start_cash()
	EconomyManager.lifetime_earnings = 0
	EconomyManager.unlock_tier = 0
	EconomyManager.apply_mode()
	EconomyManager.cash_changed.emit(EconomyManager.cash)
	_needs_setup = false
	new_game.close()
	start_game()


## tab < 0 = the fish tab that matches the tank on screen.
func open_shop(tab: int = -1) -> void:
	ErrorLog.crumb("open_shop" + " " + str(tab))
	close_panels()
	if tab < 0:
		tab = ShopPanel.Tab.SALT if current_tank().tank_type == TankController.TankType.SALTWATER else ShopPanel.Tab.FRESH
	shop.open_tab(tab)


func open_fish_panel() -> void:
	ErrorLog.crumb("open_fish_panel")
	close_panels()
	fish_panel.open()


func open_tank_panel() -> void:
	ErrorLog.crumb("open_tank_panel")
	close_panels()
	tank_panel.open()


func open_guide() -> void:
	ErrorLog.crumb("open_guide")
	close_panels()
	guide.open()


func open_business(tab: int = 0) -> void:
	ErrorLog.crumb("open_business" + " " + str(tab))
	close_panels()
	business.open_tab(tab)


func open_stats() -> void:
	ErrorLog.crumb("open_stats")
	close_panels()
	stats.open()


func open_advisor() -> void:
	ErrorLog.crumb("open_advisor")
	close_panels()
	advisor.open()


func open_settings() -> void:
	ErrorLog.crumb("open_settings")
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
	ErrorLog.crumb("select_tank" + " " + str(index))
	if index < 0 or index >= _tanks.size() or _tanks[index].locked:
		return
	_select_tank(index)


func _select_tank(index: int) -> void:
	_current_tank_index = index
	for i in range(_tanks.size()):
		_tanks[i].visible = (i == index)
	state_changed.emit()


## HUD tank button: on to the next owned tank, or straight to the tank shop if there's only one.
func cycle_tank() -> void:
	ErrorLog.crumb("cycle_tank")
	for step in range(1, _tanks.size()):
		var index := (_current_tank_index + step) % _tanks.size()
		if not _tanks[index].locked:
			_select_tank(index)
			return
	open_shop(ShopPanel.Tab.TANKS)


func owned_tank_count() -> int:
	var count := 0
	for tank in _tanks:
		if not tank.locked:
			count += 1
	return count


func _first_free_slot() -> int:
	for i in range(_tanks.size()):
		if _tanks[i].locked:
			return i
	return -1


## Index of an owned tank holding the given kind of water, or -1. Prefers the current tank.
func find_tank_of_type(saltwater: bool) -> int:
	var wanted := TankController.TankType.SALTWATER if saltwater else TankController.TankType.FRESHWATER
	if current_tank().tank_type == wanted:
		return _current_tank_index
	for i in range(_tanks.size()):
		if not _tanks[i].locked and _tanks[i].tank_type == wanted:
			return i
	return -1


func tank_display_name(index: int) -> String:
	var tank := _tanks[index]
	var type_key := "tank_type_salt" if tank.tank_type == TankController.TankType.SALTWATER else "tank_type_fresh"
	return Localization.t("tank_name", [index + 1, Localization.t(type_key), int(tank.tank_liters)])


func tank_block_reason(preset: TankPresetData) -> String:
	if _first_free_slot() == -1:
		return Localization.t("alert_no_tank_slots")
	if preset.unlock_tier > EconomyManager.unlock_tier:
		return _tier_lock_text(preset.unlock_tier)
	return ""


func _on_buy_tank(preset_id: String) -> void:
	buy_tank(preset_id)


func buy_tank(preset_id: String) -> bool:
	ErrorLog.crumb("buy_tank" + " " + str(preset_id))
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
	var slot := _first_free_slot()
	_tanks[slot].unlock(preset.tank_liters, preset.tank_type, preset.ambient_temp_base_c)
	AudioManager.play("coin")
	_select_tank(slot)
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
	ErrorLog.crumb("buy_equipment" + " " + str(equipment_id))
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
	if not Market.in_stock(species):
		return Localization.t("shop_out_of_stock")
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


## `sex`: FishController.Sex.MALE/FEMALE to buy a specific one (the shop's ♂/♀ toggle), or -1
## for a random one (dev tools, and anything not written against the sex system).
func buy_fish(species_id: String, sex: int = -1) -> bool:
	ErrorLog.crumb("buy_fish" + " " + str(species_id))
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
	var fish := current_tank().add_fish(species, false, sex)
	Progress.bump("fish_bought")
	AudioManager.play("coin")
	toast(Localization.t("toast_bought_named", [fish.fish_name, Localization.t("sp_%s" % species_id)]), "good")
	state_changed.emit()
	return true


# ----------------------------------------------------------------------------------------
# Selling
# ----------------------------------------------------------------------------------------

func sell_one_of(species_id: String, fry: bool) -> bool:
	ErrorLog.crumb("sell_one_of" + " " + str(species_id))
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
	ErrorLog.crumb("sell_all_fry")
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
	ErrorLog.crumb("feed")
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
	Progress.bump("feeds")
	AudioManager.play("feed")
	state_changed.emit()
	return true


func _on_water_change() -> void:
	water_change()


func water_change() -> void:
	ErrorLog.crumb("water_change")
	current_tank().perform_water_change(0.25)
	Progress.bump("water_changes")
	AudioManager.play("splash")
	toast(Localization.t("toast_water_changed"), "good")
	state_changed.emit()


func medication_price() -> int:
	var medication := ShopManager.get_medication("general_illness_treatment")
	return medication.price if medication != null else 0


func _on_treat_disease() -> void:
	treat_disease()


func treat_disease() -> bool:
	ErrorLog.crumb("treat_disease")
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
	ErrorLog.crumb("reset_game")
	SaveManager.delete_save()
	GameState.mode = GameState.Mode.CAREER
	GameState.difficulty = GameState.Difficulty.NORMAL
	Progress.reset()
	Market.reset()
	History.reset()
	TimeManager.reset_speed()
	set_tool(TankController.Tool.HAND)
	_needs_setup = true
	EconomyManager.from_save_dict({})
	EconomyManager.apply_mode()
	EconomyManager.cash_changed.emit(EconomyManager.cash)
	TimeManager.sim_minutes_total = 0.0
	TimeManager.current_season = TimeManager.Season.SPRING
	_tanks[0].reset_to_new(false, 40.0, TankController.TankType.FRESHWATER, 22.0)
	for i in range(1, _tanks.size()):
		_tanks[i].reset_to_new(true, 40.0, TankController.TankType.FRESHWATER, 22.0)
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
	var to_shop_fish := open_shop.bind(-1)

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
	if tank.algae_level() >= 55.0:
		return {"text": Localization.t("tip_algae"), "action": set_tool.bind(TankController.Tool.SCRAPER), "kind": "warn"}
	if tank.mulm_level() >= 55.0:
		return {"text": Localization.t("tip_mulm"), "action": set_tool.bind(TankController.Tool.VACUUM), "kind": "warn"}
	if tank.stocking_fraction() > 0.9:
		return {"text": Localization.t("tip_crowded"), "action": open_fish_panel, "kind": "warn"}

	## species -> {"male": count, "female": count} of non-fry adults, for the breeding-pair tip.
	var adults_by_species: Dictionary = {}
	for fish in fish_list:
		if fish.is_fry:
			continue
		if not adults_by_species.has(fish.species):
			adults_by_species[fish.species] = {"male": 0, "female": 0}
		var key := "male" if fish.sex == FishController.Sex.MALE else "female"
		adults_by_species[fish.species][key] += 1
	for species in adults_by_species.keys():
		var counts: Dictionary = adults_by_species[species]
		if species.fry_per_batch_max > 0 and (counts["male"] == 0) != (counts["female"] == 0):
			## Exactly one sex present (the other is zero) — breeding is blocked on the missing one.
			return {"text": Localization.t("tip_need_pair", [Localization.t("sp_%s" % species.id)]), "action": to_shop_fish, "kind": "info"}
	for species in adults_by_species.keys():
		if species.schooling_min_group > 1 and _count_species(fish_list, species) < species.schooling_min_group:
			return {"text": Localization.t("tip_need_school", [Localization.t("sp_%s" % species.id), species.schooling_min_group]), "action": to_shop_fish, "kind": "info"}

	var fry := tank.fry_count()
	if fry > 0:
		return {"text": Localization.t("tip_fry", [fry]), "action": open_fish_panel, "kind": "info"}
	if tank.light_equipment == null:
		return {"text": Localization.t("tip_buy_light"), "action": to_shop_equipment, "kind": "info"}
	if Market.orders_ready_count() > 0:
		return {"text": Localization.t("tip_order_ready"), "action": open_business.bind(BusinessPanel.Tab.ORDERS), "kind": "info"}
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
# Hand tools: dropping food by tapping, scraping the glass, vacuuming the sand
# ----------------------------------------------------------------------------------------

func set_tool(new_tool: int) -> void:
	ErrorLog.crumb("set_tool" + " " + str(new_tool))
	tool = new_tool
	for tank in _tanks:
		tank.tool = new_tool
	state_changed.emit()


## One tap of the food tool. Every fourth pinch costs the usual $1 for a feeding.
func pinch_feed(tank: TankController, point: Vector2) -> void:
	if tank.get_fish().is_empty():
		toast(Localization.t("alert_no_fish_to_feed"), "bad")
		return
	_pinch_count += 1
	if _pinch_count % 4 == 1:
		if not EconomyManager.spend(FEED_COST, "Bought food"):
			toast(Localization.t("alert_not_enough_cash_for_food"), "bad")
			return
	tank.pinch(ShopManager.get_food("basic_flakes"), point)
	AudioManager.play("feed")
	state_changed.emit()


func _on_tool_cleaned(tool_kind: int, blobs: int) -> void:
	Progress.bump("scraped" if tool_kind == TankController.Tool.SCRAPER else "vacuumed", blobs)
	AudioManager.play("scrub")
	state_changed.emit()


# ----------------------------------------------------------------------------------------
# Career, collection and market events -> toasts
# ----------------------------------------------------------------------------------------

func _on_mission_completed(mission_id: String, reward: int) -> void:
	toast(Localization.t("toast_mission", [Localization.t("ms_%s" % mission_id), reward]), "good")
	AudioManager.play("fanfare")


func _on_stage_changed(new_stage: int) -> void:
	if new_stage > Goals.STAGE_COUNT:
		toast(Localization.t("toast_career_done"), "good")
	else:
		toast(Localization.t("toast_stage_up", [Localization.t("stage_%d" % new_stage)]), "good")
	AudioManager.play("fanfare")
	state_changed.emit()


func _on_collection_reward(kind: String, species_id: String, amount: int) -> void:
	match kind:
		"bred":
			toast(Localization.t("toast_collect_bred", [Localization.t("sp_%s" % species_id), amount]), "good")
		"morph":
			toast(Localization.t("toast_collect_morph", [Localization.t("sp_%s" % species_id), amount]), "good")
		_:
			toast(Localization.t("toast_collect_milestone", [amount]), "good")
	AudioManager.play("coin")


func _on_order_completed(order: Dictionary, reward: int) -> void:
	toast(Localization.t("toast_order_done", [Localization.t("sp_%s" % order["species_id"]), reward]), "good")
	AudioManager.play("fanfare")
	state_changed.emit()


func _on_order_expired(order: Dictionary) -> void:
	toast(Localization.t("toast_order_expired", [Localization.t("sp_%s" % order["species_id"])]), "info")
	state_changed.emit()


func _on_rare_arrived(species_ids: Array) -> void:
	var names: Array = []
	for id in species_ids:
		names.append(Localization.t("sp_%s" % id))
	toast(Localization.t("toast_rare_arrived", [", ".join(names)]), "info")
	state_changed.emit()


func _on_auction_resolved(fish_name: String, _species_id: String, amount: int) -> void:
	toast(Localization.t("toast_auction_done", [fish_name, amount]), "good")
	AudioManager.play("cash")
	state_changed.emit()


func _on_contest_started() -> void:
	toast(Localization.t("toast_contest_started"), "info")
	state_changed.emit()


# ----------------------------------------------------------------------------------------
# The advisor: why is the coach line saying that?
# ----------------------------------------------------------------------------------------

## {"title": coach line, "lines": causes + what to do, "metric": History field to graph or "",
## "fish": the fish involved}. Mirrors the order of current_tip().
func advice() -> Dictionary:
	var tank := current_tank()
	var lines: Array = []
	var metric := ""
	var fish_list: Array = []
	var cold := false
	for fish in tank.get_fish():
		if tank.temperature < fish.species.temp_min_c:
			cold = true
	if tank.filter == null:
		lines.append(Localization.t("advice_no_filter"))
	elif tank.ammonia > WaterChemistry.AMMONIA_DANGER or tank.nitrite > WaterChemistry.NITRITE_DANGER or tank.nitrate > WaterChemistry.NITRATE_DANGER:
		metric = "ammonia" if tank.ammonia > WaterChemistry.AMMONIA_DANGER else ("nitrite" if tank.nitrite > WaterChemistry.NITRITE_DANGER else "nitrate")
		lines.append(Localization.t("advice_water_high"))
		var causes := 0
		if tank.stocking_fraction() >= 0.7:
			lines.append(Localization.t("advice_cause_stock", [int(round(tank.stocking_fraction() * 100.0))]))
			causes += 1
		if tank.filter_maturity < 70.0:
			lines.append(Localization.t("advice_cause_filter", [int(tank.filter_maturity)]))
			causes += 1
		if tank.days_since_water_change >= 5.0:
			lines.append(Localization.t("advice_cause_change", [int(tank.days_since_water_change)]))
			causes += 1
		if tank.mulm_level() >= 30.0:
			lines.append(Localization.t("advice_cause_mulm", [int(tank.mulm_level())]))
			causes += 1
		if causes == 0:
			lines.append(Localization.t("advice_cause_food"))
		lines.append(Localization.t("advice_fix_water"))
	elif tank.hungry_fish_count() > 0:
		for fish in tank.get_fish():
			if fish.hunger < 35.0:
				fish_list.append(fish)
		lines.append(Localization.t("advice_hungry", [fish_list.size()]))
		lines.append(Localization.t("advice_fix_feed"))
	elif tank.sick_fish_count() > 0:
		for fish in tank.get_fish():
			if fish.is_sick:
				fish_list.append(fish)
		lines.append(Localization.t("advice_sick", [fish_list.size()]))
		lines.append(Localization.t("advice_cause_change", [int(tank.days_since_water_change)]))
		lines.append(Localization.t("advice_fix_treat"))
	elif cold:
		metric = "temp"
		lines.append(Localization.t("advice_cold", [tank.temperature]))
		lines.append(Localization.t("advice_fix_heater"))
	elif tank.algae_level() >= 55.0:
		metric = "algae"
		lines.append(Localization.t("advice_algae", [int(tank.algae_level())]))
		lines.append(Localization.t("advice_fix_algae"))
	elif tank.mulm_level() >= 55.0:
		metric = "mulm"
		lines.append(Localization.t("advice_mulm", [int(tank.mulm_level())]))
		lines.append(Localization.t("advice_fix_mulm"))
	else:
		metric = "nitrate"
		lines.append(Localization.t("advice_ok"))
	return {"title": current_tip()["text"], "lines": lines, "metric": metric, "fish": fish_list}


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


func _on_fish_died(species: FishSpeciesData, fish_name: String, reason: String) -> void:
	var key := "toast_died_old_age" if reason == "old_age" else "toast_died"
	toast(Localization.t(key, [fish_name, Localization.t("sp_%s" % species.id)]), "info" if reason == "old_age" else "bad")
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
