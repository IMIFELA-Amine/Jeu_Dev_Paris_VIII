shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform sampler2D texture_albedo : source_color, filter_linear_mipmap;
uniform sampler2D texture_alpha : hint_default_white, filter_linear_mipmap;
uniform float seuil_alpha : hint_range(0.0, 1.0) = 0.5;

uniform float vitesse_vent : hint_range(0.1, 5.0) = 1.3;
uniform float force_vent : hint_range(0.0, 0.5) = 0.12;

void vertex() {
	vec3 pos_monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float facteur_hauteur = max(0.0, VERTEX.y * 0.08);
	float oscillation = sin(TIME * vitesse_vent + pos_monde.x * 0.25 + pos_monde.z * 0.25) * force_vent;
	
	VERTEX.x += oscillation * facteur_hauteur;
	VERTEX.z += (oscillation * 0.6) * facteur_hauteur;
}

void fragment() {
	vec4 couleur = texture(texture_albedo, UV);
	float masque = texture(texture_alpha, UV).r;
	
	ALBEDO = couleur.rgb;
	ALPHA = masque;
	ALPHA_SCISSOR_THRESHOLD = seuil_alpha;
	ROUGHNESS = 0.85;
}