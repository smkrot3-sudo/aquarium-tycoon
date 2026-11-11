extends ModalPanel
class_name NewGamePanel
## Shown when a new game starts: pick Career / Free play / Sandbox, and (except in Sandbox) how
## hard it should be. Closing it without starting just returns to the home screen.

var _mode: int = GameState.Mode.CAREER
var _difficulty: int = GameState.Difficulty.NORMAL
var _mode_buttons: Array[Button] = []
var _difficulty_buttons: Array[Button] = []
var _mode_text: Label
var _difficulty_text: Label
var _difficulty_card: PanelContainer


func _build() -> void:
	set_title(Localization.t("newgame_title"))
	var column := UiKit.vbox(12)
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(column)

	column.add_child(UiKit.label(Localization.t("newgame_mode"), UiKit.FONT_BODY, UiKit.COL_MUTED))
	var mode_row := UiKit.hbox(10)
	column.add_child(mode_row)
	var mode_keys := ["mode_career", "mode_free", "mode_sandbox"]
	for i in range(mode_keys.size()):
		var b := UiKit.button(Localization.t(mode_keys[i]), "tab", 72.0, UiKit.FONT_HEADING)
		b.toggle_mode = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_pick_mode.bind(i))
		mode_row.add_child(b)
		_mode_buttons.append(b)
	var mode_card := UiKit.panel(UiKit.COL_CARD, 16, 16.0, 12.0)
	column.add_child(mode_card)
	_mode_text = UiKit.paragraph("", UiKit.FONT_BODY, UiKit.COL_TEXT)
	mode_card.add_child(_mode_text)

	_difficulty_card = UiKit.panel(UiKit.COL_CARD_DIM, 16, 16.0, 12.0)
	column.add_child(_difficulty_card)
	var diff_column := UiKit.vbox(10)
	_difficulty_card.add_child(diff_column)
	diff_column.add_child(UiKit.label(Localization.t("newgame_difficulty"), UiKit.FONT_BODY, UiKit.COL_MUTED))
	var diff_row := UiKit.hbox(10)
	diff_column.add_child(diff_row)
	var diff_keys := ["diff_easy", "diff_normal", "diff_hard"]
	for i in range(diff_keys.size()):
		var b := UiKit.button(Localization.t(diff_keys[i]), "tab", 60.0, UiKit.FONT_BODY)
		b.toggle_mode = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_pick_difficulty.bind(i))
		diff_row.add_child(b)
		_difficulty_buttons.append(b)
	_difficulty_text = UiKit.paragraph("", UiKit.FONT_SMALL, UiKit.COL_MUTED)
	diff_column.add_child(_difficulty_text)

	column.add_child(UiKit.spacer())
	var start := UiKit.action_button(Localization.t("newgame_start"), UiKit.icon("play", 36.0), "primary", false, Vector2(0.0, 80.0), 32)
	start.pressed.connect(func(): game.begin_new_game(_mode, _difficulty))
	column.add_child(start)


func refresh() -> void:
	for i in range(_mode_buttons.size()):
		_mode_buttons[i].set_pressed_no_signal(i == _mode)
	for i in range(_difficulty_buttons.size()):
		_difficulty_buttons[i].set_pressed_no_signal(i == _difficulty)
	_mode_text.text = Localization.t(["mode_career_desc", "mode_free_desc", "mode_sandbox_desc"][_mode])
	_difficulty_card.visible = _mode != GameState.Mode.SANDBOX
	_difficulty_text.text = Localization.t(["diff_easy_desc", "diff_normal_desc", "diff_hard_desc"][_difficulty])


func _pick_mode(mode: int) -> void:
	_mode = mode
	refresh()


func _pick_difficulty(difficulty: int) -> void:
	_difficulty = difficulty
	refresh()
