shader_type canvas_item;
// Acabado de cámara para todo el juego: viñeta que cierra la vista y grano de película que se mueve.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.45;
// Desde qué distancia al centro empieza a oscurecer y dónde llega al máximo.
uniform vec2 vignette_range = vec2(0.35, 0.95);
uniform float grain_strength : hint_range(0.0, 0.3) = 0.05;
// Cuántas veces por segundo cambia el grano.
uniform float grain_rate = 24.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec3 color = texture(screen_texture, SCREEN_UV).rgb;
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 centered = (SCREEN_UV - 0.5) * vec2(aspect, 1.0);
	float vignette = smoothstep(vignette_range.x, vignette_range.y, length(centered) * 2.0);
	color *= 1.0 - vignette * vignette_strength;
	float grain = hash(FRAGCOORD.xy + floor(TIME * grain_rate) * 17.0) - 0.5;
	// El grano pesa más en las sombras, como en una película expuesta con poca luz.
	float shadow_weight = 1.0 - clamp(dot(color, vec3(0.333)), 0.0, 1.0);
	color += grain * grain_strength * shadow_weight;
	COLOR = vec4(color, 1.0);
}
