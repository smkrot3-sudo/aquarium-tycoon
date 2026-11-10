extends Node2D
## Dev-only style prototype for the 2D art direction pivot — not wired into the real game yet.
## Renders every real species from ShopManager's catalog with its actual fin_variant_id/
## pattern_id/palette_color, so this is a true preview of species recognizability, not just a
## shape-style check.

func _ready() -> void:
	var size := get_viewport_rect().size

	_build_water(size)
	_build_substrate(size)
	_build_glass_frame(size)
	_build_plants(size)

	await get_tree().process_frame

	var species_ids := [
		"guppy", "neon_tetra", "zebra_danio", "platy", "betta", "molly",
		"cory_catfish", "harlequin_rasbora", "honey_gourami", "cherry_shrimp",
		"clownfish", "blue_green_chromis", "cleaner_shrimp",
	]
	var cols := 5
	var margin_x := size.x * 0.08
	var margin_y := size.y * 0.1
	var cell_w: float = (size.x - margin_x * 2.0) / cols
	var cell_h: float = (size.y - margin_y * 2.0) / ceil(float(species_ids.size()) / cols)

	for i in range(species_ids.size()):
		var species: FishSpeciesData = ShopManager.get_species(species_ids[i])
		if species == null:
			print("Missing species: ", species_ids[i])
			continue
		var fish := FishVisualBuilder2D.build(species)
		var col: int = i % cols
		var row: int = i / cols
		fish.position = Vector2(margin_x + cell_w * (col + 0.5), margin_y + cell_h * (row + 0.5))
		fish.scale = Vector2.ONE * 1.1
		add_child(fish)

		var label := Label.new()
		label.text = species.display_name
		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_font_size_override("font_size", 13)
		label.position = Vector2(margin_x + cell_w * col + 4, margin_y + cell_h * (row + 1) - 18)
		add_child(label)

	for i in range(3):
		await get_tree().process_frame

	var image := get_viewport().get_texture().get_image()
	var out_path := "C:/Users/Smkro/AppData/Local/Temp/claude/d528264c1ede9f9d/b9c8c669-f1ed-4965-989e-19b340674cff/scratchpad/prototype_2d.png"
	image.save_png(out_path)
	print("Saved prototype screenshot -> ", out_path)
	get_tree().quit()


func _build_water(size: Vector2) -> void:
	var water := Polygon2D.new()
	water.polygon = PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)])
	water.vertex_colors = PackedColorArray([
		Color(0.35, 0.65, 0.82), Color(0.35, 0.65, 0.82),
		Color(0.08, 0.28, 0.45), Color(0.08, 0.28, 0.45),
	])
	add_child(water)


func _build_substrate(size: Vector2) -> void:
	var h := size.y
	var points := PackedVector2Array([
		Vector2(0, h * 0.97), Vector2(size.x * 0.25, h * 0.94), Vector2(size.x * 0.55, h * 0.96),
		Vector2(size.x * 0.8, h * 0.93), Vector2(size.x, h * 0.95),
		Vector2(size.x, h), Vector2(0, h),
	])
	var substrate := Polygon2D.new()
	substrate.polygon = points
	substrate.color = Color(0.68, 0.56, 0.4)
	add_child(substrate)
	var outline := Line2D.new()
	outline.points = points
	outline.width = 2.0
	outline.default_color = Color(0.45, 0.35, 0.22)
	add_child(outline)


func _build_glass_frame(size: Vector2) -> void:
	var margin := 6.0
	var points := PackedVector2Array([
		Vector2(margin, margin), Vector2(size.x - margin, margin),
		Vector2(size.x - margin, size.y - margin), Vector2(margin, size.y - margin),
		Vector2(margin, margin),
	])
	var frame := Line2D.new()
	frame.points = points
	frame.width = 8.0
	frame.default_color = Color(0.85, 0.92, 0.95, 0.35)
	frame.joint_mode = Line2D.LINE_JOINT_ROUND
	add_child(frame)


func _build_plants(size: Vector2) -> void:
	var cluster_xs := [0.03, 0.97]
	for cx in cluster_xs:
		for b in range(3):
			var blade := Line2D.new()
			var base := Vector2(cx * size.x + randf_range(-10, 10), size.y * 0.97)
			var tip := base + Vector2(randf_range(-8, 8), -randf_range(30, 60))
			blade.points = PackedVector2Array([base, base.lerp(tip, 0.5) + Vector2(randf_range(-6, 6), 0), tip])
			blade.width = 4.0
			blade.default_color = Color(0.12, 0.5 + randf_range(-0.1, 0.1), 0.2)
			blade.begin_cap_mode = Line2D.LINE_CAP_ROUND
			blade.end_cap_mode = Line2D.LINE_CAP_ROUND
			add_child(blade)
