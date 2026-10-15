class_name ActorSprite
extends AnimatedSprite2D
## Plays exported Trickster animations by action name and facing vector.
## Sheets come from tools/export_actor.py: animations are named
## "<action>_<dir>" and every frame shares one foot anchor.

const DIRS: Array[String] = ["e", "se", "s", "sw", "w", "nw", "n", "ne"]

var available: Dictionary = {}  # action -> Array of direction codes
var lengths: Dictionary = {}    # action -> seconds at speed 1.0
var facing := Vector2(1, 1).normalized()


func setup(actor_name: String) -> bool:
	var base := "res://original_assets/actors/%s/%s" % [actor_name, actor_name]
	if not ResourceLoader.exists(base + ".tres") or not FileAccess.file_exists(base + ".json"):
		push_warning("Missing exported sprites for %s; run tools/export_actor.py" % actor_name)
		return false
	sprite_frames = load(base + ".tres")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(base + ".json"))
	centered = false
	offset = -Vector2(manifest.anchor[0], manifest.anchor[1])
	for action in manifest.actions:
		var dirs: Dictionary = manifest.actions[action].dirs
		available[action] = dirs.keys()
		var total := 0.0
		for f in dirs.values()[0]:
			total += minf(f.ms, 400.0)  # long holds (death poses) are capped
		lengths[action] = total / 1000.0
	return true


static func dir_index(v: Vector2) -> int:
	return posmod(roundi(v.angle() / (PI / 4.0)), 8)


func has_action(action: String) -> bool:
	return available.has(action)


func dir_for(action: String, v: Vector2) -> String:
	var want := dir_index(v)
	var best := ""
	var best_dist := 99
	for d in available.get(action, []):
		var dist := absi(DIRS.find(d) - want)
		dist = mini(dist, 8 - dist)
		if dist < best_dist:
			best_dist = dist
			best = d
	return best


## Plays an action facing `v`. `duration` > 0 rescales the clip to that length.
func play_action(action: String, v := Vector2.ZERO, duration := 0.0, restart := false) -> void:
	if not has_action(action):
		return
	if v != Vector2.ZERO:
		facing = v.normalized()
	var anim := "%s_%s" % [action, dir_for(action, facing)]
	speed_scale = lengths[action] / duration if duration > 0.0 else 1.0
	if animation == anim and is_playing() and not restart:
		return
	stop()
	play(anim)
