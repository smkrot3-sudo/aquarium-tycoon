extends ModalPanel
class_name WelcomePanel
## Shown once when a brand-new game starts: the whole loop in four short lines, then one big
## button straight into the shop. (The full version lives in the Guide's "how to play" tab.)

const STEPS := 4


func _build() -> void:
	set_title(Localization.t("welcome_title"))
	var list := UiKit.vbox(8)
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(list)
	for i in range(STEPS):
		var card := UiKit.panel(UiKit.COL_CARD, 16, 14.0, 10.0)
		list.add_child(card)
		var row := UiKit.hbox(14)
		card.add_child(row)
		var badge := UiKit.panel(UiKit.COL_PRIMARY, 24, 0.0, 0.0)
		badge.custom_minimum_size = Vector2(48.0, 48.0)
		badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var number := UiKit.label(str(i + 1), UiKit.FONT_HEADING, UiKit.COL_TEXT, true)
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.add_child(number)
		row.add_child(badge)
		row.add_child(UiKit.paragraph(Localization.t("welcome_step_%d" % (i + 1)), UiKit.FONT_BODY, UiKit.COL_TEXT))

	var go := UiKit.action_button(Localization.t("welcome_go"), UiKit.icon("bag", 32.0), "primary", false, Vector2(420.0, 76.0), 28)
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	go.pressed.connect(func(): game.open_shop(ShopPanel.Tab.EQUIPMENT))
	body.add_child(go)
