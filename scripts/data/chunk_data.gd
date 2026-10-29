class_name ChunkData
extends Resource
## One run's worth of the world: three regions played in one job tier (docs/design/systems-plan.md,
## "A run is one chunk of three regions"). Deviation (user, 2026-10-22): a chunk is played in one
## job tier, and its clear opens the next chunk for that character, in its next job. The defaults
## are chunk 1's, so a route without a chunk plays as chunk 1 does.

@export var number := 1
@export var regions: Array[RegionData] = []
## The level a run starts at: 1, or the level the chunk before ends at (a veteran start).
@export var start_level := 1
## The job tier the whole chunk is played in (1st, 2nd or 3rd job).
@export_range(1, 3) var job_tier := 1
## The chunk whose clear opens this one for a character (0: open from the start).
@export var opened_by := 0
## Ours: cards of this tier up to this original TM level (CardData.tm_level) are offered from the
## first room. Chunk 1: the original's first 20 TM levels pass in its first hours; here they give
## room 1 a choice (six of a Fighter's eleven cards).
@export var tm_open := 20
## Ours: past tm_open, a card of this tier comes this many run levels per original TM level.
## Chunk 1 spreads a 1st job's cards (TM 1-50, Sense's to 70) over Lv 1 to about 54: a Fighter's
## last card (TM 50) comes at Lv 18 in Desert Beach, Sense's TM 70 ones at Lv 30 in the Relics.
## Reading: one run level stands for both the original's character and TM levels.
@export var tm_pace := 0.6
## How a veteran start carries the earlier jobs' cards (RunVeteran.carry_cards()): "" none,
## "max" every card at its cap, "all:L" every card at Lv L, "draft:N:L" N picks of one of three,
## each at Lv L, offered before the first room.
@export var veteran_cards := ""


## Whether the character `cls_id` may play this chunk.
func open_for(cls_id: String) -> bool:
	return opened_by == 0 or Profile.chunk_cleared(cls_id) >= opened_by


## Whether the chunk can be played yet (its regions are built).
func playable() -> bool:
	return not regions.is_empty()


## The regions' names, for the gate's menu ("Coral Beach > Desert Beach > Caballa Relics").
func route_text() -> String:
	var names: PackedStringArray = []
	for r in regions:
		names.append(r.display_name)
	return " > ".join(names)
