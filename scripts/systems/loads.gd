class_name Loads
extends RefCounted
## What a truck and its hitched trailer carry of the five resources (docs/plan.md §6), as the
## buildings and sites read it: fuel in litres, the rest in loads. The loads are the trucks' own
## (Hold, Vehicle.rig_*); this is the one place Infra reaches them through.

const RESOURCES := ["fuel", "parts", "gravel", "timber", "concrete"]


## How much of res the truck and its hitched trailer carry.
static func amount(v: Vehicle, res: String) -> float:
	return v.rig_holding(res)


## Whether the rig carries res at all, empty or not (the scout carries nothing).
static func carries(v: Vehicle, res: String) -> bool:
	return v.holds().any(func(h: Hold) -> bool: return h.carries(res))


## Whether the rig carries any of the resources.
static func carries_any(v: Vehicle) -> bool:
	for res in RESOURCES:
		if carries(v, res):
			return true
	return false


## How much more of res the rig takes.
static func room(v: Vehicle, res: String) -> float:
	return v.rig_room(res)


## Puts up to n of res on, the bed first: what went on.
static func put(v: Vehicle, res: String, n: float) -> float:
	return v.rig_put(res, n) if n > 0.0 else 0.0


## Takes up to n of res off, the trailer first: what came off.
static func take(v: Vehicle, res: String, n: float) -> float:
	return v.rig_take(res, n) if n > 0.0 else 0.0


## Every resource off (the tow's price).
static func clear(v: Vehicle) -> void:
	for h in v.holds():
		if h.kind in Hold.RESOURCES:
			h.clear()


## What the rig carries, for a message: "TIMBER 1 + FUEL 320 L"; "" nothing.
static func text(v: Vehicle) -> String:
	return v.load_text()


## An amount of res as said: "fuel 400 L", "timber 2".
static func unit(res: String, n: float) -> String:
	if res == "fuel":
		return "fuel %d L" % roundi(n)
	if res == "soil":
		return "soil %.1f m3" % n
	return "%s %s" % [res, str(snappedf(n, 0.1)).trim_suffix(".0")]
