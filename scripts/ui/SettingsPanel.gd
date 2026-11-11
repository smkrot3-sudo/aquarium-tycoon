extends ModalPanel
class_name SettingsPanel
## Settings: language, volume (big -/+ steps instead of a fiddly slider), the in-app updater,
## and starting over. Update state itself lives in GameController so it survives the UI being
## rebuilt on a language switch.

var _volume_bar: ProgressBar
var _volume_value: Label
var _update_button: Button
var _update_status: Label
var _reset_row: HBoxContainer
var _reset_confirm_row: HBoxContainer


func _build() -> void:
	set_title(Localization.t("nav_settings"))
	var scroll := UiKit.scroll()
	body.add_child(scroll)
	var list := UiKit.vbox(10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	# --- language
	var language_row := _section(list, Localization.t("settings_language"))
	for lang in ["he", "en"]:
		var lang_button := UiKit.button("עברית" if lang == "he" else "English", "primary" if Localization.current_language == lang else "tab", 64.0)
		lang_button.custom_minimum_size.x = 170.0
		lang_button.pressed.connect(Localization.set_language.bind(lang))
		language_row.add_child(lang_button)

	# --- volume
	var volume_row := _section(list, Localization.t("settings_volume"))
	var quieter := UiKit.action_button("", UiKit.icon("minus", 30.0), "secondary", false, Vector2(84.0, 64.0))
	quieter.pressed.connect(_nudge_volume.bind(-0.1))
	volume_row.add_child(quieter)
	_volume_bar = UiKit.progress(AudioManager.master_volume, UiKit.COL_ACCENT, Vector2(260.0, 22.0))
	volume_row.add_child(_volume_bar)
	var louder := UiKit.action_button("", UiKit.icon("plus", 30.0), "secondary", false, Vector2(84.0, 64.0))
	louder.pressed.connect(_nudge_volume.bind(0.1))
	volume_row.add_child(louder)
	_volume_value = UiKit.label("", UiKit.FONT_BODY, UiKit.COL_TEXT, true)
	_volume_value.custom_minimum_size = Vector2(70.0, 0.0)
	volume_row.add_child(_volume_value)

	# --- updates
	var update_row := _section(list, Localization.t("settings_updates", [UpdateChecker.APP_VERSION_NAME]))
	_update_button = UiKit.button("", "primary", 64.0)
	_update_button.custom_minimum_size.x = 260.0
	_update_button.pressed.connect(game.advance_update)
	update_row.add_child(_update_button)
	_update_status = UiKit.paragraph("", UiKit.FONT_SMALL, UiKit.COL_MUTED)
	_update_status.custom_minimum_size = Vector2(240.0, 0.0)
	update_row.add_child(_update_status)

	# --- game
	_reset_row = _section(list, Localization.t("settings_game"))
	var home_button := UiKit.action_button(Localization.t("settings_to_home"), UiKit.icon("home", 28.0), "secondary", false, Vector2(0.0, 64.0), UiKit.FONT_BUTTON)
	home_button.pressed.connect(game.go_home)
	_reset_row.add_child(home_button)
	var reset_button := UiKit.button(Localization.t("settings_new_game"), "danger", 64.0)
	reset_button.pressed.connect(_ask_reset.bind(true))
	_reset_row.add_child(reset_button)
	if OS.is_debug_build():
		var skip_button := UiKit.button(Localization.t("action_fast_forward"), "tab", 64.0)
		skip_button.pressed.connect(game._on_fast_forward)
		_reset_row.add_child(skip_button)

	_reset_confirm_row = _section(list, Localization.t("settings_new_game_confirm"))
	var yes_button := UiKit.button(Localization.t("settings_new_game_yes"), "danger", 64.0)
	yes_button.pressed.connect(func():
		_ask_reset(false)
		game.reset_game()
	)
	_reset_confirm_row.add_child(yes_button)
	var no_button := UiKit.button(Localization.t("settings_cancel"), "secondary", 64.0)
	no_button.custom_minimum_size.x = 160.0
	no_button.pressed.connect(_ask_reset.bind(false))
	_reset_confirm_row.add_child(no_button)
	_reset_confirm_row.get_parent().get_parent().visible = false

	game.update_status_changed.connect(_refresh_update)


## Adds a titled card to `list` and returns the row inside it for the section's controls.
func _section(list: VBoxContainer, title: String) -> HBoxContainer:
	var card := UiKit.panel(UiKit.COL_CARD, 18, 16.0, 12.0)
	list.add_child(card)
	var column := UiKit.vbox(8)
	card.add_child(column)
	column.add_child(UiKit.label(title, UiKit.FONT_BODY, UiKit.COL_MUTED))
	var row := UiKit.hbox(12)
	column.add_child(row)
	return row


func _ask_reset(asking: bool) -> void:
	_reset_confirm_row.get_parent().get_parent().visible = asking
	_reset_row.get_parent().get_parent().visible = not asking


func _nudge_volume(delta: float) -> void:
	AudioManager.master_volume = snappedf(AudioManager.master_volume + delta, 0.1)
	AudioManager.play("click")
	refresh()


func _refresh_update() -> void:
	if _update_button == null:
		return
	_update_button.text = game.update_button_text()
	_update_button.disabled = game.update_state == GameController.UpdateState.CHECKING or game.update_state == GameController.UpdateState.DOWNLOADING
	_update_status.text = game.update_status_text


func refresh() -> void:
	_volume_bar.value = AudioManager.master_volume
	_volume_value.text = "%d%%" % int(round(AudioManager.master_volume * 100.0))
	_ask_reset(false)
	_refresh_update()
