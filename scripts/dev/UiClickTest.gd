extends Node
## Dev-only end-to-end input test: plays the opening minutes of the game purely by injecting
## pointer presses at the on-screen position of real buttons (the same mouse events Android
## synthesizes from touches), then checks the game state changed. Calling GameController
## methods directly — as the smoke test does — can't catch a button that is drawn but never
## receives input (an invisible control on top of it, a wrong mouse filter...). This can.
## Run windowed with a phone-shaped --resolution. Not part of the shipped game.

var _main: GameController
var _failures: int = 0


func _ready() -> void:
	_main = load("res://scenes/main/Main.tscn").instantiate()
	add_child(_main)
	await _frames(20)
	var tank := _main.current_tank()
	## Mission / collection rewards would move the cash these checks count; switch them off.
	Progress.loading = true

	await _tap_text("שחק")
	_check("Play on a new game opens the setup screen", _main.new_game.visible)
	await _tap_text("התחל")
	_check("Start hides the home screen", not _main.home.visible and not _main.new_game.visible)
	_check("Welcome panel opened on a new game", _main.welcome.visible)
	## The starter tank is 15 L and fish unlock by level; give the test a roomier tank and level.
	EconomyManager.add_xp(Levels.xp_for_level(10))
	EconomyManager.cash = 60
	tank.tank_liters = 60.0
	tank._rebuild_view()

	await _tap_text("יאללה, לחנות")
	_check("Welcome button opens the shop", _main.shop.visible and not _main.welcome.visible)

	await _tap_text("$12")
	_check("Tapping the filter card installs a filter", tank.filter != null and tank.filter.id == "basic_filter")
	_check("...and takes the money", EconomyManager.cash == 48)

	await _tap_text("דגי מים מתוקים")
	await _tap_card_buy("גופי")
	await _tap_card_buy("גופי")
	_check("Tapping the guppy card twice adds two guppies", _main.count_fish("guppy", false) == 2)
	_check("...and takes the money", EconomyManager.cash == 38)

	await _tap_card_buy("בטא (דג קרב)")
	_check("Tapping the betta card ($12, affordable) adds a betta", _main.count_fish("betta", false) == 1)

	await _tap_card_sex_toggle("פלאטי", true)
	await _tap_card_buy("פלאטי")
	var bought_female := false
	for fish in tank.get_fish():
		if fish.species.id == "platy":
			bought_female = fish.sex == FishController.Sex.FEMALE
	_check("Picking ♀ on a card and buying gets a female", bought_female)

	await _tap_text("דגי מים מלוחים")
	_check("Saltwater tab shows the switch-tank banner (freshwater tank on screen)", _main.shop._banner.visible)
	await _tap_icon(_main.shop, "close")
	_check("Close button closes the shop", not _main.shop.visible)

	var a_guppy: FishController = null
	for fish in tank.get_fish():
		if fish.species.id == "guppy":
			a_guppy = fish
			break
	if a_guppy != null:
		var guppy_name := a_guppy.fish_name
		## Park it in open water so a HUD button or the edge of the tank can't be under the tap.
		a_guppy.position = tank.get_swim_rect().get_center()
		await _frames(2)
		var guppy_screen := tank.to_global(a_guppy.position)
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = guppy_screen
		event.global_position = guppy_screen
		event.pressed = true
		get_viewport().push_input(event, true)
		await _frames(6)
		event.pressed = false
		get_viewport().push_input(event, true)
		await _frames(6)
		_check("Tapping a fish in the tank opens its identity card", _main.fish_detail.visible and _main.fish_detail.title_text == guppy_name)
		_check("The card shows the species name", Localization.t("sp_guppy") in _get_all_text(_main.fish_detail))
		await _tap_icon(_main.fish_detail, "close")
		_check("Closing the identity card returns to the tank", not _main.fish_detail.visible)

	for fish in tank.get_fish():
		fish.hunger = 10.0
	await _frames(20)
	var cash_before := EconomyManager.cash
	await _tap_text("האכל · $1")
	_check("Bottom-bar Feed feeds the fish", tank.get_fish()[0].hunger > 40.0 and EconomyManager.cash == cash_before - 1)

	tank.ammonia = 2.0
	await _tap_text("החלפת מים")
	_check("Bottom-bar water change works", tank.ammonia < 1.6)

	await _tap_text("הדגים שלי")
	_check("Bottom-bar My Fish opens the panel", _main.fish_panel.visible)
	cash_before = EconomyManager.cash
	await _tap_card_buy("בטא (דג קרב)")
	_check("Sell button sells the betta", _main.count_fish("betta", false) == 0 and EconomyManager.cash == cash_before + 10)
	await _tap_icon(_main.fish_panel, "close")

	await _tap_text("מצב האקווריום")
	_check("Bottom-bar Tank Status opens the panel", _main.tank_panel.visible)
	await _tap_icon(_main.tank_panel, "close")

	await _tap_text("אנציקלופדיה")
	_check("Bottom-bar Guide opens the guide", _main.guide.visible)
	await _tap_text("ציוד")
	_check("Guide tab switches", _main.guide._tab == GuidePanel.Tab.EQUIPMENT and _main.guide._list.get_child_count() >= 10)

	await _tap_text("דגי מים מתוקים")
	await _tap_card_buy("גופי")
	_check("Tapping a fish tile in the album opens its species page", _main.guide._detail_species != null and _main.guide._detail_species.id == "guppy")
	_check("Species page shows its real-world origin text", Localization.t("origin_sp_guppy") in _get_all_text(_main.guide))
	await _tap_text("חזרה לרשימה")
	_check("Back button returns to the album", _main.guide._detail_species == null and _main.guide._list.visible)
	await _tap_icon(_main.guide, "close")

	await _tap_text("חנות")
	_check("Bottom-bar Shop opens the shop", _main.shop.visible)
	await _tap_icon(_main.shop, "close")
	_check("Shop closes again", not _main.shop.visible)

	## Force "feed" to be the top coach-line tip (it's outranked by a sick fish or dirty water,
	## either of which a long enough test run can randomly roll along the way).
	tank.ammonia = 0.0
	tank.nitrite = 0.0
	tank.nitrate = 0.0
	tank.medication_remaining_days = 0.0
	for fish in tank.get_fish():
		fish.hunger = 10.0
		fish.is_sick = false
	await _frames(30)
	_main.hud.refresh()
	await _tap_node(_main.hud._tip_button)
	_check("Tapping the coach line performs its action (feed)", tank.get_fish()[0].hunger > 40.0)

	## --- new in 1.6: speed button, business panel, tools
	await _tap_text("x1")
	_check("The speed button switches to 2x", TimeManager.speed_index == 1)
	await _tap_text("x2")
	await _tap_text("x4")
	_check("...then pauses", TimeManager.player_paused)
	await _tap_text("||")
	_check("...and resumes at 1x", not TimeManager.player_paused and TimeManager.speed_index == 0)

	await _tap_icon(_main.hud, "clipboard")
	_check("The business button opens the business panel", _main.business.visible)
	await _tap_text("הזמנות")
	_check("The Orders tab opens", _main.business._tab == BusinessPanel.Tab.ORDERS)
	await _tap_text("אוסף")
	_check("The Collection tab opens", _main.business._tab == BusinessPanel.Tab.COLLECTION)
	await _tap_icon(_main.business, "close")
	_check("Closing the business panel returns to the tank", not _main.business.visible)

	await _tap_icon(_main.hud, "scraper")
	_check("Tapping the scraper selects it", _main.tool == TankController.Tool.SCRAPER and tank.tool == TankController.Tool.SCRAPER)
	tank._algae.set_level(60.0)
	var algae_before: float = tank.algae_level()
	var blob_point := Vector2.ZERO
	for blob in tank._algae._blobs:
		if float(blob["cover"]) > 0.3:
			blob_point = tank.to_global(tank._algae.rect.position + Vector2(blob["pos"].x * tank._algae.rect.size.x, blob["pos"].y * tank._algae.rect.size.y))
			break
	if blob_point != Vector2.ZERO:
		var drag := InputEventMouseButton.new()
		drag.button_index = MOUSE_BUTTON_LEFT
		drag.position = blob_point
		drag.global_position = blob_point
		drag.pressed = true
		get_viewport().push_input(drag, true)
		await _frames(4)
		drag.pressed = false
		get_viewport().push_input(drag, true)
		await _frames(4)
	_check("Swiping with the scraper wipes algae off", tank.algae_level() < algae_before)
	await _tap_icon(_main.hud, "hand")
	_check("The hand tool puts it away", _main.tool == TankController.Tool.HAND)

	await _tap_icon(_main.hud, "question")
	_check("The ? next to the coach line opens the advisor", _main.advisor.visible)
	await _tap_icon(_main.advisor, "close")

	await _tap_icon(_main.hud, "gear")
	_check("Top-bar gear opens settings", _main.settings.visible)
	await _tap_text("English")
	await _frames(10)
	_check("Language button switches to English and keeps settings open", Localization.current_language == "en" and _main.settings.visible)
	await _tap_text("עברית")
	await _frames(10)
	await _tap_text("לתפריט הראשי")
	_check("Main-menu button returns to the home screen", _main.home.visible)
	await _tap_text("המשך משחק")
	_check("Continue returns to the game", not _main.home.visible and not _main.welcome.visible)

	print("=== UI click test finished: %s ===" % ("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures))
	get_tree().quit()


func _visible_panels() -> Array:
	var names: Array = []
	for panel in _main._all_panels():
		if panel != null and panel.visible:
			names.append(panel.get_class() + ":" + str(panel.get_script().get_global_name()))
	if _main.home.visible:
		names.append("home")
	return names


func _check(what: String, ok: bool) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", what])


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().process_frame


func _find_all_buttons(node: Node) -> Array:
	var out: Array = []
	if node is Button:
		out.append(node)
	for child in node.get_children():
		out.append_array(_find_all_buttons(child))
	return out


func _button_text(button: Button) -> String:
	if button.has_meta("label"):
		return (button.get_meta("label") as Label).text
	return button.text


## First visible, enabled button whose caption equals `text` — searching the topmost screens
## first, exactly as a finger would hit whatever is drawn on top.
func _find_button(node: Node, text: String) -> Button:
	var children := node.get_children()
	children.reverse()
	for child in children:
		if child is Control and not child.visible:
			continue
		var found := _find_button(child, text)
		if found != null:
			return found
	if node is Button and not node.disabled and node.is_visible_in_tree() and _button_text(node) == text:
		return node
	return null


func _find_icon_button(node: Node, kind: String) -> Button:
	for child in node.get_children():
		if child is Control and not child.visible:
			continue
		if child is UiIcon and child.kind == kind:
			var parent: Node = child
			while parent != null and not (parent is Button):
				parent = parent.get_parent()
			if parent != null:
				return parent
		var found := _find_icon_button(child, kind)
		if found != null:
			return found
	return null


func _find_label(node: Node, text: String) -> Label:
	if node is Label and node.text == text and node.is_visible_in_tree():
		return node
	for child in node.get_children():
		var found := _find_label(child, text)
		if found != null:
			return found
	return null


## Finds a card by its title label (the species/item name), then taps its button — a
## descendant button (price/buy/sell, as in the Shop and Fish panel) if there is one, otherwise
## an ANCESTOR button (the guide album, where the whole tile is one Button around the label).
## Robust against many cards sharing the same price, which plain price-text matching can't.
func _tap_card_buy(title: String) -> void:
	var label := _find_label(_main.ui_root, title)
	if label == null:
		_failures += 1
		print("[FAIL] no visible card titled '%s'" % title)
		return
	var row: Node = label.get_parent().get_parent()
	await _scroll_into_view(row)
	var buttons := _find_all_buttons(row)
	if buttons.is_empty():
		var ancestor: Node = row
		while ancestor != null and not (ancestor is Button):
			ancestor = ancestor.get_parent()
		if ancestor != null:
			buttons = [ancestor]
	if buttons.is_empty():
		_failures += 1
		print("[FAIL] card '%s' has no button" % title)
		return
	## Fish cards put a ♂/♀ pick before the actual buy button (ShopPanel._add_fish_card), so the
	## buy/sell button is the LAST one in the row, not the first (equipment/tank cards and the
	## guide album only ever have the one button, so "last" is still correct there too).
	await _tap_node(buttons[-1])


## Taps a fish card's ♂ (female=false) or ♀ (female=true) toggle without buying — the two
## toggle buttons are whatever _tap_card_buy finds before the buy button itself (index 0/1).
func _tap_card_sex_toggle(title: String, female: bool) -> void:
	var label := _find_label(_main.ui_root, title)
	if label == null:
		_failures += 1
		print("[FAIL] no visible card titled '%s'" % title)
		return
	var row: Node = label.get_parent().get_parent()
	await _scroll_into_view(row)
	var buttons := _find_all_buttons(row)
	if buttons.size() < 3:
		_failures += 1
		print("[FAIL] card '%s' has no sex toggle" % title)
		return
	await _tap_node(buttons[1 if female else 0])


func _get_all_text(node: Node) -> String:
	var out := ""
	if node is Label:
		out += (node as Label).text + "\n"
	for child in node.get_children():
		out += _get_all_text(child)
	return out


## Long card lists (41 species) can place a card below the viewport, where a synthetic click
## at its true screen position lands outside the window and does nothing — real scrolling
## finger-drag isn't simulated here, so scroll programmatically instead.
func _scroll_into_view(control: Control) -> void:
	var scroll: Node = control.get_parent()
	while scroll != null and not (scroll is ScrollContainer):
		scroll = scroll.get_parent()
	if scroll == null:
		return
	var content: Control = scroll.get_child(0)
	var local_y: float = control.get_global_rect().position.y - content.get_global_rect().position.y
	scroll.scroll_vertical = maxi(0, int(local_y - 60.0))
	await _frames(6)


func _tap_text(text: String) -> void:
	var button := _find_button(_main.ui_root, text)
	if button == null:
		_failures += 1
		print("[FAIL] no visible button captioned '%s'" % text)
		return
	await _scroll_into_view(button)
	await _tap_node(button)


func _tap_icon(root: Node, kind: String) -> void:
	var button := _find_icon_button(root, kind)
	if button == null:
		_failures += 1
		print("[FAIL] no visible '%s' icon button" % kind)
		return
	await _tap_node(button)


## One synthetic tap. The engine only lets a button start a press while it believes the pointer
## is hovering it, and re-checks hover against the REAL OS cursor whenever a layout changes (a
## caption edit is enough) — so a synthetic press that lands a few frames after its pointer-move
## can be silently ignored. Moving and pressing in the same frame avoids that; if a tap is still
## swallowed it is repeated once, which a real finger would do too.
func _tap_node(control: Control) -> void:
	for attempt in range(2):
		var fired := [false]
		if not is_instance_valid(control):
			return
		if control is Button:
			(control as Button).pressed.connect(func(): fired[0] = true, CONNECT_ONE_SHOT)
		await _tap_node_once(control)
		if not (is_instance_valid(control) and control is Button) or fired[0]:
			return
		print("  (info) tap swallowed on '%s', repeating" % _button_text(control))


func _tap_node_once(control: Control) -> void:
	var point: Vector2 = control.get_global_rect().get_center()
	var move := InputEventMouseMotion.new()
	move.position = point
	move.global_position = point
	get_viewport().push_input(move, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = point
		event.global_position = point
		get_viewport().push_input(event, true)
		await _frames(3)
	await _frames(6)
