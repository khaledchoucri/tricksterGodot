class_name Silhouette
extends Node2D
## Tinted outline of an actor (and its held weapon) drawn over all scenery,
## shown while the actor is hidden behind props. Copies the source sprites'
## state every frame.

const SHADER := preload("res://shaders/silhouette.gdshader")

@export var body_path: NodePath = ^"../Sprite"
@export var weapon_path: NodePath = ^"../Weapon"

var _body: AnimatedSprite2D
var _weapon: Sprite2D
var _body_copy := AnimatedSprite2D.new()
var _weapon_copy := Sprite2D.new()


func _ready() -> void:
	z_as_relative = false
	z_index = 30
	visible = false
	_body = get_node(body_path)
	_weapon = get_node_or_null(weapon_path)
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	for copy: CanvasItem in [_body_copy, _weapon_copy]:
		copy.material = mat
		add_child(copy)


func _process(_delta: float) -> void:
	if not visible:
		return
	_body_copy.sprite_frames = _body.sprite_frames
	_body_copy.animation = _body.animation
	_body_copy.frame = _body.frame
	_body_copy.centered = _body.centered
	_body_copy.offset = _body.offset
	_body_copy.flip_h = _body.flip_h
	_body_copy.position = _body.position
	_body_copy.scale = _body.scale
	_weapon_copy.visible = _weapon != null and _weapon.visible
	if _weapon_copy.visible:
		_weapon_copy.texture = _weapon.texture
		_weapon_copy.centered = _weapon.centered
		_weapon_copy.offset = _weapon.offset
		_weapon_copy.flip_v = _weapon.flip_v
		_weapon_copy.position = _weapon.position
		_weapon_copy.rotation = _weapon.rotation
