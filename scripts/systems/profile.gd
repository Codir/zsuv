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
	p.money = cfg.get_value("progress", "money", 0)
	p.owned = cfg.get_value("progress", "owned", p.owned)
	p.last = cfg.get_value("progress", "last", "khutir")
	p.skies = cfg.get_value("progress", "skies", {})
	p.records = cfg.get_value("progress", "records", {})
	if not "khutir" in p.owned:
		p.owned.append("khutir")
	return p


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


func sky(valley_id: String) -> Weather.Kind:
	return skies.get(valley_id, Weather.Kind.OWN)


func set_sky(valley_id: String, kind: Weather.Kind) -> void:
	skies[valley_id] = kind
	save()
