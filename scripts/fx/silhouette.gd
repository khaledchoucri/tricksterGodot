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
var _worn_copies: Array[Sprite2D] = []
var _mat: ShaderMaterial


func _ready() -> void:
	z_as_relative = false
	z_index = 30
	visible = false
	_body = get_node(body_path)
	_weapon = get_node_or_null(weapon_path)
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	for copy: CanvasItem in [_body_copy, _weapon_copy]:
		copy.material = _mat
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
	# Worn items (hats, shields) are sprites under the body.
	var worn: Array[Sprite2D] = []
	for c in _body.get_children():
		if c is Sprite2D:
			worn.append(c)
	while _worn_copies.size() < worn.size():
		var copy := Sprite2D.new()
		copy.material = _mat
		_body_copy.add_child(copy)
		_worn_copies.append(copy)
	for i in _worn_copies.size():
		var copy := _worn_copies[i]
		copy.visible = i < worn.size() and worn[i].visible
		if copy.visible:
			var w := worn[i]
			copy.texture = w.texture
			copy.region_enabled = w.region_enabled
			copy.region_rect = w.region_rect
			copy.centered = w.centered
			copy.flip_h = w.flip_h
			copy.position = w.position
