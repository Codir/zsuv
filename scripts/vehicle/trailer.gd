class_name Trailer
extends Chassis
## A trailer on raycast wheels (Chassis), built from its TrailerSpec. Unhitched it stands on its
## wheels and, at the front, on its stand, its brakes on; hitched to a truck (Vehicle.trailer),
## its brakes follow the truck's. A load on it adds its weight and shows.

const STAND_K := 40000.0
const STAND_DAMPING := 4000.0
const STAND_TRAVEL := 0.6

var spec: TrailerSpec  # set before it enters the tree; the pickup's trailer if not
var truck: Vehicle  # hitched to; null: standing on its own
var load := ""  # the kind of load on it; "" none
var _loads := {}  # kind -> its node


func _ready() -> void:
	if spec == null:
		spec = TrailerSpec.trailer()
	mass = spec.mass
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = spec.center_of_mass
	can_sleep = false
	angular_damp = 0.4
	rest_length = spec.rest_length
	spring_k = spec.spring_k
	damping = spec.damping
	anti_roll = spec.anti_roll
	for b in spec.shapes:
		_add_box_shape(b.size, b.pos)
	call("_build_" + spec.body)
	for w in spec.wheels:
		_add_wheel(w.mount, w.radius, w.width, false, false, Color(0.4, 0.4, 0.42))
	axles = spec.axles


## A load of kind on it, or none ("").
func set_load(kind: String) -> void:
	load = kind
	mass = spec.mass + float(spec.cargo_mass.get(kind, 0.0))
	for k in _loads:
		_loads[k].visible = k == kind


func _physics_process(delta: float) -> void:
	_update_wheels(delta)
	var brake := truck.braking if truck else 1.0
	for w in wheels:
		w.request = 0.0
		w.allowed = w.traction
		_apply_tire(w, brake, delta)
	if truck == null:
		_stand(delta)


func _process(delta: float) -> void:
	_animate_wheels(delta)


## Unhitched, the front rests on its stand: a stiff spring down to the ground, and the ground's
## friction holding it where it stands.
func _stand(delta: float) -> void:
	var up := global_transform.basis.y
	var top := global_transform * (spec.stand + Vector3(0.0, STAND_TRAVEL, 0.0))
	var q := PhysicsRayQueryParameters3D.create(top, top - up * STAND_TRAVEL)
	q.exclude = _ray_exclude()
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return
	var p: Vector3 = hit.position
	var compression := STAND_TRAVEL - top.distance_to(p)
	var v := point_velocity(p)
	var f := maxf(STAND_K * compression - STAND_DAMPING * v.dot(up), 0.0)
	var slide := v - up * v.dot(up)
	apply_force(up * f - slide * (mass * 0.5 / delta) * 0.3, p - global_position)


## The pickup's trailer: a low steel box on one axle, a drawbar to the coupler.
func _build_trailer() -> void:
	var grey := Color(0.36, 0.38, 0.4)
	Psx.box(self, Vector3(1.8, 0.12, 3.0), Vector3(0.0, 0.06, 0.0), grey)
	for side in [-1.0, 1.0]:
		Psx.box(self, Vector3(0.06, 0.45, 3.0), Vector3(0.87 * side, 0.34, 0.0), grey)
	Psx.box(self, Vector3(1.8, 0.45, 0.06), Vector3(0.0, 0.34, 1.47), grey)
	Psx.box(self, Vector3(1.8, 0.45, 0.06), Vector3(0.0, 0.34, -1.47), grey)
	Psx.box(self, Vector3(0.12, 0.1, 1.1), Vector3(0.0, 0.08, -2.05), DARK)
	_loads["double"] = _crates(Vector3(0.0, 0.55, 0.0))


## The tractor's farm trailer: a high-sided box on two axles.
func _build_farm() -> void:
	var green := Color(0.3, 0.42, 0.26)
	Psx.box(self, Vector3(2.3, 1.0, 4.6), Vector3(0.0, 0.6, 0.0), green)
	Psx.box(self, Vector3(0.14, 0.12, 1.4), Vector3(0.0, 0.2, -2.9), DARK)
	var heap := Node3D.new()
	Psx.box(heap, Vector3(2.1, 0.4, 4.4), Vector3(0.0, 1.2, 0.0), Color(0.78, 0.66, 0.36))
	add_child(heap)
	heap.visible = false
	_loads["bulk"] = heap


## The semi truck's flatbed: a long deck on two axles at the back.
func _build_semi_trailer() -> void:
	Psx.box(self, Vector3(2.4, 0.3, 11.0), Vector3(0.0, 0.95, 0.0), Color(0.28, 0.3, 0.34))
	var logs := Node3D.new()
	for i in 6:
		var trunk := Psx.mesh(logs, Psx.cylinder(0.3, 0.3, 10.0, 8), Vector3(-0.75 + (i % 3) * 0.75, 1.4 + (i / 3) * 0.55, 0.0), Color(0.45, 0.32, 0.2))
		trunk.rotation.x = PI * 0.5
	add_child(logs)
	logs.visible = false
	_loads["long"] = logs


func _crates(at: Vector3) -> Node3D:
	var crates := Node3D.new()
	Psx.box(crates, Vector3(1.5, 0.8, 2.4), at, Color(0.55, 0.38, 0.2))
	add_child(crates)
	crates.visible = false
	return crates
