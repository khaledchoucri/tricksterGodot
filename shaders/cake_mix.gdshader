shader_type canvas_item;
// Trickster's effect textures sit on black: in the normal blend modes black is see-through.
render_mode blend_mix;

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	float lum = max(t.r, max(t.g, t.b));
	COLOR = vec4(t.rgb / max(lum, 0.001) * COLOR.rgb, lum * t.a * COLOR.a);
}
