class_name Fleet
extends Node
## The player's trucks out on the map (docs/plan.md §8 "Trucks out on the map", "Truck to truck").
## One is driven; every other stays where it was left, its engine off, its handbrake on, its
## lights off, its trailer hitched, its load and fuel its own. More than FREEZE_FAR from the truck
## being driven it is frozen, and it wakes when that truck comes near (or hooks it: Winch).
## E beside a parked truck of yours, stopped: with fuel barrels on the rig, pours fuel into it
## until its tank is full or the barrels are empty; else steps across into it. On the paper map a
## click on a truck's mark drives that truck (MapScreen). scripts/main.gd follows `switched`.

signal switched(v: Vehicle)  # the player drives v now
signal message(text: String)
signal claimed(v: Vehicle)  # a truck found in the floods runs: the player's now (main.gd)

const FREEZE_FAR := 80.0  # m from the truck being driven: frozen beyond
const WAKE_NEAR := 70.0  # and woken within
const STEP_ACROSS := 5.0  # m between the two trucks' sides for E to step across
const POUR_REACH := 6.0  # and to pour fuel from barrels
const STOPPED := 1.0  # m/s
const MEND := 0.5  # a load of parts beside a truck found brings its condition up to this

var trucks: Array[Vehicle] = []  # out on the map, the driven one among them
var driven: Vehicle


## v is out on the map from now on; driven if drive, else parked.
func add(v: Vehicle, drive := false) -> void:
	if not v in trucks:
		trucks.append(v)
		v.said.connect(_say)
		v.winch.said.connect(_say)
	if drive:
		drive_truck(v)
	else:
		v.set_driven(false)


## v leaves the map (into a garage, or freed): it is no longer one of the fleet's.
func remove(v: Vehicle) -> void:
	trucks.erase(v)
	if v.said.is_connected(_say):
		v.said.disconnect(_say)
		v.winch.said.disconnect(_say)
	if driven == v:
		driven = null


## The player's truck of spec id out on the map, or null (not one still lost in the floods).
func find(id: String) -> Vehicle:
	for v in trucks:
		if is_instance_valid(v) and v.spec.id == id and not v.lost:
			return v
	return null


## The player drives v from now on, where it stands; the one driven before is parked.
func drive_truck(v: Vehicle) -> void:
	if not v in trucks:
		add(v)
	var old := driven
	driven = v
	if old and old != v and is_instance_valid(old):
		old.set_driven(false)
	v.set_frozen(false)
	v.set_driven(true)
	switched.emit(v)


## The parked truck nearest the one driven, within reach (m between their sides), or null.
func parked_near(reach: float) -> Vehicle:
	if driven == null:
		return null
	var best: Vehicle = null
	var best_d := reach
	for v in trucks:
		if v == driven or not is_instance_valid(v):
			continue
		if v.global_position.distance_to(driven.global_position) > reach + 20.0:
			continue
		var d := driven.gap_to(v)
		if d <= best_d:
			best = v
			best_d = d
	return best


## The truck E pours fuel into: a parked one within POUR_REACH whose tank is not full, when the
## rig has fuel barrels on; or null.
func pour_target() -> Vehicle:
	if driven == null or driven.rig_holding("fuel") <= 0.0:
		return null
	var v := parked_near(POUR_REACH)
	return v if v and v.fuel < v.spec.fuel_capacity - 0.5 else null


## E: pours fuel from the barrels, or steps across into a parked truck. True when it did either.
func interact() -> bool:
	if driven == null or absf(driven.forward_speed) >= STOPPED:
		return false
	var into := pour_target()
	if into:
		pour(into)
		return true
	var m := mend_target()
	if m:
		driven.rig_take("parts", 1.0)
		m.condition = MEND
		message.emit("The %s is mended: %d%%" % [m.spec.title.to_lower(), roundi(MEND * 100.0)])
		return true
	var v := parked_near(STEP_ACROSS)
	if v and v.lost:
		message.emit(_lost_text(v))
		return true
	if v:
		drive_truck(v)
		message.emit("Driving the %s" % v.spec.title.to_lower())
		return true
	return false


## A truck found in the floods, beside the driven one, that a load of parts on the rig mends.
func mend_target() -> Vehicle:
	if driven == null or driven.rig_holding("parts") < 1.0:
		return null
	var v := parked_near(STEP_ACROSS)
	return v if v and v.lost and v.condition < MEND else null


## What a truck found still needs to run.
func _lost_text(v: Vehicle) -> String:
	var needs := PackedStringArray()
	if v.fuel <= 0.0:
		needs.append("fuel from barrels")
	if v.condition <= 0.0:
		needs.append("a load of parts")
	return "The %s needs %s to run" % [v.spec.title.to_lower(), " and ".join(needs)] if not needs.is_empty() else ""


## Pours fuel from the driven rig's barrels into v until its tank is full or they are empty.
func pour(v: Vehicle) -> float:
	var litres := driven.rig_take("fuel", v.spec.fuel_capacity - v.fuel)
	v.fuel = minf(v.fuel + litres, v.spec.fuel_capacity)
	var left := driven.rig_holding("fuel")
	message.emit("Poured %d L into the %s%s" % [roundi(litres), v.spec.title.to_lower(),
		": its tank is full" if left > 0.0 else ": the barrels are empty"])
	return litres


## What E does here, for the HUD's bottom line ("" nothing).
func prompt() -> String:
	if driven == null or absf(driven.forward_speed) >= STOPPED:
		return ""
	var into := pour_target()
	if into:
		return "[E] Pour fuel into the %s" % into.spec.title.to_lower()
	var m := mend_target()
	if m:
		return "[E] Mend the %s with the parts" % m.spec.title.to_lower()
	var v := parked_near(STEP_ACROSS)
	if v and v.lost:
		return _lost_text(v)
	return "[E] Drive the %s" % v.spec.title.to_lower() if v else ""


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and interact():
		get_viewport().set_input_as_handled()


## Far from the truck being driven, a parked truck that has come to rest is frozen; near it, or
## pulled by a winch, it is woken.
func _physics_process(_delta: float) -> void:
	if driven == null or not is_instance_valid(driven):
		return
	for v in trucks:
		if is_instance_valid(v) and v.lost and v.fuel > 0.0 and v.condition > 0.0:
			v.lost = false
			claimed.emit(v)
	for v in trucks:
		if v == driven or not is_instance_valid(v):
			continue
		var d := v.global_position.distance_to(driven.global_position)
		if v.dormant:
			if d < WAKE_NEAR or v.hooked_by:
				v.set_frozen(false)
			elif v.trailer and not v.trailer.freeze:  # hitched while it was frozen
				v.set_frozen(false)
		elif d > FREEZE_FAR and v.hooked_by == null and _at_rest(v):
			v.set_frozen(true)


## Standing on its wheels, still: a truck just set down is not frozen in the air.
func _at_rest(v: Vehicle) -> bool:
	if v.linear_velocity.length() > 0.2 or v.wheels.any(func(w: Chassis.Wheel) -> bool: return not w.contact):
		return false
	return v.trailer == null or v.trailer.linear_velocity.length() < 0.2


func _say(text: String) -> void:
	message.emit(text)
