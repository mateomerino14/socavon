shader_type spatial;
// Roca del socavón: textura triplanar en paredes y techo, barro con gravilla en el suelo.
// Una segunda lectura a gran escala oscurece y aclara zonas para que no se note la repetición.

uniform sampler2D rock_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_orm : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ground_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ground_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ground_orm : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;

// Repeticiones de la textura por metro.
uniform float rock_tiling = 0.25;
uniform float ground_tiling = 0.45;
// Escala de las manchas grandes respecto a la textura de roca.
uniform float macro_tiling = 0.11;
uniform vec2 macro_brightness = vec2(0.4, 1.05);
// Rango de brillo de la textura que se estira entre oscuro y claro.
uniform vec2 macro_range = vec2(0.03, 0.12);
// Desde qué inclinación una cara cuenta como suelo, y qué tan suave es el paso.
uniform float floor_threshold : hint_range(0.0, 1.0) = 0.65;
uniform float floor_softness : hint_range(0.0, 0.5) = 0.12;
// Nitidez del cruce entre las tres proyecciones.
uniform float blend_sharpness = 4.0;
uniform float occlusion_light_affect : hint_range(0.0, 1.0) = 0.6;

varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// Pesos de las proyecciones X, Y y Z según hacia dónde mira la cara.
vec3 projection_weights(vec3 n) {
	vec3 w = pow(abs(n), vec3(blend_sharpness));
	return w / (w.x + w.y + w.z);
}

// Lee una textura de color o de datos con proyección triplanar.
vec4 triplanar(sampler2D tex, vec3 p, vec3 w) {
	return texture(tex, p.zy) * w.x + texture(tex, p.xz) * w.y + texture(tex, p.xy) * w.z;
}

// Normales triplanares con mezcla "whiteout" para que el relieve siga a cada cara.
vec3 triplanar_normal(sampler2D tex, vec3 p, vec3 n, vec3 w) {
	vec3 tx = texture(tex, p.zy).xyz * 2.0 - 1.0;
	vec3 ty = texture(tex, p.xz).xyz * 2.0 - 1.0;
	vec3 tz = texture(tex, p.xy).xyz * 2.0 - 1.0;
	tx = vec3(tx.xy + n.zy, abs(tx.z) * n.x);
	ty = vec3(ty.xy + n.xz, abs(ty.z) * n.y);
	tz = vec3(tz.xy + n.xy, abs(tz.z) * n.z);
	return normalize(tx.zyx * w.x + ty.xzy * w.y + tz.xyz * w.z);
}

// Normal del suelo: solo la proyección desde arriba.
vec3 floor_normal(sampler2D tex, vec2 uv, vec3 n) {
	vec3 t = texture(tex, uv).xyz * 2.0 - 1.0;
	t = vec3(t.xy + n.xz, abs(t.z) * n.y);
	return normalize(t.xzy);
}

void fragment() {
	vec3 n = normalize(world_normal);
	vec3 w = projection_weights(n);
	vec3 rock_p = world_position * rock_tiling;
	vec2 ground_uv = world_position.xz * ground_tiling;
	float on_floor = smoothstep(
		floor_threshold - floor_softness, floor_threshold + floor_softness, n.y
	);

	vec3 albedo = triplanar(rock_albedo, rock_p, w).rgb;
	vec3 orm = triplanar(rock_orm, rock_p, w).rgb;
	vec3 normal_ws = triplanar_normal(rock_normal, rock_p, n, w);

	albedo = mix(albedo, texture(ground_albedo, ground_uv).rgb, on_floor);
	orm = mix(orm, texture(ground_orm, ground_uv).rgb, on_floor);
	normal_ws = normalize(mix(normal_ws, floor_normal(ground_normal, ground_uv, n), on_floor));

	float macro = triplanar(rock_albedo, rock_p * macro_tiling, w).r;
	albedo *= mix(macro_brightness.x, macro_brightness.y, smoothstep(macro_range.x, macro_range.y, macro));

	ALBEDO = albedo;
	AO = orm.r;
	AO_LIGHT_AFFECT = occlusion_light_affect;
	ROUGHNESS = orm.g;
	NORMAL = normalize((VIEW_MATRIX * vec4(normal_ws, 0.0)).xyz);
}
