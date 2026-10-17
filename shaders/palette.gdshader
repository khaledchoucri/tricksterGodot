shader_type canvas_item;
// Playable characters' sheets store a palette index in red (tools/
// export_actor.py --indexed); this looks the colour up in a 256x1 palette, so
// outfits can be dyed in game (ActorSprite.set_outfit).

uniform sampler2D palette : filter_nearest;

// In fragment() COLOR already includes the texture; take the modulate from
// the vertex stage instead.
varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec4 src = texture(TEXTURE, UV);
	int i = int(round(src.r * 255.0));
	vec3 c = texelFetch(palette, ivec2(i, 0), 0).rgb;
	COLOR = vec4(c, src.a) * tint;
}
