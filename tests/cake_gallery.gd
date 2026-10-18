extends Node2D
## Plays the exported original effects (Cake) on a grid, 12 per page, and
## saves each page at a few moments, to check the player and to see which
## effect is which. Needs a window:
##   godot res://tests/cake_gallery.tscn -- out=C:/path [match=M_2] [times=0.15,0.4,0.9]

const CELL := Vector2(320, 240)
const COLS := 4
const ROWS := 3

var out := "user://cakes"
var match_text := ""
var times: Array[float] = [0.15, 0.4, 0.9]


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out = a.substr(4)
		elif a.begins_with("match="):
			match_text = a.substr(6)
		elif a.begins_with("times="):
			times.clear()
			for t in a.substr(6).split(","):
				times.append(float(t))
	DirAccess.make_dir_recursive_absolute(out)
	RenderingServer.set_default_clear_color(Color(0.42, 0.45, 0.4))
	_go.call_deferred()


func _go() -> void:
	var names: Array = Cake._data().keys()
	names = names.filter(func(n: String) -> bool: return n != "" and (match_text == "" or match_text in n))
	names.sort()
	var per := COLS * ROWS
	for page in ceili(names.size() / float(per)):
		for ch in get_children():
			ch.queue_free()
		await get_tree().process_frame
		var batch := names.slice(page * per, (page + 1) * per)
		for i in batch.size():
			var at := Vector2((i % COLS + 0.5) * CELL.x, (i / COLS + 0.75) * CELL.y)
			var mark := Node2D.new()
			add_child(mark)
			var label := Label.new()
			label.text = batch[i]
			label.position = at + Vector2(-CELL.x / 2 + 6, -CELL.y * 0.72)
			label.add_theme_font_size_override("font_size", 13)
			add_child(label)
			var dot := ColorRect.new()
			dot.color = Color(0, 0, 0, 0.5)
			dot.size = Vector2(6, 3)
			dot.position = at - Vector2(3, 1)
			add_child(dot)
			Cake.play(self, batch[i], at, {"hold": 2.0})
		var t0 := 0.0
		for t in times:
			await get_tree().create_timer(t - t0).timeout
			t0 = t
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(out.path_join("page%02d_t%03d.png" % [page, int(t * 100)]))
	print("pages: ", ceili(names.size() / float(per)))
	get_tree().quit()
