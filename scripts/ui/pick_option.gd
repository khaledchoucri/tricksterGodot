class_name PickOption
extends Button
## One choice in the pick-one panel (a card, a type point, gear, a refine).

const LINE_HEIGHT := 18.0


func setup(index: int, title: String, tag: String, text: String, icon_tex: Texture2D = null) -> void:
	(%Head as Label).text = "%d.  %s   %s" % [index + 1, title, tag]
	(%Body as Label).text = text
	var icon_rect: TextureRect = %Icon
	icon_rect.texture = icon_tex
	icon_rect.visible = icon_tex != null
	# Grow for bodies longer than one line.
	custom_minimum_size.y = maxf(custom_minimum_size.y, 46.0 + LINE_HEIGHT * text.count("
") + LINE_HEIGHT)
