class_name Chassis
extends RigidBody3D
## Raycast wheels under a body, a truck's or a trailer's. Each wheel is a spring and a damper on
## a ray down from its mount, anti-roll ties the two of an axle, and a tyre grips as the ground
## under it lets it: snow and mud add rolling resistance and cut grip, less so for a big tyre or a
## lugged one. What drives a wheel (request) and how much of its grip it may use (allowed) is the
## body's to set: Vehicle's engine and differentials, a Trailer's brakes.

const SLIP_SPIN := 14.0
const SPIN_FREE := 2.5  # m/s a spinning tread may run ahead of the ground and keep its grip
const SPIN_LOSS := 4.0  # m/s more, and its grip has fallen to SPIN_GRIP
const SPIN_GRIP := 0.75
const DARK := Color(0.12, 0.12, 0.13)


class Wheel:
	var mount: Vector3
	var radius := 0.5
	var front: bool  # steered
	var drive2: bool  # driven in 2WD too
	var sink := 1.0  # how much of the drag of snow and mud its tyre feels (a big one floats)
	var bite := 0.0  # how much of the grip snow and mud take its tread wins back (not on ice)
	var chains := false  # snow chains on it (an upgrade): ice grips, snow bites more (docs/plan.md §8)
	var width := 0.4
	var wet := 0.0  # m of it in water, 0 dry
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


var land: Land  # the ground it drives on
var wheels: Array[Wheel] = []
var axles: Array[Vector2i] = []  # the wheels of an axle, left and right
var rest_length := 0.5
var spring_k := 32000.0
var damping := 3800.0
var anti_roll := 16000.0
var steer := 0.0  # of the steered wheels, radians
var spin_limit := INF  # m/s of tread a spinning driven wheel reaches: the gear's top speed (Vehicle)
var boxes: Array[Dictionary] = []  # its body's collision boxes, {size, pos} (the spec's): what water lifts and drags
var water_depth := 0.0  # m of water over the ground under its deepest wheel, 0 dry


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
	if land:
		w.surface = land.sample(w.point) if land.is_ground(hit.collider) else Terrain.Surface.new()  # on a deck or a building: firm, road grip
		if w.sink != 1.0 or w.bite != 0.0:
			w.surface.rolling *= w.sink
			w.surface.grip = lerpf(w.surface.grip, 1.0, w.bite * (1.0 - w.surface.ice))
		if w.chains:  # ice 0.15 -> 0.4, and 0.3 more bite in snow
			w.surface.grip = lerpf(w.surface.grip, maxf(w.surface.grip, 0.4), w.surface.ice)
			if w.surface.snow > 0.02:
				w.surface.grip = lerpf(w.surface.grip, 1.0, 0.3)
	var comp_vel := clampf((w.compression - prev) / delta, -5.0, 5.0)
	w.load = maxf(spring_k * w.compression + damping * comp_vel, 0.0)
	apply_force(up * w.load, w.point - global_position)


## Water (docs/plan.md §8): each wheel in it is dragged against its motion through the water, the
## more the deeper and the faster, and the body is lifted by half the water its boxes put aside
## (never afloat: at most LIFT_MAX of its weight) and dragged too; the water's motion is the
## current's, so standing in a river it is pushed downstream, the more the deeper. Spray flies off
## a wheel going in fast. Sets water_depth and each wheel's wet.
const WATER := 1000.0  # kg/m3
const WHEEL_DRAG := 0.6  # its drag coefficient, on the tyre's wet side
const BODY_DRAG := 0.9
const LIFT_MAX := 0.35  # of its weight


func _apply_water() -> void:
	water_depth = 0.0
	if land == null:
		return
	var down := -global_transform.basis.y
	var any := false
	for w in wheels:
		var hub := global_transform * w.mount + down * (w.dist - w.radius)
		var level := land.water_level(Vector2(hub.x, hub.z))
		var bottom := hub.y - w.radius
		w.wet = clampf(level - bottom, 0.0, 2.0 * w.radius) if level > -INF else 0.0
		if w.wet <= 0.0:
			continue
		any = true
		water_depth = maxf(water_depth, level - bottom)
		var flow := land.water_current(Vector2(hub.x, hub.z))
		var rel := point_velocity(hub) - Vector3(flow.x, 0.0, flow.y)
		rel.y *= 0.3
		var area := w.wet * w.width * 2.0  # the tyre and the wheel well before it
		apply_force(-rel * rel.length() * 0.5 * WATER * WHEEL_DRAG * area - rel * 300.0 * w.wet, hub - global_position)
	if not any and boxes.is_empty():
		return
	var lift_total := 0.0
	var pushes: Array = []
	for b in boxes:
		var c: Vector3 = global_transform * (b.pos as Vector3)
		var level := land.water_level(Vector2(c.x, c.z))
		if level == -INF:
			continue
		var size: Vector3 = b.size
		var sub := clampf(level - (c.y - size.y * 0.5), 0.0, size.y)
		if sub <= 0.0:
			continue
		water_depth = maxf(water_depth, level - land.get_height(c.x, c.z))
		var at := Vector3(c.x, c.y - size.y * 0.5 + sub * 0.5, c.z)
		var lift := 0.5 * WATER * 9.8 * size.x * size.z * sub
		lift_total += lift
		var flow := land.water_current(Vector2(c.x, c.z))
		var rel := point_velocity(at) - Vector3(flow.x, 0.0, flow.y)
		rel.y = 0.0
		var local := global_transform.basis.inverse() * rel
		var area := sub * (absf(local.z) * size.x + absf(local.x) * size.z) / maxf(rel.length(), 0.001)
		pushes.append([at, lift, -rel * rel.length() * 0.5 * WATER * BODY_DRAG * area])
	var scale := minf(1.0, LIFT_MAX * mass * 9.8 / maxf(lift_total, 0.001))
	for p in pushes:
		apply_force(Vector3.UP * p[1] * scale + p[2], p[0] - global_position)


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
			# Spinning, it grips less the faster it runs ahead of the ground: up to the gear's top
			# speed (spin_limit), so in mud a low gear digs in where a high one polishes it.
			var over := clampf((_spin_tread(w) - absf(v_long) - SPIN_FREE) / SPIN_LOSS, 0.0, 1.0) * clampf(w.surface.mud, 0.0, 1.0)
			f_long = signf(w.request) * w.allowed * 0.85 * lerpf(1.0, SPIN_GRIP, over)
		else:
			f_long = w.request
	var f_lat := -v_lat * wheel_mass / delta * 0.5

	var tire := Vector2(f_long, f_lat)
	if tire.length() > w.traction:
		tire = tire.normalized() * w.traction
	var roll := w.surface.rolling * w.load * clampf(v_long * 8.0, -1.0, 1.0)
	apply_force(fwd * (tire.x - roll) + right * tire.y, w.point - global_position)

	w.spin_speed = signf(w.request) * _spin_tread(w) / w.radius if w.slip else v_long / w.radius
	if land and (w.surface.snow > 0.02 or w.surface.mud > 0.05):
		land.compact(w.point, 0.08 if w.slip else 0.25)


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
		var splash := w.wet > 0.05 and linear_velocity.length() > 2.5  # through water, fast
		var spraying := w.contact and w.slip and (w.surface.snow > 0.05 or w.surface.mud > 0.1)
		w.spray.emitting = spraying or splash
		if splash:
			w.spray.global_position = w.point + up * w.wet
			w.spray.direction = Vector3(0.0, 1.0, 0.5)
			w.spray.color = Color(0.75, 0.82, 0.88)
		elif spraying:
			w.spray.global_position = w.point + up * 0.15
			w.spray.direction = Vector3(0.0, 1.0, 1.2 * signf(w.request))
			w.spray.color = Color(0.3, 0.22, 0.15) if w.surface.mud > w.surface.snow else _layer_spray()


## What flies off a spinning wheel that is not mud: snow, sand or dust, as the valley has it.
func _layer_spray() -> Color:
	return land.valley_at(Vector2(global_position.x, global_position.z)).layer_color.lightened(0.15) if land else Color(0.9, 0.93, 1.0)


func _add_wheel(mount: Vector3, radius: float, width: float, front: bool, drive2: bool, rim_color := Color(0.75, 0.3, 0.1)) -> Wheel:
	var w := Wheel.new()
	w.mount = mount
	w.radius = radius
	w.front = front
	w.drive2 = drive2
	w.dist = rest_length + radius
	w.width = width
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


## How fast a spinning wheel's tread runs (m/s): as fast as it spins, up to spin_limit.
func _spin_tread(w: Wheel) -> float:
	return minf(SLIP_SPIN * w.radius, spin_limit)
