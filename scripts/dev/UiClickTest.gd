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

	await _tap_text("שחק")
	_check("Play hides the home screen", not _main.home.visible)
	_check("Welcome panel opened on a new game", _main.welcome.visible)

	await _tap_text("יאללה, לחנות")
	_check("Welcome button opens the shop", _main.shop.visible and not _main.welcome.visible)

	await _tap_text("$12")
	_check("Tapping the filter card installs a filter", tank.filter != null and tank.filter.id == "basic_filter")
	_check("...and takes the money", EconomyManager.cash == 48)

	await _tap_text("דגים")
	await _tap_text("$5")
	await _tap_text("$5")
	_check("Tapping the guppy card twice adds two guppies", _main.count_fish("guppy", false) == 2)
	_check("...and takes the money", EconomyManager.cash == 38)

	await _tap_text("$12")
	_check("Not enough for... (betta is $12, affordable) adds a betta", _main.count_fish("betta", false) == 1)

	await _tap_icon(_main.shop, "close")
	_check("Close button closes the shop", not _main.shop.visible)

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
	await _tap_text("$10")
	_check("Sell button sells the betta", _main.count_fish("betta", false) == 0 and EconomyManager.cash == cash_before + 10)
	await _tap_icon(_main.fish_panel, "close")

	await _tap_text("מצב האקווריום")
	_check("Bottom-bar Tank Status opens the panel", _main.tank_panel.visible)
	await _tap_icon(_main.tank_panel, "close")

	await _tap_text("מדריך")
	_check("Bottom-bar Guide opens the guide", _main.guide.visible)
	await _tap_text("ציוד")
	_check("Guide tab switches", _main.guide._tab == GuidePanel.Tab.EQUIPMENT and _main.guide._list.get_child_count() >= 10)
	await _tap_icon(_main.guide, "close")

	await _tap_text("חנות")
	_check("Bottom-bar Shop opens the shop", _main.shop.visible)
	await _tap_icon(_main.shop, "close")

	tank.ammonia = 0.0
	for fish in tank.get_fish():
		fish.hunger = 10.0
	await _frames(30)
	await _tap_node(_main.hud._tip_button)
	_check("Tapping the coach line performs its action (feed)", tank.get_fish()[0].hunger > 40.0)

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


func _check(what: String, ok: bool) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", what])


func _frames(count: int) -> void:
	for i in range(count):
		await get_tree().process_frame


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


func _tap_text(text: String) -> void:
	var button := _find_button(_main.ui_root, text)
	if button == null:
		_failures += 1
		print("[FAIL] no visible button captioned '%s'" % text)
		return
	await _tap_node(button)


func _tap_icon(root: Node, kind: String) -> void:
	var button := _find_icon_button(root, kind)
	if button == null:
		_failures += 1
		print("[FAIL] no visible '%s' icon button" % kind)
		return
	await _tap_node(button)


func _tap_node(control: Control) -> void:
	var point: Vector2 = control.get_global_rect().get_center()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = point
		event.global_position = point
		get_viewport().push_input(event, true)
		await _frames(3)
	await _frames(6)
