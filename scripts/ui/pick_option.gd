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
	fit(custom_minimum_size.x)


## Sizes the row for its text wrapped at `width`. Measured from the fonts,
## not from layout (which may not have run yet, and once made rows huge).
func fit(width: float) -> void:
	var text_w := width - 14.0 - (ICON_ROOM if (%Icon as Control).visible else 14.0)
	var gap := float((%Text as VBoxContainer).get_theme_constant("separation"))
	var h := _text_height(%Head, text_w) + gap + _text_height(%Body, text_w) + 18.0
	custom_minimum_size = Vector2(width, maxf(64.0, ceilf(h)))


static func _text_height(l: Label, width: float) -> float:
	if l.text == "":
		return 0.0
	var font := l.get_theme_font("font")
	var size := l.get_theme_font_size("font_size")
	var lines := l.text.split("\n")
	var h := 0.0
	for line in lines:
		h += font.get_multiline_string_size(line if line != "" else " ", HORIZONTAL_ALIGNMENT_LEFT, width, size).y
	return h + float(l.get_theme_constant("line_spacing")) * (lines.size() - 1)
