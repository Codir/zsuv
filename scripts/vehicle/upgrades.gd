class_name Upgrades
extends RefCounted
## What a garage makes and fits from parts, and its repairs (docs/plan.md §8 "Upgrades",
## "Condition and repair"). There is no money: an upgrade costs loads of parts, taken from the
## base's yard (a Site's stock, `give("parts", n)`; the railhead's never run out). Fitted, it
## stays on the truck (Vehicle.upgrades) and the truck shows it. The jam's: the snorkel, the
## chains and the 6x6's three bodies; the rest are cheap once the list is here.

## {id: {title, cost (loads of parts), fits (TruckSpec ids; empty: all), what}}
const ALL := {
	"snorkel": {"title": "Snorkel", "cost": 1, "fits": ["pickup", "scout", "six", "tractor", "mixer"],
		"what": "the air intake up on the roof: through deep water"},
	"chains": {"title": "Chains", "cost": 1, "fits": [],
		"what": "grip on ice, more bite in snow; 15% slower"},
	"body_tank": {"title": "Tank body", "cost": 1, "fits": ["six"], "what": "2000 L of fuel"},
	"body_flatbed": {"title": "Flatbed body", "cost": 1, "fits": ["six"], "what": "timber or parts"},
	"body_tipper": {"title": "Tipper body", "cost": 1, "fits": ["six"], "what": "gravel or soil"},
}
## The 6x6's bodies, one at a time: what each carries (kg of a full load) and how much is full.
const BODIES := {
	"body_tank": {"masses": {"fuel": 1700.0}, "capacity": {"fuel": 2000.0}},
	"body_flatbed": {"masses": {"parts": 900.0, "timber": 3000.0}, "capacity": {}},
	"body_tipper": {"masses": {"gravel": 4000.0, "soil": 4000.0}, "capacity": {"soil": 10.0}},
}
const CHAINS_SPEED := 0.85
const REPAIR_STEP := 0.5  # of condition for a load of parts


## The upgrades that fit v, in the garage's order: [{id, title, cost, what, fitted}].
static func list(v: Vehicle) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id in ALL:
		if fits(v.spec, id):
			var u: Dictionary = ALL[id]
			out.append({"id": id, "title": u.title, "cost": u.cost, "what": u.what, "fitted": id in v.upgrades})
	return out


static func fits(spec: TruckSpec, id: String) -> bool:
	if not ALL.has(id):
		return false
	var on: Array = ALL[id].fits
	return (on.is_empty() or spec.id in on) and not (id == "snorkel" and spec.snorkel == Vector3.ZERO)


## Why the garage cannot fit id on v now ("" it can): with parts the parts in the yard.
static func cannot_fit(v: Vehicle, id: String, parts: float) -> String:
	if not fits(v.spec, id):
		return "It does not fit the %s" % v.spec.title.to_lower()
	if id in v.upgrades:
		return "Fitted already"
	if id in BODIES and not v.hold.is_empty():
		return "Unload it first"
	if parts < float(ALL[id].cost):
		return "It takes %d parts: bring them to the yard" % int(ALL[id].cost)
	return ""


## Makes and fits id on v at base, from its parts (Site.give): the message to show.
static func fit(v: Vehicle, id: String, base: Node, infra: Node = null) -> String:
	var parts: float = base.available("parts") if base else 0.0
	var why := cannot_fit(v, id, parts)
	if why != "":
		return why
	_take_parts(base, float(ALL[id].cost), infra)
	v.fit(id)
	return "Fitted: %s, %s" % [String(ALL[id].title).to_lower(), ALL[id].what]


## What a repair of v costs: a load of parts for each 50% (or part of it) it is down.
static func repair_cost(v: Vehicle) -> int:
	return ceili((1.0 - v.condition) / REPAIR_STEP - 0.001)


## Repairs v at base, as far as its parts go: the message to show.
static func repair(v: Vehicle, base: Node, infra: Node = null) -> String:
	var cost := repair_cost(v)
	if cost <= 0:
		return "It needs no repair"
	var parts: float = base.available("parts") if base else 0.0
	var n := cost if parts >= float(cost) else floori(parts)  # a railhead's are endless (INF)
	if n <= 0:
		return "A repair takes parts: bring them to the yard"
	_take_parts(base, float(n), infra)
	v.condition = minf(v.condition + n * REPAIR_STEP, 1.0)
	return "Repaired: %d%%" % roundi(v.condition * 100.0)


## Takes n parts from base's yard: through Infra.draw when there is one (it saves), else the Site.
static func _take_parts(base: Node, n: float, infra: Node) -> void:
	if infra and infra.has_method("draw"):
		infra.draw(base, "parts", n)
	else:
		base.give("parts", n)


## The workshop's page of the garage (Contracts, U on the garage): each upgrade that fits v, then
## the repair, numbered from 1; base is the one the truck is at (null: none, nothing is made).
static func workshop_text(v: Vehicle, base: Node) -> String:
	var parts: float = base.available("parts") if base else 0.0
	var lines := PackedStringArray(["WORKSHOP - %s   parts: %s" % [v.spec.title.to_upper(), "endless" if parts == INF else str(int(parts))], ""])
	var ups := list(v)
	for i in ups.size():
		var u: Dictionary = ups[i]
		lines.append("%d  %-14s %d parts  %s" % [i + 1, String(u.title).to_upper(), u.cost, "fitted" if u.fitted else u.what])
	var cost := repair_cost(v)
	lines.append("%d  %-14s %s" % [ups.size() + 1, "REPAIR", ("%d%%, a load of parts for each 50%%: %d" % [roundi(v.condition * 100.0), cost]) if cost > 0 else "in full repair"])
	return "\n".join(lines)


## How many lines the workshop has for v: its upgrades and the repair.
static func workshop_size(v: Vehicle) -> int:
	return list(v).size() + 1


## The workshop's line i for v at base: fits that upgrade, or repairs; the message to show.
static func workshop_pick(v: Vehicle, i: int, base: Node, infra: Node = null) -> String:
	if base == null:
		return "The workshop is at a base's garage"
	var ups := list(v)
	if i < ups.size():
		return fit(v, ups[i].id, base, infra)
	return repair(v, base, infra)
