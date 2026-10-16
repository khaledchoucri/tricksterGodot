class_name Sparks
extends CPUParticles2D
## One-shot burst of particles (hit sparks, dust, embers) that frees itself.


static func burst(parent: Node, at: Vector2, color: Color, amount := 14, speed := 120.0,
		life := 0.4, size := 2.5, gravity := 0.0) -> Sparks:
	var p := Sparks.new()
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = amount
	p.lifetime = life
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, gravity)
	p.damping_min = speed * 1.2
	p.damping_max = speed * 1.8
	p.scale_amount_min = size * 0.6
	p.scale_amount_max = size
	var ramp := Gradient.new()
	ramp.set_color(0, color)
	ramp.set_color(1, Color(color, 0.0))
	p.color_ramp = ramp
	p.z_index = 16
	parent.add_child(p)
	p.global_position = at
	p.emitting = true
	p.finished.connect(p.queue_free)
	return p
