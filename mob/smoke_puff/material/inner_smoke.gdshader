shader_type spatial;
render_mode shadows_disabled, cull_back;

// Optimized lightweight spatial shader for inner smoke puff (zero-loop procedural deformation)
uniform vec3 albedo : source_color;

uniform float progress = 0.0;
uniform float smoothness = 0.05;

uniform float ease = 2.0;
uniform float base_scale = 1.0;
uniform float deformation_scale = 1.0;

uniform float texture_offset = 0.0;
uniform float fresnel_offset = 1.0;
uniform float global_alpha = 1.0;


float fresnel(vec3 normal, vec3 view, float amount) {
	return pow(1.0 - clamp(dot(normal, view), 0.0, 1.0), amount);
}

void vertex() {
	// Lightweight analytical deformation: eliminates 27-iteration loop on mobile
	vec3 p = VERTEX * 2.0 + vec3(texture_offset);
	float wave = sin(p.x * 2.0) * cos(p.z * 2.0) * 0.5;
	VERTEX += NORMAL * (wave * 0.1) * deformation_scale;
	VERTEX *= base_scale;
}

void fragment() {
	ALBEDO = albedo;
	EMISSION = albedo * 0.5;
	ALPHA = (1.0 - fresnel(NORMAL, VIEW, 2.0 * fresnel_offset)) * global_alpha;
}
