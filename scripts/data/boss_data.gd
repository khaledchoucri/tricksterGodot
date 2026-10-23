class_name BossData
extends Resource
## What a boss brings beyond its monster row: its BossMonsterparamEx row (lives, heals,
## summons, speech) and the numbers of its moveset. An EnemyData names one (`boss`); the
## boss's script (scripts/boss.gd and the boss's own) reads it.
##
## The moveset's numbers live in `tune`, read through Boss.num(key, default), so a hardened
## variant (the coming Extreme Measures Heat) can be another BossData with bigger numbers
## and no code of its own.

## LifeCnt: lives beyond the first. The server (GameServer.exe 0x5645d0) refills a boss's
## HP to MaxHP and takes a life instead of letting it die, so a boss with LifeCnt 3 is four
## full bars; its HP packet (0x5a8e60) sends the lives left, which the client draws as that
## many bars (uBossHPInfoView, Trickster.bin 0x79f4e0).
@export var lives := 0
## The heals of HealLeftLife_n / HealLevel_n / HealTime_n (0x565af0): every `every` seconds,
## from `lives` lives left down, a coin flip casts M Cure (5101) for `share` of a bar
## (ESAction_Mon_Heal Ratio at HealLevel). Each is {"lives": int, "share": float, "every": float}.
@export var heals: Array[Dictionary] = []
## Speech_0 (as the fight opens), Speech_1 (as it summons) and Speech_RChange (as it rages).
@export var line_open := ""
@export var line_summon := ""
@export var line_rage := ""
## The name card's second line under the boss's name. Ours.
@export var title := ""
## SummonMon_n, by the part each plays in the fight: role -> EnemyData.
@export var summons: Dictionary = {}
## Spells whose look a boss's cast borrows from the player's cards: role -> CardData.
@export var spells: Dictionary = {}
## The moveset's numbers: key -> number (see each boss script's header for its keys).
@export var tune: Dictionary = {}
