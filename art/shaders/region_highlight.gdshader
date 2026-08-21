shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, fog_disabled, shadows_disabled;

uniform vec4 highlight_color : source_color = vec4(0.3, 0.55, 1.0, 1.0);
uniform float fill_alpha : hint_range(0.0, 1.0) = 0.2;
uniform float edge_alpha : hint_range(0.0, 1.0) = 0.92;
uniform float edge_softness : hint_range(0.02, 0.4) = 0.14;
uniform float edge_core : hint_range(0.0, 0.12) = 0.03;
uniform float glow_strength : hint_range(0.0, 2.0) = 0.65;
// 1 = same-region neighbor on that side (no outer rim).
uniform float n_north = 0.0;
uniform float n_east = 0.0;
uniform float n_south = 0.0;
uniform float n_west = 0.0;

void fragment() {
	// Custom XZ quad: UV.x -> local X, UV.y -> local Z (-Z = north).
	float dist_outer = 1.0;
	if (n_west < 0.5) {
		dist_outer = min(dist_outer, UV.x);
	}
	if (n_east < 0.5) {
		dist_outer = min(dist_outer, 1.0 - UV.x);
	}
	if (n_north < 0.5) {
		dist_outer = min(dist_outer, UV.y);
	}
	if (n_south < 0.5) {
		dist_outer = min(dist_outer, 1.0 - UV.y);
	}

	float rim = 1.0 - smoothstep(edge_core, edge_softness, dist_outer);
	float alpha = mix(fill_alpha, edge_alpha, rim);

	ALBEDO = highlight_color.rgb;
	ALPHA = alpha;
	EMISSION = highlight_color.rgb * (rim * glow_strength);
}
