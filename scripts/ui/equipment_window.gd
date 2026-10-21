class_name EquipmentWindow
extends Control
## The original's equipment window (data/UI_nori/EquipUI.nri, laid out by EquipUI.ucf), drawn
## at twice its size: 13 slots around the character and the fashion grid below. It shows what
## is worn (run gear, wardrobe pieces and the drill); hovering a slot names its item. The bracer
## and pet slots stay empty until those items exist, as their outline art shows.

const ART := "equip_window"
const SCALE := 2
## EquipUI.ucf: grid 0 is 4 x 5 cells of 38 x 33 from (8, 8); grid 1 (fashion) is 5 x 2 cells of
## 31 x 31 from (6, 180). The character stands in grid 0's middle (columns 1-2, rows 1-3).
const GRID := Vector2(8, 8)
const CELL := Vector2(38, 33)
const FASHION_GRID := Vector2(6, 180)
const FASHION_CELL := Vector2(31, 31)
const ICON := 32
## What each cell holds, read from the art's outline icons. Reading: our two accessory slots are
## the necklace and ring cells; the original's accessories (type 7) fit either.
const SLOTS: Array[Dictionary] = [
	{"cell": Vector2i(1, 0), "kind": "gear", "key": "hat", "name": "Hat"},
	{"cell": Vector2i(2, 0), "kind": "wardrobe", "key": "ear", "name": "Ears"},
	{"cell": Vector2i(3, 0), "kind": "wardrobe", "key": "speed", "name": "Sprint"},
	{"cell": Vector2i(0, 1), "kind": "gear", "key": "weapon", "name": "Weapon"},
	{"cell": Vector2i(3, 1), "kind": "gear", "key": "shield", "name": "Shield"},
	{"cell": Vector2i(0, 2), "kind": "gear", "key": "acc1", "name": "Necklace"},
	{"cell": Vector2i(3, 2), "kind": "gear", "key": "acc2", "name": "Ring"},
	{"cell": Vector2i(0, 3), "kind": "none", "key": "bracer", "name": "Bracer"},
	{"cell": Vector2i(3, 3), "kind": "drill", "key": "drill", "name": "Drill"},
	{"cell": Vector2i(0, 4), "kind": "none", "key": "pet", "name": "Pet"},
	{"cell": Vector2i(1, 4), "kind": "gear", "key": "innerwear", "name": "Belt"},
	{"cell": Vector2i(2, 4), "kind": "wardrobe", "key": "tail", "name": "Tail"},
	{"cell": Vector2i(3, 4), "kind": "wardrobe", "key": "cape", "name": "Cape"},
]
## The fashion grid, row by row (the art's outlines). Our wardrobe's head and face pieces go here.
const FASHION: Array[String] = ["head", "face", "hand item", "top", "coat", "hands", "socks", "shoes", "bottom", "belt"]

var _icons: Dictionary[String, TextureRect] = {}
var _preview: ActorSprite


func _ready() -> void:
	var art := Assets.ui(ART)
	var bg := TextureRect.new()
	bg.texture = load(art) if ResourceLoader.exists(art) else null
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var size_1x := bg.texture.get_size() if bg.texture else Vector2(166, 246)
	bg.size = size_1x * SCALE
	custom_minimum_size = bg.size
	add_child(bg)
	_add_preview()
	for s in SLOTS:
		_add_icon(String(s.key), GRID + CELL * Vector2(s.cell), CELL)
	for i in FASHION.size():
		_add_icon("fashion:" + FASHION[i], FASHION_GRID + FASHION_CELL * Vector2(i % 5, i / 5), FASHION_CELL)


## The character in the window's middle, dressed as the player is.
func _add_preview() -> void:
	var box := SubViewportContainer.new()
	box.stretch = true
	box.stretch_shrink = SCALE
	box.position = (GRID + CELL) * SCALE
	box.size = CELL * Vector2(2, 3) * SCALE
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(box)
	var view := SubViewport.new()
	view.transparent_bg = true
	box.add_child(view)
	_preview = ActorSprite.new()
	_preview.position = Vector2(CELL.x, CELL.y * 2.6)
	view.add_child(_preview)


func _add_icon(key: String, at: Vector2, cell: Vector2) -> void:
	var t := TextureRect.new()
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.position = (at + (cell - Vector2(ICON, ICON)) / 2.0) * SCALE
	t.size = Vector2(ICON, ICON) * SCALE
	t.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(t)
	_icons[key] = t


func refresh() -> void:
	if _preview:
		Player.dress_sprite(_preview)
		_preview.play_action("idle", Vector2(0, 1))
	var pieces: Dictionary[String, WardrobeData] = {}
	for w in Run.worn_pieces():
		pieces[w.slot] = w
	for s in SLOTS:
		var key := String(s.key)
		match String(s.kind):
			"gear":
				var g := Run.gear.equipped(key)
				_show(key, g.data.icon() if g else null, String(s.name), g.title() + "\n" + g.summary() if g else "")
			"wardrobe":
				var w: WardrobeData = pieces.get(key)
				_show(key, w.icon() if w else null, String(s.name), w.display_name + "\n" + w.describe() if w else "")
			"drill":
				var d := Run.purse.drill()
				_show(key, d.icon() if d else null, String(s.name), d.display_name if d else "")
			_:
				_show(key, null, String(s.name), "")
	for f in FASHION:
		var w: WardrobeData = pieces.get(f)
		_show("fashion:" + f, w.icon() if w else null, f.capitalize(), w.display_name + "\n" + w.describe() if w else "")


func _show(key: String, icon: Texture2D, slot_name: String, text: String) -> void:
	var t := _icons[key]
	t.texture = icon
	t.tooltip_text = "%s\n%s" % [slot_name, text] if text != "" else "%s: empty" % slot_name


## The item names shown in each slot, for tests: slot key -> tooltip.
func shown() -> Dictionary[String, String]:
	var out: Dictionary[String, String] = {}
	for k in _icons:
		out[k] = _icons[k].tooltip_text
	return out
