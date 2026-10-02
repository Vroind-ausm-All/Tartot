// Die Figur auf der Buehne: ein einziges gemaltes Bild, das sich wie eine
// Gummischlauch-Figur der Fleischer-Zeit bewegt.
//
// Das Bild wird nicht in Einzelteile zerlegt, sondern verformt: die Fuesse
// bleiben stehen, der Oberkoerper biegt sich (biegen), eine Welle laeuft
// durch den Koerper (welle_*), die Mitte blaeht sich auf (beule). Dazu das
// "Kochen" der Linien wie bei handgezeichneten Zeichentrickfilmen, Blitz,
// Toenung, eine Aura und das Zerfallen beim Tod.
//
// Die Textur hat ringsum Luft (rand_min/rand_max), damit die Verformung
// nicht am Bildrand abgeschnitten wird.
shader_type canvas_item;

uniform vec2 rand_min = vec2(0.1, 0.1);
uniform vec2 rand_max = vec2(0.9, 0.9);

uniform float biegen = 0.0;          // Anteil der Breite, um den der Kopf seitlich wandert
uniform float welle_hoehe = 0.0;     // Ausschlag der Koerperwelle
uniform float welle_dichte = 6.0;
uniform float welle_phase = 0.0;
uniform float beule = 0.0;           // >0 aufblaehen, <0 einziehen
uniform vec2 beule_mitte = vec2(0.5, 0.45);
uniform float kochen = 1.0;          // Linien-Kochen (0 aus)
uniform float zeit = 0.0;

uniform float blitz = 0.0;
uniform vec4 blitz_farbe : source_color = vec4(1.0, 0.97, 0.9, 1.0);
uniform float toenung = 0.0;
uniform vec4 toenung_farbe : source_color = vec4(1.0, 0.35, 0.3, 1.0);
uniform float aura = 0.0;
uniform vec4 aura_farbe : source_color = vec4(1.0, 0.75, 0.3, 1.0);
uniform float aura_px = 14.0;
uniform float aufloesen = 0.0;
uniform vec4 glut_farbe : source_color = vec4(1.0, 0.55, 0.2, 1.0);
// Abheben vom Hintergrund: Tintenkontur aussen, Gegenlicht als heller Saum
// an der dem Licht zugewandten Kante (Licht kommt von hinten oben).
uniform float kontur_px = 3.0;
uniform vec4 kontur_farbe : source_color = vec4(0.07, 0.05, 0.04, 1.0);
uniform float randlicht = 0.0;
uniform float randlicht_px = 7.0;
uniform vec2 licht_richtung = vec2(-0.45, -0.9);
uniform vec4 randlicht_farbe : source_color = vec4(1.0, 0.85, 0.55, 1.0);
uniform float silhouette = 0.0;      // 1: nur Schattenriss (fuer Helfer und Schatten)
uniform vec4 silhouette_farbe : source_color = vec4(0.08, 0.06, 0.05, 1.0);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float glatt(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

vec2 verformt(vec2 uv) {
	vec2 groesse = rand_max - rand_min;
	vec2 f = (uv - rand_min) / groesse;          // 0..1 in der Figur
	float hoehe = clamp(1.0 - f.y, 0.0, 1.3);     // 0 an den Fuessen, 1 am Kopf
	vec2 q = f;
	q.x -= biegen * hoehe * hoehe;
	q.x -= welle_hoehe * sin(f.y * welle_dichte - welle_phase) * smoothstep(0.0, 0.5, hoehe);
	vec2 d = f - beule_mitte;
	q -= d * beule * exp(-dot(d, d) * 7.0);
	// Kochen: die Linien zittern 8-mal pro Sekunde, wie neu gezeichnet
	float bild = floor(zeit * 8.0);
	q += (vec2(glatt(f * 9.0 + bild * 3.1), glatt(f * 9.0 + 17.0 + bild * 1.7)) - 0.5) * 0.0045 * kochen;
	return rand_min + q * groesse;
}

void fragment() {
	vec2 uv = verformt(UV);
	vec4 c = texture(TEXTURE, uv);
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) c = vec4(0.0);

	// Kontur: ein Tintenrand rund um die Figur trennt sie vom Buehnenbild.
	if (kontur_px > 0.01 && c.a < 0.99) {
		float k = 0.0;
		for (int i = 0; i < 12; i++) {
			float w = float(i) / 12.0 * 6.2832;
			k = max(k, texture(TEXTURE, uv + vec2(cos(w), sin(w)) * kontur_px * TEXTURE_PIXEL_SIZE).a);
		}
		c = vec4(mix(kontur_farbe.rgb, c.rgb, c.a), max(c.a, k * kontur_farbe.a));
	}
	// Gegenlicht: wo zum Licht hin Luft ist, leuchtet der Rand der Figur.
	if (randlicht > 0.001 && c.a > 0.5) {
		vec2 r = normalize(licht_richtung) * randlicht_px * TEXTURE_PIXEL_SIZE;
		float frei = 1.0 - texture(TEXTURE, uv + r).a;
		frei = max(frei, (1.0 - texture(TEXTURE, uv + r * 0.5).a) * 0.7);
		c.rgb = mix(c.rgb, randlicht_farbe.rgb, frei * randlicht * 0.75);
	}

	// Aura: der Umriss leuchtet nach aussen
	if (aura > 0.001) {
		float a = 0.0;
		for (int i = 0; i < 12; i++) {
			float w = float(i) / 12.0 * 6.2832;
			vec2 o = vec2(cos(w), sin(w)) * aura_px * TEXTURE_PIXEL_SIZE;
			a = max(a, texture(TEXTURE, uv + o).a);
			a = max(a, texture(TEXTURE, uv + o * 0.5).a * 0.8);
		}
		float flackern = 0.8 + 0.2 * sin(zeit * 9.0 + UV.y * 20.0);
		vec4 rand = vec4(aura_farbe.rgb, a * aura * flackern * (1.0 - c.a));
		c = vec4(mix(rand.rgb, c.rgb, c.a), max(c.a, rand.a));
	}

	if (silhouette > 0.001) c.rgb = mix(c.rgb, silhouette_farbe.rgb, silhouette);
	c.rgb = mix(c.rgb, c.rgb * toenung_farbe.rgb * 1.35, toenung);
	c.rgb = mix(c.rgb, blitz_farbe.rgb, blitz);

	if (aufloesen > 0.0) {
		float n = glatt(UV * 26.0) * 0.6 + glatt(UV * 7.0) * 0.4;
		float s = aufloesen * 1.2 - 0.1;
		if (n < s) c.a = 0.0;
		float kante = 1.0 - smoothstep(0.0, 0.07, n - s);
		c.rgb = mix(c.rgb, glut_farbe.rgb * 1.6, kante * step(0.001, c.a));
	}
	COLOR = c * COLOR;
}
