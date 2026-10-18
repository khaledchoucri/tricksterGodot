shader_type canvas_item;
// Additive: the texture's light is added to what's behind it.
render_mode blend_add;

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	COLOR = vec4(t.rgb * COLOR.rgb * COLOR.a * t.a, 1.0);
}
