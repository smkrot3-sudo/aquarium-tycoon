extends RefCounted
class_name TankDecorBuilder2D
## 2D counterpart to the old TankDecorBuilder (3D) — purely cosmetic plant/rock/coral clutter so
## the tank doesn't read as an empty water rectangle. `rect` is the tank's current on-screen view
## rect (TankController._view_rect), so decor repositions correctly if the window is resized.
##
## Prefers illustrated sprites (res://assets/decor/plant_freshwater.png, rock.png,
## coral_marine.png — see assets/process_assets.py for how they're generated) and falls back to
## the original procedural Line2D/Polygon2D shapes only if a sprite is missing, same
## fallback pattern as FishVisualBuilder2D.

const PLANT_SPRITE := "res://assets/decor/plant_freshwater.png"
const CORAL_SPRITE := "res://assets/decor/coral_marine.png"
const ROCK_SPRITE := "res://assets/decor/rock.png"


static func build(is_marine: bool, rect: Rect2) -> Node2D:
	var decor := Node2D.new()
	decor.name = "Decor"

	var baseline_y: float = rect.position.y + rect.size.y * 0.93
	var plant_sprite := CORAL_SPRITE if is_marine else PLANT_SPRITE
	var plant_target_height: float = rect.size.y * (0.16 if is_marine else 0.22)

	var cluster_count := 3
	for i in range(cluster_count):
		var pos := Vector2(rect.position.x + rect.size.x * randf_range(0.08, 0.92), baseline_y)
		if ResourceLoader.exists(plant_sprite):
			decor.add_child(_make_sprite_decor(plant_sprite, pos, plant_target_height, true))
		else:
			var blade_count := randi_range(4, 6)
			for b in range(blade_count):
				var base := pos + Vector2(randf_range(-14.0, 14.0), 0.0)
				decor.add_child(_make_plant_blade(base, is_marine))

	var rock_count := 2
	for i in range(rock_count):
		var pos := Vector2(rect.position.x + rect.size.x * randf_range(0.1, 0.9), baseline_y)
		if ResourceLoader.exists(ROCK_SPRITE):
			decor.add_child(_make_sprite_decor(ROCK_SPRITE, pos, rect.size.y * 0.1, false))
		else:
			decor.add_child(_make_rock(pos))

	return decor


## Anchors the sprite's bottom-center at `pos`, scaled so its height matches `target_height`.
static func _make_sprite_decor(path: String, pos: Vector2, target_height: float, anchor_bottom: bool) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = load(path)
	sprite.centered = false
	var tex_size: Vector2 = sprite.texture.get_size()
	var s: float = target_height / maxf(tex_size.y, 1.0)
	sprite.scale = Vector2.ONE * s
	var offset := Vector2(-tex_size.x * s * 0.5, -tex_size.y * s if anchor_bottom else -tex_size.y * s * 0.5)
	sprite.position = pos + offset
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return sprite


static func _make_plant_blade(base: Vector2, is_marine: bool) -> Line2D:
	var height := randf_range(28.0, 60.0)
	var tip := base + Vector2(randf_range(-10.0, 10.0), -height)
	var blade := Line2D.new()
	blade.points = PackedVector2Array([
		base, base.lerp(tip, 0.5) + Vector2(randf_range(-8.0, 8.0), 0.0), tip,
	])
	blade.width = 4.0
	if is_marine:
		blade.default_color = Color(0.45 + randf_range(-0.08, 0.08), 0.25, 0.5 + randf_range(-0.08, 0.08))
	else:
		blade.default_color = Color(0.12, 0.45 + randf_range(-0.1, 0.1), 0.18)
	blade.begin_cap_mode = Line2D.LINE_CAP_ROUND
	blade.end_cap_mode = Line2D.LINE_CAP_ROUND
	return blade


static func _make_rock(pos: Vector2) -> Polygon2D:
	var radius := randf_range(10.0, 20.0)
	var rock := Polygon2D.new()
	var points := PackedVector2Array()
	var segments := 10
	for i in range(segments):
		var t: float = float(i) / float(segments) * TAU
		points.append(Vector2(cos(t) * radius * 1.3, sin(t) * radius * 0.65 - radius * 0.5))
	rock.polygon = points
	rock.position = pos
	var shade := randf_range(0.35, 0.55)
	rock.color = Color(shade, shade * 0.95, shade * 0.9)
	return rock
