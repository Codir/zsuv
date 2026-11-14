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
const FETCH := 50.0  # litres from a base's tank to fetch a truck out on the map to it (docs/plan.md §6)
const WAYPOINT_CLEAR := 12.0  # m: a click this near the waypoint on the map clears it

var vehicle: Vehicle
var land: Land
var profile := Profile.new()  # the player's, saved; one kept in memory when there is none
var infra: Infra  # the bases (the railhead, the outposts); scripts/main.gd sets it
var fleet: Fleet  # the trucks out on the map; scripts/main.gd sets it
var prompt := ""
var spawn_pos := Vector3.ZERO  # the railhead's spawn
var spawn_yaw := 0.0
var base: Site  # the base trucks are set down at now (the tow's, the garage's); null: the railhead
var garage_open := false  # Tab at a base
var trailers: Array[Trailer] = []  # the player's, in this valley (scripts/main.gd parks them)
var target := {}  # a waypoint set on the map ({name, pos}); empty: none
var goal := {}  # the upper village ({name, pos}): where the arrow points with no waypoint

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


## Where the arrow points: the waypoint, else the goal, else the railhead.
func current_target() -> Dictionary:
	if not target.is_empty():
		return target
	return goal if not goal.is_empty() else _depot


func objective_text() -> String:
	var b := here_base()
	if not target.is_empty():
		return "%s  %d m" % [String(target.name).to_upper(), _distance_to(target)]
	if b:
		return "AT THE %s" % base_name(b).to_upper()
	if not goal.is_empty():
		return "%s  %d m" % [String(goal.name).to_upper(), _distance_to(goal)]
	return "BACK TO THE %s  %d m" % [String(_depot.name).to_upper(), _distance_to(_depot)]


## A click on the paper map at p: a waypoint there, or, on the waypoint, none.
func toggle_waypoint(p: Vector2) -> void:
	if not target.is_empty() and (target.pos as Vector2).distance_to(p) < WAYPOINT_CLEAR:
		target = {}
	else:
		target = {"name": "Waypoint", "pos": p}


## The base the truck is at (the railhead, an outpost), or null.
func here_base() -> Site:
	var p := Vector2(vehicle.global_position.x, vehicle.global_position.z)
	if infra:
		return infra.base_near(p)
	return null


func base_name(b: Site) -> String:
	return String(_depot.name) if b == null or (infra and b == infra.railhead) else b.spec.title


## Where a truck is set down now: {pos, yaw} at the base the last tow or garage used.
func spawn_now() -> Dictionary:
	if base == null or infra == null or base == infra.railhead or not is_instance_valid(base):
		return {"pos": spawn_pos, "yaw": spawn_yaw}
	return infra.base_spawn(base)


## The garage: the trucks and trailers, each driven, at the base, the player's to drive, or not
## found yet.
func garage_text() -> String:
	var lines := PackedStringArray(["GARAGE - %s" % base_name(here_base() if here_base() else base).to_upper(), ""])
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


## The garage's item i: a truck of the player's is driven from here (one out on the map is fetched
## here for FETCH litres from the base's tank); a trailer waits at the railhead; one not the
## player's is still out there to be found.
func garage_pick(i: int) -> void:
	var item: Dictionary = garage_items()[i]
	if not profile.has_rig(item.id):
		message.emit("Not yet: the %s is out there to be found" % String(item.title).to_lower())
		return
	if item.truck == "":
		message.emit("The %s waits at the railhead: back up to it and press C" % String(item.title).to_lower())
	elif item.truck != vehicle.spec.id:
		var b := here_base()
		var out: Vehicle = fleet.find(item.truck) if fleet else null
		if out and infra and b:
			if b.available("fuel") < FETCH:
				message.emit("The tank here is dry: fetching the %s takes %d L" % [String(item.title).to_lower(), FETCH])
				return
			infra.draw(b, "fuel", FETCH)
			message.emit("The %s is fetched here: %d L from the tank" % [String(item.title).to_lower(), FETCH])
		base = b
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


## Whether the truck is at a base (the railhead, an outpost): its garage opens there.
func near_depot() -> bool:
	return here_base() != null if infra else _near(_depot)


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
	if garage_open:
		prompt = "[1]-[%d] drive   [Tab] close" % garage_items().size()
	elif near_depot() and slow:
		prompt = "[Tab] Garage"
	elif vehicle.fuel <= 0.0:
		prompt = "Out of fuel! [T] Tow to the nearest base (the load is lost)"


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).physical_keycode
		if garage_open:
			var n := garage_items().size()
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


## T: the tow takes the truck (and its trailer) to the nearest base; the load on them is lost.
func recover() -> void:
	var lost := Loads.text(vehicle)
	Loads.clear(vehicle)
	vehicle.fuel = maxf(vehicle.fuel, vehicle.spec.fuel_capacity * 0.5)
	base = infra.nearest_base(Vector2(vehicle.global_position.x, vehicle.global_position.z)) if infra else null
	towing.emit()
	var at := spawn_now()
	vehicle.set_down(at.pos, at.yaw)  # clear of the trucks parked there (Vehicle)
	message.emit("The tow truck dragged you back to the %s%s" % [base_name(base).to_lower(),
		(". Lost: " + lost.to_lower()) if lost != "" else ""])


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
