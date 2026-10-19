class_name Mine
extends Node2D
## A buried mine: a faint mark on the ground until a monster comes within
## `radius`, then it bursts once on every monster that close.

const ARM := 0.4  # it can't go off the instant it is laid

var room: Room
var radius := 70.0
var life := 20.0
var on_burst: Callable  # called with the monsters caught
var _t := 0.0


func _ready() -> void:
	z_index = -1


func _physics_process(delta: float) -> void:
	_t += delta
	if _t >= life:
		queue_free()
		return
	queue_redraw()
	if _t < ARM or not is_instance_valid(room):
		return
	var caught: Array[Enemy] = []
	for e in room.enemies:
		if e.is_hittable() and Combat.in_circle(global_position, e.global_position, radius * 0.6, e.body_radius):
			caught.append(e)
	if caught.is_empty():
		return
	var all: Array[Enemy] = []
	for e in room.enemies:
		if e.is_hittable() and Combat.in_circle(global_position, e.global_position, radius, e.body_radius):
			all.append(e)
	if on_burst.is_valid():
		on_burst.call(all)
	queue_free()


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_t * 4.0)
	draw_circle(Vector2.ZERO, 5.0, Color(0.35, 0.3, 0.25, 0.8))
	draw_circle(Vector2.ZERO, 2.0, Color(1.0, 0.35, 0.2, 0.4 + 0.5 * pulse))
