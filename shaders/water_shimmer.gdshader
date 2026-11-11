shader_type canvas_item;
render_mode blend_add;

// Applied to a full-tank Polygon2D that sits right on top of the illustrated background (see
// TankController._rebuild_shimmer). Draws nothing but light: a cheap moving caustic-like
// shimmer plus faint diagonal "god ray" glints, added over the art underneath — pure math, no
// texture sampling, so it's safe at mobile scale. Requires the polygon's uv array to be set to
// the unit square so UV is predictable regardless of the tank's on-screen size.

uniform float shimmer_speed : hint_range(0.0, 3.0) = 0.6;
uniform float shimmer_strength : hint_range(0.0, 1.0) = 0.10;
uniform float ray_speed : hint_range(0.0, 2.0) = 0.15;
uniform float ray_strength : hint_range(0.0, 1.0) = 0.09;

void fragment() {
	vec2 uv = UV;

	float shimmer = sin((uv.x * 14.0 + uv.y * 6.0) + TIME * shimmer_speed * 6.0) * 0.5 + 0.5;
	shimmer *= sin((uv.x * 6.0 - uv.y * 9.0) - TIME * shimmer_speed * 4.0) * 0.5 + 0.5;
	shimmer *= smoothstep(0.0, 0.6, 1.0 - uv.y); // fades out toward the sand

	float ray = sin((uv.x * 4.0 - uv.y * 1.5) * 6.2831853 + TIME * ray_speed) * 0.5 + 0.5;
	ray = pow(ray, 4.0) * smoothstep(1.0, 0.1, uv.y); // brightest near the surface

	float light = shimmer * shimmer_strength + ray * ray_strength;
	COLOR = vec4(vec3(0.75, 0.95, 1.0) * light, 1.0);
}
