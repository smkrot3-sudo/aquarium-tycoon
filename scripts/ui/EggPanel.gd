extends ModalPanel
class_name EggPanel
## Tap a clutch of eggs in the tank to open this: how many are alive, how many have gone white,
## how long until they hatch, whether a parent is guarding them, and what the player can do: pick
## out the dead eggs (so the fungus doesn't spread), move the clutch to a tank of its own (so
## nothing eats it), or throw it away. Refreshes once a second since the eggs ripen live.

const POLL_INTERVAL := 1.0

var _tank: TankController
var _batch_id: int = 0
var _picture: TextureRect
var _species_label: Label
var _stat_rows: VBoxContainer
var _clean_button: Button
var _dest_list: VBoxContainer
var _poll_accum: float = 0.0


func _build() -> void:
	set_title(Localization.t("egg_title"))
	var columns := UiKit.hbox(16)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(columns)

	var left := UiKit.vbox(10)
	left.custom_minimum_size = Vector2(220.0, 0.0)
	columns.add_child(left)
	var frame := UiKit.panel(UiKit.COL_CARD, 20, 14.0, 14.0)
	left.add_child(frame)
	_picture = UiKit.texture_icon("", Vector2(190.0, 120.0))
	frame.add_child(_picture)
	_species_label = UiKit.label("", UiKit.FONT_BODY, UiKit.COL_ACCENT)
	_species_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(_species_label)

	var right := UiKit.panel(UiKit.COL_CARD, 20, 16.0, 14.0)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_child(right)
	var scroll := UiKit.scroll()
	right.add_child(scroll)
	_stat_rows = UiKit.vbox(8)
	_stat_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_stat_rows)

	var actions := UiKit.hbox(10)
	body.add_child(actions)
	_clean_button = UiKit.action_button(Localization.t("egg_remove_white"), UiKit.icon("cross", 28.0), "secondary", false, Vector2(0.0, 64.0), UiKit.FONT_BUTTON)
	_clean_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_clean_button.pressed.connect(func():
		if _tank != null and is_instance_valid(_tank):
			_tank.remove_dud_eggs(_batch_id)
			refresh()
	)
	actions.add_child(_clean_button)
	var discard := UiKit.action_button(Localization.t("egg_discard"), UiKit.icon("close", 28.0), "danger", false, Vector2(0.0, 64.0), UiKit.FONT_BUTTON)
	discard.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	discard.pressed.connect(func():
		if _tank != null and is_instance_valid(_tank):
			_tank.remove_egg_batch(_batch_id)
			game.state_changed.emit()
		close()
	)
	actions.add_child(discard)

	body.add_child(UiKit.label(Localization.t("egg_move_to"), UiKit.FONT_SMALL, UiKit.COL_MUTED))
	var dest_scroll := UiKit.scroll()
	dest_scroll.custom_minimum_size = Vector2(0.0, 80.0)
	body.add_child(dest_scroll)
	_dest_list = UiKit.vbox(8)
	_dest_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dest_scroll.add_child(_dest_list)


func inspect(tank: TankController, batch_id: int) -> void:
	_tank = tank
	_batch_id = batch_id


func open() -> void:
	if _tank == null or not is_instance_valid(_tank):
		return
	visible = true
	refresh()
	_fill_destinations()


func refresh() -> void:
	if _tank == null or not is_instance_valid(_tank):
		close()
		return
	var batch := _tank.find_egg_batch(_batch_id)
	if batch.is_empty():
		close()
		return
	var species := ShopManager.get_species(str(batch["species_id"]))
	if species == null:
		close()
		return
	var path := "res://assets/fish/%s.png" % species.id
	_picture.texture = load(path) if ResourceLoader.exists(path) else null
	_species_label.text = Localization.t("sp_%s" % species.id)

	for child in _stat_rows.get_children():
		_stat_rows.remove_child(child)
		child.queue_free()
	var alive: int = int(round(float(batch["viable"])))
	var white: int = int(round(float(batch["duds"])))
	_add_stat(Localization.t("egg_alive"), str(alive), UiKit.COL_GOOD if alive > 0 else UiKit.COL_BAD)
	_add_stat(Localization.t("egg_white"), str(white), UiKit.COL_WARN if white > 0 else UiKit.COL_TEXT)
	var remaining: float = maxf(0.0, float(batch["remaining_days"]))
	_add_stat(Localization.t("egg_hatch_in"), Localization.t("egg_days", [remaining]))
	var total: float = maxf(0.001, float(batch["total_days"]))
	_add_bar(Localization.t("egg_development"), clampf(1.0 - remaining / total, 0.0, 1.0), UiKit.COL_PRIMARY)
	var guarded: bool = bool(batch.get("guarded_now", false))
	if bool(batch["guard"]):
		_add_stat(Localization.t("egg_guard"), Localization.t("egg_guarded") if guarded else Localization.t("egg_no_parent"), UiKit.COL_GOOD if guarded else UiKit.COL_WARN)
	else:
		_add_stat(Localization.t("egg_guard"), Localization.t("egg_unguarded"), UiKit.COL_WARN)

	var risks: Array = []
	var eaters := 0
	for fish in _tank.get_fish():
		if not fish.is_fry and fish.species.diet_type != FishSpeciesData.Diet.HERBIVORE:
			eaters += 1
	if eaters > 0 and not guarded:
		risks.append(Localization.t("egg_risk_eaten"))
	if _tank.ammonia > 0.15 or _tank.nitrite > 0.15 or _tank.nitrate > 40.0:
		risks.append(Localization.t("egg_risk_water"))
	if white > 0:
		risks.append(Localization.t("egg_risk_white"))
	if risks.is_empty():
		_stat_rows.add_child(UiKit.paragraph(Localization.t("egg_risk_none"), UiKit.FONT_SMALL, UiKit.COL_GOOD))
	for risk in risks:
		_stat_rows.add_child(UiKit.paragraph(risk, UiKit.FONT_SMALL, UiKit.COL_WARN))
	_clean_button.disabled = white <= 0


func _fill_destinations() -> void:
	var batch := _tank.find_egg_batch(_batch_id)
	var species := ShopManager.get_species(str(batch.get("species_id", ""))) if not batch.is_empty() else null
	if species == null:
		return
	for child in _dest_list.get_children():
		_dest_list.remove_child(child)
		child.queue_free()
	var shown := 0
	for i in range(game.tanks().size()):
		var dest: TankController = game.tanks()[i]
		if dest == _tank or dest.locked:
			continue
		var reason: String = game.egg_move_block_reason(species, dest)
		var button := UiKit.button(Localization.t("egg_move_button", [game.tank_display_name(i)]), "secondary", 56.0, UiKit.FONT_BODY)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if reason != "":
			button.disabled = true
			button.tooltip_text = reason
		else:
			button.pressed.connect(_on_move.bind(i))
		_dest_list.add_child(button)
		if reason != "":
			_dest_list.add_child(UiKit.paragraph(reason, UiKit.FONT_SMALL, UiKit.COL_MUTED))
		shown += 1
	if shown == 0:
		_dest_list.add_child(UiKit.paragraph(Localization.t("egg_no_other_tank"), UiKit.FONT_SMALL, UiKit.COL_MUTED))


func _on_move(dest_index: int) -> void:
	if game.move_eggs(_tank, _batch_id, dest_index):
		close()


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


func _process(delta: float) -> void:
	if not visible:
		return
	_poll_accum += delta
	if _poll_accum >= POLL_INTERVAL:
		_poll_accum = 0.0
		refresh()
