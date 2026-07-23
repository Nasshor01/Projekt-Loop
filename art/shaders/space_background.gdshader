shader_type spatial;

// Vesmírné pozadí s plynulým pomalým posunem (animace)
uniform sampler2D albedo_texture : source_color;
uniform float scroll_speed_x : hint_range(-0.1, 0.1) = 0.015;
uniform float scroll_speed_y : hint_range(-0.1, 0.1) = 0.008;
uniform float brightness : hint_range(0.5, 1.5) = 0.85;

void fragment() {
	// Pomalý posun UV pro efekt "letu vesmírem" (TIME je v sekundách)
	vec2 uv = UV + vec2(TIME * scroll_speed_x, TIME * scroll_speed_y);
	// Opakování textury, aby pohyb působil nekonečně (pokud je obrázek tilable)
	uv = fract(uv);
	vec4 tex = texture(albedo_texture, uv);
	ALBEDO = tex.rgb * brightness;
}
