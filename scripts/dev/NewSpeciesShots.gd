extends Node
## Dev-only: screenshots of the shop and the encyclopedia showing the 1.8 species.
var _main: GameController
var _dir := ""

func _settle(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_dir, name])

func _ready() -> void:
	_dir = OS.get_environment("SHOT_DIR")
	_main = load("res://scenes/main/Main.tscn").instantiate()
	add_child(_main)
	await _settle(5)
	_main.begin_new_game(GameState.Mode.FREE, GameState.Difficulty.NORMAL)
	_main.close_panels()
	GameState.mode = GameState.Mode.SANDBOX
	EconomyManager.apply_mode()
	EconomyManager.add_xp(Levels.xp_for_level(50))
	EconomyManager.cash = 100000
	Progress.loading = true
	_main.open_shop(ShopPanel.Tab.FRESH)
	await _settle(15)
	await _shot("shop_fresh")
	_main.open_shop(ShopPanel.Tab.TANKS)
	await _settle(15)
	await _shot("shop_tanks")
	_main.open_guide()
	await _settle(10)
	for id in ["koi", "silver_arowana", "ocellate_stingray", "maxima_clam"]:
		_main.guide.show_species(ShopManager.get_species(id))
		await _settle(10)
		await _shot("guide_" + id)
	get_tree().quit()
