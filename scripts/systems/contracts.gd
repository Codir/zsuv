class_name Contracts
extends Node3D
## A simple delivery loop: pick up cargo at the depot -> haul it -> get paid.

signal message(text: String)

const INTERACT_RADIUS := 12.0
const RECOVER_COST := 100

var vehicle: Vehicle
var terrain: Terrain
var profile := Profile.new()  # the player's, saved; one kept in memory when there is none
var money: int:
	get:
		return profile.money
	set(value):
		profile.money = value
		profile.save()
var prompt := ""
var spawn_pos := Vector3.ZERO
var spawn_yaw := 0.0

var _depot: Dictionary
var _jobs: Array[Dictionary] = []
var _job_index := 0
var _arrow: Node3D
var _markers: Array[Node3D] = []


func setup(v: Vehicle, t: Terrain, locations: Dictionary) -> void:
	vehicle = v
	terrain = t
	_depot = locations.depot
	_jobs = []
	for loc in locations.values():
		if loc.has("cargo"):
			_jobs.append({"name": loc.name, "cargo": loc.cargo, "loc": loc, "reward": loc.reward})
	_markers.append(_make_marker(_depot, Color(1.0, 0.8, 0.2)))
	for job in _jobs:
		_markers.append(_make_marker(job.loc, Color(0.3, 1.0, 0.4)))

	_arrow = Node3D.new()
	add_child(_arrow)
	var prism := PrismMesh.new()
	prism.size = Vector3(0.7, 1.1, 0.25)
	var arrow_mesh := Psx.mesh(_arrow, prism, Vector3.ZERO, Color(1.0, 0.85, 0.2), 1.5)
	arrow_mesh.rotation.x = -PI * 0.5
	_update_markers()


func current_target() -> Dictionary:
	return _jobs[_job_index].loc if vehicle.has_cargo else _depot


func objective_text() -> String:
	var job := _jobs[_job_index]
	if vehicle.has_cargo:
		return "DELIVER: %s -> %s  %d m  +$%d" % [job.cargo, job.name, _distance_to(job.loc), job.reward]
	return "PICK UP AT DEPOT: %s for %s  %d m" % [job.cargo, job.name, _distance_to(_depot)]


func _process(_delta: float) -> void:
	if vehicle == null:
		return
	var job := _jobs[_job_index]
	var target: Dictionary = job.loc if vehicle.has_cargo else _depot
	var tpos := _loc_pos(target)
	_arrow.global_position = vehicle.global_position + Vector3(0.0, 3.2, 0.0)
	var look := Vector3(tpos.x, _arrow.global_position.y, tpos.z)
	_arrow.visible = _arrow.global_position.distance_to(look) > INTERACT_RADIUS
	if _arrow.visible:
		_arrow.look_at(look, Vector3.UP)

	prompt = ""
	var slow := absf(vehicle.forward_speed) < 2.0
	if vehicle.has_cargo and _near(job.loc):
		prompt = "[E] Unload" if slow else "Stop to unload"
	elif _near(_depot):
		var action := "Refuel" if vehicle.has_cargo else "Load %s + refuel" % job.cargo
		prompt = ("[E] " + action) if slow else "Stop at the depot"
	elif vehicle.fuel <= 0.0:
		prompt = "Out of fuel! [T] Tow to depot (-$%d)" % RECOVER_COST


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_interact()
	elif event.is_action_pressed("recover"):
		recover()


func recover() -> void:
	money -= RECOVER_COST
	vehicle.fuel = maxf(vehicle.fuel, Vehicle.FUEL_CAPACITY * 0.5)
	vehicle.teleport(spawn_pos, spawn_yaw)
	message.emit("The tow truck dragged you back to the depot. -$%d" % RECOVER_COST)


func _interact() -> void:
	if absf(vehicle.forward_speed) >= 2.0:
		return
	var job := _jobs[_job_index]
	if vehicle.has_cargo and _near(job.loc):
		vehicle.set_cargo(false)
		money += int(job.reward)
		message.emit("Delivered to %s! +$%d" % [job.name, job.reward])
		_job_index = (_job_index + 1) % _jobs.size()
		_update_markers()
	elif _near(_depot):
		vehicle.fuel = Vehicle.FUEL_CAPACITY
		if not vehicle.has_cargo:
			vehicle.set_cargo(true)
			message.emit("Loaded: %s. Head for %s" % [job.cargo, job.name])
			_update_markers()
		else:
			message.emit("Tank is full")


func _update_markers() -> void:
	var has_cargo := vehicle.has_cargo
	_markers[0].visible = not has_cargo
	for i in _jobs.size():
		_markers[i + 1].visible = has_cargo and i == _job_index


func _near(loc: Dictionary) -> bool:
	return _distance_to(loc) < INTERACT_RADIUS


func _distance_to(loc: Dictionary) -> float:
	var p: Vector2 = loc.pos
	return Vector2(vehicle.global_position.x, vehicle.global_position.z).distance_to(p)


func _loc_pos(loc: Dictionary) -> Vector3:
	var p: Vector2 = loc.pos
	return Vector3(p.x, terrain.get_height(p.x, p.y), p.y)


func _make_marker(loc: Dictionary, color: Color) -> Node3D:
	var root := Node3D.new()
	add_child(root)
	root.position = _loc_pos(loc)
	Psx.box(root, Vector3(0.25, 9.0, 0.25), Vector3(0.0, 4.5, 0.0), color, 1.2)
	Psx.box(root, Vector3(1.0, 1.0, 1.0), Vector3(0.0, 9.5, 0.0), color, 2.5)
	return root
