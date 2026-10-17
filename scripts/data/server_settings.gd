class_name ServerSettings
extends RefCounted
## Optional difficulty modifiers from the GM console (our Pact of
## Punishment): each rank adds Heat, Heat raises the TM a run banks, and
## clearing at a new best Heat pays Harkon Shards. Ranks live in
## Profile.server_settings; Run reads them through the helpers below.

const SETTINGS := {
	"server_load": {"name": "Server Load", "max": 3, "heat": 1, "text": "Monsters have +15% HP per rank."},
	"packet_loss": {"name": "Packet Loss", "max": 3, "heat": 1, "text": "Monsters deal +15% damage per rank."},
	"lag_spike": {"name": "Lag Spike", "max": 2, "heat": 2, "text": "Monster wind-ups are 12% shorter per rank."},
	"bot_swarm": {"name": "Bot Swarm", "max": 2, "heat": 1, "text": "One more monster in every wave per rank."},
	"pk_mode": {"name": "PK Mode", "max": 1, "heat": 3, "text": "From room 2, an elite joins every wave."},
	"hardcore": {"name": "Hardcore Server", "max": 1, "heat": 2, "text": "No Recovery doors, no revives, no Second Wind."},
	"drops_nerfed": {"name": "Drops Nerfed", "max": 1, "heat": 1, "text": "Half the material and Bronze Fragment drops."},
}
const ORDER: Array[String] = ["server_load", "packet_loss", "lag_spike", "bot_swarm", "pk_mode", "hardcore", "drops_nerfed"]
## Extra TM banked per point of Heat.
const TM_PER_HEAT := 0.1


static func rank(id: String) -> int:
	return int(Profile.server_settings.get(id, 0))


static func heat() -> int:
	var h := 0
	for id: String in ORDER:
		h += rank(id) * int(SETTINGS[id].heat)
	return h


## Next rank for a setting, wrapping back to 0 after the max.
static func cycle(id: String) -> void:
	var r := rank(id) + 1
	Profile.server_settings[id] = 0 if r > int(SETTINGS[id].max) else r
	Profile.save()


static func monster_hp_mult() -> float:
	return 1.0 + 0.15 * rank("server_load")


static func monster_damage_mult() -> float:
	return 1.0 + 0.15 * rank("packet_loss")


static func windup_mult() -> float:
	return 1.0 - 0.12 * rank("lag_spike")


static func extra_per_wave() -> int:
	return rank("bot_swarm")


static func pk_mode() -> bool:
	return rank("pk_mode") > 0


static func hardcore() -> bool:
	return rank("hardcore") > 0


static func drop_mult() -> float:
	return 0.5 if rank("drops_nerfed") > 0 else 1.0
