shader_type canvas_item;
// Warm printed paper: a faint fibre texture and the gentlest darkening
// toward the edges, like a page under a reading lamp.

uniform vec4 paper : source_color = vec4(0.965, 0.945, 0.906, 1.0);
uniform vec4 edge : source_color = vec4(0.905, 0.878, 0.827, 1.0);
// A wash of colour after a big chain, fading back to plain paper.
uniform vec4 tint : source_color = vec4(0.894, 0.314, 0.180, 1.0);
uniform float tint_amount = 0.0;
// Sunset surprise: the paper warms towards evening as the level nears its end.
uniform float dusk = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	vec2 d = UV - vec2(0.5, 0.45);
	float v = smoothstep(0.35, 0.95, length(d * vec2(1.1, 0.9)));
	vec3 col = mix(paper.rgb, edge.rgb, v * 0.8);
	// Paper fibres: long soft streaks plus fine grain.
	float fibre = noise(FRAGCOORD.xy * vec2(0.02, 0.18));
	float grain = hash(floor(FRAGCOORD.xy)) - 0.5;
	col -= fibre * 0.018;
	col += grain * 0.022;
	col = mix(col, tint.rgb, tint_amount * (0.35 + 0.65 * v));
	vec3 evening = mix(vec3(0.99, 0.84, 0.66), vec3(0.93, 0.68, 0.62), UV.y);
	col = mix(col, evening, dusk * (0.28 + 0.2 * v));
	COLOR = vec4(col, 1.0);
}
