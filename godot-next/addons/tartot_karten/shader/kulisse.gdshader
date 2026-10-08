// Das Buehnenbild hinter der Figur: etwas unscharf, dunstiger und dunkler,
// damit die Figur davor steht wie ein Darsteller vor dem gemalten Prospekt.
// Um die Figur herum liegt ein weicher Lichtfleck (Gegenlicht).
shader_type canvas_item;

uniform float unschaerfe_px = 1.6;
uniform float dunst = 0.12;
uniform vec4 dunst_farbe : source_color = vec4(0.45, 0.38, 0.3, 1.0);
uniform float abdunkeln = 0.88;
uniform vec2 licht_mitte = vec2(0.5, 0.45);   // in UV des Buehnenbilds
uniform vec2 licht_radius = vec2(0.3, 0.45);
uniform float licht = 0.25;
uniform vec4 licht_farbe : source_color = vec4(1.0, 0.82, 0.5, 1.0);

void fragment() {
	vec2 p = TEXTURE_PIXEL_SIZE * unschaerfe_px;
	vec4 c = texture(TEXTURE, UV) * 0.36;
	c += texture(TEXTURE, UV + vec2(p.x, 0.0)) * 0.16;
	c += texture(TEXTURE, UV - vec2(p.x, 0.0)) * 0.16;
	c += texture(TEXTURE, UV + vec2(0.0, p.y)) * 0.16;
	c += texture(TEXTURE, UV - vec2(0.0, p.y)) * 0.16;
	vec3 f = mix(c.rgb, dunst_farbe.rgb, dunst) * abdunkeln;
	vec2 d = (UV - licht_mitte) / licht_radius;
	float l = exp(-dot(d, d) * 1.6);
	f += licht_farbe.rgb * l * licht * (0.4 + 0.6 * dot(f, vec3(0.33)));
	COLOR = vec4(f, 1.0) * COLOR;
}
