shader_type spatial;
render_mode blend_mix, cull_back;
// Agua de socavón: oscura, turbia por el mineral y quieta, con ondas lentas que reflejan la lámpara.

uniform vec3 deep_color : source_color = vec3(0.09, 0.08, 0.06);
uniform vec3 murk_color : source_color = vec3(0.24, 0.16, 0.08);
uniform float opacity : hint_range(0.0, 1.0) = 0.6;
uniform float murk_amount : hint_range(0.0, 1.0) = 0.5;
uniform sampler2D ripple_normal : hint_normal, filter_linear_mipmap, repeat_enable;
// Repeticiones de las ondas por metro y su velocidad.
uniform float ripple_tiling = 0.6;
uniform vec2 ripple_speed = vec2(0.02, 0.013);
uniform float ripple_strength : hint_range(0.0, 1.0) = 0.35;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = world_position.xz * ripple_tiling;
	vec3 first = texture(ripple_normal, uv + TIME * ripple_speed).xyz;
	vec3 second = texture(ripple_normal, uv * 1.7 - TIME * ripple_speed.yx).xyz;
	float murk = texture(ripple_normal, uv * 0.15).x;
	ALBEDO = mix(deep_color, murk_color, murk * murk_amount);
	ALPHA = opacity;
	ROUGHNESS = 0.04;
	SPECULAR = 0.9;
	METALLIC = 0.2;
	NORMAL_MAP = normalize(mix(first, second, 0.5));
	NORMAL_MAP_DEPTH = ripple_strength;
}
