extends RefCounted
class_name FishVisualBuilder2D
## Builds a fish's 2D visual: an illustrated sprite if one exists for the species at
## res://assets/fish/<species_id>.png, otherwise falls back to FishShapeBuilder2D's
## procedural shape so a species is still playable before its art arrives.

static func build(species: FishSpeciesData) -> Node2D:
	var sprite_path := "res://assets/fish/%s.png" % species.id
	if ResourceLoader.exists(sprite_path):
		return _build_sprite(species, sprite_path)
	return FishShapeBuilder2D.build(species)


static func _build_sprite(species: FishSpeciesData, path: String) -> Node2D:
	var visual := Node2D.new()
	visual.name = "Visual2D"
	var sprite := Sprite2D.new()
	sprite.texture = load(path)
	sprite.centered = true
	# These sprites are scaled down a lot (full-size art -> a few dozen px in-tank); without
	# mipmaps, fine detail like the cleaner shrimp's antennae aliases into speckles.
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# Normalize to the same per-archetype width as the procedural shapes, so a sprite and a
	# fallback shape swimming in the same tank read at a consistent scale.
	var target_size: Vector2 = FishShapeBuilder2D.ARCHETYPE_SIZE.get(
		species.archetype_id, FishShapeBuilder2D.ARCHETYPE_SIZE["livebearer"]
	)
	var tex_size: Vector2 = sprite.texture.get_size()
	if tex_size.x > 0:
		sprite.scale = Vector2.ONE * (target_size.x / tex_size.x)
	visual.add_child(sprite)
	return visual
