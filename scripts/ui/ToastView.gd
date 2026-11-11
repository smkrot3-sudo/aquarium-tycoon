extends Control
class_name ToastView
## Short pop-up messages ("Bought: Guppy", "Not enough cash", "8 baby guppies were born!").
## Lives above every other screen — including the shop and the other panels — so that a tap
## which can't do what was asked always visibly answers with the reason.

const SECONDS := 3.4

var _panel: PanelContainer
var _label: Label
var _time_left: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var holder := CenterContainer.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	holder.offset_top = -(TankController.HUD_BOTTOM_PX + 84.0)
	holder.offset_bottom = -(TankController.HUD_BOTTOM_PX + 16.0)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	holder.add_child(_panel)
	_label = UiKit.label("", UiKit.FONT_BODY, UiKit.COL_TEXT, true)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(_label)


func show_toast(message: String, kind: String = "info") -> void:
	if _panel == null:
		return
	_label.text = message
	var style := UiKit.box(Color(0.02, 0.07, 0.14, 0.97), 28, 26.0, 14.0)
	style.set_border_width_all(3)
	match kind:
		"good":
			style.border_color = UiKit.COL_GOOD
		"bad":
			style.border_color = UiKit.COL_BAD
		_:
			style.border_color = UiKit.COL_ACCENT
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 10
	_panel.add_theme_stylebox_override("panel", style)
	_panel.modulate.a = 1.0
	_panel.visible = true
	_time_left = SECONDS


func _process(delta: float) -> void:
	if _time_left <= 0.0:
		return
	_time_left -= delta
	_panel.modulate.a = clampf(_time_left / 0.4, 0.0, 1.0)
	if _time_left <= 0.0:
		_panel.visible = false
