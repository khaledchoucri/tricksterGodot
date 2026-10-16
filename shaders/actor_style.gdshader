shader_type canvas_item;
// Shared finish for actor sprites: an ink outline drawn by the engine (the
// same weight on every frame and asset) and an optional palette lock that
// snaps colours to the character's own palette, which hides colour drift
// between generated frames. Sheets need transparent padding around each
// cell at least `outline_px` wide.

uniform bool outline_on = true;
uniform float outline_px = 2.0;          // in texture pixels
uniform vec4 ink : source_color = vec4(0.137, 0.231, 0.322, 1.0);  // #233B52
uniform bool palette_on = false;
uniform sampler2D palette : filter_nearest;
uniform int palette_size = 40;
uniform float palette_mix = 1.0;

varying vec4 modulate;  // the node's modulate, without the texture

void vertex() {
	modulate = COLOR;
}

vec3 nearest(vec3 c) {
	vec3 best = c;
	float best_d = 1e9;
	for (int i = 0; i < palette_size; i++) {
		vec4 p = texelFetch(palette, ivec2(i, 0), 0);
		if (p.a < 0.5) {
			continue;
		}
		// Weighted RGB distance, close enough to perceptual for this.
		vec3 d = (c - p.rgb) * vec3(0.30, 0.59, 0.11);
		float dd = dot(d, d);
		if (dd < best_d) {
			best_d = dd;
			best = p.rgb;
		}
	}
	return best;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (palette_on && c.a > 0.01) {
		c.rgb = mix(c.rgb, nearest(c.rgb), palette_mix);
	}
	if (outline_on && c.a < 0.5) {
		vec2 px = TEXTURE_PIXEL_SIZE * outline_px;
		float a = 0.0;
		for (int i = 0; i < 8; i++) {
			float ang = float(i) * 0.785398;
			a = max(a, texture(TEXTURE, UV + vec2(cos(ang), sin(ang)) * px).a);
		}
		c = mix(c, ink, step(0.5, a) * (1.0 - c.a));
		c.a = max(c.a, step(0.5, a) * ink.a);
	}
	COLOR = c * modulate;
}
