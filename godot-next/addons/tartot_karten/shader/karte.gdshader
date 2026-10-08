// Kartenshader ohne Bildschirmtextur: Neigung, Folie, schimmernd, leuchtend,
// brennend, legendaer, aufloesen, Schatten.
shader_type canvas_item;

#include "res://addons/tartot_karten/shader/karte_basis.gdshaderinc"

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

void fragment() {
	if (p.z <= 0.0) discard;
	vec2 cuv;
	float d;
	vec4 c = karte_lesen(TEXTURE, p, o, cuv, d);
	if (schatten > 0.5) {
		COLOR = vec4(0.0, 0.0, 0.0, c.a * 0.42 * modul.a);
	} else {
		c = papierlicht(c, cuv);
		c = folie(c, cuv, TIME);
		c = editionen(c, cuv, d, TIME);
		COLOR = aufloesen_anwenden(c, cuv) * modul;
	}
}
