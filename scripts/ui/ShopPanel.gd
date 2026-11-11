extends ModalPanel
class_name ShopPanel
## The shop: three tabs (fish / equipment / tanks) of cards generated straight from
## ShopManager's catalogs — adding a species or an item file adds its card, no UI work. Every
## card says in plain words why it can't be bought when it can't (locked tier, wrong water,
## tank too small...), instead of a button that silently does nothing.

enum Tab { FISH, EQUIPMENT, TANKS }

## Tier variants reuse their base tier's icon — same category of equipment either way.
const EQUIPMENT_ICON := {
	"basic_heater": "heater", "pro_heater": "heater",
	"basic_filter": "filter", "canister_filter": "filter",
	"basic_light": "light", "led_light": "light",
	"digital_test_kit": "test_kit",
}

var _tab: int = Tab.FISH
var _tab_buttons: Array[Button] = []
var _scroll: ScrollContainer
var _grid: GridContainer
var _cash_label: Label
var _tier_label: Label


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
	var names := [Localization.t("guide_tab_fish"), Localization.t("guide_tab_equipment"), Localization.t("shop_tab_tanks")]
	for i in range(names.size()):
		var tab_button := UiKit.button(names[i], "tab", 60.0)
		tab_button.toggle_mode = true
		tab_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab_button.pressed.connect(open_tab.bind(i))
		tabs.add_child(tab_button)
		_tab_buttons.append(tab_button)

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

	var keep_scroll := _scroll.scroll_vertical
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	match _tab:
		Tab.FISH:
			_fill_fish()
		Tab.EQUIPMENT:
			_fill_equipment()
		Tab.TANKS:
			_fill_tanks()
	UiKit.pass_mouse(_grid)
	_scroll.set_deferred("scroll_vertical", keep_scroll)


func _fill_fish() -> void:
	var tank := game.current_tank()
	var tank_is_marine: bool = tank.tank_type == TankController.TankType.SALTWATER
	var list: Array = ShopManager.species_catalog.values()
	## Fish that suit the tank you're looking at come first, cheapest first.
	list.sort_custom(func(a, b):
		var a_fits: bool = a.is_marine == tank_is_marine
		var b_fits: bool = b.is_marine == tank_is_marine
		if a_fits != b_fits:
			return a_fits
		if a.unlock_tier != b.unlock_tier:
			return a.unlock_tier < b.unlock_tier
		if a.base_price != b.base_price:
			return a.base_price < b.base_price
		return a.id < b.id
	)
	for species in list:
		var facts := Localization.t("shop_fish_facts", [
			Localization.t("guide_stat_marine") if species.is_marine else Localization.t("guide_stat_freshwater"),
			int(species.min_tank_liters), species.sell_price_adult,
		])
		var owned: int = game.count_fish(species.id, false) + game.count_fish(species.id, true)
		var status := Localization.t("shop_owned", [owned]) if owned > 0 else ""
		_add_card(
			"res://assets/fish/%s.png" % species.id, Vector2(120.0, 76.0),
			Localization.t("sp_%s" % species.id), facts, Localization.t("desc_sp_%s" % species.id),
			status, game.fish_block_reason(species), species.base_price,
			game.buy_fish.bind(species.id)
		)


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
		_add_card(
			"res://assets/equipment/%s.png" % icon_id, Vector2(96.0, 96.0),
			Localization.t("eq_%s" % equipment.id), Localization.t("slot_%d" % equipment.slot),
			Localization.t("desc_eq_%s" % equipment.id),
			"", game.equipment_block_reason(equipment), equipment.price,
			game.buy_equipment.bind(equipment.id), installed
		)


func _fill_tanks() -> void:
	var list: Array = ShopManager.tank_preset_catalog.values()
	list.sort_custom(func(a, b): return a.price < b.price)
	for preset in list:
		var is_marine: bool = preset.tank_type == TankController.TankType.SALTWATER
		_add_card(
			TankController.BACKGROUND[preset.tank_type], Vector2(140.0, 80.0),
			Localization.t("tank_%s" % preset.id),
			Localization.t("tank_type_salt") if is_marine else Localization.t("tank_type_fresh"),
			Localization.t("desc_tank_%s" % preset.id),
			"", game.tank_block_reason(preset), preset.price,
			game.buy_tank.bind(preset.id)
		)


## One shop card: [art] [name / facts / description / status-or-reason] [price button].
func _add_card(icon_path: String, icon_size: Vector2, title: String, facts: String, description: String, status: String, block_reason: String, price: int, on_buy: Callable, installed: bool = false) -> void:
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
	row.add_child(buy)
