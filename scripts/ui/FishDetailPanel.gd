extends ModalPanel
class_name FishDetailPanel
## Tap a fish swimming in the tank (TankController._unhandled_input) to open this: its given
## name, sex, species, age, how long it's been in this tank, and its health/hunger — the
## per-individual identity the player asked for, not just a species head-count. Refreshes once a
## second while open since age ticks up live.

const POLL_INTERVAL := 1.0

var _fish: FishController
var _picture: TextureRect
var _sex_badge: Label
var _species_label: Label
var _stat_rows: VBoxContainer
var _sell_button: Button
var _poll_accum: float = 0.0


func _build() -> void:
	var columns := UiKit.hbox(16)
	body.add_child(columns)

	var left := UiKit.vbox(10)
	left.custom_minimum_size = Vector2(220.0, 0.0)
	columns.add_child(left)
	var frame := UiKit.panel(UiKit.COL_CARD, 20, 14.0, 14.0)
	left.add_child(frame)
	_picture = UiKit.texture_icon("", Vector2(190.0, 140.0))
	frame.add_child(_picture)
	_sex_badge = UiKit.label("", UiKit.FONT_HEADING, UiKit.COL_TEXT, true)
	_sex_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(_sex_badge)
	_species_label = UiKit.label("", UiKit.FONT_BODY, UiKit.COL_ACCENT)
	_species_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(_species_label)

	var right := UiKit.panel(UiKit.COL_CARD, 20, 16.0, 14.0)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right)
	_stat_rows = UiKit.vbox(10)
	right.add_child(_stat_rows)

	_sell_button = UiKit.action_button(Localization.t("fish_detail_sell"), UiKit.icon("coin", 28.0), "warn", false, Vector2(0.0, 68.0), UiKit.FONT_BUTTON)
	_sell_button.pressed.connect(_on_sell_pressed)
	body.add_child(_sell_button)


## Called by TankController (via GameController.open_fish_detail) right before `open()`.
func inspect(fish: FishController) -> void:
	_fish = fish


func open() -> void:
	if _fish == null or not is_instance_valid(_fish):
		return
	visible = true
	refresh()


func refresh() -> void:
	if _fish == null or not is_instance_valid(_fish):
		close()
		return
	var species := _fish.species
	set_title(_fish.fish_name)
	_picture.texture = load("res://assets/fish/%s.png" % species.id) if ResourceLoader.exists("res://assets/fish/%s.png" % species.id) else null
	var is_male: bool = _fish.sex == FishController.Sex.MALE
	_sex_badge.text = Localization.t("fish_detail_sex_male") if is_male else Localization.t("fish_detail_sex_female")
	_sex_badge.add_theme_color_override("font_color", Color(0.45, 0.7, 1.0) if is_male else Color(1.0, 0.55, 0.75))
	_species_label.text = Localization.t("sp_%s" % species.id)

	for child in _stat_rows.get_children():
		_stat_rows.remove_child(child)
		child.queue_free()

	_add_stat(Localization.t("fish_detail_age"), Localization.t("fish_detail_days", [int(_fish.age_sim_days)]))
	_add_stat(Localization.t("fish_detail_in_tank"), Localization.t("fish_detail_days", [int(_fish.days_in_tank)]))
	_add_stat(Localization.t("fish_detail_stage"), Localization.t("fish_detail_fry") if _fish.is_fry else Localization.t("fish_detail_adult"))
	_add_bar(Localization.t("fish_detail_health"), _fish.health / 100.0, UiKit.COL_GOOD if _fish.health >= 60.0 else UiKit.COL_BAD)
	_add_bar(Localization.t("fish_detail_hunger"), _fish.hunger / 100.0, UiKit.COL_GOOD if _fish.hunger >= 40.0 else UiKit.COL_WARN)
	if _fish.is_sick:
		_add_stat(Localization.t("fish_detail_condition"), Localization.t("fish_detail_sick"), UiKit.COL_BAD)

	UiKit.set_action_text(_sell_button, Localization.t("fish_detail_sell_for", [Economy.fry_sale_value(species, _fish.is_fry)]))


func _add_stat(title: String, value: String, color: Color = UiKit.COL_TEXT) -> void:
	var row := UiKit.hbox(10)
	_stat_rows.add_child(row)
	var name_label := UiKit.label(title, UiKit.FONT_BODY, UiKit.COL_MUTED)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	row.add_child(UiKit.label(value, UiKit.FONT_BODY, color, true))


func _add_bar(title: String, fraction: float, color: Color) -> void:
	var row := UiKit.hbox(10)
	_stat_rows.add_child(row)
	var name_label := UiKit.label(title, UiKit.FONT_BODY, UiKit.COL_MUTED)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	row.add_child(UiKit.progress(fraction, color, Vector2(140.0, 18.0)))


func _on_sell_pressed() -> void:
	if _fish == null or not is_instance_valid(_fish):
		close()
		return
	game.sell_specific_fish(_fish)
	close()


func _process(delta: float) -> void:
	if not visible:
		return
	_poll_accum += delta
	if _poll_accum >= POLL_INTERVAL:
		_poll_accum = 0.0
		refresh()
