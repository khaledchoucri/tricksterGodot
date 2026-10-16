extends Node2D
## Runs one Coral Beach expedition: loads rooms cut from the original maps,
## hands out rewards and level-ups, and ends in a rollback or a clear, which
## banks the run into the Profile and returns to Megalopolis (scenes/hub.tscn).
## Presents combat feedback (hit-stop, shake, damage numbers) announced on
## the Events bus.

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const HUB_SCENE := "res://scenes/hub.tscn"
const REWARD_POOL: Array[String] = ["card", "card", "upgrade", "heal", "galder", "shard"]
const CAMERA_MARGIN := 60
## MP restored on entering a room.
const ROOM_MP := 40

enum Phase { LOADING, FIGHT, REWARD, DOORS, DEAD, WON, MISSING }

var phase := Phase.LOADING
var room: Room
var player: Player
var reward_here := "card"   # reward granted when the current room is cleared

var _shake := 0.0
var _hitstop_id := 0
var _pick_kind := ""
var _pick_options: Array = []
var _pending_skill: CardData  # new skill waiting for a slot to replace

@onready var hud: Hud = $Hud


func _ready() -> void:
	hud.picked.connect(_on_picked)
	hud.restart_requested.connect(_restart)
	Events.hitstop_requested.connect(_on_hitstop)
	Events.shake_requested.connect(func(amount: float) -> void: _shake = maxf(_shake, amount))
	Events.damage_shown.connect(_on_damage_shown)
	Events.enemy_spawned.connect(_on_enemy_spawned)
	Events.enemy_died.connect(_on_enemy_died)
	Events.boss_health_changed.connect(func(e: Enemy) -> void: hud.show_boss(e.display_name, e.hp, e.max_hp))
	Events.boss_spoke.connect(func(text: String) -> void: hud.log_line("[Real Golden Mole] " + text, Color("e0b54d")))
	Events.player_died.connect(_on_player_died)
	Events.revived.connect(func() -> void:
		hud.log_line("[System] Rollback Cache restored you.", Color("c9a4ff"))
		hud.notice("Saved by the Rollback Cache"))
	if not FileAccess.file_exists("res://original_assets/actors/buffalo/buffalo.json") \
			or not FileAccess.file_exists("res://original_assets/maps/map_fd11d/map.json"):
		phase = Phase.MISSING
		hud.center("Original assets not found.\nRun tools/setup_assets.py (see docs/poc/README.md), then reopen the project.")
		return
	Run.new_run()
	hud.log_line("[Notice] Trickster service has ended. Thank you for playing.", Color("f07a62"))
	hud.log_line("[Coral Beach] Players online: 1", Color("94a7b2"))
	_load_room()


## After a run: back to the city.
func _restart() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().change_scene_to_file(HUB_SCENE)


# ---------------------------------------------------------------- rooms

func _load_room() -> void:
	phase = Phase.LOADING
	if room:
		# Leave the tree right away so nothing touches the old room again.
		remove_child(room)
		room.queue_free()
		room = null
		player = null
	var plan := Run.current_room()
	room = Room.new()
	add_child(room)
	if not room.build(plan.data):
		phase = Phase.MISSING
		hud.center("Map %s is missing.\nRun tools/setup_assets.py." % plan.data.map)
		return
	room.cleared.connect(_on_room_cleared)
	room.door_entered.connect(_on_door_entered)
	_spawn_player(room.entry)
	Run.gain_mp(ROOM_MP + Run.room_mp_bonus())
	Audio.play_music(Run.region.boss_music if plan.boss else Run.region.field_music)
	Audio.play_ambience(Run.region.boss_ambience if plan.boss else Run.region.field_ambience)
	hud.set_room("%s  ·  %d / %d" % [plan.data.display_name, Run.depth + 1, Run.plan.size()])
	hud.hide_boss()
	await hud.fade(0.0, 0.3)
	var title := "Real Golden Mole" if plan.boss else plan.data.display_name
	if plan.elite:
		title += "\nElite monsters ahead"
	hud.center(title, 1.2)
	await get_tree().create_timer(0.9).timeout
	if room and room.is_inside_tree():
		phase = Phase.FIGHT
		room.start_encounter(Run.depth, plan.elite, plan.boss)


func _spawn_player(at: Vector2) -> void:
	player = PLAYER_SCENE.instantiate()
	player.room = room
	player.position = at
	room.player = player
	room.world.add_child(player)
	player.set_camera_limits(room.rect, CAMERA_MARGIN)


func _on_room_cleared() -> void:
	if not is_instance_valid(player) or player.state == Player.State.DEAD:
		return
	if Run.current_room().boss:
		_win()
		return
	phase = Phase.REWARD
	Audio.play("etc_monq_complete.wav", -4.0)
	hud.log_line("[System] Room cleared.", Color("94a7b2"))
	var cleared_room := room
	await get_tree().create_timer(0.6).timeout
	if room != cleared_room:
		return  # a different room loaded while we waited
	_grant(reward_here)


func _grant(reward: String) -> void:
	match reward:
		"card", "upgrade":
			var opts := Run.card_offers(3, reward == "upgrade")
			if opts.is_empty():
				opts = Run.card_offers(3, reward != "upgrade")
			if not opts.is_empty():
				_start_pick("card", opts)
				return
		"heal":
			var amount := int(Run.max_hp * 0.35)
			Run.heal(amount)
			Audio.play("eff_healing1.wav", -4.0)
			hud.notice("Recovered %d HP" % amount)
		"galder":
			var g := randi_range(120, 220)
			Run.galder += g
			Audio.play("etc_money.wav")
			hud.notice("+%d Galder" % g)
		"shard":
			Run.shards += 1
			Audio.play("ui_unique_get.wav", -4.0)
			hud.notice("Harkon Shard found")
			hud.log_line("[System] A Harkon Shard hums faintly in your inventory.", Color("c9a4ff"))
	_after_reward()


## Level-ups earned during the fight are chosen after any room reward.
func _after_reward() -> void:
	if Run.pending_levels > 0:
		Run.pending_levels -= 1
		_start_pick("stat", Run.stat_offers(3))
		return
	_open_doors()


func _open_doors() -> void:
	phase = Phase.DOORS
	var rewards: Array[String] = []
	if Run.depth + 1 >= Run.plan.size() - 1:
		rewards = ["boss"]
	else:
		var pool := REWARD_POOL.duplicate()
		pool.shuffle()
		rewards.append(pool[0])
		for r in pool:
			if r != pool[0]:
				rewards.append(r)
				break
	room.open_doors(rewards)
	Audio.play("etc_warpzone.wav", -6.0)
	hud.log_line("[System] Exits opened.", Color("94a7b2"))


func _on_door_entered(reward: String) -> void:
	Audio.play("etc_warp.wav")
	Run.depth += 1
	reward_here = "card" if reward == "boss" else reward
	await hud.fade(1.0, 0.25)
	_load_room()


# ---------------------------------------------------------------- picks

## kind "card": options are CardData. kind "stat": options are stat keys.
## kind "replace": options are slot indices, plus -1 to keep the current skills.
func _start_pick(kind: String, options: Array) -> void:
	_pick_kind = kind
	_pick_options = options
	var shown: Array[Dictionary] = []
	if kind == "card":
		for card: CardData in options:
			var lvl := Run.card_level(card.id)
			shown.append({"title": card.display_name,
				"tag": ("New skill" if card.is_skill() else "New talent") if lvl == 0 else "Lv %d → %d" % [lvl, lvl + 1],
				"text": card.describe(lvl + 1)})
		hud.show_pick("Choose a skill card", shown)
		Audio.play("ui_card.wav")
	elif kind == "replace":
		for slot: int in options:
			if slot < 0:
				shown.append({"title": "Keep my skills", "tag": "", "text": "Skip %s." % _pending_skill.display_name})
			else:
				var old := Run.region.card(Run.loadout[slot])
				shown.append({"title": "Replace %s" % old.display_name, "tag": "[%s]" % Hud.SLOT_KEYS[slot],
					"text": "%s takes this slot (Lv %d is lost)." % [_pending_skill.display_name, Run.card_level(old.id)]})
		hud.show_pick("Skill slots are full", shown)
	else:
		for k: String in options:
			shown.append({"title": Run.STATS[k].name, "tag": "+1", "text": Run.STATS[k].text})
		hud.show_pick("Level %d  ·  Choose a stat" % (Run.level - Run.pending_levels), shown)
		Audio.play("etc_levelup.wav")
	get_tree().paused = true


func _on_picked(i: int) -> void:
	get_tree().paused = false
	Audio.play("ui_btn_ok.wav")
	if _pick_kind == "card":
		var card: CardData = _pick_options[i]
		if card.is_skill() and Run.card_level(card.id) == 0 and Run.free_slot() < 0:
			_pending_skill = card
			_start_pick("replace", [0, 1, 2, -1])
			return
		Run.add_card(card.id)
		hud.log_line("[System] %s learned (Lv %d)." % [card.display_name, Run.card_level(card.id)], Color("a8d8da"))
	elif _pick_kind == "replace":
		var slot: int = _pick_options[i]
		if slot >= 0:
			Run.add_card(_pending_skill.id, slot)
			hud.log_line("[System] %s learned." % _pending_skill.display_name, Color("a8d8da"))
		_pending_skill = null
	else:
		Run.apply_stat(_pick_options[i])
	_after_reward()


# ---------------------------------------------------------------- end of run

func _on_player_died() -> void:
	phase = Phase.DEAD
	Run.finish(false)
	Audio.play("shchr002.wav")
	await get_tree().create_timer(1.2).timeout
	hud.log_line("[System] Connection lost.", Color("f07a62"))
	await hud.fade(0.85, 0.6)
	hud.log_line("[System] Rolling back server state...", Color("f07a62"))
	hud.show_results(false)


func _win() -> void:
	phase = Phase.WON
	Run.won = true
	Run.shards += 2
	Run.finish(true)
	Audio.play("guild_battlewin.wav")
	hud.log_line("[Notice] Coral Beach cleared. The Harkon Shards resonate.", Color("e0b54d"))
	await get_tree().create_timer(2.0).timeout
	await hud.fade(0.85, 0.6)
	hud.show_results(true)


func _process(delta: float) -> void:
	if phase in [Phase.FIGHT, Phase.REWARD, Phase.DOORS]:
		Run.time += delta
	if is_instance_valid(player):
		_shake = move_toward(_shake, 0.0, delta * 30.0)
		player.camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
	hud.refresh(player)


# ---------------------------------------------------------------- feedback

func _on_enemy_spawned(e: Enemy) -> void:
	if e.is_boss:
		hud.show_boss(e.display_name, e.hp, e.max_hp)


func _on_enemy_died(e: Enemy) -> void:
	Audio.play("sdmon103.wav" if e.is_boss else "etc_mon_death.wav", -4.0)
	var before := Run.level
	Run.add_kill(e.rewards.exp, e.rewards.tm, e.rewards.galder)
	if e.rewards.galder > 0:
		Audio.play("etc_money.wav", -10.0)
	if Run.level > before:
		Audio.play("etc_levelup.wav", -2.0)
		hud.notice("Level up! Lv %d  ·  choose a stat after the fight" % Run.level)
	if e.is_boss:
		hud.hide_boss()


func _on_hitstop(duration: float) -> void:
	_hitstop_id += 1
	var id := _hitstop_id
	Engine.time_scale = 0.05
	await get_tree().create_timer(duration, true, false, true).timeout
	if id == _hitstop_id:
		Engine.time_scale = 1.0


func _on_damage_shown(at: Vector2, amount: int, color: Color, big: bool) -> void:
	if room == null:
		return
	var l := Label.new()
	l.text = str(amount) + ("!" if big else "")
	l.add_theme_font_size_override("font_size", 18 if big else 14)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.15))
	l.add_theme_constant_override("outline_size", 4)
	l.z_index = 50
	l.position = at + Vector2(randf_range(-10, 4), 0)
	room.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", l.position.y - 22.0, 0.55).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.25).set_delay(0.35)
	tw.tween_callback(l.queue_free)
