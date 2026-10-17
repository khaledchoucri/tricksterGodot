class_name PickOption
extends Button
## One choice in the pick-one panel (a card, a type point, gear, a refine).

const LINE_HEIGHT := 18.0
const ICON_ROOM := 84.0


## `key`: the shortcut shown before the title ("1".."0", "Esc", or "").
func setup(key: Variant, title: String, tag: String, text: String, icon_tex: Texture2D = null) -> void:
	var k := str(key + 1) if key is int else String(key)
	var prefix := "" if k == "" else ("[%s]  " % k if k == "Esc" else "%s.  " % k)
	(%Head as Label).text = "%s%s   %s" % [prefix, title, tag]
	(%Body as Label).text = text
	var icon_rect: TextureRect = %Icon
	icon_rect.texture = icon_tex
	icon_rect.visible = icon_tex != null
	(%Text as Control).offset_right = -ICON_ROOM if icon_tex else -14.0
	# Grow for bodies longer than one line.
	custom_minimum_size.y = maxf(custom_minimum_size.y, 46.0 + LINE_HEIGHT * text.count("
") + LINE_HEIGHT)


## Grows to fit wrapped text once laid out at its real width.
func fit() -> void:
	var need := (%Text as Control).get_combined_minimum_size().y + 16.0
	if need > custom_minimum_size.y:
		custom_minimum_size.y = need
