class_name Cake
extends Node2D
## Plays one of Trickster's original particle effects ("cakes", exported by
## tools/export_effects.py from data/effect/cake.xml). A cake is a set of
## sub-emitters ("creams"), each starting at its own time. A cream emits
## particles at a rate up to a count; a particle has a texture from
## cream.nri, a lifetime, sizes, colours and alphas that blend from start to
## end, a velocity toward the cream's destination, gravity and air
## resistance. The original's 3D space has y up and z toward the viewer;
## here x stays, y rises on screen and z drops by half (the ground's tilt).
##
## Readings where the format doesn't say: sizes are percentages of the
## texture (a 43 px smoke puff at 300 is 129 px); "ZAlign" lays a particle flat on
## the ground; dispersions scatter a value by up to that share either way;
## StartAngle..EndAngle is the starting rotation; Bounding bounces particles
## off the ground; an emitter's first particle comes as it starts, the rest
## at its EmissionRate (the flying card, eft_skl_c_301_sut, emits one a
## second and is on screen from the throw).

const DIR := Assets.EFFECTS
const SORT_Z := {"Ground_Over": -2, "Object_Over": 18, "Map_Over": 20, "UI_Over": 40}

static var _cakes: Dictionary = {}
static var _textures: Dictionary = {}
static var _materials: Dictionary = {}

## Seconds the effect keeps emitting when it loops (0: until stop()).
var effect := ""  # the cake's name in the effect table
var hold := 0.0
## A node to stay on (a projectile, a monster); the effect follows it.
var follow: Node2D

var _subs: Array = []  # [{cream, start, emitted, carry, particles, node}]
var _t := 0.0
var _stopping := false
var _loop := false


## Whether the exported effects include `name`.
static func has(name: String) -> bool:
	return _data().has(name)


## Seconds a looping effect keeps going when no "hold" is given (the
## original loops until the game ends the skill's state).
const DEFAULT_HOLD := 1.2
## When an effect stops, its particles fade out over this long at most
## (some originals live 1000 s and only end when the effect is ended).
const FADE := 0.35


## Starts effect `name` at `at` (global) under `parent`; null if it isn't
## exported. `opts`: "hold" (seconds a looping effect keeps going), "follow"
## (a Node2D to stay on), "scale".
static func play(parent: Node, name: String, at: Vector2, opts := {}) -> Cake:
	var data: Dictionary = _data().get(name, {})
	if data.is_empty() or parent == null:
		return null
	var c := Cake.new()
	c.effect = name
	c.hold = float(opts.get("hold", DEFAULT_HOLD))
	c.follow = opts.get("follow")
	c.scale = Vector2.ONE * float(opts.get("scale", 1.0))
	c._loop = String(data.get("play", "")) in ["PlayLoop", "PlayRestart"]
	for sub: Dictionary in data.get("subs", []):
		c._subs.append({"cream": sub.cream, "start": float(sub.time), "emitted": 0, "carry": 1.0,
			"particles": [], "sort": String(sub.sort)})
	parent.add_child(c)
	c.global_position = at
	c._build()
	return c


static func _data() -> Dictionary:
	if _cakes.is_empty():
		var path := DIR + "cakes.json"
		if FileAccess.file_exists(path):
			_cakes = JSON.parse_string(FileAccess.get_file_as_string(path))
		else:
			_cakes = {"": {}}
	return _cakes


## A texture strip and its frames: {"tex": Texture2D, "frames": [[x, w, h, ox, oy]]},
## or {} when it wasn't exported.
static func _texture(file: String) -> Dictionary:
	if not _textures.has(file):
		var png := DIR + "tex/" + file + ".png"
		var meta := DIR + "tex/" + file + ".json"
		var info := {}
		if ResourceLoader.exists(png) and FileAccess.file_exists(meta):
			info = {"tex": load(png), "frames": JSON.parse_string(FileAccess.get_file_as_string(meta)).frames}
		_textures[file] = info
	return _textures[file]


## Blend modes as the original's: ADD adds light, MULT and INVMULT darken,
## the rest blend normally with black as see-through (the textures sit on black).
static func _material(blend: String) -> ShaderMaterial:
	var kind: String = {"ADD": "add", "MULT": "mul", "INVMULT": "invmul"}.get(blend, "mix")
	if not _materials.has(kind):
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/cake_%s.gdshader" % kind)
		_materials[kind] = m
	return _materials[kind]


func _build() -> void:
	for sub: Dictionary in _subs:
		var node := CakeLayer.new()
		node.sub = sub
		node.tex = _texture(String(sub.cream.get("TextureFile", "")))
		node.material = _material(String(sub.cream.get("CreamBlendMode", "BLEND")))
		node.z_index = SORT_Z.get(sub.sort, 18)
		node.z_as_relative = false
		sub.node = node
		add_child(node)


## Stops emitting and fades the particles out; the effect frees itself once
## they're gone.
func stop() -> void:
	if _stopping:
		return
	_stopping = true
	for sub: Dictionary in _subs:
		for p: Dictionary in sub.particles:
			p.life = minf(float(p.life), float(p.age) + FADE)


func _process(delta: float) -> void:
	_t += delta
	if is_instance_valid(follow):
		global_position = follow.global_position
	elif follow != null:
		stop()
	if hold > 0.0 and _t >= hold and _loop:
		stop()
	var alive := false
	for sub: Dictionary in _subs:
		alive = _step(sub, delta) or alive
	if not alive and (_stopping or not _loop):
		queue_free()


## Emits and moves one cream's particles; true while it has any or will.
func _step(sub: Dictionary, delta: float) -> bool:
	var c: Dictionary = sub.cream
	var parts: Array = sub.particles
	var local := _t - float(sub.start)
	var max_count := int(c.get("MaxCount", 1))
	var looping := _loop or int(c.get("IsLoop", 0)) == 1
	var emitting := local >= 0.0 and not _stopping and (looping or int(sub.emitted) < max_count)
	if emitting:
		sub.carry = float(sub.carry) + float(c.get("EmissionRate", 10.0)) * delta
		while float(sub.carry) >= 1.0 and parts.size() < max_count and (looping or int(sub.emitted) < max_count):
			sub.carry = float(sub.carry) - 1.0
			parts.append(_spawn(c))
			sub.emitted = int(sub.emitted) + 1
		if parts.size() >= max_count:
			sub.carry = 0.0
	var gravity := _vec(c.get("Gravity", [0, 0, 0]))
	var drag := float(c.get("AirResistance", 0.0))
	var bounce := String(c.get("Pattern", "")) == "Bounding"
	for i in range(parts.size() - 1, -1, -1):
		var p: Dictionary = parts[i]
		p.age = float(p.age) + delta
		if float(p.age) >= float(p.life):
			parts.remove_at(i)
			continue
		var v: Vector3 = p.vel
		var speed := v.length()
		if drag > 0.0 and speed > 0.0:
			v = v * maxf(speed - drag * delta, 0.0) / speed
		v += gravity * delta
		var pos: Vector3 = p.pos + v * delta
		if bounce and pos.y < 0.0 and v.y < 0.0:
			pos.y = 0.0
			v.y = -v.y * 0.4
		p.pos = pos
		p.vel = v
		p.rot = float(p.rot) + float(p.spin) * delta
	sub.node.queue_redraw()
	return parts.size() > 0 or (local < 0.0 and not _stopping) or emitting


func _spawn(c: Dictionary) -> Dictionary:
	var origin := _vec(c.get("EmitterPosition", [0, 0, 0])) + _spread(_vec(c.get("EmitterRadius", [0, 0, 0])))
	var dest := _vec(c.get("Destination", [0, 0, 0])) + _spread(_vec(c.get("DestinationRadius", [0, 0, 0])))
	var speed := _vary(float(c.get("Velocity", 0.0)), float(c.get("VelocityDispersion", 0.0)))
	var dir := dest - origin
	if dir.length() < 0.01:
		dir = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1))
	var spin := lerpf(float(c.get("MainAngleVelocity", 0.0)), float(c.get("SubAngleVelocity", c.get("MainAngleVelocity", 0.0))), randf())
	var a0 := float(c.get("StartAngle", 0.0))
	var a1 := float(c.get("EndAngle", a0))
	return {"pos": origin, "vel": dir.normalized() * speed, "age": 0.0,
		"life": maxf(_vary(float(c.get("Time", 1.0)), float(c.get("TimeDispersion", 0.0))), 0.02),
		"rot": deg_to_rad(randf_range(minf(a0, a1), maxf(a0, a1))), "spin": deg_to_rad(spin),
		"tint": randf(), "frame": randi() % 64}


static func _vec(a: Variant) -> Vector3:
	if a is Array and a.size() >= 3:
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return Vector3.ZERO


static func _spread(r: Vector3) -> Vector3:
	return Vector3(randf_range(-r.x, r.x), randf_range(-r.y, r.y), randf_range(-r.z, r.z))


static func _vary(v: float, dispersion: float) -> float:
	return v * (1.0 + clampf(dispersion, 0.0, 1.0) * randf_range(-1.0, 1.0))
