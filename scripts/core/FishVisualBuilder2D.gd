extends RefCounted
class_name FishVisualBuilder2D
## Builds a fish's 2D visual: an illustrated sprite if one exists for the species at
## res://assets/fish/<species_id>.png (drawn through the fish_swim shader so the body actually
## undulates), otherwise FishShapeBuilder2D's procedural shape so a species is still playable
## before its art arrives.
##
## The returned root has meta "material" (the per-fish ShaderMaterial, or null for the
## procedural fallback) and meta "half_height" (px at scale 1, for placing a floor shadow).

const SWIM_SHADER := preload("res://shaders/fish_swim.gdshader")
## Must match the shader's `margin` default: the art is drawn this much smaller inside its quad.
const SHADER_MARGIN := 0.12


## On-screen length in pixels (at visual scale 1, full-grown) — a square-root curve of the real
## size, so a 30cm oscar is clearly a big fish next to a 4cm tetra without filling the screen.
static func display_length(species: FishSpeciesData) -> float:
	return 22.0 + 11.0 * sqrt(maxf(species.max_size_cm, 1.0))


static func build(species: FishSpeciesData) -> Node2D:
	var sprite_path := "res://assets/fish/%s.png" % species.id
	if ResourceLoader.exists(sprite_path):
		return _build_sprite(species, sprite_path)
	var fallback := FishShapeBuilder2D.build(species)
	fallback.set_meta("material", null)
	fallback.set_meta("half_height", 12.0)
	return fallback


static func _build_sprite(species: FishSpeciesData, path: String) -> Node2D:
	var visual := Node2D.new()
	visual.name = "Visual2D"
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = load(path)
	sprite.centered = true
	# These sprites are scaled down a lot; without mipmaps fine detail (shrimp antennae,
	# lionfish spines) aliases into speckles.
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var tex_size: Vector2 = sprite.texture.get_size()
	# Tall bodies (angelfish, seahorse) are measured by their height so they don't tower.
	var longest: float = maxf(tex_size.x, tex_size.y * 1.25)
	var art_scale: float = display_length(species) / maxf(longest, 1.0)
	sprite.scale = Vector2.ONE * art_scale * (1.0 + 2.0 * SHADER_MARGIN)

	var material := ShaderMaterial.new()
	material.shader = SWIM_SHADER
	material.set_shader_parameter("margin", SHADER_MARGIN)
	sprite.material = material
	visual.add_child(sprite)
	visual.set_meta("material", material)
	visual.set_meta("half_height", tex_size.y * art_scale * 0.5)
	return visual
