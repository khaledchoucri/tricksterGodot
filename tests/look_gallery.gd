extends Node2D
## Visual check for character looks: every job's own character with worn hats,
## shields and wardrobe pieces, in several directions and actions. Saves
## <out>/looks_<actor>.png. Run windowed (it renders):
##   godot res://tests/look_gallery.tscn -- out=C:/path

const CELL := Vector2(96, 120)
const ACTS := [["idle", Vector2(0, 1)], ["idle", Vector2(1, 0)], ["walk", Vector2(1, 1)], ["idle", Vector2(0, -1)],
	["walk", Vector2(-1, 1)], ["run", Vector2(-1, -1)], ["attack", Vector2(1, 1)], ["hit", Vector2(-1, 1)]]
## Item ids worn per row, by actor (hat, shield, wardrobe face/head/ear/tail).
const GEAR := [[4018, 4051], [4121, 0], [0, 0], [4086, 6033]]

var out := "user://looks"


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
	DirAccess.make_dir_recursive_absolute(out)
	RenderingServer.set_default_clear_color(Color(0.55, 0.6, 0.55))
	_go.call_deferred()


func _go() -> void:
	for cls_path: String in ["res://data/classes/buffalo.tres", "res://data/classes/bunny.tres"]:
		var cls: ClassData = load(cls_path)
		var jobs: Array[JobData] = [cls.start_job]
		for j in cls.start_job.next_jobs:
			jobs.append(j)
			for k in j.next_jobs:
				if not k in jobs:
					jobs.append(k)
		var worn_sets: Array = [
			["hat019", "shield019", "", ""], ["hat121", "", "face_cm_001", ""],
			["", "shield004", "head_cm_006", ""], ["hat_ex_002", "shield121", "", "ear010" if cls.actor == "buffalo" else "ear009"],
			["hat086", "shield033", "face_cm_012", "tail010" if cls.actor == "buffalo" else ""],
			["", "", "", ""], ["hat033", "shield133", "", ""]]
		for r in jobs.size():
			for c in ACTS.size():
				var s := ActorSprite.new()
				add_child(s)
				s.setup(jobs[r].actor if jobs[r].actor != "" else cls.actor)
				s.position = Vector2(60 + c * CELL.x * 1.5, 105 + r * CELL.y)
				var set: Array = worn_sets[r % worn_sets.size()]
				s.wear("hat", set[0])
				s.wear("shield", set[1])
				s.wear("fashion", set[2])
				s.wear("ear", set[3])
				s.play_action(ACTS[c][0], ACTS[c][1])
				s.pause()
				s.frame = 1 if s.sprite_frames.get_frame_count(s.animation) > 1 else 0
			var l := Label.new()
			l.text = jobs[r].display_name
			l.position = Vector2(4, 105 + r * CELL.y - 100)
			add_child(l)
		await get_tree().create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("looks_%s.png" % cls.actor))
		for ch in get_children():
			ch.queue_free()
		await get_tree().process_frame
	get_tree().quit()
