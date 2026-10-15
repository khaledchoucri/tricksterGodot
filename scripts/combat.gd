class_name Combat
extends RefCounted
## Shared hit-test helpers. Attack shapes live on the ground plane, which the
## camera shows squashed 2:1, so screen offsets are un-squashed before testing.


static func ground(screen_delta: Vector2) -> Vector2:
	return Vector2(screen_delta.x, screen_delta.y * 2.0)


static func screen(ground_vec: Vector2) -> Vector2:
	return Vector2(ground_vec.x, ground_vec.y * 0.5)


static func in_circle(origin: Vector2, target: Vector2, radius: float, target_radius := 0.0) -> bool:
	return ground(target - origin).length() <= radius + target_radius


static func in_wedge(origin: Vector2, target: Vector2, dir: Vector2, radius: float, arc: float, target_radius := 0.0) -> bool:
	var d := ground(target - origin)
	if d.length() > radius + target_radius:
		return false
	if d.length() < target_radius + 4.0:
		return true
	return absf(dir.angle_to(d)) <= arc / 2.0


static func in_lane(origin: Vector2, target: Vector2, dir: Vector2, length: float, width: float, target_radius := 0.0) -> bool:
	var d := ground(target - origin)
	var along := d.dot(dir)
	var across := absf(d.dot(dir.orthogonal()))
	return along >= -target_radius and along <= length + target_radius and across <= width / 2.0 + target_radius
