class_name Assets
## The one place that knows where the original Trickster assets live: res://original_assets,
## made locally by tools/setup_assets.py and never committed. Every script asks here instead
## of writing the path, so new art can later stand in for an asset through a manifest.

const ROOT := "res://original_assets/"
## Exported actors (a folder per actor, its sheets and <actor>.json).
const ACTORS := ROOT + "actors"
## Equipment sprites drawn over the actors, and their item list.
const EQUIP := ROOT + "equip"
const AUDIO := ROOT + "audio/"
const EFFECTS := ROOT + "effects/"
const MAPS := ROOT + "maps/"
const POSE_GUIDES := ROOT + "pose_guides/"
## The original's monster rows (MonsterParamEx2), exported to JSON.
const MONSTERS := ROOT + "data/monsters.json"
const EQUIP_ITEMS := EQUIP + "/items.json"


## An item's icon (ItemParam ID).
static func item_icon(item_id: int) -> String:
	return ROOT + "icons/items/%d.png" % item_id


## A skill's icon (SkillParam ID).
static func skill_icon(skill_id: int) -> String:
	return ROOT + "icons/%d.png" % skill_id


## An exported map's folder, ending in "/".
static func map_dir(map: String) -> String:
	return MAPS + map + "/"


## A dialogue portrait.
static func portrait(name: String) -> String:
	return ROOT + "portraits/%s.png" % name


## An exported held-weapon sprite (its folder and files share the name).
static func weapon(name: String) -> String:
	return ROOT + "weapons/%s" % name


## An exported actor's description file.
static func actor_json(actor: String) -> String:
	return "%s/%s/%s.json" % [ACTORS, actor, actor]
