class_name Talker
extends RefCounted
## Talking to people, for the hub and the rest stops alike: the prompt over the
## nearest person in range, a conversation from the story file played in the
## dialogue box (with portraits), and the player held still meanwhile. What a
## conversation leads to (its "then": a menu) is the caller's.

var story: Story
var dialogue: DialogueBox
var hud: Hud
var player: Player
var npcs: Array[Npc] = []
var talking := false

var _portraits: Dictionary[String, Texture2D] = {}


func _init(p_story: Story, p_dialogue: DialogueBox, p_hud: Hud) -> void:
	story = p_story
	dialogue = p_dialogue
	hud = p_hud


func npc(id: StringName) -> Npc:
	for n in npcs:
		if n.data.id == id:
			return n
	return null


## The nearest person in talking range of `at` (prompt shown over them only), or null.
func nearest(at: Vector2) -> Npc:
	var best: Npc = null
	for n in npcs:
		n.prompt.visible = false
		if n.in_range(at) and (best == null or n.global_position.distance_to(at) < best.global_position.distance_to(at)):
			best = n
	if best:
		best.prompt.visible = true
	return best


## Plays `who`'s current conversation and marks it finished. Returns it (its "then" says
## what follows) with the player still held for the follow-up, or {} if there's nothing
## to say. The caller ends the talk with set_talking(false).
func converse(who: Npc) -> Dictionary:
	var c := story.conversation_for(String(who.data.id))
	if c.is_empty():
		return {}
	set_talking(true)
	who.prompt.visible = false
	var lines: Array = []
	for l: Array in c.get("lines", []):
		lines.append(line(String(l[0]), String(l[1])))
	await dialogue.play(lines)
	story.finish(c)
	return c


## A dialogue line: "system" speaks without a name or portrait.
func line(speaker: String, text: String) -> Dictionary:
	if speaker == "system":
		return {"name": "", "portrait": null, "text": text}
	var n := npc(StringName(speaker))
	var data: NpcData = n.data if n else null
	return {"name": data.display_name if data else speaker.capitalize(), "portrait": _portrait(data), "text": text}


func set_talking(on: bool) -> void:
	talking = on
	hud.set_log_visible(not on)
	player.set_physics_process(not on)
	player.set_process_unhandled_input(not on)
	if on:
		player.velocity = Vector2.ZERO
		player.sprite.play_action("idle")


func _portrait(data: NpcData) -> Texture2D:
	if data == null or data.portrait.is_empty():
		return null
	if not _portraits.has(data.portrait):
		var path := Assets.portrait(data.portrait)
		_portraits[data.portrait] = load(path) if ResourceLoader.exists(path) else null
	return _portraits[data.portrait]
