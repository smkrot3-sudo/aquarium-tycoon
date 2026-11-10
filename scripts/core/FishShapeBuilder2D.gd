extends RefCounted
class_name FishShapeBuilder2D
## 2D flat/vector fish builder. Unlike the first prototype (archetype shape + one flat color,
## which the user correctly rejected as "can't tell what fish this is"), this version builds
## real distinguishing features per species from data already on FishSpeciesData — fin_variant_id
## picks an actual fin SHAPE (not just a size multiplier) and pattern_id picks a real marking
## (not just a generic texture), so a neon tetra's signature blue stripe, a betta's dramatic
## trailing fins, and a harlequin rasbora's black wedge are each built distinctly. No new fields
## needed: see the species .tres files for the fin_variant_id/pattern_id values driving this.

const ARCHETYPE_SIZE := {
	"livebearer": Vector2(46.0, 26.0),
	"schooler": Vector2(50.0, 18.0),
	"labyrinth": Vector2(38.0, 28.0),
	"bottom_dweller": Vector2(52.0, 20.0),
	# Wider than the procedural shrimp body alone needs, because real shrimp reference photos
	# (and the illustrated sprites) have long antennae that are part of the full width — sizing
	# to the body only shrank those antennae to sub-pixel, aliased speckles once scaled down.
	"invertebrate": Vector2(50.0, 20.0),
}

const WEDGE_COLOR := Color(0.08, 0.08, 0.1)
const CLOWN_BAND_COLOR := Color(0.97, 0.97, 0.95)
const NEON_STRIPE_COLOR := Color(0.1, 0.65, 1.0)
const NEON_REAR_COLOR := Color(0.85, 0.15, 0.1)
const DANIO_STRIPE_COLOR := Color(0.1, 0.12, 0.2)


static func build(species: FishSpeciesData) -> Node2D:
	var visual := Node2D.new()
	visual.name = "Visual2D"

	var size: Vector2 = ARCHETYPE_SIZE.get(species.archetype_id, ARCHETYPE_SIZE["livebearer"])
	var base_color: Color = species.palette_color
	if species.pattern_id == "neon_stripe":
		base_color = Color(0.82, 0.84, 0.88)

	if species.archetype_id == "invertebrate":
		_build_shrimp(visual, size, base_color, species.pattern_id)
		return visual

	_build_tail_fin(visual, size, species.fin_variant_id, base_color)
	var body_points := _build_body(visual, size, base_color, species.archetype_id == "bottom_dweller")
	_apply_pattern(visual, size, body_points, species.pattern_id, species.palette_color)
	_build_dorsal_fin(visual, size, species.fin_variant_id, base_color)
	if species.archetype_id == "bottom_dweller":
		_add_whiskers(visual, size, base_color.darkened(0.3))
	_add_eye(visual, size)

	return visual


static func _body_polygon(size: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	var segments := 28
	var half_w := size.x * 0.5
	var half_h := size.y * 0.5
	for i in range(segments):
		var t: float = float(i) / float(segments) * TAU
		var x: float = cos(t)
		var y: float = sin(t)
		var taper: float = 1.0 if x > 0.0 else lerp(1.0, 0.3, -x)
		points.append(Vector2(x * half_w, y * half_h * taper))
	return points


static func _build_body(visual: Node2D, size: Vector2, base_color: Color, flat_belly: bool) -> PackedVector2Array:
	var points := _body_polygon(size)
	if flat_belly:
		for i in range(points.size()):
			if points[i].y > 0.0:
				points[i].y *= 0.55

	var body := Polygon2D.new()
	body.name = "Body"
	body.polygon = points
	var colors := PackedColorArray()
	var top_color := base_color.lightened(0.18)
	var bottom_color := base_color.darkened(0.22)
	for p in points:
		var blend: float = clampf((p.y / (size.y * 0.5) + 1.0) * 0.5, 0.0, 1.0)
		colors.append(top_color.lerp(bottom_color, blend))
	body.vertex_colors = colors
	visual.add_child(body)

	_add_outline(visual, points, base_color.darkened(0.55), 2.2)
	return points


static func _add_outline(visual: Node2D, points: PackedVector2Array, color: Color, width: float) -> void:
	var outline := Line2D.new()
	var closed := points.duplicate()
	closed.append(points[0])
	outline.points = closed
	outline.width = width
	outline.default_color = color
	outline.joint_mode = Line2D.LINE_JOINT_ROUND
	outline.begin_cap_mode = Line2D.LINE_CAP_ROUND
	outline.end_cap_mode = Line2D.LINE_CAP_ROUND
	visual.add_child(outline)


## Real markings layered on top of the body — each one is a visually distinct, recognizable
## feature rather than a generic "texture", so species sharing a body archetype still read as
## different fish. Positions are hand-fit to the body polygon's extent (size), not a true clip
## mask, which is fine at this scale/simplicity.
static func _apply_pattern(visual: Node2D, size: Vector2, body_points: PackedVector2Array, pattern_id: String, palette_color: Color) -> void:
	match pattern_id:
		"neon_stripe":
			## The real neon tetra's signature: an electric stripe along the upper half, a
			## warm red patch along the lower-rear half.
			var stripe := Polygon2D.new()
			stripe.name = "Stripe"
			stripe.polygon = PackedVector2Array([
				Vector2(-size.x * 0.46, -size.y * 0.08), Vector2(size.x * 0.44, -size.y * 0.14),
				Vector2(size.x * 0.44, size.y * 0.02), Vector2(-size.x * 0.46, size.y * 0.1),
			])
			stripe.color = NEON_STRIPE_COLOR
			visual.add_child(stripe)
			var rear := Polygon2D.new()
			rear.name = "RearPatch"
			rear.polygon = PackedVector2Array([
				Vector2(-size.x * 0.46, size.y * 0.02), Vector2(size.x * 0.05, size.y * 0.05),
				Vector2(size.x * 0.0, size.y * 0.32), Vector2(-size.x * 0.46, size.y * 0.3),
			])
			rear.color = NEON_REAR_COLOR
			visual.add_child(rear)
		"horizontal_stripes":
			var stripe_count := 4
			for i in range(stripe_count):
				var y: float = lerp(-size.y * 0.3, size.y * 0.32, float(i) / float(stripe_count - 1))
				var stripe := Line2D.new()
				stripe.points = PackedVector2Array([Vector2(-size.x * 0.44, y), Vector2(size.x * 0.4, y)])
				stripe.width = size.y * 0.07
				stripe.default_color = DANIO_STRIPE_COLOR
				visual.add_child(stripe)
		"spots":
			var rng_positions := [
				Vector2(-0.15, -0.15), Vector2(0.1, 0.1), Vector2(-0.3, 0.12),
				Vector2(0.28, -0.1), Vector2(0.0, 0.25), Vector2(-0.35, -0.08),
			]
			var spot_color := palette_color.darkened(0.45)
			for rel in rng_positions:
				var spot := Polygon2D.new()
				spot.polygon = _circle_points(Vector2(rel.x * size.x, rel.y * size.y), size.y * 0.09, 8)
				spot.color = spot_color
				visual.add_child(spot)
		"wedge":
			## Harlequin rasbora's black triangular wedge across the rear half of the body.
			var wedge := Polygon2D.new()
			wedge.name = "Wedge"
			wedge.polygon = PackedVector2Array([
				Vector2(-size.x * 0.05, -size.y * 0.32), Vector2(-size.x * 0.48, -size.y * 0.1),
				Vector2(-size.x * 0.48, size.y * 0.28), Vector2(size.x * 0.0, size.y * 0.3),
			])
			wedge.color = WEDGE_COLOR
			visual.add_child(wedge)
		"clown_bands":
			var band_xs := [-0.28, 0.08, 0.4]
			for bx in band_xs:
				var band := Polygon2D.new()
				var half_w: float = size.x * 0.07
				band.polygon = PackedVector2Array([
					Vector2(bx * size.x - half_w, -size.y * 0.45), Vector2(bx * size.x + half_w, -size.y * 0.45),
					Vector2(bx * size.x + half_w, size.y * 0.42), Vector2(bx * size.x - half_w, size.y * 0.42),
				])
				band.color = CLOWN_BAND_COLOR
				visual.add_child(band)
		_:
			pass


static func _build_tail_fin(visual: Node2D, size: Vector2, fin_variant_id: String, base_color: Color) -> void:
	var attach_x: float = -size.x * 0.48
	var fin_color := base_color.lightened(0.1)
	var points: PackedVector2Array

	match fin_variant_id:
		"forked":
			## Fast-swimming schoolers (tetra/danio/rasbora/chromis): a V-notch forked tail.
			var reach: float = size.x * 0.4
			var spread: float = size.y * 0.55
			points = PackedVector2Array([
				Vector2(attach_x, -spread * 0.2), Vector2(attach_x - reach, -spread),
				Vector2(attach_x - reach * 0.55, 0.0), Vector2(attach_x - reach, spread),
				Vector2(attach_x, spread * 0.2),
			])
		"fan":
			## Livebearers (guppy/platy/molly) and honey gourami: a broad rounded fan.
			var reach: float = size.x * 0.42
			var spread: float = size.y * 0.75
			points = PackedVector2Array([
				Vector2(attach_x, -spread * 0.15),
				Vector2(attach_x - reach * 0.5, -spread), Vector2(attach_x - reach, -spread * 0.5),
				Vector2(attach_x - reach * 0.9, 0.0),
				Vector2(attach_x - reach, spread * 0.5), Vector2(attach_x - reach * 0.5, spread),
				Vector2(attach_x, spread * 0.15),
			])
		"veil":
			## Betta: dramatic, oversized trailing fin built from several long overlapping
			## rays — the single biggest "is this a real distinct species" visual cue we have.
			_build_veil_tail(visual, size, base_color)
			return
		_:
			var reach: float = size.x * 0.3
			var spread: float = size.y * 0.5
			points = PackedVector2Array([
				Vector2(attach_x, -spread * 0.2), Vector2(attach_x - reach, -spread * 0.9),
				Vector2(attach_x - reach * 0.6, 0.0), Vector2(attach_x - reach, spread * 0.9),
				Vector2(attach_x, spread * 0.2),
			])

	var fin := Polygon2D.new()
	fin.name = "TailFin"
	fin.polygon = points
	fin.color = fin_color
	visual.add_child(fin)
	_add_outline(visual, points, base_color.darkened(0.5), 1.6)


static func _build_veil_tail(visual: Node2D, size: Vector2, base_color: Color) -> void:
	var attach_x: float = -size.x * 0.46
	var ray_count := 5
	var max_reach: float = size.x * 1.1
	for i in range(ray_count):
		var t: float = float(i) / float(ray_count - 1) - 0.5
		var reach: float = max_reach * (1.0 - abs(t) * 0.5)
		var width: float = size.y * 0.22
		var y_base: float = t * size.y * 1.1
		var ray := Polygon2D.new()
		ray.name = "VeilRay%d" % i
		ray.polygon = PackedVector2Array([
			Vector2(attach_x, y_base - width * 0.3),
			Vector2(attach_x - reach, y_base - width * 0.9),
			Vector2(attach_x - reach * 0.8, y_base),
			Vector2(attach_x - reach, y_base + width * 0.9),
			Vector2(attach_x, y_base + width * 0.3),
		])
		ray.color = base_color.lightened(0.1 - float(i) * 0.03)
		visual.add_child(ray)
	# Matching oversized dorsal + anal fin "drama" for the betta silhouette.
	var dorsal := Polygon2D.new()
	dorsal.polygon = PackedVector2Array([
		Vector2(-size.x * 0.1, -size.y * 0.4), Vector2(size.x * 0.1, -size.y * 1.3),
		Vector2(size.x * 0.3, -size.y * 0.35),
	])
	dorsal.color = base_color.lightened(0.08)
	visual.add_child(dorsal)
	_add_outline(visual, dorsal.polygon, base_color.darkened(0.5), 1.4)
	var anal := Polygon2D.new()
	anal.polygon = PackedVector2Array([
		Vector2(-size.x * 0.05, size.y * 0.35), Vector2(size.x * 0.1, size.y * 1.1),
		Vector2(size.x * 0.28, size.y * 0.32),
	])
	anal.color = base_color.lightened(0.05)
	visual.add_child(anal)
	_add_outline(visual, anal.polygon, base_color.darkened(0.5), 1.4)


static func _build_dorsal_fin(visual: Node2D, size: Vector2, fin_variant_id: String, base_color: Color) -> void:
	if fin_variant_id == "veil":
		return  # handled by _build_veil_tail, which gives the betta a much larger dorsal
	var fin_mult: float = 1.5 if fin_variant_id == "fan" else 1.0
	var base_x: float = size.x * 0.05
	var height: float = size.y * 0.5 * fin_mult
	var points := PackedVector2Array([
		Vector2(base_x - size.x * 0.16, -size.y * 0.42),
		Vector2(base_x + size.x * 0.02, -size.y * 0.42 - height),
		Vector2(base_x + size.x * 0.2, -size.y * 0.42),
	])
	var fin := Polygon2D.new()
	fin.name = "DorsalFin"
	fin.polygon = points
	fin.color = base_color.lightened(0.1)
	visual.add_child(fin)
	_add_outline(visual, points, base_color.darkened(0.5), 1.4)


static func _add_whiskers(visual: Node2D, size: Vector2, color: Color) -> void:
	for side in [-1.0, 1.0]:
		var whisker := Line2D.new()
		var start := Vector2(size.x * 0.44, side * size.y * 0.15)
		whisker.points = PackedVector2Array([start, start + Vector2(size.x * 0.22, side * size.y * 0.3)])
		whisker.width = 1.4
		whisker.default_color = color
		visual.add_child(whisker)


static func _add_eye(visual: Node2D, size: Vector2) -> void:
	var eye_pos := Vector2(size.x * 0.28, -size.y * 0.08)
	var sclera := Polygon2D.new()
	sclera.name = "EyeWhite"
	sclera.polygon = _circle_points(eye_pos, size.y * 0.16, 10)
	sclera.color = Color(0.96, 0.96, 0.94)
	visual.add_child(sclera)
	var pupil := Polygon2D.new()
	pupil.name = "EyePupil"
	pupil.polygon = _circle_points(eye_pos + Vector2(size.x * 0.02, 0.0), size.y * 0.08, 8)
	pupil.color = Color(0.05, 0.05, 0.07)
	visual.add_child(pupil)


static func _circle_points(center: Vector2, radius: float, segments: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(segments):
		var t: float = float(i) / float(segments) * TAU
		points.append(center + Vector2(cos(t), sin(t)) * radius)
	return points


static func _build_shrimp(visual: Node2D, size: Vector2, base_color: Color, pattern_id: String) -> void:
	var points := _body_polygon(size * Vector2(0.9, 0.85))
	var body := Polygon2D.new()
	body.name = "Body"
	body.polygon = points
	var colors := PackedColorArray()
	for p in points:
		var blend: float = clampf((p.y / (size.y * 0.5) + 1.0) * 0.5, 0.0, 1.0)
		colors.append(base_color.lightened(0.2).lerp(base_color.darkened(0.2), blend))
	body.vertex_colors = colors
	visual.add_child(body)
	_add_outline(visual, points, base_color.darkened(0.5), 2.0)

	if pattern_id == "horizontal_stripes":
		for i in range(3):
			var y: float = lerp(-size.y * 0.25, size.y * 0.28, float(i) / 2.0)
			var stripe := Line2D.new()
			stripe.points = PackedVector2Array([Vector2(-size.x * 0.35, y), Vector2(size.x * 0.3, y)])
			stripe.width = size.y * 0.06
			stripe.default_color = base_color.darkened(0.4)
			visual.add_child(stripe)

	for side in [-1.0, 1.0]:
		var antenna := Line2D.new()
		antenna.name = "Antenna%d" % int(side)
		var start := Vector2(size.x * 0.4, side * size.y * 0.15)
		antenna.points = PackedVector2Array([start, start + Vector2(size.x * 0.45, side * size.y * 0.35)])
		antenna.width = 1.4
		antenna.default_color = base_color.darkened(0.3)
		visual.add_child(antenna)
