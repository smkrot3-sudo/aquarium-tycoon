extends Node
## Dev-only: boots the real Main scene, stocks the tank with a few fish so the shot isn't
## empty, waits for rendering to settle, and saves a PNG. Not part of the shipped game.

func _ready() -> void:
	var main_scene: PackedScene = load("res://scenes/main/Main.tscn")
	var main: Node = main_scene.instantiate()
	add_child(main)

	await get_tree().process_frame
	await get_tree().process_frame

	main._on_buy_equipment("basic_filter")
	main._on_buy_equipment("basic_light")
	main._on_buy_fish("guppy")
	main._on_buy_fish("guppy")
	main._on_buy_fish("neon_tetra")
	main._on_buy_fish("neon_tetra")
	main._on_buy_fish("cherry_shrimp")

	for i in range(30):
		await get_tree().process_frame

	var image := get_viewport().get_texture().get_image()
	var out_path := "C:/Users/Smkro/AppData/Local/Temp/claude/d528264c1ede9f9d/b9c8c669-f1ed-4965-989e-19b340674cff/scratchpad/aquarium_screenshot.png"
	var err := image.save_png(out_path)
	print("Screenshot save result: ", err, " -> ", out_path)
	print("Image size: ", image.get_size())

	## Second shot: the marine/reef tank, with its own tinted decor + species.
	EconomyManager.earn(300, "test funds for marine tank screenshot")
	main._on_buy_tank("marine_reef_tank")
	main._on_buy_equipment("protein_skimmer")
	main._on_buy_fish("clownfish")
	main._on_buy_fish("blue_green_chromis")
	main._on_buy_fish("blue_green_chromis")
	main._on_buy_fish("cleaner_shrimp")

	for i in range(30):
		await get_tree().process_frame

	var image2 := get_viewport().get_texture().get_image()
	var out_path2 := "C:/Users/Smkro/AppData/Local/Temp/claude/d528264c1ede9f9d/b9c8c669-f1ed-4965-989e-19b340674cff/scratchpad/aquarium_screenshot_marine.png"
	var err2 := image2.save_png(out_path2)
	print("Marine screenshot save result: ", err2, " -> ", out_path2)

	## Third shot: the in-game Guide/Encyclopedia screen (fish tab), to verify the dynamically
	## built cards (icon/name/description/stats) actually render.
	main.get_node("UI/GuidePanel").open()
	for i in range(10):
		await get_tree().process_frame
	var image3 := get_viewport().get_texture().get_image()
	var out_path3 := "C:/Users/Smkro/AppData/Local/Temp/claude/d528264c1ede9f9d/b9c8c669-f1ed-4965-989e-19b340674cff/scratchpad/aquarium_guide.png"
	var err3 := image3.save_png(out_path3)
	print("Guide screenshot save result: ", err3, " -> ", out_path3)

	## Fourth shot: same Guide screen, switched to English — the language toggle rebuilds the
	## whole screen live (Localization.language_changed), so this is also a quick regression
	## check that switching languages while the Guide is open doesn't break it.
	Localization.set_language("en")
	for i in range(10):
		await get_tree().process_frame
	var image4 := get_viewport().get_texture().get_image()
	var out_path4 := "C:/Users/Smkro/AppData/Local/Temp/claude/d528264c1ede9f9d/b9c8c669-f1ed-4965-989e-19b340674cff/scratchpad/aquarium_guide_en.png"
	var err4 := image4.save_png(out_path4)
	print("Guide EN screenshot save result: ", err4, " -> ", out_path4)

	get_tree().quit()
