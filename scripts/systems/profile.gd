class_name Profile
extends RefCounted
## What a player keeps between drives: the money, the records, the trucks and trailers bought,
## the truck picked and where they were last. Saved to user:// on every change (in a browser that
## is its IndexedDB); a profile with no path is kept in memory only, as the tests and the captures
## use it. docs/plan.md §11 is what it becomes.

const PATH := "user://zsuv.cfg"

var path := ""
var money := 0
var records := {}  # job key -> {time, medal}
var last := "steppe"  # the valley the game was in; a new game starts in the steppe
var rigs := PackedStringArray()  # the trucks and trailers bought (TruckSpec, TrailerSpec ids)
var truck := "pickup"  # the truck the garage puts at the depot


## Whether there is a save at at to continue.
static func exists(at := PATH) -> bool:
	return at != "" and FileAccess.file_exists(at)


static func open(at := PATH) -> Profile:
	var p := Profile.new()
	p.path = at
	var cfg := ConfigFile.new()
	if cfg.load(at) != OK:
		return p
	# A value of the wrong type (a hand edit, another build's file) is left at its default, so a
	# bad file never stops the game.
	var money: Variant = cfg.get_value("progress", "money", p.money)
	if typeof(money) in [TYPE_INT, TYPE_FLOAT]:
		p.money = int(money)
	p.rigs = _ids(cfg.get_value("progress", "rigs", p.rigs), p.rigs)
	p.truck = _value(cfg, "truck", TYPE_STRING, p.truck)
	if not p.has_rig(p.truck) or TruckSpec.find(p.truck) == null:
		p.truck = "pickup"
	p.last = _value(cfg, "last", TYPE_STRING, p.last)
	if Valley.find(p.last) == null:
		p.last = "steppe"
	p.records = _value(cfg, "records", TYPE_DICTIONARY, p.records)
	return p


## A list of ids as saved, or default when it is not one; no repeats, nothing but strings.
static func _ids(value: Variant, default: PackedStringArray) -> PackedStringArray:
	if typeof(value) not in [TYPE_PACKED_STRING_ARRAY, TYPE_ARRAY]:
		return default
	var out := PackedStringArray()
	for id in value:
		if typeof(id) in [TYPE_STRING, TYPE_STRING_NAME] and not str(id) in out:
			out.append(str(id))
	return out


static func _value(cfg: ConfigFile, key: String, type: int, default: Variant) -> Variant:
	var value: Variant = cfg.get_value("progress", key, default)
	return value if typeof(value) == type else default


func save() -> void:
	if path == "":
		return
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "money", money)
	cfg.set_value("progress", "last", last)
	cfg.set_value("progress", "records", records)
	cfg.set_value("progress", "rigs", rigs)
	cfg.set_value("progress", "truck", truck)
	cfg.save(path)


## Whether the truck or trailer id is the player's (the pickup always is).
func has_rig(id: String) -> bool:
	return id == "pickup" or id in rigs


## Why the garage cannot sell item (Garage.catalogue()) yet ("" when it can).
func cannot_buy_rig(item: Dictionary) -> String:
	if has_rig(item.id):
		return "owned"
	if money < int(item.price):
		return "$%d more to earn" % (int(item.price) - money)
	return ""


## Buys item if it can: true when it did.
func buy_rig(item: Dictionary) -> bool:
	if cannot_buy_rig(item) != "":
		return false
	money -= int(item.price)
	for id in item.gives:
		if not id in rigs:
			rigs.append(id)
	save()
	return true


## The best time of job key: {time, medal}, or empty when there is none.
func record(key: String) -> Dictionary:
	var best: Variant = records.get(key, {})
	if typeof(best) != TYPE_DICTIONARY or typeof(best.get("time")) not in [TYPE_INT, TYPE_FLOAT]:
		return {}
	return best
