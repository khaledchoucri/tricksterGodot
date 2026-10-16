class_name PickOption
extends Button
## One choice in the pick-one panel (a card, a stat, a slot to replace).


func setup(index: int, title: String, tag: String, text: String) -> void:
	(%Head as Label).text = "%d.  %s   %s" % [index + 1, title, tag]
	(%Body as Label).text = text
