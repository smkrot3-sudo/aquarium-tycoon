extends Control
class_name HomeScreen
## The game's front page: illustrated tank art with a few fish drifting past, the title, and
## the three things you can do before playing — Play/Continue, Guide, Settings. Shown at launch
## and whenever the player taps the home button; the simulation is paused while it is up.

const DRIFTERS := ["guppy", "neon_tetra", "platy", "betta", "honey_gourami", "zebra_danio"]
## Fractions of the screen height: two lanes above the title, two below the buttons.
const LANES := [0.02, 0.72, 0.12, 0.8, 0.07, 0.76]

var game: GameController

var _play_button: Button
var _update_button: Button
var _drifters: Array = []  ## [{node: TextureRect, speed: float, phase: float, base_y: float}]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var art := TextureRect.new()
	art.texture = load("res://assets/backgrounds/freshwater.jpg")
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art)

	var fish_layer := Control.new()
	fish_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fish_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	## Drifters are positioned by hand in screen space; never mirror them for RTL.
	fish_layer.layout_direction = Control.LAYOUT_DIRECTION_LTR
	add_child(fish_layer)
	var view := get_viewport_rect().size
	for i in range(DRIFTERS.size()):
		var fish := UiKit.texture_icon("res://assets/fish/%s.png" % DRIFTERS[i], Vector2(150.0, 90.0))
		fish.size = Vector2(150.0, 90.0)
		fish_layer.add_child(fish)
		var entry := {
			"node": fish, "speed": randf_range(34.0, 70.0), "phase": randf() * TAU,
			"base_y": view.y * LANES[i % LANES.size()],
		}
		fish.position = Vector2(randf_range(0.0, view.x), entry["base_y"])
		_drifters.append(entry)

	## Darken the middle so the title and buttons read clearly over the art.
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.05, 0.12, 0.38)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var column := UiKit.vbox(14)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(column)

	var title := UiKit.outline(UiKit.label(Localization.t("ui_title"), 84, Color(1.0, 0.97, 0.86), true), 16, Color(0.0, 0.16, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	title.add_theme_constant_override("shadow_offset_y", 6)
	column.add_child(title)
	var tagline := UiKit.outline(UiKit.label(Localization.t("home_tagline"), 26, UiKit.COL_TEXT, true), 8)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(tagline)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0.0, 14.0)
	column.add_child(gap)

	_play_button = UiKit.action_button(Localization.t("home_play"), UiKit.icon("play", 40.0), "primary", false, Vector2(440.0, 96.0), 38)
	_play_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_play_button.pressed.connect(game.start_game)
	column.add_child(_play_button)

	var row := UiKit.hbox(14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(row)
	var guide_button := UiKit.action_button(Localization.t("home_how_to_play"), UiKit.icon("book", 32.0), "secondary", false, Vector2(213.0, 72.0), UiKit.FONT_BUTTON)
	guide_button.pressed.connect(game.open_guide)
	row.add_child(guide_button)
	var settings_button := UiKit.action_button(Localization.t("nav_settings"), UiKit.icon("gear", 32.0), "secondary", false, Vector2(213.0, 72.0), UiKit.FONT_BUTTON)
	settings_button.pressed.connect(game.open_settings)
	row.add_child(settings_button)

	_update_button = UiKit.button(Localization.t("home_update_available"), "gold", 60.0, UiKit.FONT_BODY)
	_update_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_update_button.visible = false
	_update_button.pressed.connect(game.open_settings)
	column.add_child(_update_button)

	var version := UiKit.outline(UiKit.label(Localization.t("home_version", [UpdateChecker.APP_VERSION_NAME]), UiKit.FONT_SMALL, UiKit.COL_TEXT), 5)
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	version.offset_left = 20.0
	version.offset_top = -40.0
	version.offset_bottom = -12.0
	version.offset_right = 320.0
	add_child(version)

	game.update_status_changed.connect(refresh)
	refresh()


func refresh() -> void:
	if _play_button == null:
		return
	UiKit.set_action_text(_play_button, Localization.t("home_continue") if SaveManager.has_save() else Localization.t("home_play"))
	_update_button.visible = game.update_state == GameController.UpdateState.AVAILABLE or game.update_state == GameController.UpdateState.READY_TO_INSTALL


func _process(delta: float) -> void:
	if not visible:
		return
	var view := get_viewport_rect().size
	for entry in _drifters:
		var fish: TextureRect = entry["node"]
		entry["phase"] += delta
		fish.position.x += entry["speed"] * delta
		fish.position.y = entry["base_y"] + sin(entry["phase"] * 0.8) * 14.0
		if fish.position.x > view.x + 20.0:
			fish.position.x = -fish.size.x - randf_range(20.0, 260.0)
