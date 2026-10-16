class_name PickOption
extends Button
## One choice in the pick-one panel (a card, a type point, gear, a refine).

const ICON_SCALE := 1.5


func setup(index: int, title: String, tag: String, text: String, icon_tex: Texture2D = null) -> void:
	(%Head as Label).text = "%d.  %s   %s" % [index + 1, title, tag]
	(%Body as Label).text = text
	if icon_tex:
		var r := TextureRect.new()
		r.texture = icon_tex
		r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.scale = Vector2.ONE * ICON_SCALE
		r.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
		r.position = Vector2(custom_minimum_size.x - icon_tex.get_width() * ICON_SCALE - 14.0,
			(custom_minimum_size.y - icon_tex.get_height() * ICON_SCALE) / 2.0)
		add_child(r)
