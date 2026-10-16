class_name EnemyData
extends Resource
## A monster in the combat roster. Stats come from the original monster row;
## the attack pattern and its tuning are ours.

@export var id: StringName
## Row ID in MonsterParamEx2 (HP, damage, speed, rewards).
@export var monster_id := ""
## Attack pattern in Enemy.KINDS: melee, lunge, slam, spin or shot.
@export_enum("melee", "lunge", "slam", "spin", "shot") var kind := "melee"
@export var body_radius := 14.0
## Encounter budget price.
@export var cost := 1
## First room depth where it can appear.
@export var min_depth := 0
@export var speed_mult := 1.0
@export var hp_mult := 1.0
@export var is_boss := false
## Signature drop for compounding, and the chance a kill drops one.
@export var material: MaterialData
@export var material_chance := 0.2
## Overrides for the pattern's numbers (windup, radius, length...).
@export var tune: Dictionary = {}
