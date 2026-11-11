extends ModalPanel
class_name ShopPanel
## The shop: four tabs (freshwater fish / saltwater fish / equipment / tanks) of cards generated
## straight from ShopManager's catalogs — adding a species or an item file adds its card, no UI
## work. Every card says in plain words why it can't be bought when it can't (locked level,
## wrong water, tank too small...), instead of a button that silently does nothing. Fish cards
## carry their own ♂/♀ pick (GameController.buy_fish's `sex` argument) since breeding now needs
## one of each — buying blind would make half of every purchase a coin flip the player can't see.

enum Tab { FRESH, SALT, EQUIPMENT, TANKS }

## Tier variants reuse their base tier's icon — same category of equipment either way.
const EQUIPMENT_ICON := {
	"basic_heater": "heater", "pro_heater": "heater",
	"basic_filter": "filter", "canister_filter": "filter",
	"basic_light": "light", "led_light": "light",
	"digital_test_kit": "test_kit",
}

var _tab: int = Tab.FRESH
var _tab_buttons: Array[Button] = []
var _scroll: ScrollContainer
var _grid: GridContainer
var _cash_label: Label
var _tier_label: Label
var _banner: PanelContainer
var _banner_label: Label
var _banner_button: Button
var _banner_action: Callable
## species_id -> FishController.Sex last picked on its card, remembered across a refresh so
## toggling ♂/♀ and then buying doesn't reset what you just chose.
var _sex_choice: Dictionary = {}


func _build() -> void:
	set_title(Localization.t("shop_title"))

	var tier_chip := UiKit.chip(56.0)
	_tier_label = UiKit.label("", UiKit.FONT_SMALL, UiKit.COL_MUTED)
	tier_chip.get_meta("row").add_child(_tier_label)
	header_extra.add_child(tier_chip)
	var cash_chip := UiKit.chip(56.0)
	cash_chip.get_meta("row").add_child(UiKit.icon("coin", 30.0))
	_cash_label = UiKit.label("$0", 26, UiKit.COL_GOLD, true)
	cash_chip.get_meta("row").add_child(_cash_label)
	header_extra.add_child(cash_chip)

	var tabs := UiKit.hbox(8)
	body.add_child(tabs)
	var names := [Localization.t("shop_tab_fresh"), Localization.t("shop_tab_salt"), Localization.t("guide_tab_equipment"), Localization.t("shop_tab_tanks")]
	for i in range(names.size()):
		var tab_button := UiKit.button(names[i], "tab", 60.0, UiKit.FONT_BODY)
		tab_button.toggle_mode = true
		tab_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab_button.clip_text = true
		tab_button.pressed.connect(open_tab.bind(i))
		tabs.add_child(tab_button)
		_tab_buttons.append(tab_button)

	## Shown when the fish on this tab can't live in the tank currently on screen.
	_banner = UiKit.panel(Color(0.3, 0.2, 0.05, 1.0), 16, 16.0, 8.0)
	body.add_child(_banner)
	var banner_row := UiKit.hbox(12)
	_banner.add_child(banner_row)
	_banner_label = UiKit.paragraph("", UiKit.FONT_SMALL, UiKit.COL_GOLD)
	_banner_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	banner_row.add_child(_banner_label)
	_banner_button = UiKit.button("", "gold", 56.0, UiKit.FONT_BODY)
	_banner_button.pressed.connect(func():
		if _banner_action.is_valid():
			_banner_action.call()
	)
	banner_row.add_child(_banner_button)

	_scroll = UiKit.scroll()
	body.add_child(_scroll)
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	_scroll.add_child(_grid)

	game.state_changed.connect(func():
		if visible:
			refresh()
	)


func open_tab(tab: int) -> void:
	var changed: bool = tab != _tab or not visible
	_tab = tab
	visible = true
	refresh()
	if changed:
		_scroll.set_deferred("scroll_vertical", 0)


func refresh() -> void:
	for i in range(_tab_buttons.size()):
		_tab_buttons[i].set_pressed_no_signal(i == _tab)
	_cash_label.text = "$%d" % EconomyManager.cash
	var to_next := Economy.earnings_to_next_tier(EconomyManager.lifetime_earnings)
	if to_next > 0:
		_tier_label.text = Localization.t("shop_tier_progress", [EconomyManager.unlock_tier, to_next])
	else:
		_tier_label.text = Localization.t("shop_tier_max", [EconomyManager.unlock_tier])

	_refresh_banner()
	var keep_scroll := _scroll.scroll_vertical
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	match _tab:
		Tab.FRESH:
			_fill_fish(false)
		Tab.SALT:
			_fill_fish(true)
		Tab.EQUIPMENT:
			_fill_equipment()
		Tab.TANKS:
			_fill_tanks()
	UiKit.pass_mouse(_grid)
	_scroll.set_deferred("scroll_vertical", keep_scroll)


func _refresh_banner() -> void:
	_banner.visible = false
	if _tab != Tab.FRESH and _tab != Tab.SALT:
		return
	var wants_salt: bool = _tab == Tab.SALT
	var tank_is_salt: bool = game.current_tank().tank_type == TankController.TankType.SALTWATER
	if wants_salt == tank_is_salt:
		return
	_banner.visible = true
	var other := game.find_tank_of_type(wants_salt)
	if other == -1:
		_banner_label.text = Localization.t("shop_need_salt_tank")
		_banner_button.text = Localization.t("shop_buy_salt_tank")
		_banner_action = open_tab.bind(Tab.TANKS)
	else:
		_banner_label.text = Localization.t("shop_viewing_fresh" if wants_salt else "shop_viewing_salt")
		_banner_button.text = Localization.t("shop_switch_tank")
		_banner_action = game.select_tank.bind(other)


func _fill_fish(saltwater: bool) -> void:
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
	for species in list:
		_add_fish_card(species)


func _fill_equipment() -> void:
	var list: Array = ShopManager.equipment_catalog.values()
	list.sort_custom(func(a, b):
		if a.unlock_tier != b.unlock_tier:
			return a.unlock_tier < b.unlock_tier
		if a.slot != b.slot:
			return a.slot < b.slot
		return a.price < b.price
	)
	for equipment in list:
		var icon_id: String = EQUIPMENT_ICON.get(equipment.id, equipment.id)
		var installed: bool = game.is_equipment_installed(equipment)
		var shell := _build_card_shell(
			"res://assets/equipment/%s.png" % icon_id, Vector2(96.0, 96.0),
			Localization.t("eq_%s" % equipment.id), Localization.t("slot_%d" % equipment.slot),
			Localization.t("desc_eq_%s" % equipment.id),
			"", game.equipment_block_reason(equipment), installed
		)
		shell["row"].add_child(_buy_button(equipment.price, game.equipment_block_reason(equipment), installed, game.buy_equipment.bind(equipment.id)))


func _fill_tanks() -> void:
	var list: Array = ShopManager.tank_preset_catalog.values()
	list.sort_custom(func(a, b): return a.price < b.price)
	for preset in list:
		var is_marine: bool = preset.tank_type == TankController.TankType.SALTWATER
		var facts := Localization.t("shop_tank_facts", [
			Localization.t("tank_type_salt") if is_marine else Localization.t("tank_type_fresh"), int(preset.tank_liters),
		])
		var shell := _build_card_shell(
			TankController.BACKGROUND[preset.tank_type], Vector2(140.0, 80.0),
			Localization.t("tank_%s" % preset.id), facts,
			Localization.t("desc_tank_%s" % preset.id),
			"", game.tank_block_reason(preset), false
		)
		shell["row"].add_child(_buy_button(preset.price, game.tank_block_reason(preset), false, game.buy_tank.bind(preset.id)))


## Fish get their own card layout: the price area is a ♂/♀ pick plus one buy button instead of
## a single generic buy button, since which one you're buying now actually matters.
func _add_fish_card(species: FishSpeciesData) -> void:
	var block_reason := game.fish_block_reason(species)
	var facts := Localization.t("shop_fish_facts", [int(species.min_tank_liters), species.sell_price_adult])
	if species.fry_per_batch_max > 0:
		facts += " · " + Localization.t("shop_fish_breeds")
	var males: int = 0
	var females: int = 0
	for fish in game.current_tank().get_fish():
		if fish.species == species and not fish.is_fry:
			if fish.sex == FishController.Sex.MALE:
				males += 1
			else:
				females += 1
	var status := Localization.t("shop_owned_sexed", [males, females]) if males + females > 0 else ""
	var shell := _build_card_shell(
		"res://assets/fish/%s.png" % species.id, Vector2(120.0, 84.0),
		Localization.t("sp_%s" % species.id), facts, Localization.t("desc_sp_%s" % species.id),
		status, block_reason, false
	)

	var buy_area := UiKit.vbox(4)
	buy_area.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	shell["row"].add_child(buy_area)

	if block_reason != "":
		buy_area.add_child(_buy_button(species.base_price, block_reason, false, game.buy_fish.bind(species.id)))
		return

	var chosen: int = _sex_choice.get(species.id, FishController.Sex.MALE)
	var toggle := UiKit.hbox(4)
	toggle.alignment = BoxContainer.ALIGNMENT_CENTER
	buy_area.add_child(toggle)
	var male_button := UiKit.action_button("", UiKit.icon("male", 24.0), "primary" if chosen == FishController.Sex.MALE else "tab", false, Vector2(56.0, 44.0))
	var female_button := UiKit.action_button("", UiKit.icon("female", 24.0), "primary" if chosen == FishController.Sex.FEMALE else "tab", false, Vector2(56.0, 44.0))
	male_button.pressed.connect(func():
		_sex_choice[species.id] = FishController.Sex.MALE
		UiKit.style_button(male_button, "primary")
		UiKit.style_button(female_button, "tab")
	)
	female_button.pressed.connect(func():
		_sex_choice[species.id] = FishController.Sex.FEMALE
		UiKit.style_button(female_button, "primary")
		UiKit.style_button(male_button, "tab")
	)
	toggle.add_child(male_button)
	toggle.add_child(female_button)

	var affordable: bool = EconomyManager.can_afford(species.base_price)
	var buy := UiKit.action_button("$%d" % species.base_price, UiKit.label(Localization.t("shop_buy"), UiKit.FONT_SMALL, UiKit.COL_TEXT, true), "primary" if affordable else "secondary", true, Vector2(132.0, 56.0), 24)
	## Reads the CURRENT choice at buy time (a Callable can't see `chosen` update later), not
	## the value captured when the button was built.
	UiKit.on_tap(buy, _scroll, func(): game.buy_fish(species.id, _sex_choice.get(species.id, FishController.Sex.MALE)))
	buy_area.add_child(buy)


## Shared left side of every card: [art] [name / facts / description / status-or-reason]. The
## caller appends whatever buy control(s) belong on the right into the returned "row".
func _build_card_shell(icon_path: String, icon_size: Vector2, title: String, facts: String, description: String, status: String, block_reason: String, installed: bool) -> Dictionary:
	var blocked: bool = block_reason != ""
	var card := UiKit.panel(UiKit.COL_CARD_DIM if blocked and not installed else UiKit.COL_CARD, 18, 12.0, 10.0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0.0, 150.0)
	_grid.add_child(card)
	var row := UiKit.hbox(12)
	card.add_child(row)

	var art := UiKit.texture_icon(icon_path, icon_size)
	art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if blocked and not installed:
		art.modulate = Color(1, 1, 1, 0.55)
	row.add_child(art)

	var text := UiKit.vbox(2)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(text)
	var title_label := UiKit.label(title, UiKit.FONT_HEADING, UiKit.COL_TEXT, true)
	title_label.clip_text = true
	text.add_child(title_label)
	if facts != "":
		var facts_label := UiKit.label(facts, UiKit.FONT_SMALL, UiKit.COL_ACCENT)
		facts_label.clip_text = true
		text.add_child(facts_label)
	text.add_child(UiKit.paragraph(description, UiKit.FONT_SMALL, UiKit.COL_MUTED, 2))
	if installed:
		text.add_child(UiKit.label(block_reason, UiKit.FONT_SMALL, UiKit.COL_GOOD, true))
	elif blocked:
		text.add_child(UiKit.paragraph(block_reason, UiKit.FONT_SMALL, UiKit.COL_WARN, 2))
	elif status != "":
		text.add_child(UiKit.label(status, UiKit.FONT_SMALL, UiKit.COL_GOOD))

	return {"card": card, "row": row}


## The single generic buy button used by equipment and tanks (fish build their own ♂/♀ area).
func _buy_button(price: int, block_reason: String, installed: bool, on_buy: Callable) -> Button:
	var blocked: bool = block_reason != ""
	var buy: Button
	if installed:
		buy = UiKit.action_button("", UiKit.icon("check", 36.0, UiKit.COL_GOOD), "tab", false, Vector2(132.0, 84.0))
		buy.disabled = true
	elif blocked:
		buy = UiKit.action_button("$%d" % price, UiKit.icon("lock", 28.0, Color(0.7, 0.75, 0.82)), "tab", true, Vector2(132.0, 84.0), UiKit.FONT_BODY)
		## Still tappable: tapping a locked card explains (as a toast) what's missing.
		UiKit.on_tap(buy, _scroll, on_buy)
	else:
		var affordable: bool = EconomyManager.can_afford(price)
		buy = UiKit.action_button("$%d" % price, UiKit.label(Localization.t("shop_buy"), UiKit.FONT_BODY, UiKit.COL_TEXT, true), "primary" if affordable else "secondary", true, Vector2(132.0, 84.0), 28)
		UiKit.on_tap(buy, _scroll, on_buy)
	buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return buy
