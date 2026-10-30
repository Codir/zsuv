class_name Chassis
extends RigidBody3D
## Raycast wheels under a body, a truck's or a trailer's. Each wheel is a spring and a damper on
## a ray down from its mount, anti-roll ties the two of an axle, and a tyre grips as the ground
## under it lets it: snow and mud add rolling resistance and cut grip. What drives a wheel
## (request) and how much of its grip it may use (allowed) is the body's to set: Vehicle's engine
## and differentials, a Trailer's brakes.

const SLIP_SPIN := 14.0
const DARK := Color(0.12, 0.12, 0.13)


class Wheel:
	var mount: Vector3
	var radius := 0.5
	var front: bool  # steered
	var drive2: bool  # driven in 2WD too
	var pivot: Node3D
	var spin: Node3D
	var spray: CPUParticles3D
	var contact := false
	var compression := 0.0
	var dist := 0.0
	var load := 0.0
	var point := Vector3.ZERO
	var normal := Vector3.UP
	var surface := Terrain.Surface.new()
	var traction := 0.0
	var allowed := 0.0
	var request := 0.0
	var spin_angle := 0.0
	var spin_speed := 0.0
	var slip := false


var terrain: Terrain
var wheels: Array[Wheel] = []
var axles: Array[Vector2i] = []  # the wheels of an axle, left and right
var rest_length := 0.5
var spring_k := 32000.0
var damping := 3800.0
var anti_roll := 16000.0
var steer := 0.0  # of the steered wheels, radians


## Springs, dampers and anti-roll for every wheel, then each wheel's grip on what it stands on.
func _update_wheels(delta: float) -> void:
	var space := get_world_3d().direct_space_state
	var up := global_transform.basis.y
	for w in wheels:
		_update_suspension(w, space, up, delta)
	for a in axles:
		_apply_anti_roll(wheels[a.x], wheels[a.y], up)
	for w in wheels:
		w.traction = w.load * w.surface.grip if w.contact else 0.0


## What a wheel's ray must not hit: the body itself (and whatever it is hitched to).
func _ray_exclude() -> Array[RID]:
	return [get_rid()]


func _update_suspension(w: Wheel, space: PhysicsDirectSpaceState3D, up: Vector3, delta: float) -> void:
	var origin := global_transform * w.mount
	var ray_len := rest_length + w.radius
	var q := PhysicsRayQueryParameters3D.create(origin, origin - up * ray_len)
	q.exclude = _ray_exclude()
	var hit := space.intersect_ray(q)
	var prev := w.compression
	if hit.is_empty():
		w.contact = false
		w.compression = 0.0
		w.dist = ray_len
		w.load = 0.0
		return
	w.contact = true
	w.point = hit.position
	w.normal = hit.normal
	w.dist = origin.distance_to(w.point)
	w.compression = ray_len - w.dist
	if terrain:
		w.surface = terrain.sample(w.point)
	var comp_vel := clampf((w.compression - prev) / delta, -5.0, 5.0)
	w.load = maxf(spring_k * w.compression + damping * comp_vel, 0.0)
	apply_force(up * w.load, w.point - global_position)


func _apply_anti_roll(a: Wheel, b: Wheel, up: Vector3) -> void:
	if not (a.contact and b.contact):
		return
	var f := (a.compression - b.compression) * anti_roll
	apply_force(up * f, global_transform * a.mount - global_position)
	apply_force(-up * f, global_transform * b.mount - global_position)


## The tyre's force at the contact: request along the wheel up to what it is allowed, the brake
## (0..1) holding it, sideways grip, rolling resistance; all within its traction.
func _apply_tire(w: Wheel, brake: float, delta: float) -> void:
	w.slip = false
	if not w.contact:
		var free_spin := signf(w.request) * SLIP_SPIN if w.request != 0.0 else 0.0
		w.spin_speed = lerpf(w.spin_speed, free_spin, delta * 3.0)
		return
	var basis := global_transform.basis
	var turn := steer if w.front else 0.0
	var n := w.normal
	var fwd := (-basis.z).rotated(basis.y, turn)
	var right := basis.x.rotated(basis.y, turn)
	fwd = (fwd - n * fwd.dot(n)).normalized()
	right = (right - n * right.dot(n)).normalized()
	var vel := point_velocity(w.point)
	var v_long := vel.dot(fwd)
	var v_lat := vel.dot(right)
	var wheel_mass := mass / wheels.size()

	var f_long := 0.0
	if brake > 0.0:
		f_long = -v_long * wheel_mass / delta * brake
	elif w.request != 0.0:
		if absf(w.request) > w.allowed:
			w.slip = true
			f_long = signf(w.request) * w.allowed * 0.85
		else:
			f_long = w.request
	var f_lat := -v_lat * wheel_mass / delta * 0.5

	var tire := Vector2(f_long, f_lat)
	if tire.length() > w.traction:
		tire = tire.normalized() * w.traction
	var roll := w.surface.rolling * w.load * clampf(v_long * 8.0, -1.0, 1.0)
	apply_force(fwd * (tire.x - roll) + right * tire.y, w.point - global_position)

	w.spin_speed = signf(w.request) * SLIP_SPIN if w.slip else v_long / w.radius
	if terrain and (w.surface.snow > 0.02 or w.surface.mud > 0.05):
		terrain.compact(w.point, 0.08 if w.slip else 0.25)


func point_velocity(p: Vector3) -> Vector3:
	return linear_velocity + angular_velocity.cross(p - global_transform * center_of_mass)


## The wheels where their springs hold them, turned, spinning, throwing snow or mud as they slip.
func _animate_wheels(delta: float) -> void:
	var up := global_transform.basis.y
	for w in wheels:
		w.pivot.position = w.mount + Vector3(0.0, -(w.dist - w.radius), 0.0)
		if w.front:
			w.pivot.rotation.y = steer
		w.spin_angle = wrapf(w.spin_angle + w.spin_speed * delta, -PI, PI)
		w.spin.rotation.x = -w.spin_angle
		var spraying := w.contact and w.slip and (w.surface.snow > 0.05 or w.surface.mud > 0.1)
		w.spray.emitting = spraying
		if spraying:
			w.spray.global_position = w.point + up * 0.15
			w.spray.direction = Vector3(0.0, 1.0, 1.2 * signf(w.request))
			w.spray.color = Color(0.3, 0.22, 0.15) if w.surface.mud > w.surface.snow else _layer_spray()


## What flies off a spinning wheel that is not mud: snow, sand or dust, as the valley has it.
func _layer_spray() -> Color:
	return terrain.valley.layer_color.lightened(0.15) if terrain else Color(0.9, 0.93, 1.0)


func _add_wheel(mount: Vector3, radius: float, width: float, front: bool, drive2: bool, rim_color := Color(0.75, 0.3, 0.1)) -> Wheel:
	var w := Wheel.new()
	w.mount = mount
	w.radius = radius
	w.front = front
	w.drive2 = drive2
	w.dist = rest_length + radius
	w.pivot = Node3D.new()
	w.pivot.position = mount
	add_child(w.pivot)
	w.spin = Node3D.new()
	w.pivot.add_child(w.spin)
	var tire := Psx.mesh(w.spin, Psx.cylinder(radius, radius, width, 10), Vector3.ZERO, DARK)
	tire.rotation.z = PI * 0.5
	var rim := Psx.mesh(w.spin, Psx.cylinder(radius * 0.56, radius * 0.56, width + 0.02, 8), Vector3.ZERO, Color(0.55, 0.55, 0.58))
	rim.rotation.z = PI * 0.5
	Psx.box(w.spin, Vector3(width + 0.04, 0.08, 0.2), Vector3(0.0, radius * 0.36, 0.0), rim_color)

	w.spray = CPUParticles3D.new()
	w.spray.emitting = false
	w.spray.amount = 24
	w.spray.lifetime = 0.7
	w.spray.local_coords = false
	w.spray.spread = 25.0
	w.spray.initial_velocity_min = 2.5
	w.spray.initial_velocity_max = 4.5
	w.spray.gravity = Vector3(0.0, -9.8, 0.0)
	w.spray.scale_amount_min = 0.6
	w.spray.scale_amount_max = 1.2
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE * 0.12
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	bm.material = m
	w.spray.mesh = bm
	add_child(w.spray)
	wheels.append(w)
	return w


func _add_box_shape(size: Vector3, pos: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = pos
	add_child(cs)
