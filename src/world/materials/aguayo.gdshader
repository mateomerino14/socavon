shader_type spatial;
// Aguayo andino: franjas de colores tejidas a lo largo del paño, con trama fina y desgaste.

uniform vec3 color_a : source_color = vec3(0.62, 0.05, 0.12);
uniform vec3 color_b : source_color = vec3(0.95, 0.55, 0.05);
uniform vec3 color_c : source_color = vec3(0.08, 0.32, 0.45);
uniform vec3 color_d : source_color = vec3(0.12, 0.42, 0.16);
uniform vec3 thread_color : source_color = vec3(0.9, 0.85, 0.75);
// Franjas por metro a lo ancho del paño y finura de la trama.
uniform float stripes_per_meter = 18.0;
uniform float weave_per_meter = 220.0;

varying vec3 local_position;

void vertex() {
	local_position = VERTEX;
}

void fragment() {
	float band = floor(local_position.z * stripes_per_meter + local_position.y * stripes_per_meter);
	float pick = mod(band, 4.0);
	vec3 color = color_a;
	color = mix(color, color_b, step(1.0, pick) * (1.0 - step(2.0, pick)));
	color = mix(color, color_c, step(2.0, pick) * (1.0 - step(3.0, pick)));
	color = mix(color, color_d, step(3.0, pick));
	float edge = fract(local_position.z * stripes_per_meter + local_position.y * stripes_per_meter);
	color = mix(thread_color, color, smoothstep(0.02, 0.08, edge) * smoothstep(0.98, 0.92, edge));
	float weave = sin(local_position.x * weave_per_meter) * sin(local_position.z * weave_per_meter);
	ALBEDO = color * (0.85 + 0.15 * weave);
	ROUGHNESS = 0.95;
}
