shader_type spatial;
render_mode shadows_disabled, cull_disabled;

// Optimized lightweight spatial shader for mobile poof effect (zero-loop procedural deformation)
uniform vec3 albedo : source_color;
varying float dissolve_val;

uniform float progress = 0.0;
uniform float smoothness = 0.05;

uniform float ease = 2.0;
uniform float base_scale = 1.0;
uniform float deformation_scale = 1.0;

uniform float texture_offset = 0.0;


void vertex() {
	// Lightweight analytical deformation: eliminates expensive 27-iteration 3D Voronoi loop on mobile
	vec3 p = VERTEX * 2.2 + vec3(texture_offset);
	float wave = sin(p.x * 1.5) * cos(p.y * 1.5) + sin(p.z * 2.0) * 0.5;
	dissolve_val = clamp((wave + 1.5) * 0.35, 0.0, 1.0);
	VERTEX += NORMAL * (wave * 0.12) * deformation_scale;
	VERTEX *= base_scale;
}

void fragment() {
	ALBEDO = albedo;
	EMISSION = albedo * 0.4;
	ALPHA = smoothstep(progress - smoothness, progress + smoothness, dissolve_val);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
