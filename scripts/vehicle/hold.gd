class_name Hold
extends RefCounted
## What a truck's bed or a trailer carries (docs/plan.md §6, §8 "The load belongs to the truck"):
## one kind of load at a time, counted in loads, or fuel in litres and soil in m3. A Vehicle and a
## Trailer each have one (`hold`); Vehicle.rig_* reads and writes the truck's and its hitched
## trailer's together, which is what a building or a site does with the truck standing at it:
##   v.rig_room("timber")       how much more of it the rig can take
##   v.rig_holding("timber")    how much of it the rig has on
##   v.rig_put("timber", 1.0)   loads it, what fits; returns what went on
##   v.rig_take("timber", 1.0)  unloads it; returns what came off
## The masses and how much is a full load come from the spec (TruckSpec / TrailerSpec cargo_mass
## and capacity).

signal changed

## The resources of Zsuv (§6); a kind not among them is one of Khutir Road's job loads.
const RESOURCES := ["fuel", "parts", "gravel", "timber", "concrete", "soil"]
## Concrete sets this long after it goes into the mixer (§7), and the load is lost.
const CONCRETE_SETS := 300.0

var masses := {}  # kind -> kg of a full load (the spec's cargo_mass); a kind not here it does not carry
var capacity := {}  # kind -> how much of it is a full load; 1 if not listed
var kind := ""  # what is on, "" nothing
var amount := 0.0  # how much of it
var look := ""  # another look of the kind (a trailer's "bulk_peat"), "" its own
var age := 0.0  # seconds since this load went on: concrete sets (CONCRETE_SETS)


func carries(k: String) -> bool:
	return masses.has(k)


## How much of k is a full load here (0: it does not carry k).
func full(k: String) -> float:
	return float(capacity.get(k, 1.0)) if carries(k) else 0.0


## How much more of k fits: none while another kind is on.
func room(k: String) -> float:
	if not carries(k) or (kind != "" and kind != k):
		return 0.0
	return maxf(full(k) - amount, 0.0)


## How much of k is on.
func holding(k: String) -> float:
	return amount if kind == k else 0.0


func is_empty() -> bool:
	return kind == ""


## Puts up to n of k on (all that fits when n is INF); returns how much went on.
func put(k: String, n := INF) -> float:
	var on := minf(n, room(k))
	if on <= 0.0:
		return 0.0
	if kind != k:
		kind = k
		age = 0.0
	amount += on
	changed.emit()
	return on


## Takes up to n of k off (all of it when n is INF); returns how much came off.
func take(k: String, n := INF) -> float:
	if kind != k or kind == "":
		return 0.0
	var off := minf(n, amount)
	amount -= off
	if amount <= 0.0001:
		clear()
	else:
		changed.emit()
	return off


## A whole load of k, whatever was on before, carried or not (Khutir Road's jobs: set_cargo,
## set_load); "" empties it.
func set_whole(k: String, how_it_looks := "") -> void:
	kind = k
	amount = full(k) if carries(k) else (1.0 if k != "" else 0.0)
	look = how_it_looks
	age = 0.0
	changed.emit()


func clear() -> void:
	kind = ""
	amount = 0.0
	look = ""
	age = 0.0
	changed.emit()


## What the load weighs: a full load's mass times how full it is. A kind it does not carry (a job
## load put on by hand) weighs as a plain load, if it carries plain ones.
func mass() -> float:
	if kind == "":
		return 0.0
	var whole := float(masses.get(kind, masses.get("plain", 0.0)))
	var f := full(kind)
	return whole * (amount / f if f > 0.0 else 1.0)


## For the HUD: "TIMBER 1", "FUEL 320 L", "SOIL 6.4/10 m3", "CONCRETE 4:12" (sets in); "" empty.
func text() -> String:
	if kind == "":
		return ""
	match kind:
		"fuel":
			return "FUEL %d L" % roundi(amount)
		"soil":
			return "SOIL %.1f/%d m3" % [amount, roundi(full(kind))]
		"concrete":
			var left := maxi(ceili(CONCRETE_SETS - age), 0)
			return "CONCRETE %d:%02d" % [left / 60, left % 60]
	if not kind in RESOURCES:
		return ""
	return "%s %s" % [kind.to_upper(), str(snappedf(amount, 0.1)).trim_suffix(".0")]


## For saving (Profile): the load as plain values, and back.
func to_dict() -> Dictionary:
	return {"kind": kind, "amount": amount, "look": look, "age": age}


func from_dict(d: Dictionary) -> void:
	kind = str(d.get("kind", ""))
	amount = float(d.get("amount", 0.0))
	look = str(d.get("look", ""))
	age = float(d.get("age", 0.0))
	changed.emit()
