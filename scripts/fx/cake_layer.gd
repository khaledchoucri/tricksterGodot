class_name CakeLayer
extends Node2D
## Draws one cream (sub-emitter) of a Cake: its particles, with the cream's
## texture, blend mode and draw layer. Cake moves the particles.

var sub: Dictionary
var tex: Dictionary  # {"tex": Texture2D, "frames": [[x, w, h, ox, oy]]}


func _draw() -> void:
	if tex.is_empty():
		return
	var c: Dictionary = sub.cream
	var frames: Array = tex.frames
	var n := frames.size()
	if n == 0:
		return
	var anim := int(c.get("AnimationType", 0))
	var anim_speed := float(c.get("AnimationSpeed", 0.0))
	var flat := int(c.get("IsZAlign", 0)) == 1
	var sine := int(c.get("IsSineAlpha", 0)) == 1
	var c0 := _color(c, "Start")
	var c0b := _color(c, "Start", "Sub")
	var c1 := _color(c, "End")
	var c1b := _color(c, "End", "Sub")
	var a0 := float(c.get("MainStartAlpha", 255.0)) / 255.0
	var a1 := float(c.get("MainEndAlpha", 255.0)) / 255.0
	var mid_t := float(c.get("MiddleAlphaTime", 0.0))
	var mid_a := float(c.get("MiddleAlphaAlpha", 0.0))
	var s0 := Vector2(float(c.get("StartSizeX", c.get("StartSize", 100.0))), float(c.get("StartSizeY", c.get("StartSize", 100.0))))
	var s1 := Vector2(float(c.get("EndSizeX", c.get("EndSize", 100.0))), float(c.get("EndSizeY", c.get("EndSize", 100.0))))
	for p: Dictionary in sub.particles:
		var k := clampf(float(p.age) / float(p.life), 0.0, 1.0)
		var frame := 0
		match anim:
			1:
				frame = int(p.frame) % n
			2:
				frame = mini(int(k * n), n - 1)
			3:
				frame = (int(p.frame) + int(float(p.age) * anim_speed / 10.0 * 10.0)) % n if anim_speed > 0.0 else int(p.frame) % n
		var f: Array = frames[frame]
		if int(f[1]) <= 0:
			continue
		var alpha := lerpf(a0, a1, k)
		if mid_t > 0.0 and mid_t < 1.0:
			alpha = lerpf(a0, mid_a, k / mid_t) if k < mid_t else lerpf(mid_a, a1, (k - mid_t) / (1.0 - mid_t))
		if sine:
			alpha *= sin(k * PI)
		var tint := c0.lerp(c0b, float(p.tint)).lerp(c1.lerp(c1b, float(p.tint)), k)
		# Sizes are percentages of the texture frame (100 = as drawn).
		var size := Vector2(float(f[1]), float(f[2])) * s0.lerp(s1, k) / 100.0
		var pos: Vector3 = p.pos
		var at := Vector2(pos.x, -pos.y + pos.z * 0.5)
		var xf := Transform2D(float(p.rot), at)
		if flat:
			xf = Transform2D(0.0, at) * Transform2D(0.0, Vector2(1.0, 0.5), 0.0, Vector2.ZERO) * Transform2D(float(p.rot), Vector2.ZERO)
		draw_set_transform_matrix(xf)
		draw_texture_rect_region(tex.tex, Rect2(-size / 2.0, size), Rect2(float(f[0]), 0.0, float(f[1]), float(f[2])),
			Color(tint, alpha))
	draw_set_transform_matrix(Transform2D.IDENTITY)


static func _color(c: Dictionary, which: String, kind := "Main") -> Color:
	var a: Variant = c.get(kind + which + "Color", [255, 255, 255])
	if a is Array and a.size() >= 3:
		return Color(float(a[0]) / 255.0, float(a[1]) / 255.0, float(a[2]) / 255.0)
	return Color.WHITE
