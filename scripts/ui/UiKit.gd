extends RefCounted
class_name UiKit
## Shared look-and-feel for the whole phone UI: palette, type scale, and small factory helpers
## for the handful of widgets every screen is built from. The entire UI is built in code (see
## GameController._build_ui) so there is exactly one place that decides what a button, a card
## or a chip looks like.
##
## Sizes are in logical pixels of a 648px-tall landscape viewport (project stretch mode
## canvas_items/expand). On a ~6.5" phone one logical pixel is about 0.1mm, so the 22px body
## text is ~2.3mm tall and the 64px+ buttons are comfortably finger-sized.

const FONT_SMALL := 18
const FONT_BODY := 22
const FONT_BUTTON := 24
const FONT_HEADING := 26
const FONT_TITLE := 34

const COL_TEXT := Color(0.96, 0.98, 1.0)
const COL_MUTED := Color(0.66, 0.78, 0.9)
const COL_PANEL := Color(0.04, 0.1, 0.19, 0.97)
const COL_CARD := Color(0.08, 0.18, 0.3, 1.0)
const COL_CARD_DIM := Color(0.07, 0.13, 0.2, 1.0)
const COL_GLASS := Color(0.02, 0.08, 0.16, 0.72)
const COL_PRIMARY := Color(0.07, 0.66, 0.58)
const COL_SECONDARY := Color(0.15, 0.36, 0.6)
const COL_GOLD := Color(1.0, 0.8, 0.28)
const COL_GOOD := Color(0.42, 0.9, 0.52)
const COL_WARN := Color(1.0, 0.66, 0.22)
const COL_BAD := Color(1.0, 0.42, 0.36)
const COL_ACCENT := Color(0.35, 0.85, 0.95)

static var _bold_font: Font


static func bold_font() -> Font:
	if _bold_font == null:
		var variation := FontVariation.new()
		variation.base_font = ThemeDB.fallback_font
		variation.variation_embolden = 0.7
		_bold_font = variation
	return _bold_font


static func box(color: Color, radius: int = 16, margin_h: float = 14.0, margin_v: float = 10.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.content_margin_left = margin_h
	style.content_margin_right = margin_h
	style.content_margin_top = margin_v
	style.content_margin_bottom = margin_v
	style.anti_aliasing = true
	return style


static func build_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = FONT_BODY
	theme.set_color("font_color", "Label", COL_TEXT)
	theme.set_font_size("font_size", "Button", FONT_BUTTON)
	theme.set_font("font", "Button", bold_font())
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_constant("h_separation", "Button", 10)

	## Fat, finger-sized scrollbar grabber; the track itself is nearly invisible.
	var grabber := box(Color(1, 1, 1, 0.35), 5, 0.0, 0.0)
	grabber.content_margin_left = 5.0
	grabber.content_margin_right = 5.0
	theme.set_stylebox("grabber", "VScrollBar", grabber)
	theme.set_stylebox("grabber_highlight", "VScrollBar", grabber)
	theme.set_stylebox("grabber_pressed", "VScrollBar", grabber)
	theme.set_stylebox("scroll", "VScrollBar", box(Color(1, 1, 1, 0.06), 5, 5.0, 0.0))

	var bar_bg := box(Color(0, 0, 0, 0.4), 9, 0.0, 0.0)
	var bar_fill := box(COL_PRIMARY, 9, 0.0, 0.0)
	theme.set_stylebox("background", "ProgressBar", bar_bg)
	theme.set_stylebox("fill", "ProgressBar", bar_fill)
	return theme


## "primary" (teal, the thing to press), "secondary" (blue), "gold" (shop/money), "warn"
## (orange, selling), "danger" (red), "glass" (translucent, floats over the tank), "tab".
static func style_button(button: Button, kind: String = "secondary") -> void:
	var base: Color = COL_SECONDARY
	match kind:
		"primary":
			base = COL_PRIMARY
		"gold":
			base = Color(0.85, 0.58, 0.1)
		"warn":
			base = Color(0.88, 0.45, 0.16)
		"danger":
			base = Color(0.78, 0.22, 0.22)
		"glass":
			base = COL_GLASS
		"tab":
			base = Color(0.1, 0.2, 0.33)
	var is_flat: bool = kind == "glass" or kind == "tab"
	var edge: int = 0 if is_flat else 5

	var normal := box(base, 18, 18.0, 8.0)
	normal.border_width_bottom = edge
	normal.border_color = base.darkened(0.38)
	if kind == "glass":
		normal.set_border_width_all(2)
		normal.border_color = Color(1, 1, 1, 0.18)

	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = base.darkened(0.18) if not is_flat else base.lightened(0.18)
	pressed.border_width_bottom = 2 if not is_flat else normal.border_width_bottom
	pressed.content_margin_top = normal.content_margin_top + (3.0 if not is_flat else 0.0)

	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = base.lightened(0.08)

	var disabled: StyleBoxFlat = normal.duplicate()
	disabled.bg_color = Color(0.2, 0.25, 0.32, 0.9)
	disabled.border_color = Color(0.13, 0.16, 0.2, 0.9)

	if kind == "tab":
		## A toggled-on tab is the "pressed" style: bright accent so the current tab is obvious.
		pressed.bg_color = COL_PRIMARY
		hover = normal.duplicate()

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("hover_pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_color_override("font_color", COL_TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_hover_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", COL_TEXT)
	button.add_theme_color_override("font_disabled_color", Color(0.62, 0.68, 0.75))
	button.set_meta("kind", kind)


## Re-style only when the kind actually changes (HUD buttons flip between calm and "press me").
static func set_button_kind(button: Button, kind: String) -> void:
	if button.get_meta("kind", "") != kind:
		style_button(button, kind)


## Plain text button. Every button in the game clicks.
static func button(text: String, kind: String = "secondary", min_height: float = 64.0, font_size: int = FONT_BUTTON) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0.0, min_height)
	b.add_theme_font_size_override("font_size", font_size)
	style_button(b, kind)
	b.pressed.connect(func(): AudioManager.play("click"))
	return b


## Button with an icon (any Control — a UiIcon or a texture_icon) and an optional caption,
## stacked (`vertical`) or side by side. The caption Label is stored in meta "label" so callers
## can update it. Button doesn't size itself to child controls, so the minimum width is derived
## from the caption here.
static func action_button(text: String, icon: Control, kind: String = "secondary", vertical: bool = false, min_size: Vector2 = Vector2(0.0, 64.0), font_size: int = FONT_BODY) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	style_button(b, kind)
	b.pressed.connect(func(): AudioManager.play("click"))

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(center)
	var content: BoxContainer = VBoxContainer.new() if vertical else HBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 2 if vertical else 10)
	center.add_child(content)

	var needed := Vector2.ZERO
	if icon != null:
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		content.add_child(icon)
		needed = icon.custom_minimum_size
	if text != "":
		var caption := label(text, font_size, COL_TEXT, true)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(caption)
		b.set_meta("label", caption)
		var text_size: Vector2 = bold_font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		if vertical:
			needed = Vector2(maxf(needed.x, text_size.x), needed.y + text_size.y)
		else:
			needed = Vector2(needed.x + text_size.x + 10.0, maxf(needed.y, text_size.y))
	b.custom_minimum_size = Vector2(maxf(min_size.x, needed.x + 28.0), maxf(min_size.y, needed.y + 16.0))
	return b


static func set_action_text(button: Button, text: String) -> void:
	if not button.has_meta("label"):
		return
	var caption: Label = button.get_meta("label")
	if caption.text != text:
		caption.text = text


static func label(text: String, font_size: int = FONT_BODY, color: Color = COL_TEXT, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", bold_font())
	return l


## Wrapping paragraph text; must sit in a container that gives it a width (expand-fill).
static func paragraph(text: String, font_size: int = FONT_SMALL, color: Color = COL_MUTED, max_lines: int = -1) -> Label:
	var l := label(text, font_size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if max_lines > 0:
		l.max_lines_visible = max_lines
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return l


## Text drawn straight over the tank art needs an outline to stay readable.
static func outline(l: Label, size: int = 6, color: Color = Color(0.0, 0.07, 0.15, 0.95)) -> Label:
	l.add_theme_constant_override("outline_size", size)
	l.add_theme_color_override("font_outline_color", color)
	return l


static func texture_icon(path: String, icon_size: Vector2) -> TextureRect:
	var rect := TextureRect.new()
	rect.custom_minimum_size = icon_size
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if path != "" and ResourceLoader.exists(path):
		rect.texture = load(path)
	return rect


static func icon(kind: String, icon_size: float = 36.0, color: Color = COL_TEXT) -> UiIcon:
	var i := UiIcon.new()
	i.kind = kind
	i.color = color
	i.custom_minimum_size = Vector2(icon_size, icon_size)
	i.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return i


static func panel(color: Color = COL_CARD, radius: int = 18, margin_h: float = 14.0, margin_v: float = 12.0) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(color, radius, margin_h, margin_v))
	return p


## Small translucent pill for HUD readouts. Returns the panel; add content to its "row" meta.
static func chip(min_height: float = 56.0) -> PanelContainer:
	var style := box(COL_GLASS, 28, 16.0, 6.0)
	style.set_border_width_all(2)
	style.border_color = Color(1, 1, 1, 0.16)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", style)
	p.custom_minimum_size = Vector2(0.0, min_height)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := hbox(8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(row)
	p.set_meta("row", row)
	return p


static func hbox(separation: int = 10) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", separation)
	return h


static func vbox(separation: int = 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", separation)
	return v


static func spacer() -> Control:
	var s := Control.new()
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s


static func margin(left: float, top: float, right: float, bottom: float) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", int(left))
	m.add_theme_constant_override("margin_top", int(top))
	m.add_theme_constant_override("margin_right", int(right))
	m.add_theme_constant_override("margin_bottom", int(bottom))
	return m


static func progress(value: float, color: Color = COL_PRIMARY, min_size: Vector2 = Vector2(160.0, 18.0)) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.step = 0.001
	bar.value = clampf(value, 0.0, 1.0)
	bar.show_percentage = false
	bar.custom_minimum_size = min_size
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_theme_stylebox_override("fill", box(color, 9, 0.0, 0.0))
	return bar


## Vertical touch-scrolling list. Children that would swallow the drag (buttons, panels) must
## be made MOUSE_FILTER_PASS — call pass_mouse() on the content after filling it.
static func scroll() -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return s


static func pass_mouse(node: Node) -> void:
	if node is Control and node.mouse_filter == Control.MOUSE_FILTER_STOP:
		node.mouse_filter = Control.MOUSE_FILTER_PASS
	for child in node.get_children():
		pass_mouse(child)


## Connect a button that lives inside a scroll list: a finger that lands on the button and then
## drags to scroll must not also "click" it when it lifts.
static func on_tap(button: Button, scroll_container: ScrollContainer, callback: Callable) -> void:
	button.button_down.connect(func(): button.set_meta("scroll_at_down", scroll_container.scroll_vertical))
	button.pressed.connect(func():
		if absi(scroll_container.scroll_vertical - int(button.get_meta("scroll_at_down", scroll_container.scroll_vertical))) <= 12:
			callback.call()
	)


## Left/right logical-pixel insets that keep content clear of a display cutout / rounded
## corners in landscape. Falls back to a small fixed gutter where the platform reports nothing.
static func safe_insets(viewport: Viewport) -> Vector2:
	var gutter := Vector2(14.0, 14.0)
	var window_size := Vector2(DisplayServer.window_get_size())
	if window_size.x <= 0.0 or window_size.y <= 0.0:
		return gutter
	var safe := DisplayServer.get_display_safe_area()
	if safe.size.x <= 0 or safe.size.y <= 0:
		return gutter
	var logical: Vector2 = viewport.get_visible_rect().size
	var px_to_logical: float = logical.x / window_size.x
	var left: float = maxf(0.0, float(safe.position.x)) * px_to_logical
	var right: float = maxf(0.0, window_size.x - float(safe.end.x)) * px_to_logical
	## Guard against a desktop/odd platform reporting a safe area unrelated to this window.
	if left > logical.x * 0.12 or right > logical.x * 0.12:
		return gutter
	return Vector2(maxf(gutter.x, left + 6.0), maxf(gutter.y, right + 6.0))
