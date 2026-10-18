class_name JobData
extends Resource
## A job in a class's tree (Fighter -> Knight -> Gladiator / Mercenary).
## Every run starts in the 1st job and changes job during the run; each job
## adds its skill tree to the card offers.

@export var id: StringName
@export var display_name := ""
@export_range(1, 3) var tier := 1
## Skill tree: the cards this job can offer (their prerequisites still apply).
@export var cards: Array[CardData] = []
## Granted when the job begins (a 1st job's starting skill).
@export var starter: CardData
## Job passive, checked by code through Run.has_passive().
@export var passive: StringName
@export var passive_name := ""
@export_multiline var passive_text := ""
@export_multiline var text := ""
## The character this job turns you into (an exported actor). In Trickster a
## job change replaces the character: Knight and Boxer at the 2nd job, and at
## the 3rd one body per type and sex. Empty keeps the previous job's.
@export var actor := ""
## Jobs this one can change into.
@export var next_jobs: Array[JobData] = []
## A branch that has to be earned: the Profile stat that unlocks it (e.g.
## "clears_gladiator"), how much of it, and the hint shown while locked.
@export var unlock_stat := ""
@export var unlock_count := 0
@export var unlock_text := ""


## `unlock_stat` may list several stats separated by "|" (any of them counts).
func unlocked() -> bool:
	if unlock_stat == "":
		return true
	var total := 0
	for stat in unlock_stat.split("|"):
		total += int(Profile.stats.get(stat, 0))
	return total >= unlock_count
