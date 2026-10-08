// Grund des Kampftischs: dunkler, koerniger Karton mit warmer Mitte und
// links und rechts der Perforation eines Filmstreifens - wie auf den
// Boss-Blaettern. Aus godot-karten/demo/demo.gd (_hintergrund).
shader_type canvas_item;

float h(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec2 px = UV * vec2(1080.0, 1920.0);
	vec3 c = vec3(0.075, 0.058, 0.048) * (0.85 + 0.3 * h(floor(px / 3.0)));
	// Warmes Licht ueber dem Tisch, zur Ecke hin dunkler.
	vec2 m = (UV - vec2(0.5, 0.62)) * vec2(1.0, 0.75);
	c *= 1.18 - 0.75 * dot(m, m) * 2.2;
	// Filmstreifen links und rechts: Perforation wie auf den Blaettern
	if (px.x < 36.0 || px.x > 1044.0) {
		c = vec3(0.035, 0.028, 0.024);
		float lx = px.x < 36.0 ? px.x : px.x - 1044.0;
		float ly = mod(px.y, 46.0);
		vec2 q = vec2(lx - 18.0, ly - 23.0);
		vec2 b = abs(q) - vec2(9.0, 11.0);
		float d = length(max(b, 0.0)) + min(max(b.x, b.y), 0.0) - 3.0;
		if (d < 0.0) c = vec3(0.74, 0.62, 0.45) * (0.85 + 0.2 * h(floor(px / 2.0)));
	}
	COLOR = vec4(c, 1.0);
}
