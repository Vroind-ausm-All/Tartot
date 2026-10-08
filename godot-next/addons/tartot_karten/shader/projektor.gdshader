// Projektor: legt sich ueber das ganze Bild wie ein alter Filmprojektor.
//
// - Bildstand: das Bild zittert minimal, 24-mal pro Sekunde neu
// - Flackern: die Helligkeit atmet unruhig
// - Halation: helle Stellen gluehen rotgolden nach (wie Licht auf Nitrofilm)
// - Korn, Staub und gelegentliche Kratzer
// - Vignette, dazu ein roter Rand, wenn der Spieler getroffen wird
// - Irisblende fuer Szenenwechsel (iris >= 1.2 ist offen, 0 geschlossen)
//
// Alles ist zurueckhaltend gestellt: man soll es fuehlen, nicht sehen.
shader_type canvas_item;

uniform sampler2D bildschirm : hint_screen_texture, filter_linear;
uniform float korn = 0.05;
uniform float flackern = 0.025;
uniform float bildstand = 0.0009;
uniform float halation = 0.28;
uniform float vignette = 0.42;
uniform float kratzer = 1.0;
uniform float iris = 1.5;
uniform float rot = 0.0;
uniform float seitenverhaeltnis = 1.7778;

float hash(float n) { return fract(sin(n) * 43758.5453); }
float hash2(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float luma(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }

void fragment() {
	float bild = floor(TIME * 24.0);
	vec2 uv = SCREEN_UV;
	uv += (vec2(hash(bild), hash(bild + 7.1)) - 0.5) * bildstand;
	vec3 c = texture(bildschirm, uv).rgb;

	if (halation > 0.001) {
		vec3 h = vec3(0.0);
		vec2 px = SCREEN_PIXEL_SIZE * 9.0;
		for (int i = 0; i < 8; i++) {
			float w = float(i) / 8.0 * 6.2832;
			h += texture(bildschirm, uv + vec2(cos(w), sin(w)) * px).rgb;
		}
		h /= 8.0;
		float hell = max(0.0, luma(h) - 0.62) * 2.2;
		c += vec3(1.0, 0.5, 0.28) * hell * halation;
	}

	c *= 1.0 + (hash(bild * 1.37) - 0.5) * flackern * 2.0;
	float g = hash2(floor(uv * vec2(540.0, 960.0)) + bild * 3.17) - 0.5;
	c += g * korn * (0.6 + 0.4 * luma(c));

	if (kratzer > 0.0) {
		// ein heller, senkrechter Kratzer, der ab und zu durchs Bild laeuft
		float spur = hash(floor(TIME * 1.3));
		if (spur > 0.72) {
			float x = hash(floor(TIME * 1.3) + 3.0);
			float d = abs(uv.x - x - sin(uv.y * 30.0 + TIME) * 0.002);
			c += vec3(0.9, 0.85, 0.7) * smoothstep(0.0012, 0.0, d) * 0.35 * kratzer;
		}
		// Staubflocken: kurze dunkle Punkte, jedes Bild woanders
		for (int i = 0; i < 3; i++) {
			vec2 p = vec2(hash(bild * 3.0 + float(i)), hash(bild * 5.0 + float(i) * 2.0));
			float r = 0.0015 + 0.002 * hash(bild + float(i) * 11.0);
			vec2 dd = (uv - p) * vec2(1.0, 1.0 / seitenverhaeltnis);
			c *= 1.0 - smoothstep(r, r * 0.4, length(dd)) * 0.6 * kratzer * step(0.5, hash(bild * 7.0 + float(i)));
		}
	}

	vec2 m = (uv - 0.5) * vec2(1.0, seitenverhaeltnis) / seitenverhaeltnis * 1.6;
	float v = smoothstep(1.0, 0.25, length(m));
	c *= mix(1.0 - vignette, 1.0, v);
	c = mix(c, vec3(0.55, 0.04, 0.03), rot * pow(1.0 - v, 1.6) * 0.65);

	vec2 im = (SCREEN_UV - 0.5) * vec2(1.0, seitenverhaeltnis);
	float offen = smoothstep(iris, iris - 0.012, length(im));
	c *= offen;
	COLOR = vec4(c, 1.0);
}
