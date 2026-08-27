shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx;

// One shader for every large surface in the game.
//
// Six materials -- wet concrete, oxidised steel, flaking marine paint, river
// silt, mineral staining, condensation -- are this file with different
// parameters, reading the one 256x256 RGBA tile that tools/gen/make_noise.py
// produces. That is the whole texture budget (docs/BUDGETS.md), and it buys a
// vocabulary rather than six pictures.
//
// Triplanar, because docs/ART_BIBLE.md requires it on anything large enough
// that a UV seam would show, and because a modular kit on a 0.5 m grid is
// nothing but large flat things meeting at right angles.
//
// Deliberately no normal map. Under one sodium practical with hard falloff,
// roughness variation carries the surface and a normal map costs texture
// budget and fetches this target does not have. Whether that reads as material
// on a phone is a device question and is queued in NEEDS_DEVICE_QA.md.

uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;

group_uniforms base;
// Two tones and a mix. The mix weights pick which noise scales drive it, so
// one parameter set gives broad blotching and another gives fine speckle.
uniform vec3 albedo_dark : source_color = vec3(0.10, 0.10, 0.11);
uniform vec3 albedo_light : source_color = vec3(0.20, 0.21, 0.23);
uniform vec4 albedo_weights = vec4(0.2, 0.5, 0.3, 0.0);
uniform float metallic_amount : hint_range(0.0, 1.0) = 0.0;
uniform float specular_amount : hint_range(0.0, 1.0) = 0.5;
// World metres covered by one tile of the texture.
uniform float tile_metres : hint_range(0.05, 8.0) = 2.0;

group_uniforms roughness;
uniform float roughness_low : hint_range(0.0, 1.0) = 0.45;
uniform float roughness_high : hint_range(0.0, 1.0) = 0.85;
uniform vec4 roughness_weights = vec4(0.5, 0.3, 0.2, 0.0);

group_uniforms breakup;
// A second colour with a hard edge: rust as a mask on a steel plate, or paint
// lifting off primer. Never a decal -- it is a threshold on the noise, so it
// tiles and cannot be seen to repeat at the scale a decal would.
uniform vec3 breakup_colour : source_color = vec3(0.16, 0.09, 0.05);
uniform float breakup_amount : hint_range(0.0, 1.0) = 0.0;
uniform float breakup_threshold : hint_range(0.0, 1.0) = 0.55;
uniform float breakup_softness : hint_range(0.001, 0.5) = 0.06;
uniform float breakup_roughness : hint_range(0.0, 1.0) = 0.9;

group_uniforms deposits;
// Silt settles on upward faces and in corners.
uniform vec3 silt_colour : source_color = vec3(0.18, 0.16, 0.12);
uniform float silt_amount : hint_range(0.0, 1.0) = 0.0;
// Mineral staining runs down a vertical face. Channel A of the tile is
// stretched 8:1 for exactly this and is only applied where the face is steep.
uniform vec3 stain_colour : source_color = vec3(0.15, 0.13, 0.09);
uniform float stain_amount : hint_range(0.0, 1.0) = 0.0;

group_uniforms water;
// Everything below the waterline is darker and smoother, with a noisy edge so
// the line reads as a tide mark rather than a plane.
uniform float waterline_y = -100.0;
uniform float waterline_fuzz : hint_range(0.01, 1.0) = 0.25;
uniform float wet_darkening : hint_range(0.0, 1.0) = 0.45;
uniform float wet_roughness : hint_range(0.0, 1.0) = 0.15;

varying vec3 world_position;
varying vec3 world_normal;


vec4 triplanar(vec3 position, vec3 normal, float metres) {
	// Sharp blend: a wide blend smears the tile across a corner and reads as
	// fog. pow 6 keeps each face almost entirely its own projection.
	vec3 blend = pow(abs(normal), vec3(6.0));
	blend /= max(blend.x + blend.y + blend.z, 0.0001);
	vec2 scale = vec2(1.0 / max(metres, 0.001));
	vec4 x = texture(noise_tex, position.zy * scale);
	vec4 y = texture(noise_tex, position.xz * scale);
	vec4 z = texture(noise_tex, position.xy * scale);
	return x * blend.x + y * blend.y + z * blend.z;
}


void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}


void fragment() {
	vec4 n = triplanar(world_position, world_normal, tile_metres);

	float tone = clamp(dot(n, albedo_weights) / max(dot(vec4(1.0), albedo_weights), 0.001), 0.0, 1.0);
	vec3 colour = mix(albedo_dark, albedo_light, tone);
	float rough = mix(roughness_low, roughness_high,
		clamp(dot(n, roughness_weights) / max(dot(vec4(1.0), roughness_weights), 0.001), 0.0, 1.0));

	// Rust, or paint lifting. One threshold, two uses.
	float mask = smoothstep(breakup_threshold, breakup_threshold + breakup_softness, n.g) * breakup_amount;
	colour = mix(colour, breakup_colour, mask);
	rough = mix(rough, breakup_roughness, mask);

	// Deposits. Silt lands on what faces up; stain runs down what stands up.
	float upward = clamp(world_normal.y, 0.0, 1.0);
	float silt = silt_amount * upward * upward * smoothstep(0.35, 0.8, n.b);
	colour = mix(colour, silt_colour, silt);
	rough = mix(rough, 0.95, silt);

	float vertical = 1.0 - abs(world_normal.y);
	float stain = stain_amount * vertical * smoothstep(0.45, 0.9, n.a);
	colour = mix(colour, stain_colour, stain);

	// The tide mark.
	float wet = 1.0 - smoothstep(
		waterline_y - waterline_fuzz * n.r,
		waterline_y + waterline_fuzz * (1.0 + n.b),
		world_position.y
	);
	colour *= mix(1.0, 1.0 - wet_darkening, wet);
	rough = mix(rough, wet_roughness, wet * 0.85);

	ALBEDO = colour;
	ROUGHNESS = clamp(rough, 0.02, 1.0);
	METALLIC = metallic_amount;
	SPECULAR = specular_amount;
}
