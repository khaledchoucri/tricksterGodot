class_name AttackPattern
extends Resource
## How a monster attacks: its reach, timing, the shape it hits and how it reacts to hits.
## The five patterns live in data/attacks/; an EnemyData names one, and its `tune` overrides
## any of these numbers for that monster. Ours: the original's monsters attack through the
## server's AI tables, so the patterns and their numbers are designed, not read.

## How close it gets before it starts an attack.
@export var range := 42.0
## Seconds of telegraph before the hit, of the hit itself, and of recovery after.
@export var windup := 0.6
@export var active := 0.12
@export var recover := 0.55
## What the hit covers: a wedge ahead (radius, arc in degrees), a lane ahead (length,
## width) or a circle around it (radius).
@export_enum("wedge", "lane", "circle") var shape := "wedge"
@export var radius := 0.0
@export var arc := 0.0
@export var length := 0.0
@export var width := 0.0
## Hits it shrugs off before staggering: 0 staggers on every hit, -1 never.
@export var poise := 0
## Fires a projectile instead of hitting in place, keeps `keep_away` from you, and can't
## while silenced.
@export var ranged := false
@export var keep_away := 0.0
@export var shot_speed := 0.0
## Rushes along its lane during the hit, and can't be staggered meanwhile.
@export var dashes := false
## The landing shakes the screen.
@export var shakes := false


## This pattern with a monster's overrides applied (EnemyData.tune), as its own copy.
func tuned(tune: Dictionary) -> AttackPattern:
	var out: AttackPattern = duplicate()
	for key: String in tune:
		assert(key in out, "not an AttackPattern field: " + key)
		out.set(key, tune[key])
	return out
