class_name GunBar
extends Node2D
## The gun's bar above the shooter, as the client draws its gauge (42 x 8 at
## 20 px left and 96 px up: Trickster.bin 0x445ec0). While reloading it fills
## grey; loaded, it shows the power gauge, with the power zone (above the
## gun's PowStartPoint) marked and lit gold once the gauge is in it.

const WIDTH := 42.0
const HEIGHT := 6.0

var gun: GunCycle


func _ready() -> void:
	z_index = 30
	position = Vector2(-WIDTH / 2.0, -96.0)


func _process(_delta: float) -> void:
	visible = gun != null and gun.has_gun()
	if visible:
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-1, -1, WIDTH + 2, HEIGHT + 2), Color(0.05, 0.06, 0.08, 0.85))
	if gun.state == GunCycle.State.RELOADING:
		draw_rect(Rect2(0, 0, WIDTH * gun.reload_ratio(), HEIGHT), Color(0.7, 0.72, 0.78))
		return
	if not gun.charges():
		draw_rect(Rect2(0, 0, WIDTH, HEIGHT), Color(0.55, 0.85, 1.0))  # loaded, ready to fire
		return
	var zone := gun.zone_ratio()
	draw_rect(Rect2(WIDTH * zone, 0, WIDTH * (1.0 - zone), HEIGHT), Color(0.45, 0.32, 0.08, 0.9))
	var lit := gun.in_power_zone()
	draw_rect(Rect2(0, 0, WIDTH * gun.power_ratio(), HEIGHT), Color(1.0, 0.82, 0.3) if lit else Color(0.55, 0.85, 1.0))
	draw_rect(Rect2(WIDTH * zone - 1, -2, 2, HEIGHT + 4), Color(1, 1, 1, 0.9))
