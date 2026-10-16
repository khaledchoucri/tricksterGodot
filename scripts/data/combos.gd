class_name Combos
extends RefCounted
## Basic attack chains, one per fighting style. Times are seconds from the
## start of the swing at normal speed; "windows" are the active hit frames
## (each window can hit an enemy once). "frames" plays only part of the
## animation, [from, to]; from > to plays it backwards. Steps with "slash"
## leave a sword trail; "cw" is the sweep direction when aiming right, and it
## mirrors when aiming left, like the art.

## Buffalo, Knight line: wide sword arcs.
const SLASH := {"anim": "weapon_crit", "frames": [3, 7], "len": 0.32, "windows": [[0.06, 0.14]],
	"chain_at": 0.13, "dash_cancel": 0.07, "free_at": 0.22, "damage": 22, "reach": 60.0, "arc": 150.0,
	"knockback": 140.0, "lunge": 70.0, "hitstop": 0.045, "sound": "weapon001.wav", "slash": true, "cw": true}
const BACKHAND := {"anim": "weapon_crit", "frames": [7, 2], "len": 0.32, "windows": [[0.06, 0.14]],
	"chain_at": 0.13, "dash_cancel": 0.07, "free_at": 0.22, "damage": 24, "reach": 60.0, "arc": 150.0,
	"knockback": 140.0, "lunge": 70.0, "hitstop": 0.045, "sound": "weapon001.wav", "slash": true, "cw": false}
const CLEAVE := {"anim": "weapon_crit", "frames": [3, 7], "len": 0.46, "windows": [[0.14, 0.24]],
	"chain_at": 99.0, "dash_cancel": 0.12, "free_at": 0.38, "damage": 40, "reach": 70.0, "arc": 230.0,
	"knockback": 300.0, "lunge": 120.0, "hitstop": 0.075, "finisher": true, "sound": "sachr002_1.wav",
	"slash": true, "cw": true}
const SWORD: Array[Dictionary] = [SLASH, BACKHAND, CLEAVE]

## Bunny, Boxer line (kept for when she's playable): jab, flurry, kick.
const JAB := {"anim": "attack", "len": 0.34, "windows": [[0.09, 0.16]], "chain_at": 0.14,
	"dash_cancel": 0.08, "free_at": 0.24, "damage": 22, "reach": 50.0, "arc": 115.0,
	"knockback": 140.0, "lunge": 70.0, "hitstop": 0.045, "sound": "sachr002.wav"}
const FLURRY := {"anim": "attack", "len": 0.32, "windows": [[0.05, 0.1], [0.15, 0.2]], "chain_at": 0.18,
	"dash_cancel": 0.06, "free_at": 0.24, "damage": 14, "reach": 50.0, "arc": 120.0,
	"knockback": 60.0, "lunge": 50.0, "hitstop": 0.03, "sound": "weapon001.wav"}
const KICK := {"anim": "attack2", "len": 0.44, "windows": [[0.13, 0.26]], "chain_at": 99.0,
	"dash_cancel": 0.12, "free_at": 0.34, "damage": 36, "reach": 58.0, "arc": 150.0,
	"knockback": 300.0, "lunge": 110.0, "hitstop": 0.075, "finisher": true, "sound": "sachr002_1.wav"}
const PUNCH: Array[Dictionary] = [JAB, FLURRY, KICK]
