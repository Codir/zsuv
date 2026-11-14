class_name Loads
extends RefCounted
## What a truck and its hitched trailer carry of the five resources (docs/plan.md §6): fuel in
## litres, the rest in loads. Buildings and sites read and change loads only through here, so this
## is the one place to point at the trucks' own loads when they have them (stream B's): until then
## a carrier (the truck's bed, or a trailer) keeps its load in its meta "loads", one resource at a
## time, and shows it with the looks Khutir Road had.

const RESOURCES := ["fuel", "parts", "gravel", "timber", "concrete"]
## What each truck's bed and each trailer takes of each resource (fuel in litres).
const ROOM := {
	"pickup": {"fuel": 400.0, "parts": 1.0},
	"six": {"fuel": 2000.0, "parts": 1.0, "timber": 1.0, "gravel": 1.0},
	"mixer": {"concrete": 1.0},
	"trailer": {"fuel": 400.0, "parts": 1.0},
	"farm": {"gravel": 1.0, "timber": 1.0},
	"semi_trailer": {"timber": 3.0},
}
## How a load looks on a bed (Vehicle.set_cargo's kind) or in a trailer (Trailer.set_load's look).
const BED_LOOK := {"concrete": "heavy", "timber": "heavy"}
const TRAILER_LOOK := {"gravel": "bulk_peat", "timber": "bulk_hay"}
const META := &"loads"


## The truck's bed, then its trailer if one is hitched.
static func carriers(v: Vehicle) -> Array[Node]:
	var out: Array[Node] = [v]
	if v.trailer:
		out.append(v.trailer)
	return out


static func _id(c: Node) -> String:
	return (c as Vehicle).spec.id if c is Vehicle else (c as Trailer).spec.id


## What carrier c holds: {resource: amount}, at most one resource.
static func held(c: Node) -> Dictionary:
	return c.get_meta(META, {})


## How much of res the truck and its hitched trailer carry.
static func amount(v: Vehicle, res: String) -> float:
	var n := 0.0
	for c in carriers(v):
		n += float(held(c).get(res, 0.0))
	return n


## Whether the truck carries anything of res at all, empty or not (the scout carries nothing).
static func carries(v: Vehicle, res: String) -> bool:
	for c in carriers(v):
		if ROOM.get(_id(c), {}).has(res):
			return true
	return false


## Whether the truck carries any of the resources.
static func carries_any(v: Vehicle) -> bool:
	for res in RESOURCES:
		if carries(v, res):
			return true
	return false


## How much more of res the truck and its hitched trailer take: a carrier holding something else
## takes none.
static func room(v: Vehicle, res: String) -> float:
	var n := 0.0
	for c in carriers(v):
		n += _room(c, res)
	return n


static func _room(c: Node, res: String) -> float:
	var cap := float(ROOM.get(_id(c), {}).get(res, 0.0))
	var h := held(c)
	if h.is_empty():
		return cap
	if not h.has(res):
		return 0.0
	return maxf(cap - float(h[res]), 0.0)


## Puts up to n of res on, the bed first: what went on.
static func put(v: Vehicle, res: String, n: float) -> float:
	var done := 0.0
	for c in carriers(v):
		var r := minf(_room(c, res), n - done)
		if r <= 0.0:
			continue
		var h := held(c).duplicate()
		h[res] = float(h.get(res, 0.0)) + r
		_store(c, h)
		done += r
	return done


## Takes up to n of res off, the trailer first: what came off.
static func take(v: Vehicle, res: String, n: float) -> float:
	var done := 0.0
	var cs := carriers(v)
	cs.reverse()
	for c in cs:
		var h := held(c).duplicate()
		var r := minf(float(h.get(res, 0.0)), n - done)
		if r <= 0.0:
			continue
		h[res] = float(h[res]) - r
		if h[res] <= 0.001:
			h.erase(res)
		_store(c, h)
		done += r
	return done


## Everything off (the tow's price).
static func clear(v: Vehicle) -> void:
	for c in carriers(v):
		_store(c, {})


## What the truck carries, for the dashboard: "PARTS 1  FUEL 400 L"; "" nothing.
static func text(v: Vehicle) -> String:
	var parts := PackedStringArray()
	for res in RESOURCES:
		var n := amount(v, res)
		if n > 0.0:
			parts.append(unit(res, n).to_upper())
	return "  ".join(parts)


## An amount of res as said: "fuel 400 L", "timber 2".
static func unit(res: String, n: float) -> String:
	if res == "fuel":
		return "fuel %d L" % roundi(n)
	return "%s %s" % [res, str(snappedf(n, 0.1)).trim_suffix(".0")]


static func _store(c: Node, h: Dictionary) -> void:
	c.set_meta(META, h)
	var res: String = h.keys()[0] if not h.is_empty() else ""
	if c is Vehicle:
		var v := c as Vehicle
		v.set_cargo(res != "", BED_LOOK.get(res, "plain"))
	else:
		var t := c as Trailer
		if res == "":
			t.set_load("")
		else:
			t.set_load(t.spec.cargo_mass.keys()[0], TRAILER_LOOK.get(res, ""))
