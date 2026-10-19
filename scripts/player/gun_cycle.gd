class_name GunCycle
extends Node
## The gun's cycle as the original client runs it (Trickster.bin's
## GunProcessHandler: 0x50f760 the per-frame states, 0x50f330 and 0x50f3a0
## the fill rates, 0x50f4c0 the shot test, 0x5b9d10 the reload after a shot).
##  - Every shot starts a reload at once: progress fills by
##    dt_ms x rate x GaugeSpeed / 600 and completes at 200, so a reload takes
##    120000 / GaugeSpeed ms. Walking or running resets it (Quick Reload keeps
##    it), and so does a hit (Invincible Reload keeps it) and a dash (our rule).
##  - Loaded, a power gauge fills by dt_ms x PowRange / 1200 up to 200; a shot
##    fired with it above PowStartPoint is a power shot.
## No bullets (the user's rule): the gun is loaded or reloading, nothing else.

signal changed

enum State { NONE, RELOADING, LOADED }

const FULL := 200.0

var state := State.NONE
var progress := 0.0   # reload, 0..200
var power := 0.0      # power gauge once loaded, 0..200
var gun: Dictionary = {}  # the equipped gun's ItemData.gun
var player: Player


## Takes up a gun (or none) and starts loading it, as equipping does.
func equip(p_gun: Dictionary) -> void:
	gun = p_gun
	if gun.is_empty():
		state = State.NONE
	else:
		_start_reload()
	changed.emit()


func has_gun() -> bool:
	return not gun.is_empty()


func loaded() -> bool:
	return state == State.LOADED


## A reload's length in seconds, as Speedloader leaves it.
func reload_time() -> float:
	return 120.0 / maxf(float(gun.get("speed", 100)), 1.0) * Run.reload_mult()


func reload_ratio() -> float:
	return clampf(progress / FULL, 0.0, 1.0)


func power_ratio() -> float:
	return clampf(power / FULL, 0.0, 1.0)


## Where the power zone starts on the bar, 0..1.
func zone_ratio() -> float:
	return clampf(float(gun.get("zone", FULL)) / FULL, 0.0, 1.0)


func in_power_zone() -> bool:
	return loaded() and power > float(gun.get("zone", FULL))


## Fires: true if the gun was loaded (and whether it was a power shot in
## `last_power`); the reload starts at once.
var last_power := false


func fire() -> bool:
	if not loaded():
		return false
	last_power = in_power_zone()
	_start_reload()
	changed.emit()
	return true


## A dash, or a hit without Invincible Reload, throws the reload back to 0.
func interrupt(by_hit: bool) -> void:
	if state != State.RELOADING:
		return
	if by_hit and Run.card_level(&"invincible_reload") > 0:
		return
	progress = 0.0
	changed.emit()


func _start_reload() -> void:
	state = State.RELOADING
	progress = 0.0
	power = 0.0


func _physics_process(delta: float) -> void:
	if state == State.NONE or not is_instance_valid(player):
		return
	var ms := delta * 1000.0
	if state == State.RELOADING:
		# Moving resets the reload unless Quick Reload (the client's rule).
		if player.velocity.length() > 5.0 and player.state == Player.State.MOVE \
				and Run.card_level(&"quick_reload") <= 0:
			progress = 0.0
		else:
			progress += ms * float(gun.get("speed", 100)) / 600.0 / Run.reload_mult()
		if progress >= FULL:
			progress = FULL
			state = State.LOADED
			power = 0.0
		changed.emit()
	elif state == State.LOADED and power < FULL:
		power = minf(power + ms * float(gun.get("power", 170)) / 1200.0, FULL)
		changed.emit()
