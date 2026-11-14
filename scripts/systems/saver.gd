class_name Saver
extends Node
## The whole game into the profile and back (docs/plan.md §11): every truck out on the map with
## its fuel and load and the trailer it has hitched, the trailers standing on their own, the
## earthworks (with the map's version), the fog, the scout's track, the waypoint and the stats;
## Infra keeps the buildings and sites in it itself. It saves on every change Infra reports, when a
## truck is switched, the earthworks at most every DIG_EVERY s while the ground changes and when B
## or V is let go, every TRUCKS_EVERY s for where the trucks stand, when the window loses focus
## or closes, and on Esc to the title. A save loads the map as made, then lays the earthworks over it.

const DIG_EVERY := 5.0
const TRUCKS_EVERY := 30.0
## Where the railhead's trucks stand at the start of a new game, about the spawn (across, along),
## and the trailer each has hitched (docs/plan.md §7).
const START := [
	{"id": "pickup", "at": Vector2(9.0, -2.0), "trailer": "trailer"},
	{"id": "tractor", "at": Vector2(-9.0, -2.0), "trailer": "farm"},
	{"id": "mixer", "at": Vector2(9.0, 16.0), "trailer": ""},
]

var main: Node  # scripts/main.gd

var _dig_timer := 0.0
var _trucks_timer := 0.0
var _shifted_seen := 0.0
var _restoring := false


func _ready() -> void:
	main.infra.changed.connect(collect)
	main.fleet.switched.connect(func(_v: Vehicle) -> void: save())
	main.leave.connect(save)  # Esc to the title: saved before the world goes


## Everything but the buildings into the profile (Infra's own save writes it out).
func collect() -> void:
	if _restoring or not is_inside_tree() or not main.vehicle.is_inside_tree():
		return
	if main.fleet.trucks.any(func(v: Vehicle) -> bool: return is_instance_valid(v) and not v.is_inside_tree()):
		return  # on the way out: what is left of the world is not the game
	var p: Profile = main.profile
	var fleet: Fleet = main.fleet
	var out: Array = []
	for v in fleet.trucks:
		if not is_instance_valid(v) or not v.is_inside_tree():
			continue
		out.append(_truck(v))
	p.fleet = out
	var standing: Array = []
	for t: Trailer in main.contracts.trailers:
		if is_instance_valid(t) and t.is_inside_tree() and t.truck == null:
			standing.append({"id": t.spec.id, "pos": t.global_position, "yaw": t.global_rotation.y, "hold": t.hold.to_dict()})
	p.trailers = standing
	p.truck = main.vehicle.spec.id
	p.earthworks = main.land.save_earthworks()
	p.fog = main.land.fog.to_save()
	p.scout_track = main.map_screen.scout_track
	p.waypoint = main.contracts.target.pos if not main.contracts.target.is_empty() else null
	p.stats = main.infra.stats.duplicate()
	_shifted_seen = main.land.earthworks.shifted


func save() -> void:
	if not _restoring:
		main.infra.write()
	collect()
	main.profile.save()


static func _truck(v: Vehicle) -> Dictionary:
	var d := {"id": v.spec.id, "pos": v.global_position, "yaw": v.global_rotation.y, "fuel": v.fuel,
		"hold": v.hold.to_dict(), "driven": v.driven, "trailer": ""}
	if v.trailer:
		d.trailer = v.trailer.spec.id
		d.trailer_hold = v.trailer.hold.to_dict()
	return d


## The profile laid over the world main has just built: the earthworks over the map as made, the
## fog, the track, the waypoint, then the trucks and trailers where they were left. A new game sets
## out the railhead's trucks instead.
func restore() -> void:
	var p: Profile = main.profile
	var land: Land = main.land
	_restoring = true
	if not p.earthworks.is_empty() and not land.load_earthworks(p.earthworks):
		main.hud.show_message("The map has changed since this save: the earthworks on it are gone")
	main.infra.refresh()
	if not p.fog.is_empty():
		land.fog.load_save(p.fog)
	main.map_screen.scout_track = p.scout_track
	if p.waypoint != null:
		main.contracts.target = {"name": "Waypoint", "pos": p.waypoint}
	_shifted_seen = land.earthworks.shifted
	if not p.fleet.is_empty():
		await _lay_trucks(p)
	elif p.new_game:
		p.new_game = false
		await _set_out()
		main.hud.show_message("The upper village calls on the radio: the road is cut. Bring us fuel 800 L and parts 2")
	_restoring = false
	save()


## The trucks as saved: the driven one moved to where it was, the rest parked; their trailers
## hitched again, and the others stood where they were.
func _lay_trucks(p: Profile) -> void:
	var hitches: Array = []  # [truck, trailer id, trailer hold]
	for d: Dictionary in p.fleet:
		var spec := TruckSpec.find(str(d.get("id", "")))
		if spec == null or typeof(d.get("pos")) != TYPE_VECTOR3:
			continue
		var v: Vehicle
		if bool(d.get("driven", false)) and main.vehicle.spec.id == spec.id:
			v = main.vehicle
			v.teleport(d.pos, float(d.get("yaw", 0.0)))
		else:
			v = main.park_truck(spec, d.pos, float(d.get("yaw", 0.0)))
		v.fuel = clampf(float(d.get("fuel", v.fuel)), 0.0, spec.fuel_capacity)
		if typeof(d.get("hold")) == TYPE_DICTIONARY:
			v.hold.from_dict(d.hold)
		if str(d.get("trailer", "")) != "":
			hitches.append([v, str(d.trailer), d.get("trailer_hold", {})])
	for d: Dictionary in p.trailers:
		var t: Trailer = main.contracts._trailer(str(d.get("id", "")))
		if t and typeof(d.get("pos")) == TYPE_VECTOR3:
			t.stand_on(Vector2(d.pos.x, d.pos.z), float(d.get("yaw", 0.0)))
			if typeof(d.get("hold")) == TYPE_DICTIONARY:
				t.hold.from_dict(d.hold)
	await _hitch_all(hitches)


## A new game: the pickup with its trailer, the tractor with its tipper and the mixer stand by the
## railhead, the scout driven (docs/plan.md §7).
func _set_out() -> void:
	main.contracts.give_rigs(PackedStringArray(["trailer", "tractor", "farm"]))
	var spawn: Vector3 = main.contracts.spawn_pos
	var yaw: float = main.contracts.spawn_yaw
	var turn := Basis(Vector3.UP, yaw)
	var hitches: Array = []
	for s in START:
		var spec := TruckSpec.find(s.id)
		if spec == null or main.fleet.find(s.id):
			continue
		var at: Vector3 = spawn + turn * Vector3(s.at.x, 0.0, s.at.y)
		at.y = main.land.get_height(at.x, at.z) + 1.5
		var v: Vehicle = main.park_truck(spec, at, yaw)
		if s.trailer != "":
			hitches.append([v, s.trailer, {}])
	await _hitch_all(hitches)


## Each [truck, trailer id, hold]: the trailer stood behind the truck and hitched.
func _hitch_all(hitches: Array) -> void:
	if hitches.is_empty():
		return
	await get_tree().physics_frame
	await get_tree().physics_frame
	for h in hitches:
		var v: Vehicle = h[0]
		var t: Trailer = main.contracts._trailer(h[1])
		if t == null or not is_instance_valid(v):
			continue
		t.place(t.behind(Transform3D(v.global_transform.basis, v.hitch_point())))
		if typeof(h[2]) == TYPE_DICTIONARY and not (h[2] as Dictionary).is_empty():
			t.hold.from_dict(h[2])
	for i in 3:
		await get_tree().physics_frame
	for h in hitches:
		var v: Vehicle = h[0]
		var t: Trailer = main.contracts._trailer(h[1])
		if t and is_instance_valid(v) and t.truck == null:
			v.hitch(t)


func _process(delta: float) -> void:
	if _restoring or main == null or main.land == null:
		return
	_dig_timer += delta
	_trucks_timer += delta
	var dug: bool = main.land.earthworks.shifted != _shifted_seen
	if dug and _dig_timer >= DIG_EVERY:
		_dig_timer = 0.0
		save()
	elif dug and (Input.is_action_just_released("dig") or Input.is_action_just_released("tip")):
		save()
	elif _trucks_timer >= TRUCKS_EVERY:
		_trucks_timer = 0.0
		save()


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST]:
		if main and main.profile and main.profile.path != "":
			save()
