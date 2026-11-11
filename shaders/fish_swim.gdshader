shader_type canvas_item;

// Makes a flat fish illustration swim. The sprite always faces right, so the head is at the
// right edge of the texture and the tail at the left. A travelling sine wave bends the picture
// sideways (in screen space: up/down), stiff at the head and whipping at the tail, exactly the
// way a real fish throws a wave down its body. FishController advances `phase` faster when the
// fish accelerates and raises `amplitude` during a burst, so the tail visibly works harder
// when the fish speeds up and almost stops when it glides.
//
// The art is drawn slightly smaller than its quad (`margin`) so the bent tail has room and is
// never clipped at the quad's edge; FishVisualBuilder2D scales the sprite up to compensate.

uniform float phase = 0.0;
uniform float amplitude : hint_range(0.0, 0.2) = 0.035;   // tail swing, in texture heights
uniform float wave_length : hint_range(0.2, 3.0) = 0.9;   // waves along the body
uniform float stiff_head : hint_range(0.0, 0.9) = 0.3;    // fraction of the body that stays rigid
uniform float bend = 0.0;                                 // whole-body curve while turning (-1..1)
uniform float margin : hint_range(0.0, 0.3) = 0.12;
uniform float breathe = 0.0;                              // 0..1 gentle pulsing of the body height
uniform float upright = 0.0;                              // 1 = seahorse-like: sway instead of wave

varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec2 uv = (UV - 0.5) * (1.0 + 2.0 * margin) + 0.5;
	float along = 1.0 - uv.x;                       // 0 at the head, 1 at the tail tip
	float flex = smoothstep(stiff_head, 1.0, along);
	flex = flex * (0.35 + 0.65 * flex);             // the tail tip swings widest

	// Travelling wave down the body, plus the head counter-swinging a little the other way.
	float wave = sin(along * 6.2831853 * wave_length - phase) * amplitude * flex;
	wave += sin(-phase) * amplitude * 0.12 * (0.5 - along);
	// A slow C-shaped curve of the whole body while the fish turns.
	wave += bend * 0.06 * (along - 0.5) * (along - 0.5) * 4.0;

	// Upright swimmers (seahorses) just rock gently around their middle.
	float sway = sin(phase * 0.5) * amplitude * 1.5 * (uv.y - 0.5);
	vec2 sample_uv = uv;
	sample_uv.y += mix(wave, 0.0, upright);
	sample_uv.x += sway * upright;
	// Breathing: the belly swells and relaxes a touch.
	sample_uv.y = (sample_uv.y - 0.5) * (1.0 - breathe * 0.03 * sin(phase * 0.25)) + 0.5;

	vec4 color = vec4(0.0);
	if (sample_uv.x >= 0.0 && sample_uv.x <= 1.0 && sample_uv.y >= 0.0 && sample_uv.y <= 1.0) {
		color = texture(TEXTURE, sample_uv);
	}
	COLOR = color * tint;
}
