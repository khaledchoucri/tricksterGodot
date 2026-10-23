class_name EnemyData
extends Resource
## A monster in the combat roster. Stats come from the original monster row;
## the attack pattern and its tuning are ours.

@export var id: StringName
## Row ID in MonsterParamEx2 (HP, damage, speed, rewards).
@export var monster_id := ""
## Overrides the original name (where two monsters would share one).
@export var display_name := ""
## How it attacks: one of data/attacks/ (melee, lunge, slam, spin, shot).
@export var attack: AttackPattern
@export var body_radius := 14.0
## Encounter budget price.
@export var cost := 1
## First room depth where it can appear.
@export var min_depth := 0
@export var speed_mult := 1.0
@export var hp_mult := 1.0
@export var is_boss := false
## Bosses: their own scene (otherwise the plain enemy scene), and an item
## they can drop on death (a legend), with its chance.
@export var scene: PackedScene
@export var drop_item: ItemData
@export var drop_chance := 0.0
## Bosses: their BossMonsterparamEx row and moveset numbers (scripts/boss.gd).
@export var boss: BossData
## How much larger than its sheet it is drawn. Reading: CharacterInfo's SizeOnStop (2 for
## the Sphinx, which shares the Mad Captain's mon161 sheet, 1 for most) draws it bigger.
@export var sprite_scale := 1.0
## Echoes: ghosts of former players of another class. Their stats come from
## `stats_override` (a monster-row-like Dictionary), they ignore the region's
## scales, and beating one offers one of its `runes` (borrowed skills).
@export var echo := false
@export var stats_override: Dictionary = {}
@export var runes: Array[CardData] = []
## Galder a hit that lands takes from you, all given back when it dies (Thief Mong's theft).
@export var steal_galder := 0
## Signature drop for compounding, and the chance a kill drops one.
@export var material: MaterialData
@export var material_chance := 0.2
## Overrides for its attack pattern's numbers (windup, radius, length...).
@export var tune: Dictionary = {}
