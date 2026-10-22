class_name BossTutankhamen
extends Boss
## Tutankhamen, the Desert Beach boss at the Pyramid Steps (scenes/boss_tutankhamen.tscn).
## His BossMonsterparamEx row (2097): four bars (LifeCnt 3); SummonMon Mad Lieutenant (2286),
## Mad Sergeant (2287), Mad Captain (2288) and Sphinx (2289); Mana Shield (2013), Mana Arrow
## (2001) and Rust (2011) from his second bar (SkillLeftLife 2), M Mana Ring (5103) and M Warp
## (5123) from his third (SkillLeftLife 1); M Cure on his last two bars (HealLeftLife).
##
## The fight, bar by bar:
##  1. He calls his three Mads as he steps in, and each keeps casting its spell on him while it
##     stands: the Lieutenant's Mad Spirit (5110), the Sergeant's Mana Shield, the Captain's M
##     Cure (5101). Up close he slams (his attack pattern) and drops sand coffins around you.
##  2. He looses Mana Arrows five at a time (Arrow Rush) and casts Rust on you (AP down).
##  3. At half his HP he calls two Sphinxes, casts Mana Storm and warps away when you keep him
##     pinned. His row's M Cure begins.
##  4. His last bar: M Cure comes every 1.5 s (HealLevel_1 4).
## Deviation (user, 2026-10-22): the Mads come as the fight opens (SummonLeftLife is 2: the row
## calls them from his second bar), they cast support spells on him (the row gives them their
## own Tactics_Mon352-354: Mad Spirit, a "guard the king" line, M Cure), the Sergeant's Mana
## Shield is a barrier that soaks damage (Mana Shield 2013 raises MD), two Sphinxes come at
## half HP, and he casts Mana Storm (2009, not in his row) in place of M Mana Ring.
## Ours: the coffins (kept from before), every cooldown, and how each spell plays out.
## Dropped: the curse fan (Mana Arrow is his row's ranged spell) and the Basic Mummy calls.
##
## Tune keys (BossData.tune), with their defaults below: coffin_every, arrow_every, arrows,
## arrow_share, rust_every, storm_every, storm_mult, storm_radius, warp_every, warp_pinned,
## spirit_every, spirit_damage, spirit_speed, spirit_for, shield_every, shield_share,
## shield_for, cure_every, cure_share, sphinxes.

## Sand coffins: three snap shut around you, one after another. Ours.
const COFFIN_EVERY := 8.5
const COFFIN_RADIUS := 52.0
const COFFIN_DELAY := 1.0
const COFFIN_STAGGER := 0.35
## Mana Arrow with Arrow Rush (2001, 2007): five arrows fly as the player's do (MagicFlight),
## each this share of his hit (as magic). Ours: every 5 s (his row tries it every 3).
const ARROW_EVERY := 5.0
const ARROWS := 5
const ARROW_SHARE := 0.3
const ARROW_RANGE := 300.0
## Rust (ESAction_DarkFog lv4): AP -24% for 18 s, landing 62% of the time. Ours: every 9 s.
const RUST_EVERY := 9.0
const RUST_RADIUS := 60.0
const RUST_WINDUP := 0.8
const RUST_CUT := 24.0
const RUST_FOR := 18.0
const RUST_CHANCE := 0.62
## Mana Storm: a burst where you stand after a telegraph. Ours.
const STORM_EVERY := 7.0
const STORM_WINDUP := 1.0
const STORM_RADIUS := 70.0
const STORM_MULT := 1.6
## M Warp (ESAction_Mon_Warp lv10, Radius 285): kept up close this long, he vanishes and
## reappears across the room. Ours: the time pinned, the vanish and the cooldown.
const WARP_PINNED := 2.5
const WARP_CLOSE := 80.0
const WARP_AWAY := 200.0
const WARP_VANISH := 0.6
const WARP_EVERY := 8.0
## The Lieutenant's M Mad Spirit (ESAction_Mon_Berserk lv2): AP x1.3 and speed x1.25 for
## 16 s, recast 5 s after (its Tactics Time).
const SPIRIT_DAMAGE := 1.3
const SPIRIT_SPEED := 1.25
const SPIRIT_FOR := 16.0
const SPIRIT_EVERY := 21.0
## The Sergeant's Mana Shield (ESAction_MagicWall lv4 Ratio 0.19): soaks 19% of a bar for
## 15 s, recast every 15 s (its first Tactics row's Time).
const SHIELD_SHARE := 0.19
const SHIELD_FOR := 15.0
const SHIELD_EVERY := 15.0
## The Captain's M Cure (ESAction_Mon_Heal lv1): 6% of a bar every 10 s (its Tactics Time).
const CURE_SHARE := 0.06
const CURE_EVERY := 10.0
## Sphinxes called at half HP.
const SPHINXES := 2

var _coffin_at := 0.0
var _arrow_at := 0.0
var _rust_at := 0.0
var _storm_at := 0.0
var _warp_at := 0.0
var _pinned_for := 0.0
var _spirit_at := 0.0
var _shield_at := 0.0
var _cure_at := 0.0
var _sphinxes_called := false
var _raged := false


func _ready() -> void:
	super._ready()
	var t := now() + INTRO_FOR
	_coffin_at = t + 5.0
	_arrow_at = t + 2.0
	_rust_at = t + 4.0
	_storm_at = t + 3.0
	_spirit_at = t + 2.0
	_shield_at = t + 3.0
	_cure_at = t + CURE_EVERY
	summon(&"spirit", 1)
	summon(&"barrier", 1)
	summon(&"mender", 1)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if state == State.DEAD or state == State.SPAWN:
		return
	_support_spells()
	if lives_left <= 1 and is_instance_valid(player):
		var close := Combat.ground(player.global_position - global_position).length() < WARP_CLOSE
		_pinned_for = _pinned_for + delta if close else 0.0


func _on_phase(lives: int) -> void:
	if lives <= 1 and not _sphinxes_called:
		_sphinxes_called = true
		Events.boss_spoke.emit(boss.line_summon)
		summon(&"sphinx", int(num("sphinxes", SPHINXES)))
	if lives <= 0 and not _raged:
		_raged = true
		Events.boss_spoke.emit(boss.line_rage)


func _state_chase() -> void:
	if not is_instance_valid(player) or player.state == Player.State.DEAD:
		super._state_chase()
		return
	var dist := Combat.ground(player.global_position - global_position).length()
	if lives_left <= 1 and _pinned_for >= num("warp_pinned", WARP_PINNED) and now() >= _warp_at:
		_warp()
		return
	if now() >= _coffin_at and room.request_attack_token(self):
		_sand_coffins()
		return
	if lives_left <= 1 and now() >= _storm_at and room.request_attack_token(self):
		_mana_storm()
		return
	if lives_left <= 2 and now() >= _rust_at and room.request_attack_token(self):
		_rust()
		return
	if lives_left <= 2 and now() >= _arrow_at and dist > 90.0 and dist < ARROW_RANGE and room.request_attack_token(self):
		_mana_arrows()
		return
	super._state_chase()


# ---------------------------------------------------------------- his Mads

## Each Mad standing casts its spell on him when it comes round.
func _support_spells() -> void:
	var lt := minion(&"spirit")
	if lt and now() >= _spirit_at:
		_spirit_at = now() + num("spirit_every", SPIRIT_EVERY)
		show_cast_from(lt, Color(1.0, 0.5, 0.35))
		empower(num("spirit_damage", SPIRIT_DAMAGE), num("spirit_speed", SPIRIT_SPEED), num("spirit_for", SPIRIT_FOR))
	var sgt := minion(&"barrier")
	if sgt and now() >= _shield_at:
		_shield_at = now() + num("shield_every", SHIELD_EVERY)
		show_cast_from(sgt, Color(0.55, 0.75, 1.0))
		shield(roundi(num("shield_share", SHIELD_SHARE) * bar_hp), num("shield_for", SHIELD_FOR))
	var cap := minion(&"mender")
	if cap and now() >= _cure_at:
		_cure_at = now() + num("cure_every", CURE_EVERY)
		if hp < bar_top():
			show_cast_from(cap, Color(0.5, 1.0, 0.55))
			heal(roundi(num("cure_share", CURE_SHARE) * bar_hp))


# ---------------------------------------------------------------- his spells

## Three coffins snap shut one after another around you.
func _sand_coffins() -> void:
	_coffin_at = now() + num("coffin_every", COFFIN_EVERY)
	_enter(State.RECOVER, 0.8)
	velocity = Vector2.ZERO
	sprite.play_action("attack", Combat.screen(Combat.ground(player.global_position - global_position)), 0.8, true)
	var spots: Array[Vector2] = [player.global_position]
	for i in 2:
		var off := Vector2.from_angle(Run.rng.randf() * TAU) * Vector2(90.0, 45.0)
		var p := player.global_position + off
		spots.append(p if room.is_walkable(p) else room.nearest_reachable(p))
	room.release_attack_token(self)
	for i in spots.size():
		_coffin(spots[i], COFFIN_DELAY + COFFIN_STAGGER * i)


func _coffin(at: Vector2, delay: float) -> void:
	var warn := Telegraph.make("circle", delay, {"radius": COFFIN_RADIUS})
	room.add_ground_fx(warn, at)
	await get_tree().create_timer(delay, false).timeout
	if state == State.DEAD or not is_inside_tree() or not is_instance_valid(player):
		return
	if is_instance_valid(warn):
		warn.trigger()
	Ring.spawn(room.ground_fx, at, COFFIN_RADIUS, 0.4, Color("d8b56a"))
	Events.shake_requested.emit(4.0)
	Audio.play("dmg_normal_c.wav", -4.0)
	if not player.is_invulnerable() and Combat.in_circle(at, player.global_position, COFFIN_RADIUS, 10.0):
		player.take_hit(damage + 4, Combat.ground(player.global_position - at).normalized(), 260.0, true, accuracy(), self)


## Mana Arrow with Arrow Rush: the arrows appear beside him and rush at you one by one.
func _mana_arrows() -> void:
	_arrow_at = now() + num("arrow_every", ARROW_EVERY)
	_cast_pose(0.7)
	var card: CardData = boss.spells.get(&"arrow")
	var count := int(num("arrows", ARROWS))
	var dmg := maxi(1, roundi(damage * num("arrow_share", ARROW_SHARE)))
	for i in count:
		var f := MagicFlight.new()
		f.room = room
		f.caster = self
		f.target = player
		f.target_point = player.global_position
		f.appear = 0.3 / count * i
		f.on_appear = func() -> void:
			if card:
				card.play("launch", -10.0)
		f.on_hit = func(who: Node2D) -> void:
			if who is Player and is_instance_valid(room):
				if card:
					for fx: String in card.effects.get("ht", []):
						Cake.play(room, fx, who.global_position, {"follow": who})
				(who as Player).take_hit(dmg, Combat.ground(who.global_position - global_position).normalized(), 60.0,
					true, accuracy(), self)
		room.add_child(f)
	room.release_attack_token(self)


## Rust: a dark fog where you stand; caught in it, your AP drops for a while.
func _rust() -> void:
	_rust_at = now() + num("rust_every", RUST_EVERY)
	_cast_pose(RUST_WINDUP)
	var at := player.global_position
	var warn := Telegraph.make("circle", RUST_WINDUP, {"radius": RUST_RADIUS, "color": Color(0.55, 0.4, 0.3)})
	room.add_ground_fx(warn, at)
	room.release_attack_token(self)
	await get_tree().create_timer(RUST_WINDUP, false).timeout
	if broken_off():
		return
	if is_instance_valid(warn):
		warn.trigger()
	Sparks.burst(room, at, Color(0.6, 0.45, 0.3), 26, 80.0, 0.9, 4.0)
	if not player.is_invulnerable() and Combat.in_circle(at, player.global_position, RUST_RADIUS, 10.0) \
			and Run.rng.randf() < RUST_CHANCE:
		Run.apply_debuff("AP", RUST_CUT, RUST_FOR, "Rust")
		Events.text_shown.emit(player.global_position + Vector2(0, -80), "Rust: AP -%d%%" % roundi(RUST_CUT), Color(0.85, 0.6, 0.4))


## Mana Storm: a burst lands where you stood after a telegraph.
func _mana_storm() -> void:
	_storm_at = now() + num("storm_every", STORM_EVERY)
	_cast_pose(STORM_WINDUP)
	var at := player.global_position
	var radius := num("storm_radius", STORM_RADIUS)
	var warn := Telegraph.make("circle", STORM_WINDUP, {"radius": radius, "color": Color(0.5, 0.55, 1.0)})
	room.add_ground_fx(warn, at)
	room.release_attack_token(self)
	await get_tree().create_timer(STORM_WINDUP, false).timeout
	if broken_off():
		return
	if is_instance_valid(warn):
		warn.trigger()
	var card: CardData = boss.spells.get(&"storm")
	if card:
		card.play("ht", -4.0)
		for fx: String in card.effects.get("ht", []):
			Cake.play(room, fx, at)
	Events.shake_requested.emit(4.0)
	if not player.is_invulnerable() and Combat.in_circle(at, player.global_position, radius, 10.0):
		player.take_hit(roundi(damage * num("storm_mult", STORM_MULT)), Combat.ground(player.global_position - at).normalized(),
			200.0, true, accuracy(), self)


## M Warp: kept up close too long, he vanishes and steps out across the room.
func _warp() -> void:
	_warp_at = now() + num("warp_every", WARP_EVERY)
	_pinned_for = 0.0
	_cancel_attack()
	_enter(State.RECOVER, WARP_VANISH + 0.3)
	velocity = Vector2.ZERO
	Sparks.burst(room, global_position + Vector2(0, -30), Color(0.7, 0.6, 1.0), 24, 140.0, 0.5)
	var tw := create_tween()
	tw.tween_property(sprite, "modulate:a", 0.0, WARP_VANISH * 0.5)
	await tw.finished
	if broken_off():
		sprite.modulate.a = 1.0
		return
	var away := Combat.screen(Vector2.from_angle(Run.rng.randf() * TAU)) * WARP_AWAY
	var spot := player.global_position + away
	global_position = spot if room.is_open_spot(spot) else room.nearest_reachable(spot)
	Ring.spawn(room.ground_fx, global_position, 50.0, 0.4, Color(0.7, 0.6, 1.0, 0.9))
	create_tween().tween_property(sprite, "modulate:a", 1.0, WARP_VANISH * 0.5)


## Holds still in his cast pose for `seconds`.
func _cast_pose(seconds: float) -> void:
	_enter(State.RECOVER, seconds)
	velocity = Vector2.ZERO
	var dir := Combat.screen(Combat.ground(player.global_position - global_position))
	sprite.play_action("cast" if sprite.has_action("cast") else "attack", dir, seconds, true)
