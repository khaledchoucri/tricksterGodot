class_name Aura
extends Node2D
## A pulsing ring on the ground around whoever wears it, for as long as a buff lasts
## (a boss's shield, Sturdy Shield, Magic Reflector). The wearer calls end() when it fades.

var radius := 40.0
var color := Color(0.6, 0.8, 1.0, 0.8)
var _t := 0.0
var _ending := -1.0

## How fast it pulses (cycles a second) and how long it takes to fade out. Ours.
const PULSE := 1.6
const FADE := 0.3


static func attach(wearer: Node2D, p_radius: float, p_color: Color) -> Aura:
	var a := Aura.new()
	a.radius = p_radius
	a.color = p_color
	a.z_index = -1
	wearer.add_child(a)
	return a


## Fades it out and frees it.
func end() -> void:
	if _ending < 0.0:
		_ending = _t


func _process(delta: float) -> void:
	_t += delta
	if _ending >= 0.0 and _t - _ending >= FADE:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var fade := 1.0 if _ending < 0.0 else 1.0 - (_t - _ending) / FADE
	var r := radius * (1.0 + 0.06 * sin(_t * TAU * PULSE))
	var pts := PackedVector2Array()
	for i in 41:
		var a := TAU * i / 40.0
		pts.append(Vector2(cos(a) * r, sin(a) * r * 0.5))
	draw_polyline(pts, Color(color, color.a * fade), 2.5, true)
	draw_colored_polygon(pts.slice(0, 40), Color(color, 0.12 * fade))
