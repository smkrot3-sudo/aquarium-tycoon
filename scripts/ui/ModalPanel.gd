extends Control
class_name ModalPanel
## Base for every full-screen panel (shop, my fish, tank status, guide, settings, welcome):
## a dimmed backdrop, a rounded sheet with a title bar and a big close button, and a `body`
## container the subclass fills in _build(). Subclasses override _build() and refresh().

signal closed

var game: GameController
var title_text: String = ""
var body: VBoxContainer
## Right-hand side of the title bar (left in Hebrew), before the close button.
var header_extra: HBoxContainer
var _title_label: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.02, 0.06, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(_on_backdrop_input)
	add_child(dim)

	var insets := UiKit.safe_insets(get_viewport())
	var frame := UiKit.margin(insets.x + 10.0, 12.0, insets.y + 10.0, 12.0)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)

	var sheet_style := UiKit.box(UiKit.COL_PANEL, 26, 20.0, 14.0)
	sheet_style.set_border_width_all(2)
	sheet_style.border_color = Color(0.35, 0.85, 0.95, 0.35)
	var sheet := PanelContainer.new()
	sheet.add_theme_stylebox_override("panel", sheet_style)
	frame.add_child(sheet)

	var column := UiKit.vbox(10)
	sheet.add_child(column)

	var header := UiKit.hbox(12)
	column.add_child(header)
	_title_label = UiKit.label(title_text, UiKit.FONT_TITLE, UiKit.COL_TEXT, true)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.clip_text = true
	header.add_child(_title_label)
	header_extra = UiKit.hbox(10)
	header.add_child(header_extra)
	var close_button := UiKit.action_button("", UiKit.icon("close", 34.0), "danger", false, Vector2(72.0, 64.0))
	close_button.pressed.connect(close)
	header.add_child(close_button)

	body = UiKit.vbox(10)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)

	_build()


func set_title(text: String) -> void:
	title_text = text
	if _title_label != null:
		_title_label.text = text


func _build() -> void:
	pass


func refresh() -> void:
	pass


func open() -> void:
	visible = true
	refresh()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		close()
