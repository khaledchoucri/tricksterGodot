shader_type canvas_item;
// Inverse multiply (INVMULT): darkens by the texture's brightness (smoke, shadow).
render_mode blend_mul;

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	COLOR = vec4(vec3(1.0) - t.rgb * COLOR.rgb * COLOR.a * t.a, 1.0);
}
