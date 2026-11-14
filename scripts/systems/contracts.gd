class_name Contracts
extends Node3D
## The railhead's side of things, with no money in them (docs/plan.md §6): the arrow and the
## marker over the railhead, the tow (T), and the garage (Tab at the railhead), which drives a truck
## the player has, never sells one. What is hauled, built and made is Infra's (scripts/systems/
## infra.gd); the loads on a truck are read through Loads.

signal message(text: String)
signal truck_wanted(spec: TruckSpec)  # the garage: drive this one (scripts/main.gd puts it at the railhead)
signal rigs_changed  # a rig became the player's: its trailer, if any, waits at the railhead
signal towing  # T: the truck is about to be set down at the railhead (main.gd sees to its trailer)

const INTERACT_RADIUS := 12.0
const SHORT := {"pickup": "PICKUP", "six": "6X6", "tractor": "TRACTOR", "semi": "SEMI", "trailer": "TRAILER"}

var vehicle: Vehicle
var land: Land
var profile := Profile.new()  # the player's, saved; one kept in memory when there is none
var prompt := ""
var spawn_pos := Vector3.ZERO
var spawn_yaw := 0.0
var garage_open := false  # Tab at the railhead
var workshop := false  # the garage turned to its workshop (U): upgrades and repair (Upgrades)
var trailers: Array[Trailer] = []  # the player's, in this valley (scripts/main.gd parks them)
var target := {}  # where the arrow points instead of the railhead ({name, pos}); empty: the railhead

var _depot: Dictionary
var _arrow: Node3D
var _markers := {}  # "depot" -> marker pole


func setup(v: Vehicle, t: Land, locations: Dictionary) -> void:
	vehicle = v
	land = t
	_depot = locations.depot
	_markers["depot"] = _make_marker(_depot, Color(1.0, 0.8, 0.2))
	_arrow = Node3D.new()
	add_child(_arrow)
	var prism := PrismMesh.new()
	prism.size = Vector3(0.7, 1.1, 0.25)
	var arrow_mesh := Psx.mesh(_arrow, prism, Vector3.ZERO, Color(1.0, 0.85, 0.2), 1.5)
	arrow_mesh.rotation.x = -PI * 0.5


## Where the arrow points: a target set (a waypoint), else the railhead.
func current_target() -> Dictionary:
	return target if not target.is_empty() else _depot


func objective_text() -> String:
	if not target.is_empty():
		return "%s  %d m" % [String(target.name).to_upper(), _distance_to(target)]
	if near_depot():
		return "AT THE %s" % String(_depot.name).to_upper()
	return "BACK TO THE %s  %d m" % [String(_depot.name).to_upper(), _distance_to(_depot)]


## The garage: the trucks and trailers, each driven, at the railhead, the player's to drive, or
## not found yet.
func garage_text() -> String:
	if workshop:
		return Upgrades.workshop_text(vehicle, workshop_base())
	var lines := PackedStringArray(["GARAGE - %s" % String(_depot.name).to_upper(), ""])
	var items := garage_items()
	for i in items.size():
		var item: Dictionary = items[i]
		var state := "not found yet"
		if item.truck == vehicle.spec.id:
			state = "driving"
		elif profile.has_rig(item.id):
			state = "at the railhead" if item.truck == "" else "yours: drive it"
		lines.append("%d  %-34s %s" % [i + 1, String(item.title).to_upper(), state])
	return "\n".join(lines)


## The pickup, then every other truck (with the trailer it comes with) and trailer.
func garage_items() -> Array[Dictionary]:
	var pickup := TruckSpec.pickup()
	var items: Array[Dictionary] = [{"id": pickup.id, "title": pickup.title,
		"gives": PackedStringArray([pickup.id]), "truck": pickup.id}]
	items.append_array(Garage.catalogue())  # the scout and the mixer among them
	return items


## The garage's item i: a truck of the player's is driven from here; a trailer waits at the
## railhead; one not the player's is still out there to be found.
func garage_pick(i: int) -> void:
	if workshop:
		message.emit(Upgrades.workshop_pick(vehicle, i, workshop_base(), get_parent().get("infra")))
		return
	var item: Dictionary = garage_items()[i]
	if not profile.has_rig(item.id):
		message.emit("Not yet: the %s is out there to be found" % String(item.title).to_lower())
		return
	if item.truck == "":
		message.emit("The %s waits at the railhead: back up to it and press C" % String(item.title).to_lower())
	elif item.truck != vehicle.spec.id:
		profile.truck = item.truck
		profile.save()
		garage_open = false
		truck_wanted.emit(TruckSpec.find(item.truck))


## The rigs ids are the player's from now on (a truck found, say): saved, and a trailer among
## them waits at the railhead.
func give_rigs(ids: PackedStringArray) -> void:
	profile.add_rigs(ids)
	rigs_changed.emit()


## The truck in play is now v (the garage put it at the railhead).
func set_vehicle(v: Vehicle) -> void:
	vehicle = v


func near_depot() -> bool:
	return _near(_depot)


func _process(_delta: float) -> void:
	if vehicle == null:
		return
	var tpos := _loc_pos(current_target())
	_arrow.global_position = vehicle.global_position + Vector3(0.0, 3.2, 0.0)
	var look := Vector3(tpos.x, _arrow.global_position.y, tpos.z)
	_arrow.visible = _arrow.global_position.distance_to(look) > INTERACT_RADIUS
	if _arrow.visible:
		_arrow.look_at(look, Vector3.UP)

	prompt = ""
	var slow := absf(vehicle.forward_speed) < 2.0
	if garage_open and not (near_depot() and slow):
		garage_open = false
	if not garage_open:
		workshop = false
	if garage_open:
		if workshop:
			prompt = "[1]-[%d] fit or repair   [U] trucks   [Tab] close" % Upgrades.workshop_size(vehicle)
		else:
			prompt = "[1]-[%d] drive   [U] workshop   [Tab] close" % garage_items().size()
	elif near_depot() and slow:
		prompt = "[Tab] Garage"
	elif vehicle.fuel <= 0.0:
		prompt = "Out of fuel! [T] Tow to the %s (the load is lost)" % String(_depot.name).to_lower()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).physical_keycode
		if garage_open:
			var n := Upgrades.workshop_size(vehicle) if workshop else garage_items().size()
			if k == KEY_U:
				workshop = not workshop
				get_viewport().set_input_as_handled()
				return
			if k >= KEY_1 and k < KEY_1 + n:
				garage_pick(k - KEY_1)
				get_viewport().set_input_as_handled()
				return
			if k == KEY_ESCAPE:
				garage_open = false
				get_viewport().set_input_as_handled()
				return
		if k == KEY_TAB and (garage_open or (near_depot() and absf(vehicle.forward_speed) < 2.0)):
			garage_open = not garage_open
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed("recover"):
		recover()


## T: the tow takes the truck (and its trailer) to the railhead; the load on them is lost.
func recover() -> void:
	var lost := Loads.text(vehicle)
	Loads.clear(vehicle)
	vehicle.fuel = maxf(vehicle.fuel, vehicle.spec.fuel_capacity * 0.5)
	towing.emit()
	vehicle.set_down(spawn_pos, spawn_yaw)  # clear of the trucks parked there (Vehicle)
	message.emit("The tow truck dragged you back to the %s%s" % [String(_depot.name).to_lower(),
		(". Lost: " + lost.to_lower()) if lost != "" else ""])


## The base whose workshop the truck is at: the one Infra says (a built outpost, the railhead),
## else the railhead when the truck is at the depot; null elsewhere.
func workshop_base() -> Node:
	var infra: Node = get_parent().get("infra")
	if infra == null:
		return null
	if infra.has_method("base_near"):
		return infra.base_near(Vector2(vehicle.global_position.x, vehicle.global_position.z))
	return infra.get("railhead") if near_depot() else null


## The player's trailer with that TrailerSpec id in this valley, or null.
func _trailer(id: String) -> Trailer:
	for t in trailers:
		if is_instance_valid(t) and t.spec.id == id:
			return t
	return null


func _near(loc: Dictionary) -> bool:
	return _distance_to(loc) < INTERACT_RADIUS


func _distance_to(loc: Dictionary) -> float:
	var p: Vector2 = loc.pos
	return Vector2(vehicle.global_position.x, vehicle.global_position.z).distance_to(p)


func _loc_pos(loc: Dictionary) -> Vector3:
	var p: Vector2 = loc.pos
	return Vector3(p.x, land.get_height(p.x, p.y), p.y)


func _make_marker(loc: Dictionary, color: Color) -> Node3D:
	var root := Node3D.new()
	add_child(root)
	root.position = _loc_pos(loc)
	Psx.box(root, Vector3(0.25, 9.0, 0.25), Vector3(0.0, 4.5, 0.0), color, 1.2)
	Psx.box(root, Vector3(1.0, 1.0, 1.0), Vector3(0.0, 9.5, 0.0), color, 2.5)
	return root
