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
## A spell cast on the basic attack instead of the combo, at no MP (Sheep's
## Mana Ring, Dragon's Mana Arrow). Its card is the class's starter.
@export var basic_skill: CardData
## Share of max MP regenerated per second (mages only).
@export var mp_regen := 0.0
## Seconds between basic attacks when the basic skill's own cooldown is too
## slow for a left-click attack (Fox: Shuriken Master's 2 s; 0 keeps it).
@export var basic_cooldown := 0.0
## Talents the class starts every run with (Lion: Quick Reload).
@export var start_cards: Array[StringName] = []
## Spells cast by this class can't be interrupted by hits (Invincible Casting).
@export var steady_casting := false
## Cards this class is never offered (the other mage's basic spell).
@export var excluded_cards: Array[StringName] = []
## Prerequisites this class meets with another card: id -> id.
@export var swap_requires: Dictionary = {}
## A class that has to be earned: Profile stat, amount, and the hint.
@export var unlock_stat := ""
@export var unlock_count := 0
@export var unlock_text := ""
@export_multiline var text := ""


func unlocked() -> bool:
	return unlock_stat == "" or int(Profile.stats.get(unlock_stat, 0)) >= unlock_count
