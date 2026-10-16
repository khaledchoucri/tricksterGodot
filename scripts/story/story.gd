class_name Story
extends RefCounted
## Picks hub conversations from a story file (data/megalopolis/story.json)
## using the player's Profile: each NPC's conversations are checked in order
## and the first whose conditions hold is used.

var _npcs: Dictionary = {}


func _init(path: String) -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data is Dictionary:
		_npcs = data.get("npcs", {})
	else:
		push_warning("Story file %s is unreadable" % path)


## The conversation an NPC would have now, or an empty Dictionary.
func conversation_for(npc_id: String) -> Dictionary:
	for c: Dictionary in _npcs.get(npc_id, []):
		if _holds(c.get("if", [])):
			return c
	return {}


## Marks a finished conversation's flags.
func finish(conversation: Dictionary) -> void:
	for flag: String in conversation.get("set", []):
		Profile.set_flag(flag)


func _holds(conditions: Array) -> bool:
	for cond: String in conditions:
		if not _check(cond):
			return false
	return true


func _check(cond: String) -> bool:
	for op in [">=", "<"]:
		var i := cond.find(op)
		if i > 0:
			var value := int(Profile.stats.get(cond.substr(0, i), 0))
			var target := cond.substr(i + op.length()).to_int()
			return value >= target if op == ">=" else value < target
	if cond.begins_with("!"):
		return not Profile.has_flag(cond.substr(1))
	return Profile.has_flag(cond)
