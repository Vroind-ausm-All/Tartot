// Gemeinsamer Teil der Kartenshader: falsche 3D-Neigung (wie bei Balatro),
// Editionen, Legendaer-Glanz und Aufloesen. karte.gdshader und
// karte_glas.gdshader binden diese Datei ein.
//
// Die Neigung verschiebt nichts im Raum, sie projiziert das Kartenbild in
// eine gedrehte Ebene. Das Rechteck des Sprites wird dafuer im Vertex-Shader
// vergroessert, damit die gekippte Karte und ihr Leuchten Platz haben.

uniform float fov : hint_range(20.0, 120.0) = 60.0;
uniform float x_rot = 0.0;   // Grad, Kippen nach vorn/hinten
uniform float y_rot = 0.0;   // Grad, Kippen nach links/rechts
// Lage der eigentlichen Karte in der (mit Luft gerenderten) Textur
uniform vec2 karte_min = vec2(0.0833, 0.0588);
uniform vec2 karte_max = vec2(0.9167, 0.9412);
uniform vec2 karte_px = vec2(240.0, 360.0);
uniform float ecke_px = 16.0;
// 0 keine, 1 schimmernd, 2 leuchtend, 3 brennend, 4 glaesern
uniform int edition = 0;
uniform float legendaer = 0.0;
uniform vec4 selten_farbe : source_color = vec4(0.89, 0.66, 0.23, 1.0);
uniform float saat = 0.0;
// 0..1: die Karte zerfaellt (Glas zerspringt, Brennen verzehrt sie)
uniform float aufloesen = 0.0;
uniform vec4 aufloese_farbe : source_color = vec4(0.88, 0.33, 0.23, 1.0);
// 1: nur die Form, als Schatten
uniform float schatten = 0.0;

varying flat vec2 o;
varying vec3 p;
// Knotenfarbe (modulate): im Fragment ist COLOR schon mit der Textur verrechnet.
varying vec4 modul;

// Rechnet die gekippte Ebene. Das Ergebnis weist vertex() den Varyings zu.
void neigung(vec2 uv, out vec3 pp, out vec2 oo, out float t) {
	float sb = sin(radians(y_rot));
	float cb = cos(radians(y_rot));
	float sc = sin(radians(x_rot));
	float cc = cos(radians(x_rot));
	mat3 inv;
	inv[0][0] = cb;      inv[0][1] = 0.0;  inv[0][2] = -sb;
	inv[1][0] = sb * sc; inv[1][1] = cc;   inv[1][2] = cb * sc;
	inv[2][0] = sb * cc; inv[2][1] = -sc;  inv[2][2] = cb * cc;
	t = tan(radians(fov) * 0.5);
	pp = inv * vec3(uv - 0.5, 0.5 / t);
	float v = (0.5 / t) + 0.5;
	pp.xy *= v * inv[2].z;
	oo = v * inv[2].xy;
}

float luma(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

float hash21(vec2 q) { return fract(sin(dot(q, vec2(127.1, 311.7))) * 43758.5453); }

float rauschen(vec2 q) {
	vec2 i = floor(q);
	vec2 f = fract(q);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), u.x),
			   mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 q) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		s += a * rauschen(q);
		q *= 2.03;
		a *= 0.5;
	}
	return s;
}

// Abstand zum Kartenrand in Pixeln: negativ innen, positiv aussen.
float karte_abstand(vec2 cuv) {
	vec2 q = (cuv - 0.5) * karte_px;
	vec2 b = karte_px * 0.5 - vec2(ecke_px);
	vec2 d = abs(q) - b;
	return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - ecke_px;
}

// Schillern in TARTOTs Palette statt Regenbogen: Indigo, Gold, Glut.
vec3 schillern(float h) {
	vec3 a = vec3(0.50, 0.56, 0.82);
	vec3 b = vec3(0.96, 0.82, 0.48);
	vec3 c = vec3(0.88, 0.33, 0.23);
	h = fract(h) * 3.0;
	if (h < 1.0) return mix(a, b, h);
	if (h < 2.0) return mix(b, c, h - 1.0);
	return mix(c, a, h - 2.0);
}

// Liefert die projizierte Kartenfarbe und die Kartenkoordinaten.
vec4 karte_lesen(sampler2D tex, vec3 pp, vec2 oo, out vec2 cuv, out float d) {
	vec2 uv = (pp.xy / pp.z) - oo;
	vec2 tuv = uv + 0.5;
	vec4 c = texture(tex, tuv);
	c.a *= step(max(abs(uv.x), abs(uv.y)), 0.5);
	cuv = (tuv - karte_min) / (karte_max - karte_min);
	d = karte_abstand(cuv);
	return c;
}

// Editionen, die ohne Bildschirmtextur auskommen (1-3), dazu Legendaer-Glanz.
vec4 editionen(vec4 c, vec2 cuv, float d, float zeit) {
	float innen = c.a;
	vec4 aura = vec4(0.0);
	float winkel = (y_rot + x_rot) * 0.03;

	if (edition == 1) {
		// Schimmernd: Folie mit feinen Linien und einem Glanzband, das der Neigung folgt.
		float band = sin((cuv.x * 1.1 + cuv.y * 0.7) * 9.0 - zeit * 1.4 + winkel * 6.0 + saat);
		float glanz = smoothstep(0.82, 1.0, band);
		float linien = 0.5 + 0.5 * sin((cuv.x - cuv.y) * 140.0 + winkel * 20.0);
		float papier = smoothstep(0.45, 0.8, luma(c.rgb));
		vec3 folie = mix(vec3(0.80, 0.76, 0.64), vec3(1.0, 0.94, 0.72), linien);
		c.rgb = mix(c.rgb, c.rgb * folie * 1.12, 0.55 * papier);
		c.rgb += vec3(1.0, 0.92, 0.62) * glanz * 0.55 * (0.35 + 0.65 * papier);
	} else if (edition == 2) {
		// Leuchtend: schillernde Flaeche und eine pulsierende Aura um die Karte.
		float h = cuv.x * 0.7 + cuv.y * 0.45 + (y_rot - x_rot) * 0.012 + zeit * 0.07 + saat;
		vec3 iri = schillern(h);
		float hell = smoothstep(0.35, 0.75, luma(c.rgb));
		c.rgb = mix(c.rgb, c.rgb * (0.55 + iri), 0.5 * hell);
		float puls = 0.65 + 0.35 * sin(zeit * 3.0 + saat * 6.0);
		float g = exp(-max(d, 0.0) / 9.0) * puls;
		aura = vec4(schillern(h + d * 0.01), g * 0.9);
	} else if (edition == 3) {
		// Brennend: verkohlter, gluehender Rand und Flammen, die an der Karte hochzuengeln.
		float n = fbm(cuv * vec2(5.0, 7.0) + vec2(saat, -zeit * 0.6));
		float rand = -d + (n - 0.5) * 22.0;
		float kohle = 1.0 - smoothstep(2.0, 16.0, rand);
		float glut = smoothstep(0.1, 0.5, kohle) * (1.0 - smoothstep(0.6, 1.0, kohle));
		c.rgb = mix(c.rgb, vec3(0.12, 0.07, 0.05), kohle * 0.85);
		c.rgb += vec3(1.0, 0.45, 0.15) * glut * (1.0 + 0.35 * sin(zeit * 9.0 + n * 10.0));
		float f = fbm(vec2(cuv.x * 9.0 + saat, cuv.y * 5.0 + zeit * 2.6));
		float hoch = exp(-max(d, 0.0) / (7.0 + 16.0 * f)) * smoothstep(1.15, 0.2, cuv.y);
		float flamme = smoothstep(0.25, 0.7, hoch * (0.55 + f));
		aura = vec4(mix(vec3(0.70, 0.10, 0.08), vec3(1.0, 0.82, 0.35), hoch), flamme);
	}

	if (legendaer > 0.5) {
		// Legendaer: ein goldener Lichtstreif laeuft ab und zu ueber den Rahmen.
		float s = fract(zeit * 0.22 + saat);
		float pos = s * 2.6 - 0.8;
		float band = smoothstep(0.07, 0.0, abs(cuv.x + cuv.y * 0.45 - pos));
		float rahmen = smoothstep(-16.0, -3.0, d);
		c.rgb += selten_farbe.rgb * band * (0.35 + 0.65 * rahmen) * 0.7;
	}

	// Aura nur ausserhalb der Karte, die Karte selbst liegt darueber.
	vec4 aussen = vec4(aura.rgb, aura.a * (1.0 - innen));
	return vec4(mix(aussen.rgb, c.rgb, innen), max(innen, aussen.a));
}

vec4 aufloesen_anwenden(vec4 c, vec2 cuv) {
	if (aufloesen <= 0.0) return c;
	float n = fbm(cuv * vec2(6.0, 8.0) + saat * 3.0);
	float schwelle = aufloesen * 1.15 - 0.05;
	if (n < schwelle) return vec4(0.0);
	float kante = 1.0 - smoothstep(0.0, 0.06, n - schwelle);
	c.rgb = mix(c.rgb, aufloese_farbe.rgb * 1.4, kante);
	return c;
}
