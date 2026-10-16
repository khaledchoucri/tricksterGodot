class_name Npc
extends Node2D
## A hub character (scenes/npc.tscn). Shows a prompt while the player is in
## talking range; the hub runs the conversation.

const TALK_RANGE := 48.0

var data: NpcData

@onready var sprite: ActorSprite = $Sprite
@onready var prompt: Label = $Prompt


func _ready() -> void:
	sprite.setup(data.actor)
	var action := "idle_auto" if sprite.has_action("idle_auto") else "idle"
	sprite.play_action(action, data.facing)
	prompt.text = "[F] " + ("Read" if data.is_object else "Talk")
	prompt.visible = false


func in_range(p: Vector2) -> bool:
	return Combat.ground(p - global_position).length() <= TALK_RANGE
