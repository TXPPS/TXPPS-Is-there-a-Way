shader_type canvas_item;

// The whole post stack, in one fullscreen pass on a CanvasLayer below the HUD.
//
// Below the HUD deliberately: grading and graining the interface would make
// small text on a phone harder to read, and this game's interface is the only
// thing in it that has to be legible in daylight.
//
// Tonemapping is NOT here. Godot's Environment does it on the hardware path for
// free, and doing it twice is how a grade ends up fighting a curve. The order
// is therefore: engine tonemap -> [distort, bloom, LUT, grain, dither,
// vignette] -> HUD. See docs/ART_BIBLE.md, "Post-process stack".

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform sampler2D grade_lut : repeat_disable, filter_linear;

group_uniforms distortion;
// Edge-weighted, both of them: the centre of the frame is untouched, because a
// distorted centre is a headache and a distorted edge is a lens.
uniform float barrel_amount : hint_range(0.0, 0.2) = 0.045;
uniform float chroma_amount : hint_range(0.0, 0.02) = 0.0035;

group_uniforms bloom;
// Thresholded high so only the practicals bloom. A bloom that catches the
// concrete is a bloom that turns the dark grey.
uniform float bloom_threshold : hint_range(0.0, 2.0) = 0.78;
uniform float bloom_strength : hint_range(0.0, 2.0) = 0.55;
uniform vec3 bloom_tint : source_color = vec3(1.0, 0.78, 0.52);

group_uniforms grade;
uniform float lut_amount : hint_range(0.0, 1.0) = 1.0;
uniform float exposure : hint_range(0.2, 2.5) = 1.0;

group_uniforms grain;
uniform float grain_amount : hint_range(0.0, 0.25) = 0.035;
// 1.0 is round grain; above that it stretches horizontally, which is what film
// pulled through a gate does and what a rising fear state leans into.
uniform float grain_anisotropy : hint_range(1.0, 8.0) = 1.0;
uniform float grain_speed : hint_range(0.0, 60.0) = 24.0;

group_uniforms shadows;
// The fix for the banding in the P0 screenshots. An 8x8 ordered matrix costs
// one modulo and no texture, and it is the difference between a falloff and a
// staircase on an 8-bit display.
uniform float dither_amount : hint_range(0.0, 4.0) = 1.0;
uniform float dither_ceiling : hint_range(0.0, 1.0) = 0.35;

group_uniforms vignette;
uniform float vignette_amount : hint_range(0.0, 1.0) = 0.0;


// Bayer 8x8 by the standard recursion, computed rather than looked up:
//   M(2n) = [[4M+0, 4M+2], [4M+3, 4M+1]]
// Reading the bits of x and y from the top down builds exactly that nesting,
// which costs three iterations and no texture upload.
float bayer8(vec2 pixel) {
	ivec2 p = ivec2(mod(pixel, 8.0));
	int v = 0;
	for (int i = 2; i >= 0; i--) {
		int xb = (p.x >> i) & 1;
		int yb = (p.y >> i) & 1;
		v = v * 4 + (2 * (xb ^ yb) + yb);
	}
	return (float(v) + 0.5) / 64.0;
}


float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}


vec3 apply_lut(vec3 colour) {
	const float steps = 16.0;
	vec3 c = clamp(colour, vec3(0.0), vec3(1.0));
	float blue = c.b * (steps - 1.0);
	float slice = floor(blue);
	float blend = blue - slice;
	float u_scale = (steps - 1.0) / (steps * steps);
	float u_base = 0.5 / (steps * steps);
	float u0 = u_base + c.r * u_scale + slice / steps;
	float u1 = u_base + c.r * u_scale + min(slice + 1.0, steps - 1.0) / steps;
	float v = 0.5 / steps + c.g * (steps - 1.0) / steps;
	return mix(texture(grade_lut, vec2(u0, v)).rgb, texture(grade_lut, vec2(u1, v)).rgb, blend);
}


void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 centred = uv - vec2(0.5);
	float radius = dot(centred, centred);

	// Barrel and chromatic aberration share the same edge weight, so they are
	// one lens rather than two effects.
	vec2 warped = uv + centred * radius * barrel_amount;
	float fringe = chroma_amount * radius * 4.0;
	vec3 colour;
	colour.r = texture(screen_tex, warped + centred * fringe).r;
	colour.g = texture(screen_tex, warped).g;
	colour.b = texture(screen_tex, warped - centred * fringe).b;

	// Bloom from the screen's own mip chain: three taps, no extra pass.
	vec3 wide = textureLod(screen_tex, warped, 3.0).rgb
		+ textureLod(screen_tex, warped, 5.0).rgb
		+ textureLod(screen_tex, warped, 7.0).rgb;
	wide /= 3.0;
	vec3 over = max(wide - vec3(bloom_threshold), vec3(0.0));
	colour += over * bloom_strength * bloom_tint;

	colour *= exposure;
	colour = mix(colour, apply_lut(colour), lut_amount);

	// Grain, stretched horizontally as fear rises.
	vec2 grain_uv = vec2(FRAGCOORD.x / max(grain_anisotropy, 1.0), FRAGCOORD.y);
	float noise = hash(grain_uv + vec2(floor(TIME * grain_speed)));
	colour += (noise - 0.5) * grain_amount;

	// Ordered dither, in the shadows only: adding noise to a lit surface is
	// grain's job, and doing it twice looks like a broken sensor.
	float lum = dot(colour, vec3(0.2126, 0.7152, 0.0722));
	float where = 1.0 - smoothstep(0.0, dither_ceiling, lum);
	colour += (bayer8(FRAGCOORD.xy) - 0.5) * (dither_amount / 255.0) * where;

	colour *= mix(1.0, smoothstep(0.85, 0.15, radius * 2.0), vignette_amount);

	COLOR = vec4(max(colour, vec3(0.0)), 1.0);
}
