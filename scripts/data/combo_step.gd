class_name ComboStep
extends Resource
## One swing of a basic attack chain. Times are seconds from the start of the
## swing at normal attack speed.

@export var anim := "attack"
## Play only part of the animation: x = first frame, y = last frame (x > y
## plays it backwards). (-1, -1) plays all of it.
@export var frames := Vector2i(-1, -1)
@export var duration := 0.32
## Active hit frames as (start, end); each window can hit an enemy once.
@export var windows: Array[Vector2] = [Vector2(0.06, 0.14)]
## Earliest time the next swing can start, a dash can cancel, and moving
## ends the swing.
@export var chain_at := 0.13
@export var dash_cancel := 0.07
@export var free_at := 0.22

@export_group("Hit")
@export var damage := 22.0
@export var reach := 60.0
@export_range(10.0, 360.0) var arc_degrees := 150.0
@export var knockback := 140.0
@export var lunge := 70.0
@export var hitstop := 0.045
## Finishers hit heavy and carry finisher talents (Uppercut's stun).
@export var finisher := false
@export var sound := "weapon001.wav"

@export_group("Sword")
## Swing a held weapon and leave a trail.
@export var slash := false
## Sweep direction when aiming right; it mirrors when aiming left, like the art.
@export var clockwise := true


func arc() -> float:
	return deg_to_rad(arc_degrees)


func frame_range() -> Array:
	return [] if frames.x < 0 else [frames.x, frames.y]
