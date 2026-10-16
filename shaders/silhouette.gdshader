shader_type canvas_item;
// Flat tinted silhouette with a brighter rim, drawn over scenery that hides
// the player.

uniform vec4 fill : source_color = vec4(0.35, 0.85, 1.0, 0.14);
uniform vec4 rim : source_color = vec4(0.75, 0.97, 1.0, 0.85);

void fragment() {
	float a = texture(TEXTURE, UV).a;
	vec2 px = TEXTURE_PIXEL_SIZE;
	float around = min(min(texture(TEXTURE, UV + vec2(px.x, 0.0)).a, texture(TEXTURE, UV - vec2(px.x, 0.0)).a),
		min(texture(TEXTURE, UV + vec2(0.0, px.y)).a, texture(TEXTURE, UV - vec2(0.0, px.y)).a));
	float edge = step(0.5, a) * (1.0 - step(0.5, around));
	vec4 c = mix(fill, rim, edge);
	COLOR = vec4(c.rgb, c.a * step(0.5, a));
}
