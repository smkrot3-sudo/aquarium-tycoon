extends ModalPanel
class_name BusinessPanel
## "My business": missions and the career stage, customer / wholesale orders (plus fish sent to
## auction), the fish show, and the species collection. Everything here is read from the Progress
## and Market autoloads; the panel only displays it and forwards the player's choices.

enum Tab { GOALS, ORDERS, SHOW, COLLECTION }

var _tab: int = Tab.GOALS
var _tab_buttons: Array[Button] = []
var _scroll: ScrollContainer
var _list: VBoxContainer
var _cash_label: Label


func _build() -> void:
	set_title(Localization.t("biz_title"))
	var cash_chip := UiKit.chip(56.0)
	cash_chip.get_meta("row").add_child(UiKit.icon("coin", 30.0))
	_cash_label = UiKit.label("$0", 26, UiKit.COL_GOLD, true)
	cash_chip.get_meta("row").add_child(_cash_label)
	header_extra.add_child(cash_chip)

	var tabs := UiKit.hbox(8)
	body.add_child(tabs)
	var names := [Localization.t("biz_tab_goals"), Localization.t("biz_tab_orders"), Localization.t("biz_tab_show"), Localization.t("biz_tab_collection")]
	for i in range(names.size()):
		var b := UiKit.button(names[i], "tab", 60.0, UiKit.FONT_BODY)
		b.toggle_mode = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		b.pressed.connect(open_tab.bind(i))
		tabs.add_child(b)
		_tab_buttons.append(b)

	_scroll = UiKit.scroll()
	body.add_child(_scroll)
	_list = UiKit.vbox(10)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)

	game.state_changed.connect(func():
		if visible:
			refresh()
	)


func open_tab(tab: int) -> void:
	var changed: bool = tab != _tab or not visible
	_tab = tab
	visible = true
	refresh()
	if changed:
		_scroll.set_deferred("scroll_vertical", 0)


func refresh() -> void:
	for i in range(_tab_buttons.size()):
		_tab_buttons[i].set_pressed_no_signal(i == _tab)
	_cash_label.text = "$%d" % EconomyManager.cash
	var keep_scroll := _scroll.scroll_vertical
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	match _tab:
		Tab.GOALS:
			_fill_goals()
		Tab.ORDERS:
			_fill_orders()
		Tab.SHOW:
			_fill_show()
		Tab.COLLECTION:
			_fill_collection()
	UiKit.pass_mouse(_list)
	_scroll.set_deferred("scroll_vertical", keep_scroll)


func _card(color: Color = UiKit.COL_CARD) -> VBoxContainer:
	var card := UiKit.panel(color, 18, 14.0, 12.0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_child(card)
	var column := UiKit.vbox(6)
	card.add_child(column)
	return column


func _note(text: String) -> void:
	var column := _card(UiKit.COL_CARD_DIM)
	column.add_child(UiKit.paragraph(text, UiKit.FONT_BODY, UiKit.COL_MUTED))


# ----------------------------------------------------------------------------------------
# Goals
# ----------------------------------------------------------------------------------------

func _fill_goals() -> void:
	var stage: int = Progress.stage
	var head := _card()
	if GameState.is_career():
		if stage > Goals.STAGE_COUNT:
			head.add_child(UiKit.label(Localization.t("goals_career_done"), UiKit.FONT_HEADING, UiKit.COL_GOOD, true))
		else:
			head.add_child(UiKit.label(Localization.t("goals_stage", [stage, Localization.t("stage_%d" % stage)]), UiKit.FONT_HEADING, UiKit.COL_GOLD, true))
			var p: Vector2i = Progress.stage_progress(stage)
			var row := UiKit.hbox(10)
			head.add_child(row)
			var bar := UiKit.progress(float(p.x) / maxf(1.0, float(p.y)), UiKit.COL_PRIMARY, Vector2(300.0, 18.0))
			bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(bar)
			row.add_child(UiKit.label("%d/%d" % [p.x, p.y], UiKit.FONT_BODY, UiKit.COL_TEXT, true))
			head.add_child(UiKit.paragraph(Localization.t("stage_%d_desc" % stage), UiKit.FONT_SMALL, UiKit.COL_MUTED))
	else:
		head.add_child(UiKit.label(Localization.t("goals_challenges"), UiKit.FONT_HEADING, UiKit.COL_GOLD, true))
		head.add_child(UiKit.paragraph(Localization.t("goals_challenges_desc"), UiKit.FONT_SMALL, UiKit.COL_MUTED))
	if Progress.effective_stage() >= Goals.STAGE_COUNT and not GameState.is_sandbox():
		head.add_child(UiKit.label(Localization.t("goals_visitors", [Progress.last_visitors, Progress.last_visitor_income]), UiKit.FONT_SMALL, UiKit.COL_ACCENT))

	var shown := mini(stage, Goals.STAGE_COUNT)
	var open_rows: Array = []
	var done_rows: Array = []
	for m in Goals.MISSIONS:
		if m[1] > shown:
			continue
		if Progress.completed.has(m[0]):
			done_rows.append(m)
		else:
			open_rows.append(m)
	for m in open_rows:
		_add_mission(m, false)
	for m in done_rows:
		_add_mission(m, true)


func _add_mission(m: Array, done: bool) -> void:
	var column := _card(UiKit.COL_CARD_DIM if done else UiKit.COL_CARD)
	var top := UiKit.hbox(10)
	column.add_child(top)
	if done:
		top.add_child(UiKit.icon("check", 30.0, UiKit.COL_GOOD))
	var title := UiKit.label(Localization.t("ms_%s" % m[0]), UiKit.FONT_BODY, UiKit.COL_MUTED if done else UiKit.COL_TEXT, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.clip_text = true
	top.add_child(title)
	var reward := maxi(1, int(round(m[4] * GameState.reward_multiplier())))
	top.add_child(UiKit.label("+$%d" % reward, UiKit.FONT_BODY, UiKit.COL_GOLD, true))
	if done:
		return
	var value := mini(Progress.metric(m[2]), m[3])
	var row := UiKit.hbox(10)
	column.add_child(row)
	var bar := UiKit.progress(float(value) / float(m[3]), UiKit.COL_ACCENT, Vector2(300.0, 14.0))
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(bar)
	row.add_child(UiKit.label("%d/%d" % [value, m[3]], UiKit.FONT_SMALL, UiKit.COL_MUTED))


# ----------------------------------------------------------------------------------------
# Orders (and auctions)
# ----------------------------------------------------------------------------------------

func _fill_orders() -> void:
	if Market.orders.is_empty():
		_note(Localization.t("orders_empty", [Market.max_open_orders()]))
	for order in Market.orders:
		_add_order(order)
	if not Market.auctions.is_empty():
		var column := _card(UiKit.COL_CARD_DIM)
		column.add_child(UiKit.label(Localization.t("auction_title"), UiKit.FONT_BODY, UiKit.COL_ACCENT, true))
		for a in Market.auctions:
			column.add_child(UiKit.label(Localization.t("auction_row", [a["fish_name"], Localization.t("sp_%s" % a["species_id"]), int(a["days_left"])]), UiKit.FONT_SMALL, UiKit.COL_MUTED))
	_note(Localization.t("auction_hint"))


func order_request_text(order: Dictionary) -> String:
	var parts: Array = ["%d × %s" % [int(order["count"]), Localization.t("sp_%s" % order["species_id"])]]
	if int(order["sex"]) == FishController.Sex.MALE:
		parts.append(Localization.t("order_sex_male"))
	elif int(order["sex"]) == FishController.Sex.FEMALE:
		parts.append(Localization.t("order_sex_female"))
	parts.append(Localization.t("order_adult") if order["adult_only"] else Localization.t("order_any_stage"))
	parts.append(Localization.t("order_min_health", [int(order["min_health"])]))
	return " · ".join(parts)


func _add_order(order: Dictionary) -> void:
	var ready: bool = Market.can_fulfill(order)
	var have: int = Market.matching_fish(order).size()
	var card := UiKit.panel(UiKit.COL_CARD, 18, 14.0, 12.0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_child(card)
	var row := UiKit.hbox(12)
	card.add_child(row)
	row.add_child(UiKit.texture_icon("res://assets/fish/%s.png" % order["species_id"], Vector2(120.0, 80.0)))

	var text := UiKit.vbox(2)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(text)
	var kind_key := "order_wholesale" if order["kind"] == "wholesale" else "order_customer"
	var who := Localization.t("cust_%d" % int(order["customer"]))
	text.add_child(UiKit.label("%s · %s" % [who, Localization.t(kind_key)], UiKit.FONT_SMALL, UiKit.COL_ACCENT))
	text.add_child(UiKit.paragraph(order_request_text(order), UiKit.FONT_BODY, UiKit.COL_TEXT, 2))
	var status := Localization.t("order_have", [mini(have, int(order["count"])), int(order["count"])]) + " · " + Localization.t("order_days_left", [int(order["days_left"])])
	text.add_child(UiKit.label(status, UiKit.FONT_SMALL, UiKit.COL_GOOD if ready else UiKit.COL_WARN))

	var order_id: int = int(order["id"])
	var deliver := UiKit.action_button("$%d" % int(order["reward"]), UiKit.label(Localization.t("order_deliver"), UiKit.FONT_SMALL, UiKit.COL_TEXT, true), "primary" if ready else "secondary", true, Vector2(140.0, 80.0), 26)
	UiKit.on_tap(deliver, _scroll, func(): _deliver(order_id))
	deliver.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(deliver)


func _deliver(order_id: int) -> void:
	if Market.fulfill_order(order_id) < 0:
		game.toast(Localization.t("order_missing"), "bad")


# ----------------------------------------------------------------------------------------
# Fish show
# ----------------------------------------------------------------------------------------

func _fill_show() -> void:
	if Progress.effective_stage() < 2:
		_note(Localization.t("show_locked"))
		return
	var contest: Dictionary = Market.contest
	if contest.is_empty():
		_note(Localization.t("show_none", [maxi(1, int(ceil(Market.next_contest_in)))]))
		return
	var head := _card()
	head.add_child(UiKit.label(Localization.t("show_theme_%d" % int(contest["theme"])), UiKit.FONT_HEADING, UiKit.COL_GOLD, true))
	head.add_child(UiKit.paragraph(Localization.t("show_desc", [int(contest["days_left"]), int(contest["fee"])]), UiKit.FONT_SMALL, UiKit.COL_MUTED))

	if bool(contest["entered"]):
		var result: Dictionary = contest["result"]
		var column := _card(UiKit.COL_CARD_DIM)
		var place := int(result["place"])
		column.add_child(UiKit.label(Localization.t("show_result_place", [place]), UiKit.FONT_HEADING, UiKit.COL_GOOD if place <= 3 else UiKit.COL_WARN, true))
		column.add_child(UiKit.paragraph(Localization.t("show_result_detail", [result["fish_name"], float(result["score"])]), UiKit.FONT_BODY, UiKit.COL_TEXT))
		var rival_texts: Array = []
		for r in result["rivals"]:
			rival_texts.append("%.1f" % float(r))
		column.add_child(UiKit.paragraph(Localization.t("show_result_rivals", [", ".join(rival_texts)]), UiKit.FONT_SMALL, UiKit.COL_MUTED))
		column.add_child(UiKit.label(Localization.t("show_result_prize", [int(result["prize"])]), UiKit.FONT_BODY, UiKit.COL_GOLD, true))
		return

	var fish_list := Market.eligible_for_contest()
	if fish_list.is_empty():
		_note(Localization.t("show_no_fish"))
		return
	_note(Localization.t("show_pick"))
	var shown := 0
	for fish in fish_list:
		if shown >= 12:
			break
		shown += 1
		var card := UiKit.panel(UiKit.COL_CARD, 18, 12.0, 8.0)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_list.add_child(card)
		var row := UiKit.hbox(12)
		card.add_child(row)
		row.add_child(UiKit.texture_icon("res://assets/fish/%s.png" % fish.species.id, Vector2(100.0, 64.0)))
		var text := UiKit.vbox(0)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(text)
		text.add_child(UiKit.label(fish.fish_name, UiKit.FONT_BODY, UiKit.COL_TEXT, true))
		text.add_child(UiKit.label("%s · %s" % [Localization.t("sp_%s" % fish.species.id), Localization.t("show_score", [Market.contest_score(fish)])], UiKit.FONT_SMALL, UiKit.COL_MUTED))
		var enter := UiKit.action_button("$%d" % int(contest["fee"]), UiKit.label(Localization.t("show_enter"), UiKit.FONT_SMALL, UiKit.COL_TEXT, true), "primary" if EconomyManager.can_afford(int(contest["fee"])) else "secondary", true, Vector2(130.0, 70.0), 24)
		UiKit.on_tap(enter, _scroll, func(): _enter(fish))
		enter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(enter)


func _enter(fish: FishController) -> void:
	if not is_instance_valid(fish):
		return
	if Market.enter_contest(fish).is_empty():
		game.toast(Localization.t("alert_not_enough_cash"), "bad")
		return
	AudioManager.play("fanfare")
	game.state_changed.emit()


# ----------------------------------------------------------------------------------------
# Collection
# ----------------------------------------------------------------------------------------

func _fill_collection() -> void:
	var total: int = ShopManager.species_catalog.size()
	var head := _card()
	head.add_child(UiKit.label(Localization.t("coll_title", [Progress.owned_species.size(), total]), UiKit.FONT_HEADING, UiKit.COL_GOLD, true))
	head.add_child(UiKit.label(Localization.t("coll_bred", [Progress.bred_species.size(), total, Progress.morph_count()]), UiKit.FONT_SMALL, UiKit.COL_ACCENT))
	head.add_child(UiKit.paragraph(Localization.t("coll_desc"), UiKit.FONT_SMALL, UiKit.COL_MUTED))

	var grid := GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	_list.add_child(grid)
	var species_list: Array = ShopManager.species_catalog.values()
	species_list.sort_custom(func(a, b):
		if a.is_marine != b.is_marine:
			return not a.is_marine
		if a.unlock_tier != b.unlock_tier:
			return a.unlock_tier < b.unlock_tier
		return a.id < b.id
	)
	for species in species_list:
		var owned: bool = Progress.owned_species.has(species.id)
		var bred: bool = Progress.bred_species.has(species.id)
		var tile := UiKit.panel(UiKit.COL_CARD if owned else UiKit.COL_CARD_DIM, 14, 8.0, 8.0)
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(tile)
		var column := UiKit.vbox(2)
		column.alignment = BoxContainer.ALIGNMENT_CENTER
		tile.add_child(column)
		var art := UiKit.texture_icon("res://assets/fish/%s.png" % species.id, Vector2(110.0, 64.0))
		if not owned:
			art.modulate = Color(0.0, 0.0, 0.0, 0.45)
		column.add_child(art)
		var name_label := UiKit.label(Localization.t("sp_%s" % species.id) if owned else "?", UiKit.FONT_SMALL, UiKit.COL_TEXT if owned else UiKit.COL_MUTED, owned)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.clip_text = true
		column.add_child(name_label)
		var badge := UiKit.hbox(2)
		badge.alignment = BoxContainer.ALIGNMENT_CENTER
		column.add_child(badge)
		badge.add_child(UiKit.icon("star", 18.0, UiKit.COL_GOLD if bred else Color(1, 1, 1, 0.15)))
