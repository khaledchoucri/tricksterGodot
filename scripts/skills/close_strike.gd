extends Skill
## Close strikes of the Sense line, at the first enemy in front within the
## table's Range:
##  - Butt Plate (3201): clubs with the gun's butt (needs a gun).
##  - Lucky Fist (3204): "trust your luck": its damage swings with LK.
##  - Exploit Weakness (3307): strikes through any defence (ignores DP).
##  - Sudden Attack (3302): only from hiding, and ends it.

const ARC := deg_to_rad(80.0)


func _init() -> void:
	duration = 0.32
	anim = "attack"
	dash_cancel_at = 0.15


func start() -> void:
	if card.id == &"sudden_attack":
		if not Run.hidden:
			return
		Run.hidden = false


func update(t: float, _delta: float) -> void:
	if not once(t, 0.1):
		return
	var foe := nearest_in_wedge(aim, param("range", 80.0) + 30.0, ARC)
	if foe == null:
		return
	var amount := damage()
	var fx := {}
	match card.id:
		&"lucky_fist":
			# More LK, more upside: anywhere from half to (1 + LK/50) times.
			amount *= Run.rng.randf_range(0.5, 1.0 + Run.stat("LK") / 50.0)
		&"exploit_weakness":
			fx.pierce = true
		&"butt_plate":
			fx.gun = true
	hit(foe, amount, 120.0, true, fx)
	feedback(0.04, 3.0)
