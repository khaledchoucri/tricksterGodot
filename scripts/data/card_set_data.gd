class_name CardSetData
extends Resource
## A set in the Card Hunter's bestiary (after the original Card_SpecialSet):
## collect one card from each monster to claim the wardrobe piece.

@export var id: StringName
@export var display_name := ""
## EnemyData ids whose cards complete the set.
@export var monsters: Array[StringName] = []
@export var reward: WardrobeData


func progress() -> int:
	var n := 0
	for m in monsters:
		if int(Profile.cards.get(String(m), 0)) > 0:
			n += 1
	return n


func complete() -> bool:
	return progress() >= monsters.size()


func claimed() -> bool:
	return Profile.has_flag("set_" + String(id))
