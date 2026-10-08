// Glaeserne Karte (Glasmorphismus): das Papier wird zu Milchglas, durch das
// man den Tisch verschwommen sieht. Tinte und farbige Motive bleiben stehen.
// Liest die Bildschirmtextur, deshalb ein eigener Shader: nur Glaskarten
// bezahlen den Kopiervorgang.
shader_type canvas_item;

#include "res://addons/tartot_karten/shader/karte_basis.gdshaderinc"

uniform sampler2D bildschirm : hint_screen_texture, filter_linear;
uniform float unschaerfe_px = 7.0;

void vertex() {
	vec3 pp;
	vec2 oo;
	float t;
	neigung(UV, pp, oo, t);
	p = pp;
	o = oo;
	VERTEX += (UV - 0.5) / TEXTURE_PIXEL_SIZE * t;
	modul = COLOR;
}

vec3 verschwommen(vec2 suv, vec2 px) {
	vec3 s = vec3(0.0);
	float w = 0.0;
	for (int x = -2; x <= 2; x++) {
		for (int y = -2; y <= 2; y++) {
			float k = exp(-float(x * x + y * y) / 4.0);
			s += texture(bildschirm, suv + vec2(float(x), float(y)) * px * unschaerfe_px * 0.5).rgb * k;
			w += k;
		}
	}
	return s / w;
}

void fragment() {
	if (p.z <= 0.0) discard;
	vec2 cuv;
	float d;
	vec4 c = karte_lesen(TEXTURE, p, o, cuv, d);
	if (schatten > 0.5) {
		COLOR = vec4(0.0, 0.0, 0.0, c.a * 0.22 * modul.a);
	} else {
		// leichte Brechung: das Glas verschiebt, was dahinter liegt
		vec2 brechung = (cuv - 0.5) * vec2(0.012, 0.008) * vec2(1.0 + y_rot * 0.02, 1.0 + x_rot * 0.02);
		vec3 hinter = verschwommen(SCREEN_UV + brechung, SCREEN_PIXEL_SIZE);
		float l = luma(c.rgb);
		float tinte = 1.0 - smoothstep(0.28, 0.62, l);
		float buntheit = length(c.rgb - vec3(l));
		float bleibt = clamp(tinte + buntheit * 1.6, 0.0, 1.0);
		vec3 glas = hinter * vec3(0.90, 0.95, 1.05) + vec3(0.10, 0.11, 0.14);
		float streif = smoothstep(0.035, 0.0, abs(cuv.x * 0.8 + cuv.y * 0.5 - 0.55 - y_rot * 0.015
				+ sin(TIME * 0.5 + saat) * 0.05)) * 0.35;
		float kante = smoothstep(-3.0, 0.0, d) * 0.45;
		vec3 farbe = mix(glas, c.rgb, bleibt * 0.9) + streif + kante;
		vec4 ergebnis = vec4(farbe, c.a);
		// Legendaer-Glanz und Aufloesen (Zerspringen) gelten auch fuer Glas.
		ergebnis = papierlicht(ergebnis, cuv);
		ergebnis = folie(ergebnis, cuv, TIME);
		ergebnis = editionen(ergebnis, cuv, d, TIME);
		COLOR = aufloesen_anwenden(ergebnis, cuv) * modul;
	}
}
