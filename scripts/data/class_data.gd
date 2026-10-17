class_name ClassData
extends Resource
## A playable class: its look, base stats, how it grows on its own (the
## type graph), its 1st job and starting weapon. Classes never hard-code
## stats or skills, so a new class is new data.

@export var id: StringName
@export var display_name := ""
## Actor folder name under original_assets/actors.
@export var actor := ""
## Stats at level 1 (Stats.KEYS).
@export var base: Dictionary = {}
## Type points gained automatically each level (they raise stats but don't
## count toward traits), e.g. {"power": 0.5, "charm": 0.3, ...}.
@export var graph: Dictionary = {}
@export var start_job: JobData
@export var start_weapon: ItemData
## Fixed basic combo (a Bunny's punches); empty: the weapon family's combo.
@export var combo: ComboData
## Whether the held weapon is drawn (a boxer keeps it sheathed).
@export var armed := true
## A class that has to be earned: Profile stat, amount, and the hint.
@export var unlock_stat := ""
@export var unlock_count := 0
@export var unlock_text := ""
@export_multiline var text := ""


func unlocked() -> bool:
	return unlock_stat == "" or int(Profile.stats.get(unlock_stat, 0)) >= unlock_count
