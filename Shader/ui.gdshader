shader_type canvas_item;

void fragment() {
    // Recentrer les coordonnées UV de [0, 1] vers [-0.5, 0.5]
    vec2 center = UV - vec2(0.5);
    
    // Calculer la distance par rapport au centre
    float dist = length(center);
    
    // Récupérer la couleur de la texture du Viewport
    vec4 tex_color = texture(TEXTURE, UV);
    
    // Découper en cercle (rayon 0.5) avec un léger lissage des bords (anti-aliasing)
    float alpha = smoothstep(0.5, 0.49, dist);
    
    COLOR = vec4(tex_color.rgb, tex_color.a * alpha);
}