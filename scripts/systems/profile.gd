class_name Profile
extends RefCounted
## What a player keeps between drives: the money, the valleys bought, the sky picked for each,
## the records. Saved to user:// on every change (in a browser that is its IndexedDB); a profile
## with no path is kept in memory only, as the tests and the captures use it.

const PATH := "user://khutir_road.cfg"

var path := ""
var money := 0
var owned := PackedStringArray(["khutir"])
var skies := {}  # valley id -> Weather.Kind
var records := {}  # job key -> {time, medal}
var last := "khutir"


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
	var owned: Variant = cfg.get_value("progress", "owned", p.owned)
	if typeof(owned) in [TYPE_PACKED_STRING_ARRAY, TYPE_ARRAY]:
		p.owned = PackedStringArray()
		for id in owned:
			if typeof(id) in [TYPE_STRING, TYPE_STRING_NAME] and not str(id) in p.owned:
				p.owned.append(str(id))
	p.last = _value(cfg, "last", TYPE_STRING, p.last)
	p.skies = _value(cfg, "skies", TYPE_DICTIONARY, p.skies)
	p.records = _value(cfg, "records", TYPE_DICTIONARY, p.records)
	if not "khutir" in p.owned:
		p.owned.append("khutir")
	return p


static func _value(cfg: ConfigFile, key: String, type: int, default: Variant) -> Variant:
	var value: Variant = cfg.get_value("progress", key, default)
	return value if typeof(value) == type else default


func save() -> void:
	if path == "":
		return
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "money", money)
	cfg.set_value("progress", "owned", owned)
	cfg.set_value("progress", "last", last)
	cfg.set_value("progress", "skies", skies)
	cfg.set_value("progress", "records", records)
	cfg.save(path)


func owns(valley_id: String) -> bool:
	return valley_id in owned


## Why valley v cannot be bought yet ("" when it can): they open in order, for money.
func cannot_buy(v: Valley) -> String:
	if owns(v.id):
		return "owned"
	var all := Valley.all()
	for i in all.size():
		if all[i].id == v.id:
			if i > 0 and not owns(all[i - 1].id):
				return "open %s first" % all[i - 1].title
			break
	if money < v.price:
		return "$%d more to earn" % (v.price - money)
	return ""


## Buys valley v if it can: true when it did.
func buy(v: Valley) -> bool:
	if cannot_buy(v) != "":
		return false
	money -= v.price
	owned.append(v.id)
	save()
	return true


## The best time of job key: {time, medal}, or empty when there is none.
func record(key: String) -> Dictionary:
	var best: Variant = records.get(key, {})
	if typeof(best) != TYPE_DICTIONARY or typeof(best.get("time")) not in [TYPE_INT, TYPE_FLOAT]:
		return {}
	return best


func sky(valley_id: String) -> Weather.Kind:
	var kind: Variant = skies.get(valley_id, Weather.Kind.OWN)
	if typeof(kind) != TYPE_INT or kind < 0 or kind >= Weather.Kind.size():
		return Weather.Kind.OWN
	return kind


func set_sky(valley_id: String, kind: Weather.Kind) -> void:
	skies[valley_id] = kind
	save()
