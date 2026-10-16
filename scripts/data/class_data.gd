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
