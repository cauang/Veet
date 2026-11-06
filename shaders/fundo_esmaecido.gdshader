shader_type canvas_item;
// Esmaece o que esta atras de um modal: desfoca de leve, escurece com um tom
// quente e acentua a vinheta nas bordas. Nao apaga a cena, so a "afasta".

uniform sampler2D tela : hint_screen_texture, filter_linear_mipmap;
uniform float desfoque : hint_range(0.0, 5.0) = 1.6;
uniform float escurecer : hint_range(0.0, 1.0) = 0.45;
uniform float vinheta : hint_range(0.0, 1.0) = 0.3;
uniform vec3 tom : source_color = vec3(0.16, 0.09, 0.05);

void fragment() {
	vec3 cena = textureLod(tela, SCREEN_UV, desfoque).rgb;
	float borda = smoothstep(0.25, 0.85, distance(SCREEN_UV, vec2(0.5)));
	float forca = clamp(escurecer + vinheta * borda, 0.0, 0.92);
	// COLOR.a carrega o fade (modulate) do painel
	COLOR = vec4(mix(cena, tom, forca), COLOR.a);
}
